# Command Tower Tracker Event Projection Contract

Status: review-ready, no-write projection contract

Captured: 2026-09-18

This contract prepares the verified Workflow 007 event receipt for review against the controlled Tracker Sandbox. It does not write to Tracker, infer a column dictionary, invent a row key, or promote Tracker to semantic authority.

## Approved boundary

- PostgreSQL remains canonical authority for the event and its state.
- Tracker is an operational visibility and logging projection only.
- Target identity is the dated Tracker Sandbox copy recorded in the bounded mapping evidence.
- `Test Log` is the review surface; exact fields, ranges, row keys, and write behavior remain live-verification items.
- The checked-in projection is a proposal fixture with `write_capability = false` and `records_written = 0`.
- Any future append or upsert requires deterministic key review, reconciliation, duplicate detection, and separate user approval.

## Projection readiness

| Item | State |
|---|---|
| Source event | Workflow 007 Sandbox receipt verified |
| Target surface | Tracker Sandbox identity verified |
| Review tab | `Test Log` bounded-read verified |
| Field dictionary | TBD-LIVE-VERIFICATION |
| Row key | TBD-LIVE-VERIFICATION |
| Write mode | NOT EXECUTED |
| PostgreSQL authority | PRESERVED |
| Reconciliation | REQUIRED before any future write |

This artifact is a review proposal, not an integration activation or schema change.

