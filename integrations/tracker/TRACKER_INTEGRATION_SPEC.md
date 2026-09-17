# Tracker Integration Specification

This specification defines only governed projection semantics. It does not recover or invent a live Tracker schema.

## Provenance

- **EVIDENCE-BACKED:** Recovered n8n WORKFLOW-008 includes event-identifier generation, Tracker-payload preparation, and a PostgreSQL `Record Tracker Event` stage.
- **NEW-v1:** Tracker is an operational visibility/logging projection and cannot override PostgreSQL.
- **TBD-LIVE-VERIFICATION:** Tracker version, provider, sheet/tab names, column names, row keys, live append/update behavior, and current workflow state.

## Approved semantics

PostgreSQL publishes approved event/state projections to Tracker. A projection may contain stable Nexus identifiers, timestamps, processing/review/reconciliation states, confidence, verification state, and provenance references. Actual field names and row mappings remain **TBD-LIVE-VERIFICATION**.

Tracker input is treated as a proposal or review signal. It must be validated, reconciled, and accepted by PostgreSQL before becoming canonical state.

## Write rules

- Append immutable event/audit projections where historical visibility is required.
- Update only explicitly mutable projection rows.
- Upsert only with a reviewed deterministic row key.
- Never infer a row key from display text.
- Duplicate delivery must be detectable through the governed idempotency key.
- Failed writes, retry state, and reconciliation outcome belong to governed Nexus records; their physical storage is **TBD-LIVE-VERIFICATION**.

## Unresolved mapping

| Item | Status |
|---|---|
| Tracker version | TBD-LIVE-VERIFICATION |
| Sheet/tab names | TBD-LIVE-VERIFICATION |
| Column dictionary and types | TBD-LIVE-VERIFICATION |
| Primary row key | TBD-LIVE-VERIFICATION |
| Append/update/upsert behavior | TBD-LIVE-VERIFICATION |
| Authentication and connection ownership | TBD-LIVE-VERIFICATION |
| Conflict and retry handling | NEW-v1 policy; live implementation TBD-LIVE-VERIFICATION |

No Tracker records are included or used by this specification.
