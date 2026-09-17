# Nexus Integration Contracts

This directory contains reviewed, platform-neutral integration contracts for Nexus Capital Map.

## Authority model

- PostgreSQL is the canonical operational data and state authority.
- n8n is the Nexus orchestration and workflow-execution layer.
- Make preserves companion and legacy automation lineage for AUTO-004A, AUTO-004B, and AUTO-004C.
- Tracker is an operational visibility and logging projection.
- Airtable is a structured review, context, and integration projection.
- GitHub is the reviewed contract, provenance, and change-history authority.

Downstream surfaces must not silently overwrite canonical PostgreSQL state.

## Provenance labels

Every specification uses these labels:

- **EVIDENCE-BACKED** — observed in recovered local artifacts.
- **NEW-v1** — introduced by the governed `NEXUS-INTEGRATION-CONTRACT-v1` design.
- **TBD-LIVE-VERIFICATION** — intentionally unresolved until controlled live or schema verification.

The Contract v1 design is new governance documentation. It is not a claim that the complete historical contract existed locally.

## Contract documents

- [NEXUS_INTEGRATION_CONTRACT_V1.md](NEXUS_INTEGRATION_CONTRACT_V1.md)
- [FIELD_AUTHORITY_MATRIX.md](FIELD_AUTHORITY_MATRIX.md)
- [RECONCILIATION_POLICY.md](RECONCILIATION_POLICY.md)
- [versioning/CONTRACT_VERSIONING.md](versioning/CONTRACT_VERSIONING.md)
- [tracker/TRACKER_INTEGRATION_SPEC.md](../tracker/TRACKER_INTEGRATION_SPEC.md)
- [airtable/AIRTABLE_INTEGRATION_SPEC.md](../airtable/AIRTABLE_INTEGRATION_SPEC.md)
- [make/MAKE_LINEAGE_AND_BOUNDARY.md](../make/MAKE_LINEAGE_AND_BOUNDARY.md)

No raw workflow, blueprint, record, credential, or production database artifact belongs in this contract directory.
