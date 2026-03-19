# Sentiment Analysis Plugin — Design Spec

## Overview

A Claude Code plugin providing 24-hour market sentiment analysis for publicly traded companies. Aggregates signals from financial news, Reddit (r/wallstreetbets + r/stocks), and StockTwits into a normalized composite score from -10 to +10.

The plugin lives alongside `fundamental-analysis/` in the same repo and follows identical plugin conventions: YAML frontmatter skills, agents with parallel dispatch, optional config for API keys, and WebSearch as a universal fallback.

### Design Decisions

- **Optional NewsAPI key**: NewsAPI.org provides structured article access (free tier: 100 req/day). Falls back to `WebSearch` when key is not configured. Same credential pattern as `sec-fetch` (stored in `config.json`).
- **24-hour default timeframe**: Optimized for pre-trade and intraday research. All sources constrained to the past 24 hours.
- **Hybrid scoring**: Claude scores individual headlines/post titles (-1 to +1); StockTwits uses its built-in bullish/bearish labels. Balances quality with token efficiency.
- **Parallel dispatch**: The `sentiment-analyst` agent fetches all three channels concurrently via sub-skills.
- **No API keys required for Reddit or StockTwits**: Both have public JSON endpoints usable via WebFetch.

---

## Plugin Structure

```
sentiment-analysis/
├── plugin.json                   # Plugin manifest
├── config.json                   # Optional: { "newsapi": { "key": "..." } }
├── agents/
│   └── sentiment-analyst.md      # Orchestrates 3 skills in parallel
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

Extract up to 20 article headlines + descriptions. Claude scores each -1.0 (very bearish) to +1.0 (very bullish) based on tone, language, and financial context.

### Reddit — Public JSON API (no key required)

```
GET https://www.reddit.com/r/wallstreetbets/search.json?q={ticker}&sort=hot&t=day&limit=15
GET https://www.reddit.com/r/stocks/search.json?q={ticker}&sort=hot&t=day&limit=15
```

Headers: `User-Agent: sentiment-analysis-skill/1.0`

Extract per post: `title`, `score` (upvotes), `num_comments`, `upvote_ratio`.

Post weight: `upvote_ratio × log(score + 1)` — surfaces high-conviction posts, suppresses low-engagement noise.

Claude assigns -1.0 to +1.0 per post title. Weighted average → channel score.

### StockTwits — Public API (no key required)

```
GET https://api.stocktwits.com/api/2/streams/symbol/{ticker}.json
```

Extract last 30 messages with a `sentiment.basic` field (`"Bullish"` or `"Bearish"`). Messages without a label are excluded from the ratio calculation.

Channel score = `(bullish_count - bearish_count) / total_labeled × 10`

---

## Composite Scoring Formula

Each channel is normalized to **-10 to +10** before weighting.

| Channel | Weight | Rationale |
|---|---|---|
| News | 45% | Most reliable; professional sources, editorial filtering |
| StockTwits | 30% | Finance-specific, pre-labeled, high signal density |
| Reddit (WSB + r/stocks avg) | 25% | Captures retail momentum but noisiest source |

```
composite = (news_score × 0.45) + (stocktwits_score × 0.30) + (reddit_score × 0.25)
```

**Reddit score** = average of WSB channel score and r/stocks channel score (equal weight within Reddit).

### Score Interpretation Bands

| Range | Label |
|---|---|
| +7.0 to +10.0 | Very Bullish |
| +3.0 to +6.9 | Bullish |
| -2.9 to +2.9 | Neutral |
| -3.0 to -6.9 | Bearish |
| -7.0 to -10.0 | Very Bearish |

---

## Components

### `news-sentiment` skill

- **Type**: auto-triggered
- **Trigger phrases**: user asks about news sentiment, recent news tone, media coverage sentiment for a stock
- **Steps**:
  1. Read `${CLAUDE_PLUGIN_ROOT}/config.json` for `newsapi.key`
  2. If key present: call NewsAPI endpoint; else: WebSearch fallback
  3. Extract up to 20 headlines + descriptions from past 24h
  4. Claude scores each headline -1.0 to +1.0
  5. Average all scores → multiply by 10 → news channel score (-10 to +10)
  6. Return: channel score, article count, top 3 headlines with individual scores, sources cited

### `reddit-sentiment` skill

- **Type**: auto-triggered
- **Trigger phrases**: user asks about Reddit sentiment, WSB opinion, retail investor sentiment, r/stocks discussion for a stock
- **Steps**:
  1. WebFetch r/wallstreetbets search JSON (past 24h, hot sort, limit 15)
  2. WebFetch r/stocks search JSON (same params)
  3. For each post: extract title, score, upvote_ratio, num_comments
  4. Claude assigns -1.0 to +1.0 per title; multiply by `upvote_ratio × log(score + 1)` as weight
  5. Weighted average per subreddit → multiply by 10 → subreddit channel score
  6. Reddit score = average of WSB and r/stocks scores
  7. Return: per-subreddit scores, top 3 posts per subreddit with upvotes + sentiment tag

### `stocktwits-sentiment` skill

- **Type**: auto-triggered
- **Trigger phrases**: user asks about StockTwits sentiment, trader sentiment stream, bullish/bearish ratio for a stock
- **Steps**:
  1. WebFetch StockTwits symbol stream for ticker
  2. Filter messages with `sentiment.basic` field (skip unlabeled)
  3. Count bullish vs bearish from last 30 labeled messages
  4. Channel score = `(bullish - bearish) / total_labeled × 10`
  5. Return: channel score, bullish count, bearish count, total labeled, sample bullish + bearish messages

### `sentiment-report` skill

- **Type**: user-invocable (`/sentiment-report`)
- **Behavior**: Calls news-sentiment, reddit-sentiment, and stocktwits-sentiment sequentially, then synthesizes composite score and full formatted output. Appends a **data source log** (API used, fallback triggered, article/post counts).

### `sentiment-analyst` agent

- **Trigger examples**:
  - "What's the sentiment on TSLA right now?"
  - "How is the market feeling about NVDA?"
  - "Reddit sentiment for AMD"
  - "Is the news bullish or bearish on AAPL?"
  - "Run a sentiment analysis on MSFT"
- **Behavior**: Dispatches news-sentiment, reddit-sentiment, and stocktwits-sentiment **in parallel**. Synthesizes composite score using weighted formula. Produces full formatted output.
- **Tools**: `WebSearch`, `WebFetch`, `Read`
- **Model**: inherit

---

## Output Format

```markdown
## Sentiment Analysis: {TICKER} — {Company Name}
*Last 24 hours · As of {timestamp UTC}*

### Composite Sentiment Score

**{score} / 10 — {Label}**

{ASCII progress bar, e.g. ████████░░}

### Channel Breakdown

| Channel | Score | Signal | Volume | Top Source |
|---------|-------|--------|--------|------------|
| News | +6.2 | Bullish | 14 articles | Reuters, Seeking Alpha |
| StockTwits | +4.8 | Bullish | 24 labeled msgs | 18 bullish / 6 bearish |
| Reddit (WSB) | +3.1 | Bullish | 12 posts | 4.2k upvotes avg |
| Reddit (r/stocks) | +2.4 | Neutral | 8 posts | 1.1k upvotes avg |

### Key Headlines (past 24h)

- [+0.9] "NVDA beats earnings, raises guidance" — Reuters
- [+0.7] "Analysts raise price targets after strong quarter" — Seeking Alpha
- [-0.4] "Supply chain concerns linger despite beat" — Bloomberg

### Notable Reddit Posts

- [WSB · ↑12.4k] "NVDA to the moon 🚀 — position: 50 calls"
- [r/stocks · ↑3.2k] "NVDA earnings breakdown — solid but priced in?"

---
*For informational purposes only. Not financial advice. Sentiment scores derived from public sources and AI analysis. Verify independently before making investment decisions.*
```

The `/sentiment-report` slash command appends a **Data Source Log** section listing: NewsAPI vs WebSearch fallback, article counts per source domain, Reddit post counts per subreddit, StockTwits labeled message count.

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

- **Ticker not found on StockTwits**: Note "StockTwits: No data available" in channel breakdown, exclude from composite, reduce confidence
- **No Reddit posts in past 24h**: Use `t=week` as fallback with a note "(7-day fallback — limited 24h data)"
- **NewsAPI rate limit hit (100 req/day)**: Automatically fall back to WebSearch; log in data source section
- **Low article/post volume** (< 5 sources total): Add "Low volume — score may not be representative" warning below composite score
- **International tickers**: Reddit and StockTwits work globally; NewsAPI may have limited non-US coverage — note in output
