# Reconciliation Policy

This policy is **NEW-v1**. The recovered artifacts establish partial topology only; they do not prove that this complete policy historically existed.

## Lifecycle

`Detect → Classify → Verify → Reconcile → Interpret Consequence → Update State → Log → Alert only if needed`

## Precedence

1. Canonical PostgreSQL state.
2. Verified governed source/evidence.
3. Approved human review decision.
4. Tracker/Airtable projection state.

Tracker and Airtable never silently overwrite PostgreSQL. Their changes are inputs or proposals.

## Required reconciliation record

Where storage is authorized, a reconciliation record should include:

- reconciliation identifier and contract version;
- event, source-system, and source-record references;
- expected and observed identity;
- conflict category and reconciliation status;
- retry count and last error category;
- first/last observed timestamps;
- reviewer or automated decision reference;
- resolution timestamp and replay reference.

The physical PostgreSQL table design is **TBD-LIVE-VERIFICATION**. No migration is created by this specification.

## Failure, retry, and replay

- Record failed writes before retry where technically possible.
- Retry only transient failures within a bounded policy.
- Do not endlessly retry validation, authority, credential, conflict, or permanent failures.
- Move unresolved failures to `DEAD_LETTER` and manual review.
- Replay retains the original `event_id` and `idempotency_key`; it must not create a duplicate canonical event.
- Record duplicate delivery attempts without duplicating immutable history.
- Alert only when a governed threshold or manual intervention state requires it.

Retry limits, dead-letter storage, alert thresholds, and operational ownership are **TBD-LIVE-VERIFICATION**.
