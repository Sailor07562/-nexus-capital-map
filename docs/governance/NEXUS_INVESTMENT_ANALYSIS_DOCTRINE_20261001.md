# Nexus Investment Analysis Doctrine — Stock Review Standard

**Doctrine ID:** NDU-20261001-002  
**Date:** 2026-10-01 (America/Los_Angeles)  
**Status:** ADOPTED — user-directed analysis standard  
**Scope:** Nexus individual-stock research, thesis reviews, and stock-review documentation.  
**Authority:** User instruction to add the agreed standard to Nexus's investment-analysis doctrine and stock-review workflow.

## Purpose and required use

Every Nexus stock review must use a common financial evidence framework with
company- and industry-specific metrics and thresholds. Use this document at
the start of the review, before forming or updating the investment conclusion.

This is a documented research requirement. Repository publication does not
prove that any runtime engine loads or enforces the checklist. PostgreSQL
remains operational data authority; existing broker, trading, capital, and
promotion controls remain unchanged.

## Core checks for every stock

Apply these questions using measures appropriate to the business model. If a
measure is inapplicable, record the reason and the relevant sector substitute.

| Check | Required analysis |
|---|---|
| Revenue and demand | Separate volume, pricing, acquisitions, and other material growth drivers where disclosed; compare growth with the thesis and realistic delivery timing. |
| Profitability | Compare relevant margins with the company's history and comparable businesses; explain mix, pricing, cost, and unusual-item effects. |
| Cash generation | Reconcile reported earnings with operating cash generation and necessary capital investment; define any free-cash-flow measure and identify one-offs. |
| Working capital | Where relevant, inspect receivables, inventory, payables, customer advances, and cash conversion; distinguish planned growth funding from collection or execution problems. |
| Financial strength | Review liquidity, debt, interest burden, refinancing needs, and material obligations using sector-appropriate measures. |
| Per-share outcomes | Check earnings and value creation per share, share-count changes, dilution, and whether buybacks offset issuance. |
| Valuation | Evaluate the price paid relative to plausible future cash flows or sector-appropriate valuation measures, embedded expectations, and downside scenarios. Better business results do not automatically mean a more attractive stock. |

## Conditional demand checks

| Metric | Constructive evidence | Concern requiring investigation | Applicability and interpretation |
|---|---|---|---|
| Backlog | Durable orders across customers/projects, credible conversion dates, and acceptable expected profitability | Cancellations, excessive concentration, delays, or weak expected profitability | Use where reported. A declining backlog can reflect successful deliveries; investigate orders and conversion together. Backlog is not cash or guaranteed revenue. |
| Book-to-bill | New orders replenish or exceed revenue over a meaningful period | Persistent order shortfall relative to revenue or deterioration in order quality | Where defined as orders divided by revenue, above 1 means orders exceed sales. Examine company definitions and several quarters; large awards can distort one quarter. |
| Revenue conversion | Delivery and revenue progression consistent with backlog timing and capacity | Persistent slippage unexplained by disclosed schedules or mix | Double-digit growth is not a universal requirement. Judge against the business and the thesis. |
| Gross margin | Sustainable margin relative to company history and peers | Unexplained deterioration, adverse mix, cost overruns, or weak contract pricing | High-20s/30% margins are candidate company-specific benchmarks, not universal pass/fail levels. Use relevant profitability measures for sectors where gross margin is unsuitable. |
| Data-center orders | Repeat demand from multiple projects/customers where disclosed | Reliance on a single award or customer without evidence of follow-on demand | Use only when data centers drive the thesis. Substitute the actual demand driver for other stocks. A large award is not inherently a bad result. |

The discussed 1.2x book-to-bill, double-digit revenue growth, and high-20s/30%
gross-margin levels originated in a company-focused discussion. They are
candidate benchmarks requiring company-specific justification, not universal
screens, proven forecasts, or automatic buy/sell rules.

## Required evidence record

For each applicable metric, record:

| Field | Requirement |
|---|---|
| Metric and definition | Name, unit, calculation, scope, and consistent reported/adjusted basis |
| Latest result | Value and fiscal period; distinguish actual results from guidance |
| Comparison | Prior-year comparable period and several-quarter trend; explain seasonality or definition changes |
| Benchmark | Company-specific expectation or threshold, rationale, and whether proposed or approved |
| Evidence | Filing/release/call source link, publication date, and relevant page or section where available |
| Interpretation | Confirming and disconfirming evidence, effect on cash generation, and implications for valuation |
| Next proof point | What forthcoming result or disclosure would strengthen or weaken the thesis |
| Evidence status | Verified, unknown/not disclosed, or not applicable with reason; missing data is never a pass |

Prefer company annual and quarterly filings, earnings releases, and earnings
calls. Reconcile material inconsistencies; distinguish management claims from
reported results and analyst judgment. Record current-price source and as-of
time when making a valuation conclusion. If price, cash-flow, or other critical
valuation inputs are missing, label the stock conclusion incomplete.

## Stock-review workflow

1. Open this standard and identify the company, review date, thesis, and relevant sector measures.
2. Retrieve the primary reports and populate the evidence record for every core check and applicable conditional check.
3. Examine several-quarter trends and comparable prior-year periods. Investigate concentrations, one-offs, and apparent contradictions.
4. Connect demand and operating results to cash generation, financial strength, and per-share outcomes.
5. Evaluate valuation and downside separately from business performance; document what success the price appears to assume.
6. State what confirms or weakens the thesis, the remaining evidence gaps, and the next proof point.
7. Before finalizing, verify that every required area is covered or explicitly marked unknown/not applicable. An unresolved material gap must remain visible in the conclusion.
8. Retain the review with its sources through the existing authorized research-recording process.

Review completion is not trade authorization. This standard creates no broker
request, capital allocation, automatic promotion, database mutation, scheduled
automation, or runtime deployment.

## Reusable review checklist

- [ ] Company, thesis, reporting periods, and review date recorded.
- [ ] Core financial checks completed using appropriate industry measures.
- [ ] Backlog, book-to-bill, and thesis-specific orders examined where relevant.
- [ ] Latest results, prior-year comparisons, and several-quarter trends recorded.
- [ ] Company-specific thresholds justified and approval status stated.
- [ ] Primary sources and dates linked; unknown and inapplicable fields labeled.
- [ ] Operating performance connected to cash generation and per-share outcomes.
- [ ] Valuation and downside assessed separately from business quality.
- [ ] Disconfirming evidence, gaps, and next proof point stated.
- [ ] Conclusion reflects unresolved material gaps and existing authority boundaries.

## Registry and inheritance

### Executable review entrypoint

The [stock-review gate](../../reviews/stock/README.md) implements this standard
for file-based review packets. Start with `scripts/stock_review_gate.py begin`;
the command loads this doctrine automatically. Completion validates required
evidence and binds the output to this document's hash. GitHub Actions rechecks
repository review packets. Source truth still requires analyst review, and
live PostgreSQL/n8n completion enforcement is not established by this adapter.

Registered in [Repository Governance](REPOSITORY_GOVERNANCE.md).
Future stock-review templates and Nexus agents performing stock analysis
should inherit this standard and link the completed evidence record. This
requirement applies to research preparation and review; runtime adoption must
be independently implemented and verified under existing change control.

**Source:** User-directed stock-analysis framework discussion and instruction
to incorporate it into Nexus on 2026-10-01.  
**Supersedes:** None.
