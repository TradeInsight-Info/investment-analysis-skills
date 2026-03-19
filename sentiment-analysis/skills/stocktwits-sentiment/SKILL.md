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
