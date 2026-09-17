# Nexus Integration Contract v1

**Contract identifier:** `NEXUS-INTEGRATION-CONTRACT-v1`

This is a **NEW-v1** governed contract. It separates design decisions from recovered local evidence and does not establish live canonical status.

## Authority and platform boundaries

| Platform | Contract role | Provenance |
|---|---|---|
| PostgreSQL | Canonical operational data and state authority | NEW-v1, aligned with repository governance |
| n8n | Nexus orchestration and workflow execution | EVIDENCE-BACKED platform lineage |
| Make | Companion/legacy automation lineage for AUTO-004A/B/C | EVIDENCE-BACKED platform lineage |
| Tracker | Operational visibility and logging projection | NEW-v1 |
| Airtable | Structured review, context, and integration projection | NEW-v1 |
| GitHub | Reviewed contract, source, provenance, and change history | NEW-v1 |

No downstream surface may silently override PostgreSQL.

## Canonical event envelope

The following fields define the **NEW-v1** envelope. Historical presence is noted separately.

| Field | Rule | Provenance |
|---|---|---|
| `contract_version` | Exactly `NEXUS-INTEGRATION-CONTRACT-v1` | NEW-v1 |
| `event_id` | Immutable UUID-compatible Nexus event identifier | NEW-v1; compatible with observed n8n event-identifier stage, not historically proven |
| `source_system` | Controlled source identifier | NEW-v1 |
| `source_artifact` | Workflow, blueprint, or evidence identifier | EVIDENCE-BACKED where recovered; otherwise TBD-LIVE-VERIFICATION |
| `source_workflow_version` | Source workflow/export version when available | EVIDENCE-BACKED or TBD-LIVE-VERIFICATION |
| `source_record_id` | Nullable upstream record identifier | NEW-v1 |
| `correlation_id` | Related-process grouping identifier | NEW-v1 |
| `causation_id` | Prior event that caused this event; nullable for roots | NEW-v1 |
| `idempotency_key` | Deterministic duplicate-detection key | NEW-v1; derivation TBD-LIVE-VERIFICATION |
| `occurred_at` | Source occurrence time | NEW-v1 |
| `received_at` | Nexus acceptance time | NEW-v1 |
| `processed_at` | Completion time; nullable before completion | NEW-v1 |
| `processing_status` | `RECEIVED`, `PROCESSING`, `PROCESSED`, `FAILED`, `DEAD_LETTER`, or `REPLAYED` | NEW-v1 |
| `review_status` | `NOT_REQUIRED`, `PENDING`, `APPROVED`, `REJECTED`, or `DEFERRED` | NEW-v1 |
| `reconciliation_status` | `NOT_REQUIRED`, `PENDING`, `MATCHED`, `CONFLICT`, or `MANUAL_REVIEW` | NEW-v1 |
| `error_status` | `NONE`, `TRANSIENT`, `VALIDATION`, `AUTHORITY`, `CONFLICT`, or `PERMANENT` | NEW-v1 |
| `confidence` | Defined source confidence without silent scale conversion | NEW-v1; scale TBD-LIVE-VERIFICATION |
| `verification_state` | `UNVERIFIED`, `STRUCTURALLY_VERIFIED`, `HUMAN_VERIFIED`, or `LIVE_VERIFIED` | NEW-v1 |
| `provenance` | Source, ingestion path, artifact, and evidence references | NEW-v1 |
| `payload` | Governed business data; never credentials or uncontrolled records | NEW-v1 |

All timestamps use UTC and serialize with `Z`. The exact source timezone behavior remains **TBD-LIVE-VERIFICATION**.

## Identity, replay, and writes

- `event_id` identifies one immutable Nexus event.
- `source_system + source_record_id` identifies an upstream object when stable source identity exists.
- `idempotency_key` must be deterministic and based on approved identity components, not mutable display text. Its production formula is **TBD-LIVE-VERIFICATION**.
- A repeated idempotency key must not create a second canonical event.
- Replays retain the original event identity and record a replay attempt separately.
- Append creates immutable event or audit history.
- Update changes only an explicitly mutable projection or status.
- Upsert uses an approved deterministic key for a mutable projection.
- Corrections to immutable events are new events linked by `causation_id`.

## Mapping boundaries

- **PostgreSQL ↔ n8n:** n8n may read or submit governed events/proposals; PostgreSQL validates and records canonical state. The observed WORKFLOW-008 topology includes event-identifier generation, Tracker payload preparation, and a PostgreSQL write (**EVIDENCE-BACKED**); the complete production contract is **TBD-LIVE-VERIFICATION**.
- **PostgreSQL → Tracker:** Publish approved state and event projections using stable Nexus identifiers, statuses, timestamps, review, reconciliation, and provenance (**NEW-v1**). Actual sheet, tab, column, and row-key mapping is **TBD-LIVE-VERIFICATION**.
- **PostgreSQL ↔ Airtable:** Publish review/context projections; Airtable review input becomes a governed proposal, never a silent canonical write (**NEW-v1**). Base, table, field, and relationship details are **TBD-LIVE-VERIFICATION**.
- **Make → governed Nexus intake:** AUTO-004A/B/C remain Make lineage. Make must enter through a governed intake boundary and cannot override PostgreSQL (**NEW-v1**, informed by EVIDENCE-BACKED Make topology).

## Conflict precedence

1. Canonical PostgreSQL state.
2. Verified governed source or evidence.
3. Approved human review decision.
4. Downstream Tracker or Airtable projection.

Downstream changes become proposals or review inputs. Conflicts are recorded and routed to reconciliation or manual review.

## Failure and reconciliation

The required doctrine is:

`Detect → Classify → Verify → Reconcile → Interpret Consequence → Update State → Log → Alert only if needed`

Record failed writes where possible before retry. Retry only eligible transient failures with bounded counts. Preserve `retry_count`, `last_error_category`, reconciliation timestamps, and resolution references. Validation, authority, credential, and permanent failures do not receive unlimited retries. `DEAD_LETTER` requires manual review before replay.

Storage tables, exact retry limits, alert thresholds, and UUID compatibility are **TBD-LIVE-VERIFICATION**; no PostgreSQL migration is introduced here.

## Change control

Contract changes require a reviewed GitHub pull request. PostgreSQL changes require a versioned migration and validation. Workflow and mapping changes must declare the contract version they consume or emit. See [CONTRACT_VERSIONING.md](versioning/CONTRACT_VERSIONING.md).

## Historical candidates

Raw recovered artifacts remain separate from this new contract:

- WORKFLOW-008 — n8n snapshot-contained evidence; standalone preservation is **TBD-LIVE-VERIFICATION**.
- AUTO-004A — Make raw-signal lineage.
- AUTO-004B v7 — Make sandbox/idempotency-oriented lineage.
- AUTO-004C governed v3 — Make Airtable orchestration lineage.

Raw artifacts must retain their original bytes and provenance. A sanitized derivative would be a distinct artifact, never a replacement.
