# Make Lineage and Boundary

This document preserves platform lineage without copying raw blueprints. The boundary rules are **NEW-v1**; the platform classifications are **EVIDENCE-BACKED**.

## Lineage

- `AUTO-004A — Raw Signal Intake Pipeline` = **Make** lineage.
- `AUTO-004B — Classification & Routing Engine` = **Make** lineage.
- `AUTO-004C — Infrastructure Context Engine` = **Make** lineage.

These artifacts must not be reclassified as n8n. Their raw exports remain separate historical or companion evidence and are not copied by this gate.

## Recovered topology

- AUTO-004A variants show Make webhook intake and transformation/routing stages (**EVIDENCE-BACKED**).
- AUTO-004B variants show Make webhook, Airtable search, and routing stages (**EVIDENCE-BACKED**).
- AUTO-004C governed v3 shows Make webhook, Airtable search/create/update, and model-assisted processing stages (**EVIDENCE-BACKED**).
- Exact current activation, connections, webhook settings, and live behavior are **TBD-LIVE-VERIFICATION**.

## Governed boundary

Make may submit a versioned intake envelope to the governed Nexus boundary. It may not silently override canonical PostgreSQL state, write an unvalidated canonical decision, or bypass identity, idempotency, provenance, review, and reconciliation checks.

Make outputs are treated as:

- input or evidence before validation;
- derived processing output where explicitly configured;
- never authoritative merely because a scenario ran successfully.

The governed intake path, contract-version support, retry behavior, and current scenario ownership are **TBD-LIVE-VERIFICATION**.

## Preservation rule

Raw Make blueprints must retain original bytes and provenance if later preserved. A sanitized or normalized representation must be a distinct derived artifact with its own hash and source reference. This document is not a substitute for raw artifact preservation.
