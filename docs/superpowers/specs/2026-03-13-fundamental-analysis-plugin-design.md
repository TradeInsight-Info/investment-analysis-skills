# Fundamental Analysis Plugin — Design Spec

## Overview

A Claude Code plugin providing comprehensive fundamental analysis of publicly traded companies. The plugin packages auto-triggered skills (organized by analysis theme), user-invocable slash commands for full reports, and agents for signal rating aggregation. It uses only web search and public web sources — no API keys required.

### Design Decisions

- **Adjustable depth**: All skills support summary vs. detailed output
- **US-optimized, international best-effort**: Optimized for NYSE/NASDAQ and SEC filings, but won't break on international tickers
- **Web search only**: Uses `WebSearch` and `WebFetch` — zero configuration for users
- **Parallel orchestration**: All analysis skills run in parallel; cross-validation runs sequentially after

---

## Data Sources

### Primary — SEC EDGAR XBRL API

The backbone for structured financial data. No API key required (just a `User-Agent` header).

| Endpoint | Purpose |
|---|---|
| `https://www.sec.gov/files/company_tickers.json` | Ticker-to-CIK lookup |
| `https://data.sec.gov/api/xbrl/companyfacts/CIK{10-digit-CIK}.json` | All financial data for one company (structured JSON) |
| `https://data.sec.gov/api/xbrl/frames/us-gaap/{concept}/{unit}/CY{year}.json` | Single metric across all companies (for peer comparison) |
| `https://efts.sec.gov/LATEST/search-index?q={query}&forms={form-type}&dateRange=custom&startdt=YYYY-MM-DD&enddt=YYYY-MM-DD` | Full-text filing search (preferred) |
| `https://www.sec.gov/cgi-bin/browse-edgar?action=getcompany&CIK={ticker}&type={form-type}` | Legacy filing index lookup (deprecated — use EFTS above when possible) |

Filing types: 10-K (annual), 10-Q (quarterly), 8-K (material events), DEF 14A (proxy/governance), Form 4 (insider transactions), S-1 (IPO).

### Secondary — Stock Analysis (stockanalysis.com)

Clean HTML tables, fetchable via `WebFetch`.

| URL Pattern | Data |
|---|---|
| `/stocks/{ticker}/financials/` | Income statement |
| `/stocks/{ticker}/financials/balance-sheet/` | Balance sheet |
| `/stocks/{ticker}/financials/cash-flow-statement/` | Cash flow |
| `/stocks/{ticker}/financials/ratios/` | Pre-computed ratios |
| `/stocks/{ticker}/forecast/` | Analyst estimates, price targets, recommendations |

Append `?p=quarterly` for quarterly data.

### Tertiary — Web Search Fallback

- **Gurufocus** (`gurufocus.com/term/{metric}/{ticker}`) — specific ratio lookups, DCF estimates, quality grades
- **TipRanks** — SmartScore (1-10 composite), analyst consensus, blogger/crowd sentiment
- **Yahoo Finance** — holder data, news, ESG scores (fetchability varies)
- **WebSearch** — news, earnings call summaries, management commentary, industry context

### Source Priority Matrix

| Data Need | 1st Choice | 2nd Choice |
|---|---|---|
| Financial statements (structured) | SEC EDGAR XBRL API | Stock Analysis |
| Pre-computed ratios | Stock Analysis `/ratios/` | Gurufocus |
| Analyst estimates & targets | Stock Analysis `/forecast/` | WebSearch |
| Signal ratings / SmartScore | TipRanks | Stock Analysis |
| Insider transactions | SEC EDGAR Form 4 | Stock Analysis |
| 10-K risk factors / MD&A | SEC EDGAR filing text | WebSearch |
| Governance / proxy data | SEC EDGAR DEF 14A | WebSearch |
| Industry/peer comparison | Stock Analysis | WebSearch |
| News & management commentary | WebSearch | Yahoo Finance |
| DCF / intrinsic value | Gurufocus | Compute from EDGAR data |

### Known Limitations

- **Macrotrends** and **Finviz** return 403 for automated requests — not usable
- **Earnings call transcripts** are largely paywalled — rely on WebSearch for summaries
- **International companies** may lack EDGAR filings — fall back to Stock Analysis and WebSearch
- **TipRanks** may have limited fetchability — WebSearch as fallback for SmartScore data
- **Stock Analysis** fetchability may degrade if they add bot blocking — monitor and fall back to Gurufocus + EDGAR
- **SEC EDGAR rate limit**: 10 requests/second per User-Agent — see Orchestration section for throttling strategy

---

## Analysis Coverage

### Tier 1 — Core Financial Analysis

#### 1. Income Statement Analysis
Revenue, COGS, gross profit, operating expenses, EBIT, EBITDA, net income, EPS (basic/diluted), share count trends. All with margin percentages and YoY growth rates.

#### 2. Balance Sheet Analysis
Current/non-current assets and liabilities, shareholders' equity, book value, tangible book value, net cash position, working capital.

#### 3. Cash Flow Analysis
Operating cash flow, CapEx, free cash flow, FCF margin, OCF-to-net-income ratio (quality of earnings), CapEx intensity, investing/financing activity breakdown.

#### 4. Profitability Analysis
Margin hierarchy (gross/operating/EBITDA/net/FCF), return metrics (ROE, ROA, ROIC, ROCE), DuPont decomposition of ROE.

#### 5. Valuation Analysis
P/E (trailing and forward), PEG, EV/EBITDA, EV/EBIT, P/FCF, P/B, P/S, earnings yield, DCF inputs (WACC, terminal growth rate, margin of safety). Enterprise value components.

#### 6. Financial Health
Liquidity ratios (current, quick, cash, OCF ratio), solvency ratios (debt-to-equity, debt-to-EBITDA, interest coverage), credit quality signals (debt maturity, covenant risk).

### Tier 2 — Growth & Returns

#### 7. Growth Analysis
Historical CAGRs (1/3/5/10yr) for revenue, EPS, FCF, dividends. Organic vs. acquisition-driven. Forward consensus estimates. TAM penetration. Rule of 40 for SaaS.

#### 8. Efficiency Analysis
Asset turnover, fixed asset turnover, DSO, DIO, DPO, cash conversion cycle, inventory/receivables turnover, revenue and EBITDA per employee, CapEx/depreciation ratio.

#### 9. Dividend Analysis
Yield, DPS, growth rate (1/3/5/10yr CAGR), payout ratio (earnings and FCF-based), consecutive growth years, buyback yield, total shareholder return yield, sustainability assessment.

#### 10. Analyst Estimates
Consensus revenue/EPS (current quarter through next year), price targets (high/low/mean/median), recommendation distribution (Buy/Hold/Sell), estimate revision trends, number of covering analysts.

### Tier 3 — Qualitative & Contextual

#### 11. Moat Analysis
Moat sources: intangible assets, switching costs, network effects, cost advantages, efficient scale. Quantitative signals: ROIC vs WACC persistence (5-10yr), margin stability, pricing power evidence.

#### 12. Competitive Position
Porter's Five Forces assessment, market share trends, competitive response analysis. Distinct from moat analysis — this is about the current landscape, moat is about durability.

#### 13. Management & Governance
Insider ownership, Form 4 transaction patterns, compensation alignment, capital allocation track record (M&A history, buyback timing), board independence, dual-class structures.

#### 14. Risk Assessment
Concentration risks (customer/product/geographic), leverage risk, accounting quality signals (accruals, GAAP vs non-GAAP gap, auditor changes), macro sensitivities (FX, rates, commodity), litigation exposure.

### Sector-Specific Metrics (applied when relevant)

- **SaaS**: ARR, NRR, CAC, LTV, LTV/CAC, churn rate, Rule of 40
- **Banking**: NIM, Tier 1 capital, NPL ratio, ROTCE, efficiency ratio
- **Retail**: same-store sales, revenue/sqft, e-commerce penetration
- **REITs**: FFO, adjusted FFO, NAV, occupancy rate, cap rate
- **Energy**: production volumes, reserve life, F&D costs, lifting cost/barrel

**Sector detection**: The ticker resolution step (Step 0) identifies the company's sector from Stock Analysis or the SIC code in EDGAR filings. Relevant skills then include sector-specific metrics in their output when the sector matches.

**Sector metric → skill mapping:**
- SaaS (ARR, NRR, churn, LTV/CAC): `growth-analysis` and `efficiency-analysis`
- SaaS Rule of 40: `profitability-analysis`
- Banking (NIM, Tier 1, NPL, ROTCE): `financial-health` and `profitability-analysis`
- Retail (same-store sales, revenue/sqft): `growth-analysis` and `efficiency-analysis`
- REITs (FFO, NAV, occupancy): `cash-flow-analysis` and `valuation-analysis`
- Energy (reserves, production, lifting cost): `efficiency-analysis` and `growth-analysis`

---

## Skills

### Auto-Triggered Analysis Skills (14)

Each fires based on description matching when the user asks a relevant question. Every analysis coverage area (#1-14) has a corresponding skill.

| Skill | Trigger Description | Coverage Areas |
|---|---|---|
| `income-statement-analysis/SKILL.md` | User asks about revenue, earnings, EPS, margins, income statement of a company | #1 Income Statement |
| `balance-sheet-analysis/SKILL.md` | User asks about assets, liabilities, equity, book value, balance sheet of a company | #2 Balance Sheet |
| `cash-flow-analysis/SKILL.md` | User asks about cash flow, free cash flow, FCF, operating cash flow, quality of earnings | #3 Cash Flow |
| `profitability-analysis/SKILL.md` | User asks about ROE, ROA, ROIC, return on capital, DuPont decomposition, profitability | #4 Profitability |
| `valuation-analysis/SKILL.md` | User asks if a stock is overvalued/undervalued, P/E, EV/EBITDA, DCF | #5 Valuation |
| `financial-health/SKILL.md` | User asks about debt levels, liquidity, solvency, balance sheet strength, current ratio | #6 Financial Health |
| `growth-analysis/SKILL.md` | User asks about revenue/earnings growth, growth rates, forward estimates | #7 Growth |
| `efficiency-analysis/SKILL.md` | User asks about working capital, cash conversion cycle, asset turnover | #8 Efficiency |
| `dividend-analysis/SKILL.md` | User asks about dividends, yield, payout ratio, dividend safety | #9 Dividend |
| `analyst-estimates/SKILL.md` | User asks about price targets, analyst ratings, consensus estimates | #10 Analyst Estimates |
| `moat-analysis/SKILL.md` | User asks about economic moat, moat durability, switching costs, network effects, ROIC vs WACC | #11 Moat |
| `competitive-position/SKILL.md` | User asks about competitive advantage, market position, Porter's Five Forces | #12 Competitive Position |
| `insider-activity/SKILL.md` | User asks about insider buying/selling, Form 4 filings, management governance | #13 Management & Governance |
| `risk-assessment/SKILL.md` | User asks about risks, red flags, accounting quality of a company | #14 Risk Assessment |

### Auto-Triggered Utility Skills (3)

These are helper skills that don't map to a single analysis area. They are also auto-triggered but serve a different role.

| Skill | Trigger Description | Role |
|---|---|---|
| `sec-filing-reader/SKILL.md` | User asks to read/summarize a 10-K, 10-Q, proxy, or other SEC filing | Utility — fetches and summarizes raw SEC filings on demand |
| `peer-comparison/SKILL.md` | User asks to compare a company against competitors or industry | Utility — pulls metrics from multiple analysis areas for side-by-side comparison |
| `cross-validation/SKILL.md` | User asks to validate/cross-check financial data across multiple sources | Utility — also invoked programmatically in report orchestration (sequential post-step) |

Note: `cross-validation` has dual usage — it auto-triggers when users explicitly ask to verify data, and it is also invoked programmatically by the `fundamental-analyst` agent as a sequential post-step after collecting all parallel results.

### User-Invocable Skills (Slash Commands) (2)

| Skill | Command | Purpose |
|---|---|---|
| `fundamental-report/SKILL.md` | `/fundamental-report {ticker}` | Full research note covering all 14 areas at summary depth (key metrics + brief interpretation per area) |
| `fundamental-report-detailed/SKILL.md` | `/fundamental-report-detailed {ticker}` | Comprehensive report covering all 14 areas at detailed depth (full data tables, trend analysis, extended commentary) |

### Skill Output Format

Every skill response includes:
1. **Header** — company name, ticker, current price, market cap
2. **Analysis body** — metrics, trends, interpretation (depth varies by detail level)
3. **Source links** — clickable URLs for each data point (e.g., `Source: https://stockanalysis.com/stocks/AAPL/financials/ratios/`)
4. **Disclaimer** — "For informational purposes only. Not financial advice."

---

## Agents

### fundamental-analyst

Orchestrates skills for complex, multi-step fundamental analysis questions.

- Dispatches relevant skills in parallel based on the user's question
- Chains multiple data fetches across EDGAR and Stock Analysis
- Produces structured output with source citations and disclaimers
- Tools: `WebSearch`, `WebFetch`, `Read`, `Write`
- Example triggers: "Do a full fundamental analysis of MSFT", "Compare META's financials to GOOG", "What are the strengths and weaknesses of NVDA?"

### signal-rater

Aggregates Buy/Hold/Sell ratings from multiple sources and produces a synthesized overall rating. **Fully independent** — fetches all its own data; does not consume output from any parallel analysis skill.

**Rating sources:**
- TipRanks SmartScore (1-10 composite based on 8 factors)
- Stock Analysis (analyst consensus)
- Gurufocus (value/quality grades)
- SEC EDGAR (insider buying/selling patterns as a signal)
- WebSearch (additional analyst opinions)

**Output:**
- Individual source ratings normalized to 5-point scale: Strong Buy / Buy / Hold / Sell / Strong Sell
- TipRanks SmartScore (1-10)
- Weighted summary rating with rationale per source
- Confidence level based on source agreement

- Tools: `WebSearch`, `WebFetch`, `Read`, `Write`
- Example triggers: "What's the rating for AAPL?", "Should I buy or sell TSLA?", "Give me buy/sell signals for MSFT"

---

## Report Structure

The full report (`/fundamental-report` and `/fundamental-report-detailed`) follows this structure:

### 1. Key Metrics Summary

Quick-reference table of the most important numbers:

```
Price, Market Cap
P/E, Forward P/E, EV/EBITDA, P/FCF
Revenue Growth, EPS Growth
ROE, ROIC
Gross Margin, Net Margin
Debt/Equity, Current Ratio
FCF Yield, Dividend Yield
TipRanks SmartScore (X/10)
Overall Signal (Buy/Hold/Sell)
```

### 2. Signal Rating

Aggregated Buy/Hold/Sell with per-source breakdown (from signal-rater agent).

### 3. Detailed Analysis

All analysis skill results organized by theme (Tier 1 → Tier 2 → Tier 3). Depth determined by which slash command was used (summary vs. detailed).

### 4. Cross-Validation

Discrepancy flags where data points differ between sources. Shows both values and source links.

### 5. Reasons to Consider

Bull case arguments derived from the analysis — e.g., strong moat, accelerating growth, undervalued relative to peers, high insider buying, expanding margins.

### 6. Reasons to Avoid

Bear case arguments — e.g., high debt levels, declining margins, accounting red flags, overvaluation, customer concentration, negative estimate revisions.

### 7. Source Links

All URLs referenced throughout the report, grouped by source.

### 8. Disclaimer

"For informational purposes only. Not financial advice. Data sourced from public filings and third-party websites. Verify critical data points independently before making investment decisions."

---

## Orchestration

### Parallel Execution Pattern

The `fundamental-report` slash commands and the `fundamental-analyst` agent use this pattern:

```
User triggers report
        │
        ├─ Step 0: Ticker resolution (CIK lookup via company_tickers.json)
        │
        ├── parallel ──┬─ income-statement-analysis     (area #1)
        │              ├─ balance-sheet-analysis        (area #2)
        │              ├─ cash-flow-analysis            (area #3)
        │              ├─ profitability-analysis        (area #4)
        │              ├─ valuation-analysis            (area #5)
        │              ├─ financial-health              (area #6)
        │              ├─ growth-analysis               (area #7)
        │              ├─ efficiency-analysis           (area #8)
        │              ├─ dividend-analysis             (area #9)
        │              ├─ analyst-estimates             (area #10)
        │              ├─ moat-analysis                 (area #11)
        │              ├─ competitive-position          (area #12)
        │              ├─ insider-activity              (area #13)
        │              ├─ risk-assessment               (area #14)
        │              ├─ peer-comparison               (utility)
        │              ├─ sec-filing-reader             (utility, 10-K summary)
        │              └─ signal-rater agent           (independent)
        │                        │
        │              all 17 results collected
        │                        │
        └── sequential ─── cross-validation
                                 │
                          Final Report assembled
```

**Step 0 — Ticker Resolution**: Before the parallel fan-out, a shared pre-step resolves the ticker to a CIK number (via `company_tickers.json`) and caches company metadata (name, exchange, sector). This avoids redundant lookups across skills and handles edge cases (ambiguous tickers, delisted companies) in one place. The resolved CIK and metadata are passed to all parallel skills.

**Parallel phase**: 14 analysis skills + 2 utility skills + 1 agent = 17 parallel tasks. Each fetches its own data independently. The signal-rater agent does not consume output from any parallel skill.

**Sequential phase**: Cross-validation runs after all results are collected, comparing key data points against alternative sources and flagging discrepancies.

**SEC EDGAR throttling**: Skills sharing the same EDGAR session should stagger requests to stay under the 10-requests/second limit. In practice, since skills run as separate subagents with independent fetch timing, natural variance in execution provides sufficient staggering. If rate limiting is hit, skills should retry with exponential backoff.

**Degradation**: If a primary source fails, skills fall back to the next source in the priority matrix and note the fallback in their output. The cross-validation step flags any areas where only one source was available.

---

## Plugin File Structure

```
fundamental-analysis/
  plugin.json
  skills/
    income-statement-analysis/SKILL.md
    balance-sheet-analysis/SKILL.md
    cash-flow-analysis/SKILL.md
    profitability-analysis/SKILL.md
    valuation-analysis/SKILL.md
    financial-health/SKILL.md
    growth-analysis/SKILL.md
    efficiency-analysis/SKILL.md
    dividend-analysis/SKILL.md
    analyst-estimates/SKILL.md
    moat-analysis/SKILL.md
    competitive-position/SKILL.md
    insider-activity/SKILL.md
    risk-assessment/SKILL.md
    sec-filing-reader/SKILL.md
    peer-comparison/SKILL.md
    cross-validation/SKILL.md
    fundamental-report/SKILL.md
    fundamental-report-detailed/SKILL.md
  agents/
    fundamental-analyst.md
    signal-rater.md
```
