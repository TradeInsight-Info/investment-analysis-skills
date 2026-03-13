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
| `https://www.sec.gov/cgi-bin/browse-edgar?action=getcompany&CIK={ticker}&type={form-type}` | Filing index lookup |

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

---

## Skills

### Auto-Triggered Skills (12)

Each fires based on description matching when the user asks a relevant question.

| Skill File | Trigger Description |
|---|---|
| `profitability-analysis.md` | User asks about margins, ROE, ROA, ROIC, profitability of a company |
| `financial-health.md` | User asks about debt levels, liquidity, solvency, balance sheet strength |
| `valuation-analysis.md` | User asks if a stock is overvalued/undervalued, P/E, EV/EBITDA, DCF |
| `growth-analysis.md` | User asks about revenue/earnings growth, growth rates, forward estimates |
| `efficiency-analysis.md` | User asks about working capital, cash conversion cycle, asset turnover |
| `dividend-analysis.md` | User asks about dividends, yield, payout ratio, dividend safety |
| `analyst-estimates.md` | User asks about price targets, analyst ratings, consensus estimates |
| `risk-assessment.md` | User asks about risks, red flags, accounting quality of a company |
| `competitive-position.md` | User asks about competitive advantage, market position, Porter's Five Forces |
| `moat-analysis.md` | User asks about economic moat, moat durability, switching costs, network effects, ROIC vs WACC |
| `insider-activity.md` | User asks about insider buying/selling, Form 4 filings |
| `sec-filing-reader.md` | User asks to read/summarize a 10-K, 10-Q, proxy, or other SEC filing |
| `peer-comparison.md` | User asks to compare a company against competitors or industry |
| `cross-validation.md` | User asks to validate/cross-check financial data across multiple sources |

### User-Invocable Skills (Slash Commands) (2)

| Skill File | Command | Purpose |
|---|---|---|
| `fundamental-report.md` | `/fundamental-report {ticker}` | Full research note (summary depth) |
| `fundamental-report-detailed.md` | `/fundamental-report-detailed {ticker}` | Comprehensive report (all 14 areas, detailed depth) |

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
- Tools: `WebSearch`, `WebFetch`, `Read`, `Write`, `Bash`
- Example triggers: "Do a full fundamental analysis of MSFT", "Compare META's financials to GOOG", "What are the strengths and weaknesses of NVDA?"

### signal-rating

Aggregates Buy/Hold/Sell ratings from multiple sources and produces a synthesized overall rating.

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

Aggregated Buy/Hold/Sell with per-source breakdown (from signal-rating agent).

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
        ├── parallel ──┬─ profitability-analysis
        │              ├─ financial-health
        │              ├─ valuation-analysis
        │              ├─ growth-analysis
        │              ├─ efficiency-analysis
        │              ├─ moat-analysis
        │              ├─ dividend-analysis
        │              ├─ analyst-estimates
        │              ├─ risk-assessment
        │              ├─ competitive-position
        │              ├─ insider-activity
        │              └─ signal-rating agent
        │                        │
        │              results collected
        │                        │
        └── sequential ─── cross-validation
                                 │
                          Final Report assembled
```

All 12 analysis tasks run in parallel (independent data fetches). Cross-validation runs sequentially after all results are collected, since it needs to compare outputs against alternative sources.

---

## Plugin File Structure

```
plugin.json
skills/
  profitability-analysis.md
  financial-health.md
  valuation-analysis.md
  growth-analysis.md
  efficiency-analysis.md
  dividend-analysis.md
  analyst-estimates.md
  risk-assessment.md
  competitive-position.md
  moat-analysis.md
  insider-activity.md
  sec-filing-reader.md
  peer-comparison.md
  cross-validation.md
  fundamental-report.md
  fundamental-report-detailed.md
agents/
  fundamental-analyst.md
  signal-rating.md
```
