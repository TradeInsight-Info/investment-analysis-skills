# Fundamental Analysis Plugin Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Claude Code plugin providing comprehensive fundamental analysis of publicly traded companies with 19 skills and 2 agents.

**Architecture:** Plugin uses auto-discovered skills organized by analysis theme, two agents (fundamental-analyst orchestrator, signal-rater aggregator), and web-only data fetching (SEC EDGAR XBRL API + Stock Analysis + WebSearch). Skills run in parallel during report generation; cross-validation runs sequentially after.

**Tech Stack:** Claude Code plugin (markdown-based skills/agents), YAML frontmatter, WebSearch/WebFetch for data

**Spec:** `docs/superpowers/specs/2026-03-13-fundamental-analysis-plugin-design.md`

**Conventions:**
- **Auto-discovery**: Claude Code auto-discovers skills in `skills/` (by finding `SKILL.md` files) and agents in `agents/` (by finding `.md` files). No explicit registration in `plugin.json` is needed.
- **Skill type field**: Auto-triggered skills omit the `type` field in frontmatter (auto-triggered is the default). Only user-invocable slash command skills include `type: user-invocable`.
- **Shared references**: All skills reference shared data-fetching and output-format instructions via: `Consult ${CLAUDE_PLUGIN_ROOT}/skills/_shared/references/data-sources.md for data fetching instructions` and `Consult ${CLAUDE_PLUGIN_ROOT}/skills/_shared/references/output-format.md for output structure`. `${CLAUDE_PLUGIN_ROOT}` is resolved at runtime by Claude Code to the plugin's install directory.
- **Skill body target**: All SKILL.md bodies should be ~1,500-2,000 words in imperative/infinitive style (verb-first instructions, not second person). Detailed content goes in `references/` subdirectories when needed.
- **`_shared/` directory**: A plan-level addition (not in the spec file structure) to avoid duplicating data-source and output-format instructions across 19 skills.

---

## Chunk 1: Plugin Scaffold and Core Infrastructure

### Task 1: Create plugin manifest and directory structure

**Files:**
- Create: `fundamental-analysis/.claude-plugin/plugin.json`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p fundamental-analysis/.claude-plugin
mkdir -p fundamental-analysis/skills
mkdir -p fundamental-analysis/agents
```

- [ ] **Step 2: Write plugin manifest**

Create `fundamental-analysis/.claude-plugin/plugin.json`:

```json
{
  "name": "fundamental-analysis",
  "version": "0.1.0",
  "description": "Comprehensive fundamental analysis of publicly traded companies — financial statements, valuation, moat analysis, signal ratings, and full research reports.",
  "keywords": ["investing", "fundamental-analysis", "stocks", "finance", "SEC", "valuation"]
}
```

- [ ] **Step 3: Commit**

```bash
git add fundamental-analysis/
git commit -m "feat: scaffold fundamental-analysis plugin structure"
```

---

### Task 2: Create shared references for data source instructions

All analysis skills need to know how to fetch data from SEC EDGAR and Stock Analysis. Create a shared reference file to avoid duplicating these instructions across 19 skills.

**Files:**
- Create: `fundamental-analysis/skills/_shared/references/data-sources.md`
- Create: `fundamental-analysis/skills/_shared/references/output-format.md`

- [ ] **Step 1: Create shared references directory**

```bash
mkdir -p fundamental-analysis/skills/_shared/references
```

- [ ] **Step 2: Write data-sources.md**

Create `fundamental-analysis/skills/_shared/references/data-sources.md` containing:

- SEC EDGAR XBRL API endpoints and usage (ticker-to-CIK lookup via `company_tickers.json`, companyfacts endpoint, frames endpoint, EFTS search)
- User-Agent header requirement for SEC EDGAR
- Stock Analysis URL patterns for all page types (financials, balance-sheet, cash-flow, ratios, forecast) with quarterly toggle
- Gurufocus URL pattern for specific ratio lookups
- TipRanks SmartScore lookup via WebSearch
- Source priority matrix (which source to try first for each data type)
- Fallback behavior: if primary source fails, try secondary; note the fallback in output
- SEC EDGAR rate limit note (10 req/s) and retry guidance

- [ ] **Step 3: Write output-format.md**

Create `fundamental-analysis/skills/_shared/references/output-format.md` containing:

- Standard output structure: Header (company name, ticker, price, market cap) → Analysis body → Source links (clickable URLs) → Disclaimer
- Disclaimer text: "For informational purposes only. Not financial advice. Data sourced from public filings and third-party websites. Verify critical data points independently before making investment decisions."
- Adjustable depth guidance: "summary" = key metrics + 1-2 sentence interpretation per item; "detailed" = full data tables, multi-year trends, extended commentary
- Source link format: inline after each data point, e.g. `(Source: [Stock Analysis](https://stockanalysis.com/stocks/AAPL/financials/ratios/))`
- For international tickers without EDGAR data: fall back to Stock Analysis and WebSearch, note limited coverage

- [ ] **Step 4: Commit**

```bash
git add fundamental-analysis/skills/_shared/
git commit -m "feat: add shared data source and output format references"
```

---

## Chunk 2: Tier 1 Analysis Skills — Core Financial (6 skills)

### Task 3: Create income-statement-analysis skill

**Files:**
- Create: `fundamental-analysis/skills/income-statement-analysis/SKILL.md`

- [ ] **Step 1: Create skill directory**

```bash
mkdir -p fundamental-analysis/skills/income-statement-analysis
```

- [ ] **Step 2: Write SKILL.md**

Create `fundamental-analysis/skills/income-statement-analysis/SKILL.md` with:

**Frontmatter:**
```yaml
---
name: income-statement-analysis
description: >
  This skill should be used when the user asks about "revenue", "earnings",
  "EPS", "income statement", "margins", "gross profit", "operating income",
  "net income", "EBITDA", "cost of goods sold", "COGS", "operating expenses",
  or "share count" of a publicly traded company. Also triggers when the user
  asks about "top line", "bottom line", or "earnings per share" for a stock.
---
```

**Body (imperative style, ~1,500 words):**

1. Purpose section: Analyze a company's income statement covering revenue, COGS, gross profit, operating expenses, EBIT, EBITDA, net income, EPS (basic/diluted), share count trends. Compute all margin percentages and YoY growth rates.
2. Data fetching process:
   - Resolve ticker to CIK using `company_tickers.json` (via WebFetch)
   - Fetch income statement data from SEC EDGAR companyfacts API (primary) or Stock Analysis `/financials/` page (secondary)
   - Retrieve both annual and quarterly data when available
3. Analysis steps:
   - Compute margin hierarchy: gross margin, operating margin, EBITDA margin, net margin
   - Compute YoY growth rates for revenue, gross profit, operating income, net income, EPS
   - Track share count trend (dilution vs buyback signal)
   - Identify revenue quality: recurring vs one-time, operating leverage
   - Note any sector-specific adjustments (SaaS companies: also report ARR if available)
4. Depth handling: if user asks for summary, provide key metrics table + 2-3 sentence interpretation. If detailed, provide full multi-year data table with trend commentary
5. Reference shared data sources: `Consult ${CLAUDE_PLUGIN_ROOT}/skills/_shared/references/data-sources.md for data fetching instructions`
6. Reference shared output format: `Consult ${CLAUDE_PLUGIN_ROOT}/skills/_shared/references/output-format.md for output structure`

- [ ] **Step 3: Commit**

```bash
git add fundamental-analysis/skills/income-statement-analysis/
git commit -m "feat: add income-statement-analysis skill"
```

---

### Task 4: Create balance-sheet-analysis skill

**Files:**
- Create: `fundamental-analysis/skills/balance-sheet-analysis/SKILL.md`

- [ ] **Step 1: Create skill directory and write SKILL.md**

```bash
mkdir -p fundamental-analysis/skills/balance-sheet-analysis
```

**Frontmatter:**
```yaml
---
name: balance-sheet-analysis
description: >
  This skill should be used when the user asks about "balance sheet", "assets",
  "liabilities", "equity", "book value", "tangible book value", "net cash",
  "working capital", "shareholders equity", "goodwill", "intangible assets",
  "debt", "accounts receivable", "inventory", or "total assets" of a publicly
  traded company.
---
```

**Body:** Follow same structure as Task 3 but covering:
- Current/non-current assets breakdown (cash, receivables, inventory, PP&E, goodwill, intangibles)
- Current/non-current liabilities breakdown (payables, short/long-term debt, deferred revenue)
- Shareholders' equity (common stock, retained earnings, AOCI, treasury stock)
- Derived metrics: book value per share, tangible book value per share, net cash (cash minus total debt), net cash per share, working capital, debt-to-equity, debt-to-assets, equity multiplier
- Multi-year trends for key items
- Reference shared data sources and output format

- [ ] **Step 2: Commit**

```bash
git add fundamental-analysis/skills/balance-sheet-analysis/
git commit -m "feat: add balance-sheet-analysis skill"
```

---

### Task 5: Create cash-flow-analysis skill

**Files:**
- Create: `fundamental-analysis/skills/cash-flow-analysis/SKILL.md`

- [ ] **Step 1: Create skill directory and write SKILL.md**

```bash
mkdir -p fundamental-analysis/skills/cash-flow-analysis
```

**Frontmatter:**
```yaml
---
name: cash-flow-analysis
description: >
  This skill should be used when the user asks about "cash flow", "free cash flow",
  "FCF", "operating cash flow", "OCF", "capital expenditures", "CapEx",
  "quality of earnings", "cash flow statement", "FCF margin", "cash conversion",
  or "levered free cash flow" of a publicly traded company. Also triggers for
  questions about "FFO" or "funds from operations" for REITs.
---
```

**Body:** Cover:
- Operating activities: OCF, D&A, stock-based compensation, working capital changes, OCF margin, OCF-to-net-income ratio (quality of earnings)
- Investing activities: CapEx, acquisitions, investment purchases/proceeds
- Financing activities: debt issuance/repayment, buybacks, dividends paid
- Derived: FCF (OCF minus CapEx), FCF margin, FCF per share, FCF growth rate, CapEx intensity (CapEx/Revenue), CapEx vs D&A ratio, levered vs unlevered FCF
- Sector-specific: REITs → FFO/AFFO; note in SKILL.md to check sector
- Reference shared data sources and output format

- [ ] **Step 2: Commit**

```bash
git add fundamental-analysis/skills/cash-flow-analysis/
git commit -m "feat: add cash-flow-analysis skill"
```

---

### Task 6: Create profitability-analysis skill

**Files:**
- Create: `fundamental-analysis/skills/profitability-analysis/SKILL.md`

- [ ] **Step 1: Create skill directory and write SKILL.md**

```bash
mkdir -p fundamental-analysis/skills/profitability-analysis
```

**Frontmatter:**
```yaml
---
name: profitability-analysis
description: >
  This skill should be used when the user asks about "ROE", "ROA", "ROIC",
  "return on equity", "return on assets", "return on invested capital", "ROCE",
  "return on capital employed", "DuPont decomposition", "DuPont analysis",
  "profitability", "return metrics", or "Rule of 40" of a publicly traded company.
---
```

**Body:** Cover:
- Margin hierarchy (gross/operating/EBITDA/net/FCF margins) with multi-year trends
- Return metrics: ROE, ROA, ROIC, ROCE, ROTE
- DuPont decomposition of ROE: Net Margin × Asset Turnover × Equity Multiplier — identify whether profitability, efficiency, or leverage is driving ROE
- Sector-specific: SaaS → Rule of 40 (Revenue Growth + FCF Margin); Banking → ROTCE
- Compare returns against cost of capital (WACC) when data available
- Reference shared data sources and output format

- [ ] **Step 2: Commit**

```bash
git add fundamental-analysis/skills/profitability-analysis/
git commit -m "feat: add profitability-analysis skill"
```

---

### Task 7: Create valuation-analysis skill

**Files:**
- Create: `fundamental-analysis/skills/valuation-analysis/SKILL.md`

- [ ] **Step 1: Create skill directory and write SKILL.md**

```bash
mkdir -p fundamental-analysis/skills/valuation-analysis
```

**Frontmatter:**
```yaml
---
name: valuation-analysis
description: >
  This skill should be used when the user asks if a stock is "overvalued",
  "undervalued", "fairly valued", or asks about "P/E ratio", "forward P/E",
  "PEG ratio", "EV/EBITDA", "EV/EBIT", "price to earnings", "price to sales",
  "price to book", "P/FCF", "price to free cash flow", "DCF",
  "discounted cash flow", "intrinsic value", "enterprise value", "earnings yield",
  "margin of safety", or "valuation" of a publicly traded company.
---
```

**Body:** Cover:
- Earnings-based: P/E (TTM), Forward P/E, PEG, normalized P/E
- Cash flow-based: P/FCF, EV/EBITDA, EV/EBIT, EV/FCF, EV/Revenue
- Book value-based: P/B, P/Tangible Book
- Revenue-based: P/S, EV/Revenue
- Income-based: dividend yield, earnings yield (1/PE vs risk-free rate)
- Enterprise value components: market cap + total debt - cash
- DCF context: note key inputs (FCF projections, WACC, terminal growth rate) — compute if sufficient data; otherwise reference Gurufocus DCF estimate
- Analyst estimates for forward valuations (from Stock Analysis `/forecast/`)
- Sector-specific: REITs → P/FFO, P/NAV
- Reference shared data sources and output format

- [ ] **Step 2: Commit**

```bash
git add fundamental-analysis/skills/valuation-analysis/
git commit -m "feat: add valuation-analysis skill"
```

---

### Task 8: Create financial-health skill

**Files:**
- Create: `fundamental-analysis/skills/financial-health/SKILL.md`

- [ ] **Step 1: Create skill directory and write SKILL.md**

```bash
mkdir -p fundamental-analysis/skills/financial-health
```

**Frontmatter:**
```yaml
---
name: financial-health
description: >
  This skill should be used when the user asks about "debt levels", "liquidity",
  "solvency", "balance sheet strength", "current ratio", "quick ratio",
  "debt to equity", "interest coverage", "financial health", "credit quality",
  "debt maturity", "leverage", "debt to EBITDA", or "cash ratio" of a publicly
  traded company. Also triggers for "Tier 1 capital" or "capital ratio" for banks.
---
```

**Body:** Cover:
- Liquidity: current ratio, quick ratio, cash ratio, OCF ratio
- Solvency: D/E, debt-to-EBITDA, net debt-to-EBITDA, interest coverage, fixed charge coverage, debt-to-assets
- Credit quality signals: debt maturity schedule (from 10-K footnotes), covenant risk, unfunded pension obligations
- Interpretation guidance: what "healthy" looks like varies by sector
- Sector-specific: Banking → Tier 1 capital ratio, NPL ratio, loan-to-deposit ratio
- Reference shared data sources and output format

- [ ] **Step 2: Commit**

```bash
git add fundamental-analysis/skills/financial-health/
git commit -m "feat: add financial-health skill"
```

- [ ] **Step 3: Commit chunk 2 checkpoint**

```bash
git add -A fundamental-analysis/skills/
git commit -m "feat: complete Tier 1 core financial analysis skills (6 skills)"
```

---

## Chunk 3: Tier 2 Analysis Skills — Growth & Returns (4 skills)

### Task 9: Create growth-analysis skill

**Files:**
- Create: `fundamental-analysis/skills/growth-analysis/SKILL.md`

- [ ] **Step 1: Create skill directory and write SKILL.md**

```bash
mkdir -p fundamental-analysis/skills/growth-analysis
```

**Frontmatter:**
```yaml
---
name: growth-analysis
description: >
  This skill should be used when the user asks about "revenue growth",
  "earnings growth", "EPS growth", "growth rate", "CAGR", "forward estimates",
  "growth analysis", "organic growth", "same-store sales growth", "comps",
  "TAM", "total addressable market", or "growth trajectory" of a publicly
  traded company.
---
```

**Body:** Cover:
- Historical CAGRs (1/3/5/10yr) for: revenue, gross profit, operating income, net income, EPS, FCF, dividends
- Growth quality: organic vs acquisition-driven, volume vs price/mix, geographic decomposition, segment-level
- Forward-looking: consensus revenue/EPS growth estimates (from Stock Analysis `/forecast/`), management guidance, long-term growth rate
- Sector-specific: Retail → same-store sales growth; SaaS → ARR/MRR growth, NRR; Energy → production volume growth, reserve replacement ratio
- Reference shared data sources and output format

- [ ] **Step 2: Commit**

```bash
git add fundamental-analysis/skills/growth-analysis/
git commit -m "feat: add growth-analysis skill"
```

---

### Task 10: Create efficiency-analysis skill

**Files:**
- Create: `fundamental-analysis/skills/efficiency-analysis/SKILL.md`

- [ ] **Step 1: Create skill directory and write SKILL.md**

```bash
mkdir -p fundamental-analysis/skills/efficiency-analysis
```

**Frontmatter:**
```yaml
---
name: efficiency-analysis
description: >
  This skill should be used when the user asks about "working capital",
  "cash conversion cycle", "asset turnover", "DSO", "DIO", "DPO",
  "days sales outstanding", "days inventory outstanding", "days payable outstanding",
  "inventory turnover", "receivables turnover", "revenue per employee",
  "efficiency", or "capital efficiency" of a publicly traded company.
---
```

**Body:** Cover:
- Asset turnover (total and fixed), receivables turnover, inventory turnover
- Working capital efficiency: DSO, DIO, DPO, cash conversion cycle (CCC = DSO + DIO - DPO), interpretation (negative CCC = competitive advantage)
- Capital efficiency: revenue per employee, EBITDA per employee, CapEx/revenue trend, CapEx/depreciation ratio
- Sector-specific: SaaS → CAC, LTV, LTV/CAC; Retail → revenue per sqft; Energy → lifting cost per barrel
- Reference shared data sources and output format

- [ ] **Step 2: Commit**

```bash
git add fundamental-analysis/skills/efficiency-analysis/
git commit -m "feat: add efficiency-analysis skill"
```

---

### Task 11: Create dividend-analysis skill

**Files:**
- Create: `fundamental-analysis/skills/dividend-analysis/SKILL.md`

- [ ] **Step 1: Create skill directory and write SKILL.md**

```bash
mkdir -p fundamental-analysis/skills/dividend-analysis
```

**Frontmatter:**
```yaml
---
name: dividend-analysis
description: >
  This skill should be used when the user asks about "dividend", "dividend yield",
  "payout ratio", "dividend safety", "dividend growth", "dividend aristocrat",
  "dividend king", "buyback", "share repurchase", "total shareholder return",
  "dividend sustainability", or "income investing" for a publicly traded company.
---
```

**Body:** Cover:
- Dividend per share (annual/quarterly), dividend yield, growth rate CAGRs (1/3/5/10yr)
- Payout ratios: earnings-based and FCF-based (more reliable)
- Consecutive growth years (Aristocrat = 25+, King = 50+)
- Buyback yield (buyback amount / market cap), total shareholder return yield
- Sustainability assessment: can dividend be maintained if earnings fall 20-30%?
- Special/irregular dividends
- Reference shared data sources and output format

- [ ] **Step 2: Commit**

```bash
git add fundamental-analysis/skills/dividend-analysis/
git commit -m "feat: add dividend-analysis skill"
```

---

### Task 12: Create analyst-estimates skill

**Files:**
- Create: `fundamental-analysis/skills/analyst-estimates/SKILL.md`

- [ ] **Step 1: Create skill directory and write SKILL.md**

```bash
mkdir -p fundamental-analysis/skills/analyst-estimates
```

**Frontmatter:**
```yaml
---
name: analyst-estimates
description: >
  This skill should be used when the user asks about "price target",
  "analyst rating", "consensus estimate", "analyst recommendation",
  "buy rating", "sell rating", "hold rating", "EPS estimate",
  "revenue estimate", "analyst coverage", "estimate revisions",
  "wall street consensus", or "analyst forecast" for a publicly traded company.
---
```

**Body:** Cover:
- Consensus estimates: revenue and EPS for current quarter, next quarter, current year, next year
- High/low/mean estimates, number of covering analysts
- Price targets: high, low, average, median
- Recommendation distribution: Strong Buy / Buy / Hold / Sell / Strong Sell counts
- Estimate revision trends: upgrades vs downgrades momentum over past 30/90 days
- Primary source: Stock Analysis `/forecast/` page
- Reference shared data sources and output format

- [ ] **Step 2: Commit**

```bash
git add fundamental-analysis/skills/analyst-estimates/
git commit -m "feat: add analyst-estimates skill"
```

---

## Chunk 4: Tier 3 Analysis Skills — Qualitative & Contextual (4 skills)

### Task 13: Create moat-analysis skill

**Files:**
- Create: `fundamental-analysis/skills/moat-analysis/SKILL.md`

- [ ] **Step 1: Create skill directory and write SKILL.md**

```bash
mkdir -p fundamental-analysis/skills/moat-analysis
```

**Frontmatter:**
```yaml
---
name: moat-analysis
description: >
  This skill should be used when the user asks about "economic moat",
  "moat", "competitive moat", "moat durability", "switching costs",
  "network effects", "cost advantage", "intangible assets", "brand moat",
  "pricing power", "ROIC vs WACC", "sustainable competitive advantage",
  or "efficient scale" of a publicly traded company.
---
```

**Body:** Cover:
- Moat sources (Morningstar framework): intangible assets (brands, patents, licenses), switching costs, network effects, cost advantages (scale, proprietary processes), efficient scale
- Quantitative moat signals: ROIC consistently above WACC for 5-10+ years, stable/expanding gross margins, pricing power evidence, market share trend
- Assessment framework: identify which moat sources apply, rate durability
- Data approach: use EDGAR for multi-year ROIC/margin data; use WebSearch for qualitative moat analysis (brand strength, patent portfolio, network dynamics)
- Reference shared data sources and output format

- [ ] **Step 2: Commit**

```bash
git add fundamental-analysis/skills/moat-analysis/
git commit -m "feat: add moat-analysis skill"
```

---

### Task 14: Create competitive-position skill

**Files:**
- Create: `fundamental-analysis/skills/competitive-position/SKILL.md`

- [ ] **Step 1: Create skill directory and write SKILL.md**

```bash
mkdir -p fundamental-analysis/skills/competitive-position
```

**Frontmatter:**
```yaml
---
name: competitive-position
description: >
  This skill should be used when the user asks about "competitive advantage",
  "market position", "Porter's Five Forces", "competitive landscape",
  "market share", "industry competition", "barriers to entry",
  "threat of substitutes", "competitive analysis", or "industry structure"
  of a publicly traded company.
---
```

**Body:** Cover:
- Porter's Five Forces assessment: competitive rivalry, threat of new entrants, threat of substitutes, buyer power, supplier power
- Market share trends and competitive response analysis
- Industry context: concentration (oligopoly vs fragmented), regulatory environment, technology disruption risk, capital intensity
- Peer comparison context: industry average margins/multiples vs company
- Distinct from moat analysis: this is about the current competitive landscape; moat is about durability of advantages
- Data approach: primarily WebSearch for industry reports, competitor info; Stock Analysis for peer financial comparisons
- Reference shared data sources and output format

- [ ] **Step 2: Commit**

```bash
git add fundamental-analysis/skills/competitive-position/
git commit -m "feat: add competitive-position skill"
```

---

### Task 15: Create insider-activity skill

**Files:**
- Create: `fundamental-analysis/skills/insider-activity/SKILL.md`

- [ ] **Step 1: Create skill directory and write SKILL.md**

```bash
mkdir -p fundamental-analysis/skills/insider-activity
```

**Frontmatter:**
```yaml
---
name: insider-activity
description: >
  This skill should be used when the user asks about "insider buying",
  "insider selling", "insider transactions", "Form 4", "insider ownership",
  "insider activity", "executive compensation", "management governance",
  "board independence", "capital allocation", "insider trading filings",
  or "management skin in the game" of a publicly traded company.
---
```

**Body:** Cover:
- Insider ownership percentage and insider buying vs selling trends (SEC Form 4 filings)
- Executive compensation structure (salary/equity/bonus from DEF 14A proxy)
- Capital allocation track record: M&A history, buyback timing quality, dividend policy consistency
- Governance: board independence ratio, classified board, dual-class structure, related-party transactions
- Transparency: guidance track record, GAAP vs non-GAAP gap, accounting conservatism signals
- Data approach: SEC EDGAR Form 4 for insider transactions, DEF 14A for proxy/governance data
- Reference shared data sources and output format

- [ ] **Step 2: Commit**

```bash
git add fundamental-analysis/skills/insider-activity/
git commit -m "feat: add insider-activity skill"
```

---

### Task 16: Create risk-assessment skill

**Files:**
- Create: `fundamental-analysis/skills/risk-assessment/SKILL.md`

- [ ] **Step 1: Create skill directory and write SKILL.md**

```bash
mkdir -p fundamental-analysis/skills/risk-assessment
```

**Frontmatter:**
```yaml
---
name: risk-assessment
description: >
  This skill should be used when the user asks about "risks", "red flags",
  "accounting quality", "risk factors", "customer concentration",
  "geographic concentration", "product concentration", "litigation risk",
  "accounting red flags", "GAAP vs non-GAAP", "risk assessment",
  "key person risk", or "regulatory risk" of a publicly traded company.
---
```

**Body:** Cover:
- Business risks: customer/product/geographic concentration, technology obsolescence, key-person dependency, litigation/legal exposure, IP protection
- Financial risks: leverage risk, refinancing risk (debt maturity wall), pension underfunding, off-balance-sheet obligations
- Macro risks: FX headwinds, tariff/trade exposure, interest rate sensitivity, inflation impact on input costs
- Accounting quality: revenue recognition aggressiveness, GAAP vs non-GAAP earnings gap, unusual accruals, auditor changes or going-concern flags
- Data approach: SEC EDGAR 10-K risk factor section (via EFTS text search or filing text), WebSearch for litigation/regulatory news
- Reference shared data sources and output format

- [ ] **Step 2: Commit**

```bash
git add fundamental-analysis/skills/risk-assessment/
git commit -m "feat: add risk-assessment skill"
```

---

## Chunk 5: Utility Skills (3 skills)

### Task 17: Create sec-filing-reader skill

**Files:**
- Create: `fundamental-analysis/skills/sec-filing-reader/SKILL.md`

- [ ] **Step 1: Create skill directory and write SKILL.md**

```bash
mkdir -p fundamental-analysis/skills/sec-filing-reader
```

**Frontmatter:**
```yaml
---
name: sec-filing-reader
description: >
  This skill should be used when the user asks to "read a 10-K", "summarize a 10-Q",
  "read an SEC filing", "find a proxy statement", "look up a DEF 14A",
  "read an 8-K", "summarize annual report", "read quarterly report",
  "check SEC filings", "look up Form 4", or asks about specific SEC filing
  content for a publicly traded company.
---
```

**Body:** Cover:
- Ticker-to-CIK resolution process
- Filing lookup: use EFTS search endpoint to find specific filing types by ticker and date range
- Filing retrieval: fetch the filing document HTML/text from the EDGAR filing URL
- Summarization approach: extract key sections based on filing type:
  - 10-K: Business description, risk factors, MD&A, financial statements, footnotes
  - 10-Q: MD&A updates, interim financial statements, risk factor updates
  - 8-K: Material event summary
  - DEF 14A: Executive compensation, board composition, shareholder proposals
  - Form 4: Insider name, transaction type, shares, price, date
- Output: structured summary with section-by-section highlights and link to full filing
- Reference shared data sources and output format

- [ ] **Step 2: Commit**

```bash
git add fundamental-analysis/skills/sec-filing-reader/
git commit -m "feat: add sec-filing-reader utility skill"
```

---

### Task 18: Create peer-comparison skill

**Files:**
- Create: `fundamental-analysis/skills/peer-comparison/SKILL.md`

- [ ] **Step 1: Create skill directory and write SKILL.md**

```bash
mkdir -p fundamental-analysis/skills/peer-comparison
```

**Frontmatter:**
```yaml
---
name: peer-comparison
description: >
  This skill should be used when the user asks to "compare companies",
  "compare stocks", "peer comparison", "compare against competitors",
  "industry comparison", "how does X compare to Y", "side by side comparison",
  "compare financials", "compare valuations", or "benchmark against peers"
  of publicly traded companies.
---
```

**Body:** Cover:
- Peer identification: use WebSearch to identify 3-5 closest public competitors in the same industry/sector
- Metrics to compare (organized in a table): revenue, revenue growth, gross margin, operating margin, net margin, ROE, ROIC, P/E, EV/EBITDA, P/FCF, debt-to-equity, FCF margin, dividend yield
- Data fetching: for each peer, fetch key metrics from Stock Analysis `/financials/ratios/` or SEC EDGAR frames endpoint (single metric across all companies)
- Output: side-by-side comparison table with the target company highlighted, brief commentary on where it stands out (better/worse than peers)
- Reference shared data sources and output format

- [ ] **Step 2: Commit**

```bash
git add fundamental-analysis/skills/peer-comparison/
git commit -m "feat: add peer-comparison utility skill"
```

---

### Task 19: Create cross-validation skill

**Files:**
- Create: `fundamental-analysis/skills/cross-validation/SKILL.md`

- [ ] **Step 1: Create skill directory and write SKILL.md**

```bash
mkdir -p fundamental-analysis/skills/cross-validation
```

**Frontmatter:**
```yaml
---
name: cross-validation
description: >
  This skill should be used when the user asks to "validate financial data",
  "cross-check numbers", "verify data", "cross-validate", "check data accuracy",
  "compare sources", "validate against another source", or asks about
  "data discrepancies" for a publicly traded company. Also invoked programmatically
  by the fundamental-analyst agent as a sequential post-step after parallel analysis.
---
```

**Body:** Cover:
- Purpose: verify key financial data points by comparing values across independent sources
- Cross-validation rules:
  - If original data came from SEC EDGAR → cross-check against Stock Analysis
  - If original data came from Stock Analysis → cross-check against SEC EDGAR or Gurufocus
  - Key metrics to validate: revenue, net income, EPS, total assets, total debt, market cap, P/E, EV/EBITDA
- Discrepancy handling: flag any metrics where values differ by more than 5% between sources, show both values with source links
- Output: table of validated metrics with status (Confirmed / Discrepancy), both source values and URLs
- Note areas where only one source was available
- Reference shared data sources and output format

- [ ] **Step 2: Commit**

```bash
git add fundamental-analysis/skills/cross-validation/
git commit -m "feat: add cross-validation utility skill"
```

---

## Chunk 6: User-Invocable Slash Command Skills (2 skills)

### Task 20: Create fundamental-report skill

**Files:**
- Create: `fundamental-analysis/skills/fundamental-report/SKILL.md`

- [ ] **Step 1: Create skill directory and write SKILL.md**

```bash
mkdir -p fundamental-analysis/skills/fundamental-report
```

**Frontmatter:**
```yaml
---
name: fundamental-report
description: >
  This skill should be used when the user invokes "/fundamental-report" followed by a
  stock ticker. Generates a comprehensive fundamental analysis research note at
  summary depth covering all 14 analysis areas.
type: user-invocable
---
```

**Body:** This is the orchestration skill. Cover:

1. **Ticker resolution (Step 0)**: Resolve ticker to CIK via `company_tickers.json`. Fetch company metadata (name, exchange, sector via Stock Analysis or SIC code). Pass to all parallel tasks.

2. **Parallel dispatch**: Launch the following as parallel subagents (using Agent tool), each analyzing the resolved ticker:
   - income-statement-analysis, balance-sheet-analysis, cash-flow-analysis, profitability-analysis, valuation-analysis, financial-health, growth-analysis, efficiency-analysis, dividend-analysis, analyst-estimates, moat-analysis, competitive-position, insider-activity, risk-assessment, peer-comparison, sec-filing-reader (10-K summary)
   - Also dispatch signal-rater agent

3. **Sequential post-step**: After all parallel results collected, invoke cross-validation to verify key data points across sources.

4. **Report assembly** — compile results into this structure:
   - **Key Metrics Summary**: quick-reference table (Price, Market Cap, P/E, Forward P/E, EV/EBITDA, P/FCF, Revenue Growth, EPS Growth, ROE, ROIC, Gross Margin, Net Margin, Debt/Equity, Current Ratio, FCF Yield, Dividend Yield, TipRanks SmartScore, Overall Signal)
   - **Signal Rating**: aggregated Buy/Hold/Sell with per-source breakdown
   - **Detailed Analysis**: all skill results organized Tier 1 → Tier 2 → Tier 3, at **summary depth** (key metrics + brief interpretation per area)
   - **Cross-Validation**: discrepancy flags
   - **Reasons to Consider**: 3-5 bull case arguments derived from the analysis
   - **Reasons to Avoid**: 3-5 bear case arguments derived from the analysis
   - **Source Links**: all URLs referenced, grouped by source
   - **Disclaimer**

5. All analysis at summary depth: key metrics + 1-2 sentence interpretation per area.

- [ ] **Step 2: Commit**

```bash
git add fundamental-analysis/skills/fundamental-report/
git commit -m "feat: add fundamental-report slash command skill"
```

---

### Task 21: Create fundamental-report-detailed skill

**Files:**
- Create: `fundamental-analysis/skills/fundamental-report-detailed/SKILL.md`

- [ ] **Step 1: Create skill directory and write SKILL.md**

```bash
mkdir -p fundamental-analysis/skills/fundamental-report-detailed
```

**Frontmatter:**
```yaml
---
name: fundamental-report-detailed
description: >
  This skill should be used when the user invokes "/fundamental-report-detailed"
  followed by a stock ticker. Generates a comprehensive fundamental analysis
  research note at detailed depth covering all 14 analysis areas with full data
  tables, multi-year trend analysis, and extended commentary.
type: user-invocable
---
```

**Body:** Same orchestration as Task 20 but with one key difference:
- All analysis at **detailed depth**: full multi-year data tables, trend analysis, extended commentary per area
- Note this in the dispatch instructions: each skill should provide detailed output
- Otherwise identical report structure

- [ ] **Step 2: Commit**

```bash
git add fundamental-analysis/skills/fundamental-report-detailed/
git commit -m "feat: add fundamental-report-detailed slash command skill"
```

---

## Chunk 7: Agents (2 agents)

### Task 22: Create fundamental-analyst agent

**Files:**
- Create: `fundamental-analysis/agents/fundamental-analyst.md`

- [ ] **Step 1: Write agent file**

Create `fundamental-analysis/agents/fundamental-analyst.md`:

**Frontmatter:**
```yaml
---
name: fundamental-analyst
description: >
  Use this agent when the user asks for open-ended fundamental analysis that spans
  multiple analysis areas, or when the question doesn't map cleanly to a single skill.

  <example>
  Context: User wants a broad fundamental analysis
  user: "Do a full fundamental analysis of MSFT"
  assistant: "I'll use the fundamental-analyst agent to perform a comprehensive analysis of Microsoft."
  <commentary>
  Open-ended request spanning multiple analysis areas — dispatch the orchestrator agent.
  </commentary>
  </example>

  <example>
  Context: User wants to compare companies across fundamentals
  user: "Compare META's financials to GOOG"
  assistant: "I'll use the fundamental-analyst agent to compare Meta and Alphabet across key fundamental metrics."
  <commentary>
  Multi-company comparison across multiple areas requires orchestration.
  </commentary>
  </example>

  <example>
  Context: User asks a compound question
  user: "What are the strengths and weaknesses of NVDA from a fundamental perspective?"
  assistant: "I'll use the fundamental-analyst agent to analyze NVIDIA's fundamental strengths and weaknesses."
  <commentary>
  Requires pulling from multiple analysis areas (profitability, valuation, moat, risks) to synthesize.
  </commentary>
  </example>

model: inherit
color: blue
tools: ["WebSearch", "WebFetch", "Read", "Write", "Agent"]
---
```

**System prompt (body):**

```
You are a senior equity research analyst specializing in fundamental analysis of publicly traded companies.

**Your Core Responsibilities:**
1. Analyze companies across all fundamental dimensions: financial statements, profitability, valuation, growth, efficiency, dividends, moat, competitive position, governance, and risk
2. Orchestrate parallel data fetching from SEC EDGAR and Stock Analysis
3. Synthesize findings into clear, actionable research output with source citations

**Analysis Process:**
1. Resolve the ticker to CIK using WebFetch on https://www.sec.gov/files/company_tickers.json
2. Determine which analysis areas are relevant to the user's question
3. For broad questions: dispatch all analysis skills in parallel using the Agent tool, then run cross-validation sequentially
4. For targeted questions: dispatch only the relevant skills
5. Synthesize all results into a cohesive narrative with the report structure: Key Metrics → Signal Rating → Analysis → Cross-Validation → Reasons to Consider → Reasons to Avoid → Source Links → Disclaimer

**Data Source Priority:**
- Structured financial data: SEC EDGAR XBRL API (primary), Stock Analysis (secondary)
- Ratios and estimates: Stock Analysis (primary), Gurufocus (secondary)
- Qualitative analysis: WebSearch
- If a source fails, fall back to the next in priority and note it

**Quality Standards:**
- Every data point must have a source link
- Flag any data that could not be cross-validated
- Include confidence level for qualitative assessments
- Always end with disclaimer: "For informational purposes only. Not financial advice."

**Output Format:**
- Use markdown tables for financial data
- Use headers to organize by analysis area
- Keep summary-depth answers concise (key metrics + interpretation)
- For detailed requests, include multi-year data tables and trend commentary
```

- [ ] **Step 2: Commit**

```bash
git add fundamental-analysis/agents/fundamental-analyst.md
git commit -m "feat: add fundamental-analyst orchestrator agent"
```

---

### Task 23: Create signal-rater agent

**Files:**
- Create: `fundamental-analysis/agents/signal-rater.md`

- [ ] **Step 1: Write agent file**

Create `fundamental-analysis/agents/signal-rater.md`:

**Frontmatter:**
```yaml
---
name: signal-rater
description: >
  Use this agent when the user asks for a buy/hold/sell rating or signal aggregation
  for a stock.

  <example>
  Context: User wants to know the overall rating
  user: "What's the rating for AAPL?"
  assistant: "I'll use the signal-rater agent to aggregate ratings from multiple sources for Apple."
  <commentary>
  User asking for rating/signal — dispatch signal-rater to aggregate from TipRanks, analysts, etc.
  </commentary>
  </example>

  <example>
  Context: User asking about buy/sell decision
  user: "Should I buy or sell TSLA?"
  assistant: "I'll use the signal-rater agent to gather and synthesize buy/sell signals for Tesla from multiple rating sources."
  <commentary>
  Buy/sell question requires aggregating signals from multiple independent sources.
  </commentary>
  </example>

  <example>
  Context: User wants signal overview
  user: "Give me buy/sell signals for MSFT"
  assistant: "I'll use the signal-rater agent to compile signals from analyst consensus, SmartScore, and other sources for Microsoft."
  <commentary>
  Explicit signal request triggers the signal-rater agent.
  </commentary>
  </example>

model: inherit
color: green
tools: ["WebSearch", "WebFetch", "Read", "Write"]
---
```

**System prompt (body):**

```
You are a signal aggregation analyst. Your job is to collect Buy/Hold/Sell ratings from multiple independent sources and synthesize them into an overall signal with confidence level.

**Your Core Responsibilities:**
1. Fetch ratings from multiple independent sources for a given stock ticker
2. Normalize each source to a common 5-point scale
3. Synthesize an overall weighted rating with rationale

**Rating Sources (fetch in this order):**
1. **TipRanks SmartScore**: Search WebSearch for "{ticker} TipRanks SmartScore" to find the 1-10 composite score based on 8 factors (analyst consensus, blogger sentiment, hedge fund activity, insider transactions, news sentiment, technical indicators, fundamentals, crowd wisdom)
2. **Stock Analysis analyst consensus**: Fetch https://stockanalysis.com/stocks/{ticker}/forecast/ for analyst recommendation distribution and consensus rating
3. **Gurufocus**: Search WebSearch for "{ticker} Gurufocus financial strength" for value/quality grades
4. **SEC EDGAR insider signal**: Search for recent Form 4 filings — net insider buying = bullish signal, net selling = bearish signal
5. **WebSearch**: Search for "{ticker} analyst rating consensus" for additional analyst opinions

**Normalization Scale:**
Map each source to: Strong Buy (5) / Buy (4) / Hold (3) / Sell (2) / Strong Sell (1)
- TipRanks SmartScore: 8-10 = Strong Buy, 6-7 = Buy, 4-5 = Hold, 2-3 = Sell, 1 = Strong Sell
- Analyst consensus: Use the majority recommendation directly
- Gurufocus grades: A+ to B = Buy range, C = Hold, D to F = Sell range
- Insider signal: Net buying > $1M = Buy, mixed = Hold, net selling > $1M = Sell

**Output Format:**

| Source | Rating | Score | Detail |
|--------|--------|-------|--------|
| TipRanks SmartScore | X/10 | [mapped 1-5] | [key factors] |
| Analyst Consensus | [rating] | [1-5] | [X Buy, Y Hold, Z Sell] |
| Gurufocus | [grade] | [1-5] | [financial strength/value] |
| Insider Signal | [Buy/Hold/Sell] | [1-5] | [net $X bought/sold] |
| Additional | [rating] | [1-5] | [source detail] |

**Overall Signal: [Strong Buy/Buy/Hold/Sell/Strong Sell]**
**Confidence: [High/Medium/Low]** (High = 4+ sources agree; Medium = 3 agree; Low = mixed)
**Weighted Average Score: X.X / 5.0**

Include source links for every rating. End with disclaimer.
```

- [ ] **Step 2: Commit**

```bash
git add fundamental-analysis/agents/signal-rater.md
git commit -m "feat: add signal-rater agent"
```

- [ ] **Step 3: Final commit for complete plugin**

```bash
git add -A fundamental-analysis/
git commit -m "feat: complete fundamental-analysis plugin — 19 skills, 2 agents"
```

---

## Summary

| Chunk | Tasks | Components |
|-------|-------|------------|
| 1: Scaffold | 1-2 | Plugin manifest, shared references |
| 2: Tier 1 | 3-8 | 6 core financial skills |
| 3: Tier 2 | 9-12 | 4 growth & returns skills |
| 4: Tier 3 | 13-16 | 4 qualitative skills |
| 5: Utility | 17-19 | 3 utility skills |
| 6: Slash Commands | 20-21 | 2 report orchestration skills |
| 7: Agents | 22-23 | 2 agents (fundamental-analyst, signal-rater) |

**Total: 23 tasks, 19 skills, 2 agents, 2 shared reference files**
