# Data Source Reference

Standard data-fetching instructions for all fundamental analysis skills. Consult this reference to determine which sources to use and how to fetch data.

## Fetching SEC EDGAR Data

**NEVER use WebFetch for SEC domains** (`www.sec.gov`, `data.sec.gov`, `efts.sec.gov`) — it will return HTTP 403. SEC requires a `User-Agent` header with the user's name and email (regulatory requirement).

**Always use the `sec-fetch` skill** for any SEC EDGAR URL. The skill automatically:
1. Reads credentials from `${CLAUDE_PLUGIN_ROOT}/config.json` if they exist
2. Prompts the user for name + email if not configured, then saves to `config.json`
3. Fetches the URL via `${CLAUDE_PLUGIN_ROOT}/skills/sec-fetch/scripts/sec-fetch.sh` with the proper `User-Agent` header

To invoke: follow the `sec-fetch` skill process — read `config.json`, then call:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/sec-fetch/scripts/sec-fetch.sh "<url>" "<sec.user>" "<sec.email>"
```

## Ticker Resolution

Before fetching any financial data, resolve the company ticker to a CIK (Central Index Key) for SEC EDGAR access:

1. Fetch `https://www.sec.gov/files/company_tickers.json` using the `sec-fetch` skill
2. Search the JSON for the ticker symbol to find the 10-digit CIK
3. Pad CIK with leading zeros to 10 digits (e.g., `320193` → `CIK0000320193`)
4. Cache the CIK and company name for use across all data fetches

If the ticker is not found (international company), skip EDGAR sources and rely on Stock Analysis and WebSearch.

## SEC EDGAR XBRL API (Primary Source)

No API key required. The `sec-fetch` skill handles the required `User-Agent` header automatically.

### Company Financial Data (Structured JSON)

```
https://data.sec.gov/api/xbrl/companyfacts/CIK{10-digit-CIK}.json
```

Returns every XBRL-tagged financial concept ever reported: revenue, net income, EPS, assets, liabilities, equity, and hundreds more. Data is organized by taxonomy (us-gaap), concept name, unit, and period.

To extract a specific metric (e.g., revenue):
- Look for `facts > us-gaap > Revenues > units > USD`
- Each entry has `val` (value), `fy` (fiscal year), `fp` (fiscal period: FY, Q1-Q4), `end` (period end date)
- Sort by `end` date for chronological ordering

Common XBRL concept names:
- Revenue: `Revenues`, `RevenueFromContractWithCustomerExcludingAssessedTax`
- Net Income: `NetIncomeLoss`
- EPS: `EarningsPerShareDiluted`, `EarningsPerShareBasic`
- Total Assets: `Assets`
- Total Liabilities: `Liabilities`
- Stockholders' Equity: `StockholdersEquity`
- Operating Income: `OperatingIncomeLoss`
- Cash: `CashAndCashEquivalentsAtCarryingValue`
- Long-term Debt: `LongTermDebt`
- Shares Outstanding: `CommonStockSharesOutstanding`

### Peer Comparison Data (Single Metric Across All Companies)

```
https://data.sec.gov/api/xbrl/frames/us-gaap/{concept}/{unit}/CY{year}.json
```

Returns a specific metric for every company that reported it in a given year. Useful for industry comparisons.

### Filing Full-Text Search (EFTS — Preferred)

```
https://efts.sec.gov/LATEST/search-index?q={query}&forms={form-type}&dateRange=custom&startdt=YYYY-MM-DD&enddt=YYYY-MM-DD
```

Returns JSON search results with filing URLs. Use for finding specific filings (10-K, 10-Q, 8-K, DEF 14A, Form 4).

### Legacy Filing Index (Deprecated — Use EFTS When Possible)

```
https://www.sec.gov/cgi-bin/browse-edgar?action=getcompany&CIK={ticker}&type={form-type}
```

## Stock Analysis (Secondary Source)

Fetchable via WebFetch. Clean HTML tables with pre-computed data.

| URL Pattern | Data |
|---|---|
| `https://stockanalysis.com/stocks/{ticker}/financials/` | Income statement (annual) |
| `https://stockanalysis.com/stocks/{ticker}/financials/?p=quarterly` | Income statement (quarterly) |
| `https://stockanalysis.com/stocks/{ticker}/financials/balance-sheet/` | Balance sheet |
| `https://stockanalysis.com/stocks/{ticker}/financials/cash-flow-statement/` | Cash flow |
| `https://stockanalysis.com/stocks/{ticker}/financials/ratios/` | Pre-computed ratios |
| `https://stockanalysis.com/stocks/{ticker}/forecast/` | Analyst estimates, price targets, recommendations |

## Tertiary Sources

- **Gurufocus** (`https://www.gurufocus.com/term/{metric}/{ticker}`) — specific ratio lookups, DCF estimates, quality grades. Individual metric pages are often fetchable.
- **TipRanks** — search via WebSearch for "{ticker} TipRanks SmartScore" to find the 1-10 composite score.
- **Yahoo Finance** — holder data, news, ESG scores. Fetchability varies.
- **WebSearch** — news, earnings call summaries, management commentary, industry context, competitive analysis.

## Source Priority Matrix

| Data Need | 1st Choice | 2nd Choice |
|---|---|---|
| Financial statements (structured) | SEC EDGAR XBRL API | Stock Analysis |
| Pre-computed ratios | Stock Analysis `/ratios/` | Gurufocus |
| Analyst estimates & targets | Stock Analysis `/forecast/` | WebSearch |
| Signal ratings / SmartScore | TipRanks (via WebSearch) | Stock Analysis |
| Insider transactions | SEC EDGAR Form 4 | Stock Analysis |
| 10-K risk factors / MD&A | SEC EDGAR filing text | WebSearch |
| Governance / proxy data | SEC EDGAR DEF 14A | WebSearch |
| Industry/peer comparison | Stock Analysis | WebSearch |
| News & management commentary | WebSearch | Yahoo Finance |
| DCF / intrinsic value | Gurufocus | Compute from EDGAR data |

## Fallback Behavior

If a primary source fails (timeout, 403, empty response):
1. Fall back to the next source in the priority matrix
2. Note the fallback in the output: "Data sourced from [secondary source] (primary source unavailable)"
3. If all sources fail for a metric, note it as "Data unavailable" rather than omitting silently

## SEC EDGAR Rate Limiting

SEC EDGAR enforces a 10-requests-per-second limit per User-Agent. If rate-limited (HTTP 429):
1. Wait 2 seconds and retry
2. If still rate-limited, wait 5 seconds
3. Maximum 3 retries before falling back to secondary source
