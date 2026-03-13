---
name: moat-analysis
description: >
  This skill should be used when the user asks about economic moats, competitive moats, moat durability,
  switching costs, network effects, cost advantages, intangible assets, brand moats, pricing power,
  ROIC vs WACC, sustainable competitive advantages, or efficient scale for a publicly traded company.
---

# Economic Moat Analysis

## Purpose

Evaluate the durability and strength of a company's competitive advantages using the Morningstar economic moat framework. Identify which moat sources apply, quantify their strength through financial signals such as sustained ROIC above WACC and margin stability, and assess whether the moat is widening, stable, or narrowing. Deliver a structured moat rating (Wide, Narrow, or None) supported by both qualitative and quantitative evidence.

## Data Fetching Process

Consult `${CLAUDE_PLUGIN_ROOT}/skills/_shared/references/data-sources.md` for full data-fetching instructions, ticker resolution, and fallback behavior.

### Step 1 — Resolve Ticker and Retrieve Financial History

1. Resolve the company ticker to a CIK via the SEC company tickers JSON endpoint.
2. Fetch the XBRL companyfacts JSON for the resolved CIK.
3. Extract the following metrics for the most recent 10 fiscal years (or as many as available):
   - Return on Invested Capital (ROIC): compute from `OperatingIncomeLoss`, `IncomeTaxExpenseBenefit`, `Assets`, `CashAndCashEquivalentsAtCarryingValue`, and current liabilities, or use the pre-computed ratio from Stock Analysis `/ratios/` as a fallback.
   - Gross margin: `GrossProfit` divided by `Revenues`.
   - Operating margin: `OperatingIncomeLoss` divided by `Revenues`.
   - Revenue growth rate year over year.
   - Market share proxy: revenue relative to industry peers (use the XBRL frames endpoint for the same NAICS/SIC sector if available).

### Step 2 — Estimate Weighted Average Cost of Capital (WACC)

1. Fetch the company's long-term debt (`LongTermDebt`) and stockholders' equity (`StockholdersEquity`) from EDGAR.
2. Fetch the current risk-free rate and equity risk premium via WebSearch (search for "current US 10-year Treasury yield" and "Damodaran equity risk premium").
3. Estimate beta from Stock Analysis or Gurufocus.
4. Compute WACC using the standard formula: WACC = (E/V) * Re + (D/V) * Rd * (1 - Tax Rate), where Re = Rf + Beta * ERP.
5. If precise inputs are unavailable, use a reasonable sector-average WACC estimate and note the assumption.

### Step 3 — Gather Qualitative Moat Evidence

1. Use WebSearch to find recent moat analyses, brand strength rankings, patent portfolios, and regulatory licenses for the company.
2. Search for switching cost evidence: customer retention rates, contract lengths, integration depth, proprietary ecosystems.
3. Search for network effect indicators: user growth metrics, platform dynamics, marketplace liquidity.
4. Search for cost advantage evidence: scale economics, proprietary processes, location advantages, resource access.
5. Search for efficient scale indicators: natural monopoly characteristics, limited market size relative to incumbents.

## Analysis Steps

### Step 1 — Identify Applicable Moat Sources

Evaluate each of the five Morningstar moat sources and determine which ones apply to the company. For each source, provide specific evidence:

**Intangible Assets**
- Assess brand strength: pricing premium over competitors, brand recognition surveys, brand value rankings.
- Review patent portfolio: number of active patents, patent citation rates, remaining patent life for key products.
- Identify regulatory licenses or approvals: FDA approvals, banking charters, spectrum licenses, government contracts with high barriers to recompete.

**Switching Costs**
- Identify integration depth: how deeply the product embeds into customer workflows, data, or infrastructure.
- Evaluate contract structures: long-term agreements, auto-renewal terms, early termination penalties.
- Assess retraining costs: time and expense required for customers to switch to a competing product.
- Look for evidence in customer retention rates and net revenue retention (especially for SaaS companies).

**Network Effects**
- Classify the type: direct (user-to-user value), indirect (platform/marketplace), or data network effects.
- Evaluate strength: user base size relative to competitors, engagement metrics, cross-side adoption rates.
- Assess vulnerability: potential for multi-homing, winner-take-all dynamics, local vs global network effects.

**Cost Advantages**
- Process-driven: proprietary manufacturing, technology, or distribution that lowers unit cost.
- Scale-driven: fixed cost leverage, purchasing power, distribution network density.
- Resource-driven: preferential access to raw materials, talent pools, or geographic locations.
- Compare gross margins and operating margins against the peer group over multiple years.

**Efficient Scale**
- Evaluate whether the addressable market is limited enough that it naturally supports only a few profitable competitors.
- Look for examples: utilities, railroads, pipelines, defense primes, niche industrial markets.
- Assess whether new entry would destroy returns for all participants.

### Step 2 — Quantify Moat Strength with Financial Signals

Present a multi-year table of quantitative moat signals:

| Signal | What It Indicates | Threshold for Moat Evidence |
|--------|-------------------|-----------------------------|
| ROIC minus WACC spread | Excess returns sustainability | Positive spread for 5+ consecutive years |
| Gross margin trend | Pricing power and cost control | Stable or expanding over 5+ years |
| Operating margin trend | Operational moat leverage | Stable or expanding over 5+ years |
| Revenue growth consistency | Demand durability | Positive in most years, low volatility |
| Market share trend | Competitive position trajectory | Stable or growing |
| Customer retention / NRR | Switching cost strength | Above 90% retention or 100%+ NRR |

For each signal, present the actual data in a table covering the most recent 5-10 years, then note whether it supports or contradicts moat existence.

### Step 3 — Assess Moat Trajectory

Determine whether the moat is widening, stable, or narrowing:

- **Widening:** ROIC-WACC spread increasing, margins expanding, market share growing, new moat sources emerging.
- **Stable:** Consistent excess returns, steady margins, maintained market share.
- **Narrowing:** ROIC-WACC spread compressing, margin erosion, market share loss, competitive disruption emerging.

Identify specific threats to the moat: technological disruption, regulatory changes, new entrants with different business models, customer preference shifts.

### Step 4 — Assign Moat Rating

Assign one of three ratings with a confidence level:

- **Wide Moat:** Multiple strong moat sources, ROIC well above WACC for 10+ years, high confidence moat will persist for 20+ years.
- **Narrow Moat:** One or two moat sources, ROIC above WACC for 5+ years, confidence moat will persist for 10+ years.
- **No Moat:** No durable competitive advantages, ROIC near or below WACC, competitive position eroding.

Provide the rating, a confidence level (High / Medium / Low), and a 2-3 sentence justification.

## Depth Handling

- **Summary depth (default):** List applicable moat sources with one sentence each, show a compact ROIC vs WACC table (3-5 years), state the moat rating and trajectory in one paragraph.
- **Detailed depth:** Full analysis of all five moat sources with evidence, 10-year quantitative signal tables, moat trajectory analysis with threat assessment, peer comparison of excess returns, and complete rating justification.
- **Specific question:** If the user asks about a single moat source (e.g., "Does AAPL have switching costs?"), focus the analysis on that source with supporting data.

## Output Formatting

Consult `${CLAUDE_PLUGIN_ROOT}/skills/_shared/references/output-format.md` for standard output structure, table formatting, source citations, and the required disclaimer.

Present the moat rating prominently near the top of the response after the header. Use tables for quantitative signals and concise narrative for qualitative evidence. Always cite the source for each data point (EDGAR filing, Stock Analysis page, or search result).
