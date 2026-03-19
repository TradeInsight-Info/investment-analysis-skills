# Sentiment Analysis Plugin Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a `sentiment-analysis` Claude Code plugin with 3 data-fetching skills, 1 report skill, and 1 orchestrating agent that synthesize news + Reddit + StockTwits signals into a -10 to +10 composite sentiment score.

**Architecture:** Four skills (news-sentiment, reddit-sentiment, stocktwits-sentiment, sentiment-report) and one agent (sentiment-analyst) in a `sentiment-analysis/` directory alongside `fundamental-analysis/`. The agent and report skill dispatch the three data-fetching skills in parallel via the `Agent` tool. Scores are weighted (News 45%, StockTwits 30%, Reddit 25%) into a composite.

**Tech Stack:** Claude Code plugin (markdown skills + agents), NewsAPI.org (optional, free tier), Reddit public JSON API, StockTwits public API, WebSearch + WebFetch.

**Spec:** `docs/superpowers/specs/2026-03-19-sentiment-analysis-plugin-design.md`

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `sentiment-analysis/plugin.json` | Plugin manifest |
| Modify | `.claude-plugin/marketplace.json` | Register as second plugin |
| Create | `sentiment-analysis/skills/news-sentiment/SKILL.md` | Fetch news, score headlines, compute channel score |
| Create | `sentiment-analysis/skills/reddit-sentiment/SKILL.md` | Fetch WSB + r/stocks, engagement-weighted scoring |
| Create | `sentiment-analysis/skills/stocktwits-sentiment/SKILL.md` | Tally pre-labeled bullish/bearish messages |
| Create | `sentiment-analysis/skills/sentiment-report/SKILL.md` | User-invocable: parallel dispatch + composite + data log |
| Create | `sentiment-analysis/agents/sentiment-analyst.md` | Agent: parallel dispatch + composite (no data log) |

---

## Signal Bands (applies to all channel scores and composite — reference here)

| Condition | Label |
|-----------|-------|
| score >= +7.0 | Very Bullish |
| score >= +3.0 and < +7.0 | Bullish |
| score > -3.0 and < +3.0 | Neutral |
| score <= -3.0 and > -7.0 | Bearish |
| score <= -7.0 | Very Bearish |

---

## Chunk 1: Plugin Scaffolding

### Task 1: Create plugin directory structure and manifest

**Files:**
- Create: `sentiment-analysis/plugin.json`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p sentiment-analysis/skills/news-sentiment
mkdir -p sentiment-analysis/skills/reddit-sentiment
mkdir -p sentiment-analysis/skills/stocktwits-sentiment
mkdir -p sentiment-analysis/skills/sentiment-report
mkdir -p sentiment-analysis/agents
```

No placeholder files needed — Git tracks files, not directories. Skill files are added in later tasks.

- [ ] **Step 2: Write `sentiment-analysis/plugin.json`**

```json
{
  "name": "sentiment-analysis",
  "description": "24-hour market sentiment analysis from financial news, Reddit (r/wallstreetbets + r/stocks), and StockTwits. Produces a normalized -10 to +10 composite sentiment score.",
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

- [ ] **Step 3: Commit scaffold**

```bash
git add sentiment-analysis/plugin.json
git commit -m "feat(sentiment): scaffold plugin directory structure and manifest"
```

---

### Task 2: Register plugin in marketplace.json

**Files:**
- Modify: `.claude-plugin/marketplace.json`

> **Path resolution note:** In `marketplace.json`, the `agents` and `skills` arrays inside each plugin entry use paths **relative to that plugin's `source` directory**, not the repo root. For example, if `source` is `"./sentiment-analysis"`, then `"./agents/sentiment-analyst.md"` resolves to `./sentiment-analysis/agents/sentiment-analyst.md`. This matches the existing `fundamental-analysis` convention.

- [ ] **Step 1: Read current marketplace.json**

Open `.claude-plugin/marketplace.json` and verify the existing `fundamental-analysis` entry format.

- [ ] **Step 2: Add sentiment-analysis entry to the `"plugins"` array**

Append after the `fundamental-analysis` entry (inside the same `"plugins"` array):

```json
{
  "name": "sentiment-analysis",
  "source": "./sentiment-analysis",
  "description": "24-hour market sentiment analysis from financial news, Reddit (r/wallstreetbets + r/stocks), and StockTwits. Produces a normalized -10 to +10 composite sentiment score.",
  "version": "0.0.1",
  "category": "finance",
  "strict": false,
  "author": {
    "name": "TradeInsight.info"
  },
  "keywords": ["investing", "sentiment", "news", "reddit", "stocktwits", "stocks", "finance"],
  "tags": ["investing", "sentiment", "news", "reddit", "stocktwits", "stocks", "finance"],
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

- [ ] **Step 3: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "feat(sentiment): register sentiment-analysis plugin in marketplace"
```

---

## Chunk 2: Data-Fetching Skills

### Task 3: Write news-sentiment skill

**Files:**
- Create: `sentiment-analysis/skills/news-sentiment/SKILL.md`

- [ ] **Step 1: Write the file**

Write the following content verbatim to `sentiment-analysis/skills/news-sentiment/SKILL.md`:

````markdown
---
name: news-sentiment
description: >
  This skill should be used when the user asks about news sentiment,
  media coverage tone, recent headline analysis, financial news sentiment,
  how the press is covering a stock, or news-driven market mood for a
  publicly traded company.
---

# News Sentiment Analysis

## Purpose

Fetch financial news articles for a company published in the past 24 hours and score
each headline for sentiment. Produce a news channel score from -10 (very bearish) to
+10 (very bullish).

## Step 1 — Resolve Ticker and Company Name

If the user provided a ticker, confirm the company name via WebSearch:
`{ticker} stock company name site:finance.yahoo.com OR site:stockanalysis.com`

If only a company name was provided, resolve the ticker the same way.

## Step 2 — Read Config for NewsAPI Key

Run:

```bash
cat ${CLAUDE_PLUGIN_ROOT}/config.json 2>/dev/null
```

If the file exists and contains `newsapi.key` (i.e., `config["newsapi"]["key"]`),
proceed to Step 3a. Otherwise proceed to Step 3b (WebSearch fallback).

## Step 3a — Fetch via NewsAPI (key available)

WebFetch the following URL, substituting:
- `{ticker}`: the stock ticker symbol
- `{company_name}`: URL-encoded company name
- `{ISO_24h_ago}`: current UTC time minus 24 hours in format `YYYY-MM-DDTHH:MM:SSZ`
- `{KEY}`: the resolved string value of `config["newsapi"]["key"]`

```
https://newsapi.org/v2/everything?q={ticker}%20OR%20%22{company_name}%22&from={ISO_24h_ago}&sortBy=publishedAt&language=en&pageSize=20&apiKey={KEY}
```

Extract from each article: `title`, `description`, `source.name`, `publishedAt`, `url`.
Use the first 20 results.

## Step 3b — WebSearch Fallback (no key)

Run WebSearch:
`"{company_name}" OR "{ticker}" stock news site:reuters.com OR site:bloomberg.com OR site:seekingalpha.com OR site:finance.yahoo.com`

Extract up to 20 headline + description pairs from search results.
Record source as `"WebSearch"` and note in output: "News via WebSearch — no NewsAPI key configured"

## Step 4 — Score Headlines

For each article headline + description pair, assign a score from -1.0 to +1.0:

- **+0.8 to +1.0**: Record earnings beat, major upgrade, regulatory approval, significant partnership
- **+0.4 to +0.7**: Positive guidance, price target raise, solid quarterly results, market share gains
- **0.0**: Neutral announcements, routine filings, personnel changes with no clear valuation impact
- **-0.4 to -0.7**: Missed estimates, minor regulatory concern, analyst downgrade
- **-0.8 to -1.0**: Major investigation, fraud allegation, severe earnings miss, CEO departure under fire

Score the combination of headline + description together. A positive headline with a
cautionary description should score lower than the headline alone suggests.

## Step 5 — Compute Channel Score

```
news_score = mean(all_headline_scores) × 10
```

Identify the 3 articles with the **highest absolute score value** (strongest signal,
regardless of direction — these are the most signal-rich stories). These are the
"key headlines" to surface in output.

## Step 6 — Handle Low Volume

If fewer than 5 articles were found, add this warning to output:
"⚠️ Low news volume ({n} articles) — score may not be representative"

## Step 7 — Output

Return the following structured result (consumed by sentiment-report and sentiment-analyst):

```
NEWS SENTIMENT RESULT
Ticker: {ticker}
Company: {company_name}
Channel Score: {news_score} / 10
Signal: {label per signal bands below}
Article Count: {n}
Source: {NewsAPI | WebSearch}
Low Volume Warning: {yes | no}

Key Headlines (highest absolute sentiment score):
1. [{score}] "{title}" — {source_name}
   {url}
2. [{score}] "{title}" — {source_name}
   {url}
3. [{score}] "{title}" — {source_name}
   {url}
```

Signal bands:
- score >= +7.0 → Very Bullish
- score >= +3.0 and < +7.0 → Bullish
- score > -3.0 and < +3.0 → Neutral
- score <= -3.0 and > -7.0 → Bearish
- score <= -7.0 → Very Bearish
````

- [ ] **Step 2: Reload plugin to verify registration**

Run `/reload-plugins` in Claude Code. Confirm `news-sentiment` appears in the loaded skills list with no errors.

- [ ] **Step 3: Smoke test**

Ask: "What is the news sentiment for NVDA?"

Verify:
- Channel score in range -10 to +10
- 3 key headlines with individual scores
- Signal label matches the band
- Source noted (NewsAPI or WebSearch)

- [ ] **Step 4: Commit**

```bash
git add sentiment-analysis/skills/news-sentiment/SKILL.md
git commit -m "feat(sentiment): add news-sentiment skill with NewsAPI + WebSearch fallback"
```

---

### Task 4: Write reddit-sentiment skill

**Files:**
- Create: `sentiment-analysis/skills/reddit-sentiment/SKILL.md`

- [ ] **Step 1: Write the file**

Write the following content verbatim to `sentiment-analysis/skills/reddit-sentiment/SKILL.md`:

````markdown
---
name: reddit-sentiment
description: >
  This skill should be used when the user asks about Reddit sentiment,
  WallStreetBets opinion, r/stocks discussion, retail investor sentiment,
  social media sentiment on Reddit, what Reddit thinks about a stock,
  or whether Reddit is bullish or bearish on a ticker.
---

# Reddit Sentiment Analysis

## Purpose

Fetch top posts mentioning a ticker from r/wallstreetbets and r/stocks (past 24 hours),
score post titles for sentiment using engagement weighting, and produce a Reddit channel
score from -10 to +10.

## Step 1 — Resolve Ticker and Company Name

Confirm both ticker and company name via WebSearch if needed.

## Step 2 — Fetch r/wallstreetbets

WebFetch with required header `User-Agent: sentiment-analysis-skill/1.0`:

```
https://www.reddit.com/r/wallstreetbets/search.json?q={ticker}&sort=hot&t=day&limit=15&restrict_sr=1
```

**If the response is empty, has fewer than 3 posts, or returns a redirect/login page:**
1. Retry with `sort=new` instead of `hot`
2. If still empty, fall back to WebSearch: `site:reddit.com/r/wallstreetbets {ticker}`
   and extract post titles from search snippets. Record: `wsb_fallback = "WebSearch"`
3. If WebSearch also yields nothing, set `wsb_available = false`

Extract per post: `title`, `score` (upvotes), `upvote_ratio`.

## Step 3 — Fetch r/stocks

Same process for:
```
https://www.reddit.com/r/stocks/search.json?q={ticker}&sort=hot&t=day&limit=15&restrict_sr=1
```

Same retry/fallback sequence. Set `rstocks_available = false` if all fail.

## Step 4 — Score Posts

For each post:

**Engagement weight** = `upvote_ratio × log(max(score, 0) + 1)`

If `score <= 0`, `max(score, 0) + 1 = 1`, so `log(1) = 0` — downvoted posts get zero weight.
If all posts in a subreddit have weight 0, use unweighted average instead.

**Sentiment score** (-1.0 to +1.0 per title):
- 🚀 rocket emoji, "moon", "calls", "YOLO", "to the moon" → bullish (+0.6 to +1.0)
- "puts", "crash", "overvalued", "short squeeze" (as threat) → bearish (-0.6 to -1.0)
- "DD" posts, questions, neutral analysis → score on content (−0.3 to +0.3)
- WSB irony ("this is not financial advice", "loss porn") → near 0.0

**Weighted average per subreddit:**
```
weighted_avg = sum(sentiment_i × weight_i) / sum(weight_i)
subreddit_score = weighted_avg × 10
```

**Top 3 posts per subreddit** = the 3 posts with the **highest engagement weight**
(popularity signals community conviction on Reddit; not highest absolute sentiment).

## Step 5 — Compute Reddit Channel Score

```
reddit_score = (wsb_score + rstocks_score) / 2
```

If one subreddit is unavailable, use the other's score directly.
If both are unavailable, set `reddit_available = false`.

## Step 6 — Output

```
REDDIT SENTIMENT RESULT
Ticker: {ticker}
Reddit Channel Score: {reddit_score} / 10
  WSB Score: {wsb_score} / 10 ({wsb_post_count} posts) [or "Unavailable"]
  r/stocks Score: {rstocks_score} / 10 ({rstocks_post_count} posts) [or "Unavailable"]
Signal: {label per signal bands below}
Fallback Notes: {any fallbacks triggered, or "none"}

Top WSB Posts (by engagement weight):
1. [↑{upvotes} | {upvote_ratio}] "{title}" → {Bullish | Neutral | Bearish}
2. ...
3. ...

Top r/stocks Posts (by engagement weight):
1. [↑{upvotes} | {upvote_ratio}] "{title}" → {Bullish | Neutral | Bearish}
2. ...
3. ...
```

Signal bands (applied to reddit_score):
- score >= +7.0 → Very Bullish
- score >= +3.0 and < +7.0 → Bullish
- score > -3.0 and < +3.0 → Neutral
- score <= -3.0 and > -7.0 → Bearish
- score <= -7.0 → Very Bearish
````

- [ ] **Step 2: Reload and verify**

Run `/reload-plugins`. Confirm `reddit-sentiment` registered.

- [ ] **Step 3: Smoke test**

Ask: "What's the Reddit sentiment for TSLA?"

Verify:
- Both WSB and r/stocks scores appear (or graceful N/A)
- Top posts listed by engagement weight
- Any fallback noted

- [ ] **Step 4: Commit**

```bash
git add sentiment-analysis/skills/reddit-sentiment/SKILL.md
git commit -m "feat(sentiment): add reddit-sentiment skill for WSB + r/stocks"
```

---

## Chunk 3: StockTwits, Report Skill, and Agent

### Task 5: Write stocktwits-sentiment skill

**Files:**
- Create: `sentiment-analysis/skills/stocktwits-sentiment/SKILL.md`

- [ ] **Step 1: Write the file**

Write the following content verbatim to `sentiment-analysis/skills/stocktwits-sentiment/SKILL.md`:

````markdown
---
name: stocktwits-sentiment
description: >
  This skill should be used when the user asks about StockTwits sentiment,
  trader bullish/bearish ratio, StockTwits stream, real-time trader sentiment,
  what traders are saying on StockTwits, or the StockTwits signal for a stock.
---

# StockTwits Sentiment Analysis

## Purpose

Fetch the StockTwits message stream for a ticker, tally bullish vs bearish
self-labeled messages, and produce a channel score from -10 to +10. No LLM
scoring needed — StockTwits users self-label messages as Bullish or Bearish.

## Step 1 — Fetch Stream

WebFetch (no API key required, no special headers):

```
https://api.stocktwits.com/api/2/streams/symbol/{ticker}.json
```

## Step 2 — Filter and Count

From the `messages` array, filter to messages where `entities.sentiment.basic`
is `"Bullish"` or `"Bearish"`. Messages without this field are excluded.

Count:
- `bullish_count` — Bullish-labeled messages
- `bearish_count` — Bearish-labeled messages
- `total_labeled` = `bullish_count + bearish_count`

Use however many labeled messages are present in the single response
(the public endpoint returns up to 30 messages per call; typically 5–20 are labeled).
No pagination needed.

**If the ticker is not found or the API returns an error:**
Set `stocktwits_available = false`.
Note: "StockTwits: Ticker {ticker} not found or API error"

**If `total_labeled = 0`** (messages present but none labeled):
Set `stocktwits_available = false`.
Note: "StockTwits: No labeled messages in stream — cannot compute score"

## Step 3 — Compute Channel Score

```
stocktwits_score = (bullish_count - bearish_count) / total_labeled × 10
```

## Step 4 — Sample Messages

Select the most recent Bullish-labeled message and most recent Bearish-labeled
message from the stream. If only one direction exists, show what is available.

## Step 5 — Output

```
STOCKTWITS SENTIMENT RESULT
Ticker: {ticker}
Channel Score: {stocktwits_score} / 10
Signal: {label per signal bands below}
Labeled Messages: {total_labeled} ({bullish_count} bullish / {bearish_count} bearish)

Sample Bullish: "{message_body}"
Sample Bearish: "{message_body}"
```

If unavailable:
```
STOCKTWITS SENTIMENT RESULT
Ticker: {ticker}
Channel Score: N/A
Signal: N/A
Note: {reason}
```

Signal bands (applied to stocktwits_score):
- score >= +7.0 → Very Bullish
- score >= +3.0 and < +7.0 → Bullish
- score > -3.0 and < +3.0 → Neutral
- score <= -3.0 and > -7.0 → Bearish
- score <= -7.0 → Very Bearish
````

- [ ] **Step 2: Reload and verify**

Run `/reload-plugins`. Confirm `stocktwits-sentiment` registered.

- [ ] **Step 3: Smoke test**

Ask: "What's the StockTwits sentiment for AAPL?"

Verify:
- Score in range -10 to +10 (or graceful N/A)
- Bullish/bearish counts shown
- Sample messages shown

- [ ] **Step 4: Commit**

```bash
git add sentiment-analysis/skills/stocktwits-sentiment/SKILL.md
git commit -m "feat(sentiment): add stocktwits-sentiment skill"
```

---

### Task 6: Write sentiment-report skill (user-invocable)

**Files:**
- Create: `sentiment-analysis/skills/sentiment-report/SKILL.md`

> **Note on tools:** Claude Code skills run in the main context and can use any available tool without declaring them in frontmatter — `tools` is an agent-only frontmatter field. This skill uses the `Agent` tool for parallel dispatch, `WebFetch`, `WebSearch`, and `Read`, but these do not appear in frontmatter.

- [ ] **Step 1: Write the file**

Write the following content verbatim to `sentiment-analysis/skills/sentiment-report/SKILL.md`:

````markdown
---
name: sentiment-report
description: >
  This skill should be used when the user asks for a full sentiment report,
  comprehensive sentiment analysis, complete sentiment summary, or explicitly
  runs /sentiment-report for a publicly traded company.
---

# Sentiment Report

## Purpose

User-invocable skill (`/sentiment-report`) that dispatches all three sentiment
data channels in parallel using the `Agent` tool, synthesizes a composite score,
and formats the full report with a data source log.

## Step 1 — Resolve Ticker and Company Name

Confirm ticker and company name via WebSearch if needed. Record the current UTC
timestamp for the report header.

## Step 2 — Dispatch Three Skills in Parallel

Use the `Agent` tool to run all three simultaneously:
- Invoke `news-sentiment` for the ticker
- Invoke `reddit-sentiment` for the ticker
- Invoke `stocktwits-sentiment` for the ticker

Do NOT proceed to Step 3 until all three have returned results.

## Step 3 — Collect Channel Scores

From each skill output, extract:
- `news_score`, `article_count`, `news_source`, `low_volume_warning`, `key_headlines`
- `reddit_score`, `wsb_score`, `rstocks_score`, `wsb_post_count`, `rstocks_post_count`, `top_wsb_posts`, `top_rstocks_posts`, `fallback_notes`
- `stocktwits_score`, `bullish_count`, `bearish_count`, `total_labeled`, `sample_bullish`, `sample_bearish`
- Availability flags from each skill

## Step 4 — Compute Composite Score

**Base weights:** News 45%, StockTwits 30%, Reddit 25%

**Re-normalize if a channel is unavailable** (null score). Adjust weights so they
sum to 1.0 across available channels only:

| Available Channels | News weight | StockTwits weight | Reddit weight |
|-------------------|-------------|-------------------|---------------|
| All three | 0.45 | 0.30 | 0.25 |
| News + StockTwits only | 0.60 (45/75) | 0.40 (30/75) | — |
| News + Reddit only | 0.643 (45/70) | — | 0.357 (25/70) |
| StockTwits + Reddit only | — | 0.545 (30/55) | 0.455 (25/55) |
| News only | 1.00 | — | — |
| StockTwits only | — | 1.00 | — |
| Reddit only | — | — | 1.00 |

```
composite = (news_score × w_news) + (stocktwits_score × w_st) + (reddit_score × w_reddit)
```

**If fewer than 2 channels have data:** Do not compute a composite. Output
"⚠️ Insufficient data to compute composite score" and show available channel
results individually.

## Step 5 — Determine Score Label

Apply the standard signal bands to the composite score:
- >= +7.0 → Very Bullish
- >= +3.0 and < +7.0 → Bullish
- > -3.0 and < +3.0 → Neutral
- <= -3.0 and > -7.0 → Bearish
- <= -7.0 → Very Bearish

## Step 6 — Build ASCII Progress Bar

Scale composite (-10 to +10) onto a 20-character bar:
- Use `█` for filled blocks, `░` for empty
- The center 10 characters represent 0. Positive scores fill right; negative fill left.
- Append the numeric score: `{bar}  ({composite_score})`

Examples:
- Score +8.0: `░░░░░░░░░░████████░░  (+8.0)`
- Score -5.0: `░░░░░█████░░░░░░░░░░  (-5.0)`
- Score 0.0:  `░░░░░░░░░░░░░░░░░░░░  (0.0)`

## Step 7 — Format Full Report

```
## Sentiment Analysis: {TICKER} — {Company Name}
*Last 24 hours · As of {UTC timestamp}*

### Composite Sentiment Score

**{composite_score} / 10 — {Label}**

{ASCII bar}

[If total sources < 5: ⚠️ Low data volume ({n} total sources) — composite may not be representative.]

### Channel Breakdown

| Channel | Score | Signal | Volume | Notes |
|---------|-------|--------|--------|-------|
| News | {news_score} | {label} | {n} articles | {top source domains} |
| StockTwits | {st_score} | {label} | {total_labeled} labeled | {bullish}/{bearish} ratio |
| Reddit (WSB) | {wsb_score} | {label} | {n} posts | avg ↑{avg_upvotes} |
| Reddit (r/stocks) | {rs_score} | {label} | {n} posts | avg ↑{avg_upvotes} |

(Use "N/A" in Score column for unavailable channels; explain in Notes)

### Key Headlines (past 24h)

- [{score}] "{title}" — {source}
- [{score}] "{title}" — {source}
- [{score}] "{title}" — {source}

### Notable Reddit Posts

- [WSB · ↑{upvotes}] "{title}" · {Bullish | Neutral | Bearish}
- [WSB · ↑{upvotes}] "{title}" · {Bullish | Neutral | Bearish}
- [r/stocks · ↑{upvotes}] "{title}" · {Bullish | Neutral | Bearish}
- [r/stocks · ↑{upvotes}] "{title}" · {Bullish | Neutral | Bearish}

### StockTwits Sample

- 🟢 Bullish: "{sample_bullish_message}"
- 🔴 Bearish: "{sample_bearish_message}"

---

### Data Source Log
- **News:** {NewsAPI (key configured) | WebSearch fallback} · {n} articles · {domain breakdown}
- **Reddit WSB:** {Direct JSON | sort=new retry | WebSearch fallback | Unavailable} · {n} posts
- **Reddit r/stocks:** {Direct JSON | sort=new retry | WebSearch fallback | Unavailable} · {n} posts
- **StockTwits:** {Direct API | Unavailable} · {total_labeled} labeled messages

---
*For informational purposes only. Not financial advice. Sentiment scores derived
from public sources and AI analysis. Verify independently before making investment decisions.*
```
````

- [ ] **Step 2: Reload and verify**

Run `/reload-plugins`. Confirm `sentiment-report` registered.

- [ ] **Step 3: Smoke test**

Run `/sentiment-report NVDA`.

Verify:
- All three channels in breakdown table
- Composite score with ASCII bar
- Key headlines listed
- Data Source Log at bottom
- Disclaimer present

- [ ] **Step 4: Commit**

```bash
git add sentiment-analysis/skills/sentiment-report/SKILL.md
git commit -m "feat(sentiment): add sentiment-report user-invocable skill with composite scoring"
```

---

### Task 7: Write sentiment-analyst agent

**Files:**
- Create: `sentiment-analysis/agents/sentiment-analyst.md`

- [ ] **Step 1: Write the file**

Write the following content verbatim to `sentiment-analysis/agents/sentiment-analyst.md`:

````markdown
---
name: sentiment-analyst
description: >
  Use this agent when the user asks about market sentiment, news tone,
  Reddit opinion, social media signals, trader mood, or bullish/bearish
  sentiment for a publicly traded company.

  <example>
  Context: User wants to know sentiment
  user: "What's the sentiment on TSLA right now?"
  assistant: "I'll use the sentiment-analyst agent to analyze TSLA sentiment across news, Reddit, and StockTwits."
  <commentary>
  User asking about market sentiment — dispatch sentiment-analyst.
  </commentary>
  </example>

  <example>
  Context: User asks about market mood
  user: "How is the market feeling about NVDA?"
  assistant: "I'll use the sentiment-analyst agent to check news, Reddit, and StockTwits sentiment for NVDA."
  <commentary>
  Market mood question — dispatch sentiment-analyst.
  </commentary>
  </example>

  <example>
  Context: User wants Reddit-specific analysis
  user: "Reddit sentiment for AMD"
  assistant: "I'll use the sentiment-analyst agent to pull Reddit and broader sentiment for AMD."
  <commentary>
  Reddit sentiment request — sentiment-analyst covers this.
  </commentary>
  </example>

  <example>
  Context: User asks about news tone
  user: "Is the news bullish or bearish on AAPL?"
  assistant: "I'll use the sentiment-analyst agent to analyze recent news and social sentiment for AAPL."
  <commentary>
  News sentiment question — dispatch sentiment-analyst.
  </commentary>
  </example>

  <example>
  Context: User wants full sentiment analysis
  user: "Run a sentiment analysis on MSFT"
  assistant: "I'll use the sentiment-analyst agent to run a full sentiment analysis for MSFT."
  <commentary>
  Explicit sentiment analysis request — dispatch sentiment-analyst.
  </commentary>
  </example>

model: inherit
tools: ["Agent", "WebSearch", "WebFetch", "Read"]
---

You are a market sentiment analyst. Assess current sentiment for a publicly traded
company across financial news, Reddit, and StockTwits, then synthesize into a
composite score.

## Step 1 — Resolve Ticker and Company Name

Confirm ticker and company name via WebSearch:
`{ticker} stock company name site:finance.yahoo.com OR site:stockanalysis.com`

## Step 2 — Dispatch All Three Channels in Parallel

Use the `Agent` tool to dispatch simultaneously:
- `news-sentiment` for the ticker
- `reddit-sentiment` for the ticker
- `stocktwits-sentiment` for the ticker

Wait for all three before proceeding.

## Step 3 — Collect and Validate Results

Extract from each skill:
- Channel score (float -10 to +10, or null if unavailable)
- Article/post/message counts
- Key headlines, top posts, StockTwits samples
- Availability flags and fallback notes

## Step 4 — Compute Composite Score

**Base weights:** News 45%, StockTwits 30%, Reddit 25%

**Re-normalize when a channel is unavailable** (weights of available channels scale
proportionally to sum to 1.0):

| Available Channels | News weight | StockTwits weight | Reddit weight |
|-------------------|-------------|-------------------|---------------|
| All three | 0.45 | 0.30 | 0.25 |
| News + StockTwits only | 0.60 (45/75) | 0.40 (30/75) | — |
| News + Reddit only | 0.643 (45/70) | — | 0.357 (25/70) |
| StockTwits + Reddit only | — | 0.545 (30/55) | 0.455 (25/55) |
| News only | 1.00 | — | — |
| StockTwits only | — | 1.00 | — |
| Reddit only | — | — | 1.00 |

```
reddit_score = (wsb_score + rstocks_score) / 2
composite = (news × w_news) + (stocktwits × w_st) + (reddit × w_reddit)
```

If fewer than 2 channels have data: output "⚠️ Insufficient data to compute composite"
and show available channel results individually.

## Step 5 — Score Label and ASCII Bar

**Signal bands:**
- >= +7.0 → Very Bullish
- >= +3.0 and < +7.0 → Bullish
- > -3.0 and < +3.0 → Neutral
- <= -3.0 and > -7.0 → Bearish
- <= -7.0 → Very Bearish

**ASCII bar** (20 chars, `█` filled, `░` empty, center = 0):
- Score +8.0: `░░░░░░░░░░████████░░  (+8.0)`
- Score -5.0: `░░░░░█████░░░░░░░░░░  (-5.0)`

## Step 6 — Format Output

```
## Sentiment Analysis: {TICKER} — {Company Name}
*Last 24 hours · As of {UTC timestamp}*

### Composite Sentiment Score

**{composite_score} / 10 — {Label}**

{ASCII bar}

[If total sources < 5: ⚠️ Low data volume ({n} sources) — score may not be representative.]

### Channel Breakdown

| Channel | Score | Signal | Volume | Notes |
|---------|-------|--------|--------|-------|
| News | {news_score} | {label} | {n} articles | {top sources} |
| StockTwits | {st_score} | {label} | {total_labeled} labeled | {bullish}/{bearish} |
| Reddit (WSB) | {wsb_score} | {label} | {n} posts | avg ↑{avg_upvotes} |
| Reddit (r/stocks) | {rs_score} | {label} | {n} posts | avg ↑{avg_upvotes} |

### Key Headlines (past 24h)

- [{score}] "{title}" — {source}
- [{score}] "{title}" — {source}
- [{score}] "{title}" — {source}

### Notable Reddit Posts

- [WSB · ↑{upvotes}] "{title}" · {sentiment}
- [WSB · ↑{upvotes}] "{title}" · {sentiment}
- [r/stocks · ↑{upvotes}] "{title}" · {sentiment}

### StockTwits Sample

- 🟢 "{sample_bullish}"
- 🔴 "{sample_bearish}"

---
*For informational purposes only. Not financial advice. Sentiment derived from public
sources and AI text analysis. Verify independently before making investment decisions.*
```
````

- [ ] **Step 2: Reload and verify**

Run `/reload-plugins`. Confirm `sentiment-analyst` agent registered.

- [ ] **Step 3: Smoke test the agent**

Ask (no slash command): "What's the sentiment on AAPL?"

Verify:
- `sentiment-analyst` agent is dispatched automatically
- Output format matches above (no Data Source Log — that's report-only)
- Composite score and ASCII bar present

- [ ] **Step 4: Commit**

```bash
git add sentiment-analysis/agents/sentiment-analyst.md
git commit -m "feat(sentiment): add sentiment-analyst agent with parallel dispatch"
```

---

## Chunk 4: Integration Test

### Task 8: End-to-end integration test

- [ ] **Step 1: Full report test — high-volume ticker**

Run `/sentiment-report NVDA`. Verify all of:
- [ ] Composite score in range -10 to +10
- [ ] Score label matches band (e.g., +5.2 → "Bullish")
- [ ] All 4 channel rows in breakdown (or N/A with reason)
- [ ] 3 key headlines with individual scores
- [ ] Reddit posts (WSB + r/stocks, or fallback noted)
- [ ] Data Source Log at bottom
- [ ] Disclaimer present

- [ ] **Step 2: Agent auto-trigger test**

Type: "How is the market feeling about TSLA today?" (no slash command)

Verify:
- `sentiment-analyst` agent invoked automatically
- No Data Source Log in output (agent doesn't include it)
- Composite score and ASCII bar present

- [ ] **Step 3: Low-volume edge case**

Test with an obscure small-cap ticker (minimal Reddit/news coverage).

Verify:
- ⚠️ Low volume warning if < 5 total sources
- "Insufficient data" output if < 2 channels available
- No error thrown — graceful degradation

- [ ] **Step 4: No NewsAPI key test**

If `config.json` exists, temporarily rename it: `mv sentiment-analysis/config.json sentiment-analysis/config.json.bak`

Run `/sentiment-report AAPL`. Verify WebSearch fallback noted in Data Source Log.

Restore: `mv sentiment-analysis/config.json.bak sentiment-analysis/config.json`

- [ ] **Step 5: Final commit**

```bash
git add .
git commit -m "feat(sentiment): complete sentiment-analysis plugin v0.0.1

- news-sentiment: NewsAPI + WebSearch fallback, headline scoring
- reddit-sentiment: WSB + r/stocks, engagement-weighted scoring
- stocktwits-sentiment: pre-labeled bullish/bearish tally
- sentiment-report: parallel dispatch, composite score, data log
- sentiment-analyst: agent with parallel dispatch, auto-triggered
- marketplace.json: registered as second plugin"
```

---

## Quick Reference: Composite Scoring

```
news_score    = mean(headline_scores) × 10
reddit_score  = (wsb_score + rstocks_score) / 2
st_score      = (bullish - bearish) / total_labeled × 10

composite     = (news × w_news) + (st × w_st) + (reddit × w_reddit)
              [weights from re-normalization table if any channel unavailable]
```

**Post weight (Reddit):** `upvote_ratio × log(max(score, 0) + 1)`

**Signal bands:** >= +7 Very Bullish | +3 to +7 Bullish | -3 to +3 Neutral | -7 to -3 Bearish | <= -7 Very Bearish
