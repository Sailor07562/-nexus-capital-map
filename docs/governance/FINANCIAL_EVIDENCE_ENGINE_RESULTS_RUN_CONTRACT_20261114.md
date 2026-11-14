# Financial Evidence Engine — Results Run Contract

**Contract ID:** FEE-RESULTS-RUN-001  
**Version:** 1.0-draft  
**Date:** 2026-11-14  
**Status:** REVIEW BRANCH / NOT MERGED / NOT DEPLOYED  
**Related:** NDU-20261001-002 (Nexus Investment Analysis Doctrine — Stock Review Standard)  
**First run reference:** Nexus receipt `fb8514bb-e527-4c46-8c43-1bfa776033f1`; archive `eab9d8ce-e1eb-429e-8f78-f993586c1e24`  
**Authority:** Research decision support only. No broker, trading, or capital-allocation authority.

## Purpose

Define the repeatable output contract for turning a Financial Evidence Engine run into explicit research priorities, evaluation decisions, next tests, and observable triggers. The engine must be useful for directing attention and must preserve uncertainty, evidence lineage, and human review.

This contract does not claim a running adapter, live source connection, recurring delivery, or deployment. The first run details above are supplied by the user and are not independently re-read by this contract.

## Required result per company

Every company included in a run must have one result object with these fields:

| Field | Requirement |
|---|---|
| `company_id` | Stable company/instrument identifier; ticker alone is insufficient where ambiguity exists. |
| `ticker` / `company_name` | Display identifiers. |
| `run_id` / `run_timestamp` | Unique run identity and timestamp with timezone. |
| `disposition` | Exactly one of `ADVANCE`, `WATCH`, `REJECT`, `AWAIT_EVIDENCE`. These are research states, never trade signals. |
| `what_changed` | Evidence changes since the prior run; explicitly say `NO_MATERIAL_CHANGE` when applicable. |
| `decision_question` | The financial or thesis question this result prioritizes. |
| `evidence_basis[]` | Source identifier/link, source type, publication date, fiscal period, metric, value, units, definition, and evidence status. |
| `limitations[]` | Missing, stale, conflicting, non-comparable, or indirect evidence. Empty only when checked and none found. |
| `tests[]` | Test identifier, expected observation, pass/fail/unknown state, rationale, and evidence links. Unknown never counts as pass. |
| `valuation_gate` | Required review threshold/range, method, current-price source and as-of time, assumptions, sensitivity, and status. If unavailable, set `NOT_EVALUATED` and state why. A threshold is not an order instruction. |
| `observable_trigger` | Specific forthcoming evidence or event, expected date/window, and what result would change the disposition. |
| `research_card_link` | Canonical card ID/URI and link status. If absent, set `MISSING`, flag as a blocking linkage gap, and retain company result. |
| `human_review` | Required status `PENDING`, `APPROVED_FOR_RESEARCH`, or `RETURNED`; reviewer and timestamp when complete. No default approval. |
| `next_action` | One bounded research action, owner, and due event/date. |
| `receipt` | Archive/reference, integrity hash where available, write status, and successful readback status. |

## Run-level envelope

Each run must include:

- `run_id`, start/completion timestamps, timezone, engine/version identifier, and input cutoff.
- Included companies and explicit exclusions with reasons.
- Source inventory and freshness window.
- Counts by disposition, test state, and linkage state.
- Exceptions, failed checks, and unresolved source conflicts.
- Output schema version.
- Archive location/reference and integrity result.
- Readback result for the archive and every company result.
- Human review status.
- Delivery status, separately marked `ON_DEMAND`, `SCHEDULED`, or `NOT_DEPLOYED`.

A saved file or successful write acknowledgement is not sufficient; the run must read back the saved archive and results and compare them to the intended output.

## Decision and data rules

1. Reported facts, company guidance, analyst interpretation, and user recollection must remain distinguishable.
2. Every figure must preserve period, units, scope, source date, and definition. Do not compare mismatched periods as if equivalent.
3. Missing evidence is `UNKNOWN`, not zero and not a pass.
4. Conflicts remain visible until resolved; do not silently select the more favorable value.
5. Cash conversion claims identify the cash-flow and capex definitions used and material working-capital effects, including customer advances where relevant.
6. Acquisition effects remain separate from organic performance when evidence permits; unsupported attribution is marked unknown.
7. A research-card linkage failure must not omit a company. Preserve the result and flag the missing relationship as an exception.
8. Valuation is separate from business quality. Price/valuation thresholds require dated inputs and assumptions.
9. `ADVANCE` means advance to specified research or valuation review only.
10. No disposition authorizes buying, selling, transferring funds, allocating capital, or submitting an order.

## Acceptance gates for the next run

A subsequent run is accepted only if all of the following are evidenced:

- [ ] All included companies have exactly one complete result object.
- [ ] The first-run result set has been reconciled against run `fb8514bb-e527-4c46-8c43-1bfa776033f1`; changes and unchanged results are explicit.
- [ ] POWL's eight reported primary observations resolve to the intended canonical equity research card, or the unresolved link is retained as a blocking exception with owner and next action.
- [ ] VLTO and NVT have valuation-review records with dated market inputs, normalized cash-flow definitions, explicit acquisition assumptions, sensitivity, downside cases, and a human research disposition; if critical inputs are unavailable, they remain `AWAIT_EVIDENCE`.
- [ ] POWL's November 16, 2026 earnings catalyst is assessed after publication against its stated backlog and cash-conversion tests; no event outcome is pre-filled.
- [ ] Every figure and test can be traced to source evidence and read back.
- [ ] Archive integrity and all-result readback pass.
- [ ] The output contains zero implied or explicit buy/sell authorization.
- [ ] Delivery remains `ON_DEMAND` unless recurring execution and delivery are separately implemented and verified.

## Repeatability and delivery gates

Before any recurring delivery deployment:

1. Execute a second on-demand run with a distinct evidence cutoff.
2. Demonstrate that unchanged inputs do not create false changes or duplicate results.
3. Demonstrate that missing, stale, conflicting, and unlinked evidence fail visibly and preserve unaffected company results.
4. Verify deterministic output structure and successful archive/result readback.
5. Obtain human review of exceptions and the result set.
6. Separately review deployment target, schedule, owner, monitoring, failure notifications, and rollback.
7. Keep broker, trading, capital, and promotion controls unchanged.

A successful on-demand rerun does not by itself prove a deployed recurring service.

## Outcome measurement

Preserve the point-in-time result, evidence snapshot, valuation assumptions, reviewer disposition, and trigger for later comparison. Assess process quality separately from market return. A favorable price move alone is not proof that the research process was sound.

## Implementation status

This document is a contract proposal on an isolated review branch. It is not executable code, a schema migration, a production write, a merged change, or a deployed service. Adoption requires code that validates this contract against real run outputs and a separately reviewed change to the appropriate runtime.

## Provenance

Project: The Nexus Journey / Nexus Capital Map  
Chat: Financial Evidence Engine first results and next milestones  
Timestamp: 2026-11-14 (exact time not supplied)  
Source status: User-supplied first-run report; engine receipt and archive references preserved above  
