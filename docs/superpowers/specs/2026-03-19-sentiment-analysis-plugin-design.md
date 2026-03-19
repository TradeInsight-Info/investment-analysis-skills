# Sentiment Analysis Plugin — Design Spec

## Overview

A Claude Code plugin providing 24-hour market sentiment analysis for publicly traded companies. Aggregates signals from financial news, Reddit (r/wallstreetbets + r/stocks), and StockTwits into a normalized composite score from -10 to +10.

The plugin lives alongside `fundamental-analysis/` in the same repo and follows identical plugin conventions: YAML frontmatter skills, agents with parallel dispatch via the `Agent` tool, optional config for API keys, and WebSearch as a universal fallback.

### Design Decisions

- **Optional NewsAPI key**: NewsAPI.org provides structured article access (free tier: 100 req/day). Falls back to `WebSearch` when key is not configured. Same credential pattern as `sec-fetch` (stored in `config.json`).
- **24-hour default timeframe**: Optimized for pre-trade and intraday research. All sources constrained to the past 24 hours.
- **Hybrid scoring**: Claude scores individual headlines/post titles (-1 to +1); StockTwits uses its built-in bullish/bearish labels. Balances quality with token efficiency.
- **Parallel dispatch**: The `sentiment-analyst` agent fetches all three channels concurrently via the `Agent` tool dispatching sub-skills. The `sentiment-report` skill does the same — it is a user-invocable wrapper around the same parallel dispatch, not a sequential runner.
- **No API keys required for Reddit or StockTwits**: Both have public JSON endpoints usable via WebFetch.

---

## Plugin Structure

```
sentiment-analysis/
├── plugin.json                   # Plugin manifest
├── config.json                   # Optional: { "newsapi": { "key": "..." } }
├── agents/
│   └── sentiment-analyst.md      # Orchestrates 3 skills in parallel via Agent tool
└── skills/
    ├── news-sentiment/
    │   └── SKILL.md              # NewsAPI + WebSearch fallback
    ├── reddit-sentiment/
    │   └── SKILL.md              # r/wallstreetbets + r/stocks
    ├── stocktwits-sentiment/
    │   └── SKILL.md              # StockTwits public API
    └── sentiment-report/
        └── SKILL.md              # User-invocable slash command
```

---

## Plugin Manifest (`plugin.json`)

```json
{
  "name": "sentiment-analysis",
  "description": "24-hour market sentiment analysis from news, Reddit, and StockTwits.",
  "version": "0.0.1",
  "agents": [
    "./agents/sentiment-analyst.md"
  ],
  "skills": [
    "./skills/news-sentiment",
    "./skills/reddit-sentiment",
    "./skills/stocktwits-sentiment",
    "./skills/sentiment-report"
  ]
}
```

Add a corresponding entry to `marketplace.json` (same format as the `fundamental-analysis` entry) with category `"finance"` and keywords `["investing", "sentiment", "news", "reddit", "stocktwits", "stocks"]`.

---

## Skill Frontmatter Conventions

All skills follow the same YAML frontmatter pattern used in `fundamental-analysis`:

```yaml
---
name: news-sentiment
description: >
  This skill should be used when the user asks about news sentiment,
  media tone, recent headlines sentiment, or news coverage for a publicly traded company.
---
```

- `name`: matches the skill directory name
- `description`: highly specific trigger phrases (determines auto-invocation)
- User-invocable skills (`sentiment-report`) add no extra frontmatter — the slash command name comes from the skill directory name

---

## Data Sources

### News — NewsAPI.org (primary) + WebSearch (fallback)

**With API key** (`config.json` has `newsapi.key`):
```
GET https://newsapi.org/v2/everything
  ?q={ticker} OR "{company name}"
  &from={ISO timestamp 24h ago}
  &sortBy=publishedAt
  &language=en
  &pageSize=20
  &apiKey={key}
```

**Without API key (fallback)**:
`WebSearch` for `"{company name}" OR "{ticker}" stock news site:reuters.com OR site:bloomberg.com OR site:seekingalpha.com OR site:finance.yahoo.com`

Extract up to 20 article headlines + descriptions from the past 24h. Claude scores each -1.0 (very bearish) to +1.0 (very bullish) based on tone, language, and financial context.

"Top 3 headlines" in output = the 3 articles with the **highest absolute score value** (most extreme sentiment, regardless of direction) — these represent the signal-strongest stories. This differs intentionally from Reddit's "top 3 posts" selection (see below), which uses engagement weight instead: for news, sentiment strength is the useful signal; for Reddit, post popularity is the useful signal since high-upvote posts represent community conviction.

### Reddit — Public JSON API (no key required)

```
GET https://www.reddit.com/r/wallstreetbets/search.json?q={ticker}&sort=hot&t=day&limit=15&restrict_sr=1
GET https://www.reddit.com/r/stocks/search.json?q={ticker}&sort=hot&t=day&limit=15&restrict_sr=1
```

**Required header**: `User-Agent: sentiment-analysis-skill/1.0` — Reddit blocks requests without a proper User-Agent.

**Known fragility**: Reddit's search JSON endpoint occasionally returns empty results for unauthenticated requests or redirects to a login page. If either subreddit returns empty or fewer than 3 posts:
1. Retry with `sort=new` instead of `hot`
2. If still empty, fall back to `WebSearch` for `site:reddit.com/r/wallstreetbets {ticker}` and extract post titles from search snippets
3. If fallback also fails, exclude that subreddit from the Reddit channel score and note it in output

Extract per post: `title`, `score` (upvotes), `upvote_ratio`.

**Post weight formula**: `upvote_ratio × log(max(score, 0) + 1)`

Clamp `score` to a minimum of 0 before applying `log` — this ensures no negative or undefined weights for downvoted posts. Posts with a net-negative score are effectively given near-zero weight (not excluded, but minimized).

Claude assigns -1.0 to +1.0 per post title. Weighted average → channel score per subreddit.

### StockTwits — Public API (no key required)

```
GET https://api.stocktwits.com/api/2/streams/symbol/{ticker}.json
```

Extract messages from the single API response (the public endpoint returns up to 30 messages per call; no pagination). Filter to only messages with a `sentiment.basic` field (`"Bullish"` or `"Bearish"`). Messages without a label are excluded. Use however many labeled messages are present in the response (typically 5–20 out of 30).

Channel score = `(bullish_count - bearish_count) / total_labeled × 10`

---

## Composite Scoring Formula

### Normalization Rule

All channel scores are on **-10 to +10** before entering the weighted formula:
- **News**: `average_of_per_headline_scores × 10` (headlines scored -1 to +1 by Claude)
- **Reddit**: `weighted_average_of_post_scores × 10` (posts scored -1 to +1 by Claude, weighted by engagement)
- **StockTwits**: `(bullish - bearish) / total_labeled × 10` (already on -10 to +10 natively)

### Weighted Composite

| Channel | Weight | Rationale |
|---|---|---|
| News | 45% | Most reliable; professional sources, editorial filtering |
| StockTwits | 30% | Finance-specific, pre-labeled, high signal density |
| Reddit (WSB + r/stocks avg) | 25% | Captures retail momentum but noisiest source |

```
reddit_score = (wsb_score + rstocks_score) / 2

composite = (news_score × 0.45) + (stocktwits_score × 0.30) + (reddit_score × 0.25)
```

### Missing Channel Handling

If one or more channels have no data (after all fallbacks exhausted):
- Re-normalize weights proportionally across available channels so they sum to 1.0
- If fewer than 2 channels have data, do not compute a composite score — output "Insufficient data to compute composite score" and show individual channel results
- Always note which channels were excluded and why

### Score Interpretation Bands

Using strict thresholds (`>=` lower bound, `<` upper bound, except endpoints):

| Condition | Label |
|---|---|
| score >= +7.0 | Very Bullish |
| score >= +3.0 and < +7.0 | Bullish |
| score > -3.0 and < +3.0 | Neutral |
| score <= -3.0 and > -7.0 | Bearish |
| score <= -7.0 | Very Bearish |

---

## Components

### `news-sentiment` skill

**Frontmatter**:
```yaml
name: news-sentiment
description: >
  This skill should be used when the user asks about news sentiment,
  media coverage tone, recent headline analysis, or financial news
  sentiment for a publicly traded company.
```

**Steps**:
1. Read `${CLAUDE_PLUGIN_ROOT}/config.json` for `newsapi.key`
2. If key present: call NewsAPI endpoint; else: WebSearch fallback
3. Extract up to 20 headlines + descriptions from past 24h
4. Claude scores each headline -1.0 to +1.0
5. `news_score = average(scores) × 10`
6. Return: channel score, article count, top 3 headlines by absolute score value with individual scores, sources cited

### `reddit-sentiment` skill

**Frontmatter**:
```yaml
name: reddit-sentiment
description: >
  This skill should be used when the user asks about Reddit sentiment,
  WallStreetBets opinion, r/stocks discussion, retail investor sentiment,
  or social media sentiment on Reddit for a publicly traded company.
```

**Steps**:
1. WebFetch r/wallstreetbets search JSON (`restrict_sr=1`, `t=day`, `sort=hot`, limit 15) with `User-Agent` header
2. WebFetch r/stocks search JSON (same params)
3. Apply retry + fallback logic if empty (see Data Sources section)
4. For each post: extract title, score, upvote_ratio
5. Claude assigns -1.0 to +1.0 per title; weight = `upvote_ratio × log(max(score, 0) + 1)`
6. `wsb_score = weighted_avg(wsb_posts) × 10`; `rstocks_score = weighted_avg(rstocks_posts) × 10`
7. Return: per-subreddit scores, top 3 posts per subreddit selected by **highest engagement weight** (not absolute sentiment — on Reddit, popularity signals community conviction) with upvotes + sentiment tag

### `stocktwits-sentiment` skill

**Frontmatter**:
```yaml
name: stocktwits-sentiment
description: >
  This skill should be used when the user asks about StockTwits sentiment,
  trader bullish/bearish ratio, StockTwits stream, or real-time trader
  sentiment for a publicly traded company.
```

**Steps**:
1. WebFetch StockTwits symbol stream for ticker
2. Filter messages with `sentiment.basic` field (skip unlabeled)
3. Count bullish vs bearish from all labeled messages in the response (however many are present — typically 5–20)
4. `stocktwits_score = (bullish - bearish) / total_labeled × 10`
5. If ticker not found or stream empty: note "StockTwits: No data available", exclude from composite
6. Return: channel score, bullish count, bearish count, total labeled, 1 sample bullish + 1 sample bearish message

### `sentiment-report` skill

**Frontmatter**:
```yaml
name: sentiment-report
description: >
  This skill should be used when the user asks for a full sentiment report,
  comprehensive sentiment analysis, or sentiment summary for a publicly
  traded company. User-invocable as /sentiment-report.
```

**Behavior**: Dispatches news-sentiment, reddit-sentiment, and stocktwits-sentiment **in parallel** using the `Agent` tool (same mechanism as `sentiment-analyst`). Synthesizes composite score and produces the full formatted output. Appends a **Data Source Log** section listing: NewsAPI vs WebSearch fallback, article counts per source domain, Reddit post counts per subreddit (and any fallbacks triggered), StockTwits labeled message count.

**Tools needed**: `Agent`, `WebSearch`, `WebFetch`, `Read`

### `sentiment-analyst` agent

**Frontmatter**:
```yaml
name: sentiment-analyst
description: >
  Use this agent when the user asks about market sentiment, news tone,
  Reddit opinion, or social media signals for a publicly traded company.

  <example>
  user: "What's the sentiment on TSLA right now?"
  </example>
  <example>
  user: "How is the market feeling about NVDA?"
  </example>
  <example>
  user: "Reddit sentiment for AMD"
  </example>
  <example>
  user: "Is the news bullish or bearish on AAPL?"
  </example>
  <example>
  user: "Run a sentiment analysis on MSFT"
  </example>

model: inherit
tools: ["Agent", "WebSearch", "WebFetch", "Read"]
```

**Behavior**: Dispatches news-sentiment, reddit-sentiment, and stocktwits-sentiment **in parallel** via the `Agent` tool. Synthesizes composite score using weighted formula. Produces full formatted output (without the Data Source Log — that is `sentiment-report`-only).

---

## Output Format

```markdown
## Sentiment Analysis: {TICKER} — {Company Name}
*Last 24 hours · As of {timestamp UTC}*

### Composite Sentiment Score

**{score} / 10 — {Label}**

{ASCII progress bar, e.g. ████████░░  (+8.1)}

### Channel Breakdown

| Channel | Score | Signal | Volume | Notes |
|---------|-------|--------|--------|-------|
| News | +6.2 | Bullish | 14 articles | Reuters, Seeking Alpha |
| StockTwits | +4.8 | Bullish | 24 labeled msgs | 18 bullish / 6 bearish |
| Reddit (WSB) | +3.1 | Bullish | 12 posts | 4.2k avg upvotes |
| Reddit (r/stocks) | +2.4 | Neutral | 8 posts | 1.1k avg upvotes |

### Key Headlines (past 24h)

- [+0.9] "NVDA beats earnings, raises guidance" — Reuters
- [-0.8] "Supply chain concerns linger despite beat" — Bloomberg
- [+0.7] "Analysts raise price targets after strong quarter" — Seeking Alpha

### Notable Reddit Posts

- [WSB · ↑12.4k] "NVDA to the moon 🚀 — position: 50 calls" · Bullish
- [r/stocks · ↑3.2k] "NVDA earnings breakdown — solid but priced in?" · Neutral

---
*For informational purposes only. Not financial advice. Sentiment scores derived from public sources and AI analysis. Verify independently before making investment decisions.*
```

The `/sentiment-report` slash command appends a **Data Source Log** section:
```markdown
### Data Source Log
- News: NewsAPI (key configured) · 14 articles · reuters.com (4), seekingalpha.com (5), bloomberg.com (3), other (2)
- Reddit WSB: Direct JSON API · 12 posts · no fallback needed
- Reddit r/stocks: WebSearch fallback (API returned empty) · 8 posts
- StockTwits: Direct API · 30 messages · 24 labeled
```

---

## Config Schema

`config.json` (optional, gitignored):
```json
{
  "newsapi": {
    "key": "your_newsapi_key_here"
  }
}
```

Skills check for this file at `${CLAUDE_PLUGIN_ROOT}/config.json`. If absent or key is missing, WebSearch fallback activates automatically with no error shown to the user.

---

## Edge Cases

- **StockTwits ticker not found or stream empty**: Note in channel breakdown, exclude from composite, re-normalize weights
- **No Reddit posts after all fallbacks**: Exclude affected subreddit(s) from Reddit channel; if both fail, exclude Reddit channel entirely and re-normalize weights
- **NewsAPI rate limit hit (100 req/day on free tier)**: Auto-fall back to WebSearch; log in Data Source Log
- **Low volume** (< 5 total articles + posts across all channels): Show warning "Low volume — score may not be representative" below composite score
- **Fewer than 2 channels with data**: Do not compute composite score; show "Insufficient data" and display available channel results individually
- **International tickers**: Reddit and StockTwits work globally; NewsAPI may have limited non-US English coverage — note in output if article count is low
- **Downvoted Reddit posts** (`score < 0`): Clamped to 0 in weight formula, effectively near-zero weight but not excluded
