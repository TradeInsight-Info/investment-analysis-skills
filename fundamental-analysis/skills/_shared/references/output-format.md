# Output Format Reference

Standard output structure for all fundamental analysis skills. Follow this format for consistent, professional output.

## Response Structure

Every skill response follows this structure:

### 1. Header

Start with company identification:

```markdown
## [Company Name] ([TICKER]) — [Analysis Type]

**Price:** $XXX.XX | **Market Cap:** $X.XXT | **Sector:** [Sector] | **Exchange:** [Exchange]
```

### 2. Analysis Body

Present findings using markdown tables for numerical data and brief narrative for interpretation.

**Summary depth** (default): Key metrics in a table + 1-2 sentence interpretation per metric group.

**Detailed depth** (when explicitly requested): Full multi-year data tables with annual and quarterly data, trend analysis, year-over-year changes, and extended commentary explaining significance and context.

### 3. Summary (Report Skills Only)

When producing a full report (via `/fundamental-report` or `/fundamental-report-detailed`), include a Summary section that distills the entire analysis into a concise block. This is the only section shown in the terminal — the full report is written to file. Template:

```markdown
## Summary

**[Company Name] ([TICKER])** — **[Overall Signal]** (Confidence: [High/Medium/Low])

**Weighted Score:** X.X / 5.0 | **Price:** $XXX.XX | **Market Cap:** $X.XXT

**Thesis:** [2-3 sentence investment thesis]

**Key Strengths:**
- [Top bull case point with metric]
- [Second point]
- [Third point]

**Key Risks:**
- [Top bear case point with metric]
- [Second point]
- [Third point]

**Report:** [Full report saved to `reports/YYYY-MM-DD-HH-MM-SS-TICKER.md`]
```

### 4. Source Links

After each data point or table, include the source as an inline link:

```markdown
(Source: [Stock Analysis](https://stockanalysis.com/stocks/AAPL/financials/ratios/))
```

Or at the end of a section:

```markdown
**Sources:**
- Financial data: [SEC EDGAR](https://data.sec.gov/api/xbrl/companyfacts/CIK0000320193.json)
- Ratios: [Stock Analysis](https://stockanalysis.com/stocks/AAPL/financials/ratios/)
```

### 5. Disclaimer

End every response with:

```markdown
---
*For informational purposes only. Not financial advice. Data sourced from public filings and third-party websites. Verify critical data points independently before making investment decisions.*
```

## Table Formatting

Use markdown tables for financial data. Include units and align numbers right:

```markdown
| Metric | 2024 | 2023 | 2022 | YoY Change |
|--------|------|------|------|------------|
| Revenue ($B) | 394.3 | 383.3 | 394.3 | +2.9% |
| Gross Margin | 46.2% | 44.1% | 43.3% | +2.1pp |
```

## Depth Handling

When determining output depth:
- If the user asks a specific question (e.g., "What's AAPL's P/E?"), provide a concise answer with context
- If the user asks for analysis (e.g., "Analyze AAPL's profitability"), provide summary depth by default
- If the user explicitly requests detailed analysis or uses `/fundamental-report-detailed`, provide detailed depth
- If invoked as part of a full report orchestration, follow the depth specified by the orchestrating skill

## Sector-Specific Adjustments

When the company's sector is known (from ticker resolution), include relevant sector-specific metrics:
- **SaaS/Software:** ARR, NRR, CAC, LTV, Rule of 40
- **Banking:** NIM, Tier 1 capital, NPL ratio, ROTCE
- **Retail:** Same-store sales, revenue/sqft
- **REITs:** FFO, NAV, occupancy rate
- **Energy:** Production volumes, reserve life, lifting cost

Only include sector-specific metrics when relevant — do not force them for companies in other sectors.

## Report File Output

When producing a full report (via report skills or the fundamental-analyst agent):

1. Write the complete report to `reports/YYYY-MM-DD-HH-MM-SS-{TICKER}.md` in the current working directory
2. Create the `reports/` directory if it doesn't exist
3. Display only the Summary section in the terminal
4. Do not print the full report content to the terminal — reference the file path instead

This does not apply to individual analysis skills invoked standalone (e.g., a single profitability-analysis). Only full report orchestrations write to file.

## International Companies

For companies without SEC EDGAR filings:
- Note that EDGAR data is unavailable
- Rely on Stock Analysis, Gurufocus, and WebSearch
- Mention that data may be less comprehensive
- Note any differences in accounting standards (IFRS vs GAAP) if applicable
