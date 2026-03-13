# Investment Analysis Skills

A collection of Agents and Skills for investment analysis — fundamental, technical, and sentiment analysis of publicly traded companies.


### Fundamental Analysis

Comprehensive fundamental analysis covering financial statements, valuation, moat analysis, signal ratings, and full research reports. Optimized for US-listed companies with best-effort international support.

**Install:**

```bash
npx skills add https://github.com/TradeInsight-info/investment-analysis-skills --skill {skill-name}
```

For Claude:

```bash
claude add marketplace
```



**Slash Commands:**


| Command                               | Description                                                                                                                    |
| --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `/fundamental-report TICKER`          | Full research note at summary depth — key metrics, signal rating, analysis across 14 areas, cross-validation, bull/bear cases |
| `/fundamental-report-detailed TICKER` | Same report at detailed depth — multi-year data tables, trend analysis, extended commentary                                   |

Reports are saved to `reports/YYYY-MM-DD-HH-MM-SS-TICKER.md` with a concise summary displayed in the terminal.


**Analysis Skills (14):**

| Skill | Tier | Description |
| --- | --- | --- |
| `income-statement-analysis` | Core Financial | Revenue, earnings, margins, EPS trends |
| `balance-sheet-analysis` | Core Financial | Assets, liabilities, equity structure |
| `cash-flow-analysis` | Core Financial | Operating, investing, financing cash flows |
| `profitability-analysis` | Core Financial | ROE, ROIC, margins, profitability ratios |
| `valuation-analysis` | Core Financial | P/E, EV/EBITDA, P/FCF, DCF, relative valuation |
| `financial-health` | Core Financial | Debt ratios, liquidity, solvency, Altman Z-Score |
| `growth-analysis` | Growth & Returns | Revenue/earnings growth, forward estimates |
| `efficiency-analysis` | Growth & Returns | Asset turnover, inventory, receivables efficiency |
| `dividend-analysis` | Growth & Returns | Yield, payout ratio, growth, sustainability |
| `analyst-estimates` | Growth & Returns | Consensus estimates, revisions, surprise history |
| `moat-analysis` | Qualitative | Economic moat sources, durability, width |
| `competitive-position` | Qualitative | Market share, Porter's Five Forces, peer landscape |
| `insider-activity` | Qualitative | Insider buying/selling, Form 4 filings |
| `risk-assessment` | Qualitative | Business, financial, regulatory, macro risks |

**Utility Skills (3):**

| Skill | Description |
| --- | --- |
| `peer-comparison` | Compare a company against sector peers |
| `sec-filing-reader` | Extract and summarize SEC EDGAR filings |
| `cross-validation` | Verify key metrics across multiple data sources |

**Agents:**


| Agent                 | Trigger                                                                     |
| ----------------------- | ----------------------------------------------------------------------------- |
| `fundamental-analyst` | Open-ended analysis requests ("analyze MSFT", "compare META to GOOG")       |
| `signal-rater`        | Buy/Hold/Sell ratings ("what's the rating for AAPL?", "should I buy TSLA?") |


**Data Sources:**

- SEC EDGAR XBRL API (primary for financial data)
- Stock Analysis (secondary for ratios, estimates)
- Gurufocus (quality grades, GF Value)
- TipRanks (SmartScore, analyst consensus)

No API keys required — all sources are publicly accessible.

### Technical Analysis

_Coming soon._

### Sentiment Analysis

_Coming soon._

## Disclaimer

For informational purposes only. Not financial advice. Data sourced from public filings and third-party websites. Verify critical data points independently before making investment decisions.
