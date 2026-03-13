---
name: efficiency-analysis
description: This skill should be used when the user asks about working capital, cash conversion cycle, asset turnover, DSO, DIO, DPO, days sales outstanding, days inventory outstanding, days payable outstanding, inventory turnover, receivables turnover, revenue per employee, efficiency, or capital efficiency for a publicly traded company.
---

# Efficiency Analysis

## Purpose

Evaluate how effectively a company utilizes its assets, manages working capital, and converts resources into revenue and profits. This skill computes asset turnover ratios, working capital cycle metrics, and capital efficiency indicators to reveal operational strengths and weaknesses that may not be apparent from top-line growth or profitability metrics alone. Efficiency analysis is critical for identifying companies with superior operational management and sustainable competitive advantages.

## Data Fetching Process

Consult `${CLAUDE_PLUGIN_ROOT}/skills/_shared/references/data-sources.md` for full data-fetching instructions, ticker resolution, and fallback behavior.

### Primary Data — SEC EDGAR XBRL API

Fetch the company facts endpoint to retrieve historical financial data:

```
https://data.sec.gov/api/xbrl/companyfacts/CIK{10-digit-CIK}.json
```

Extract the following XBRL concepts for annual (FY) and quarterly periods, sorted chronologically by `end` date:

- **Revenue:** `Revenues` or `RevenueFromContractWithCustomerExcludingAssessedTax`
- **Cost of Revenue:** `CostOfGoodsAndServicesSold` or `CostOfRevenue`
- **Total Assets:** `Assets`
- **Property, Plant & Equipment (Net):** `PropertyPlantAndEquipmentNet`
- **Accounts Receivable:** `AccountsReceivableNetCurrent`
- **Inventory:** `InventoryNet`
- **Accounts Payable:** `AccountsPayableCurrent`
- **Depreciation & Amortization:** `DepreciationDepletionAndAmortization`
- **Capital Expenditures:** `PaymentsToAcquirePropertyPlantAndEquipment`
- **EBITDA:** Derive from `OperatingIncomeLoss` plus `DepreciationDepletionAndAmortization`
- **Operating Cash Flow:** `NetCashProvidedByOperatingActivities`

Collect at least 5 years of annual data to identify trends.

### Secondary Data — Stock Analysis

Fetch the balance sheet for working capital components:

```
https://stockanalysis.com/stocks/{ticker}/financials/balance-sheet/
```

Fetch pre-computed ratios for efficiency metrics:

```
https://stockanalysis.com/stocks/{ticker}/financials/ratios/
```

Fetch the income statement and cash flow statement for revenue, COGS, CapEx, and depreciation:

```
https://stockanalysis.com/stocks/{ticker}/financials/
https://stockanalysis.com/stocks/{ticker}/financials/cash-flow-statement/
```

### Supplementary Context — WebSearch

Search for employee count data (not always available via EDGAR) and sector-specific efficiency benchmarks:

- `"{ticker} number of employees {current year}"`
- `"{ticker} revenue per employee"`
- `"{ticker} annual report employee count"`

## Analysis Steps

### Step 1 — Compute Asset Turnover Ratios

Calculate the following turnover metrics using average balances (beginning + ending / 2) for asset figures:

- **Total Asset Turnover** = Revenue / Average Total Assets. Measures how efficiently total assets generate revenue. Higher is generally better, though capital-intensive industries naturally have lower ratios.
- **Fixed Asset Turnover** = Revenue / Average Net PP&E. Measures how efficiently fixed assets (property, plant, equipment) generate revenue. Particularly relevant for manufacturing, transportation, and capital-intensive businesses.
- **Receivables Turnover** = Revenue / Average Accounts Receivable. Measures how quickly the company collects from customers. Higher values indicate faster collection.
- **Inventory Turnover** = Cost of Revenue / Average Inventory. Measures how quickly inventory is sold. Higher values indicate faster inventory movement and less capital tied up in unsold goods.

Present a multi-year table showing these ratios and their year-over-year trends:

| Metric | 2024 | 2023 | 2022 | 2021 | 2020 | Trend |
|--------|------|------|------|------|------|-------|
| Total Asset Turnover | | | | | | |
| Fixed Asset Turnover | | | | | | |
| Receivables Turnover | | | | | | |
| Inventory Turnover | | | | | | |

### Step 2 — Analyze the Working Capital Cycle

Compute the cash conversion cycle (CCC) and its three components:

- **Days Sales Outstanding (DSO)** = (Accounts Receivable / Revenue) x 365. The average number of days to collect payment from customers after a sale.
- **Days Inventory Outstanding (DIO)** = (Inventory / Cost of Revenue) x 365. The average number of days inventory is held before being sold.
- **Days Payable Outstanding (DPO)** = (Accounts Payable / Cost of Revenue) x 365. The average number of days the company takes to pay its suppliers.
- **Cash Conversion Cycle (CCC)** = DSO + DIO - DPO. The total number of days from paying for inventory to collecting cash from customers.

Present a multi-year table of the CCC components:

| Metric | 2024 | 2023 | 2022 | 2021 | 2020 |
|--------|------|------|------|------|------|
| DSO (days) | | | | | |
| DIO (days) | | | | | |
| DPO (days) | | | | | |
| **CCC (days)** | | | | | |

Interpret the CCC:

- A **negative CCC** indicates the company collects from customers before paying suppliers, representing a significant competitive advantage (common in companies like Amazon, Dell, or fast-food chains). Highlight this explicitly.
- A **declining CCC** suggests improving working capital efficiency.
- A **rising CCC** may signal deteriorating collections, inventory buildup, or reduced supplier leverage, and warrants further investigation.

### Step 3 — Evaluate Capital Efficiency

Compute metrics that measure how efficiently capital and human resources are deployed:

- **Revenue per Employee** = Revenue / Number of Employees. Benchmark against industry peers.
- **EBITDA per Employee** = EBITDA / Number of Employees. Measures profitability efficiency of the workforce.
- **CapEx as % of Revenue** = Capital Expenditures / Revenue. Indicates the reinvestment intensity required to maintain and grow the business. Lower values (with stable or growing revenue) suggest asset-light models.
- **CapEx / Depreciation Ratio** = Capital Expenditures / Depreciation & Amortization. A ratio above 1.0 indicates the company is investing more than assets are depreciating (expanding or maintaining capacity). A ratio persistently below 1.0 may indicate underinvestment.

Present a multi-year table:

| Metric | 2024 | 2023 | 2022 | 2021 | 2020 |
|--------|------|------|------|------|------|
| Revenue/Employee ($K) | | | | | |
| EBITDA/Employee ($K) | | | | | |
| CapEx/Revenue (%) | | | | | |
| CapEx/Depreciation (x) | | | | | |

### Step 4 — Identify Trends and Anomalies

Examine multi-year trends across all computed metrics:

- Flag any metric that has deteriorated for two or more consecutive years.
- Identify any sharp year-over-year changes (e.g., DSO spiking 20%+ in one year) and investigate potential causes such as acquisitions, accounting changes, or customer concentration issues.
- Compare the most recent year to the 5-year average to identify whether current performance is above or below the company's own historical norm.

### Step 5 — Synthesize Efficiency Assessment

Provide an overall efficiency characterization:

- Classify the company's working capital management (excellent, good, average, or poor) based on CCC trends and absolute levels relative to peers.
- Assess capital allocation efficiency: is the company investing sufficiently to sustain growth without over-investing?
- Identify the single most notable efficiency strength and weakness.
- Note any red flags (e.g., receivables growing faster than revenue, inventory buildup, CapEx persistently below depreciation).

## Depth Handling

Consult `${CLAUDE_PLUGIN_ROOT}/skills/_shared/references/output-format.md` for depth and formatting guidelines.

**Summary depth (default):** Present the CCC components (DSO, DIO, DPO, CCC) for the most recent 3 years in a table, plus total asset turnover and CapEx/Revenue. Include a 2-3 sentence narrative summarizing the key efficiency takeaway.

**Detailed depth:** Expand to 5-year tables for all metrics across all three categories (turnover ratios, working capital cycle, capital efficiency). Add year-over-year change calculations, trend commentary, peer comparison context, and per-employee metrics. Provide extended narrative on working capital management quality and capital allocation efficiency.

## Sector-Specific Adjustments

Apply the following sector-specific metrics when the company operates in a relevant industry:

- **SaaS / Software:** Report Customer Acquisition Cost (CAC), Customer Lifetime Value (LTV), and LTV/CAC ratio. An LTV/CAC above 3x is generally considered healthy. Report CAC payback period in months if data is available. These metrics may need to be sourced from earnings calls or investor presentations via WebSearch.
- **Retail:** Report revenue per square foot of retail space. Report inventory turnover benchmarked against retail peers (grocery: 12-15x, apparel: 4-6x, home improvement: 5-7x). Report sell-through rate if available.
- **Energy / Natural Resources:** Report lifting cost per barrel of oil equivalent (BOE) or cost per unit of production. Report finding and development cost per BOE. Lower production costs indicate operational efficiency advantages.
- **Banking / Financial Services:** Replace standard working capital metrics with efficiency ratio (non-interest expense / revenue), cost-to-income ratio, and assets per employee. Standard CCC metrics are not applicable to banks.
- **REITs:** Report operating expense ratio, occupancy rate, and revenue per available unit. Standard inventory and receivable metrics are less relevant.

Only include sector-specific metrics when the company's industry warrants them. Do not force these metrics for unrelated sectors.

## Output Format

Consult `${CLAUDE_PLUGIN_ROOT}/skills/_shared/references/output-format.md` for the standard response structure including header, source links, and disclaimer.
