# Airtable Integration Specification

This specification defines governed review and projection semantics only. It does not recover or invent a live Airtable base schema.

## Provenance

- **EVIDENCE-BACKED:** AUTO-004B Make lineage contains Airtable search and routing topology; AUTO-004C governed v3 contains Airtable search, create, and update modules.
- **NEW-v1:** Airtable is a structured review/context/integration surface and cannot override PostgreSQL.
- **TBD-LIVE-VERIFICATION:** Base IDs, table names/IDs, field names/types, linked-record relationships, automation state, and current credentials/configuration.

## Approved semantics

PostgreSQL may publish approved state and context projections to Airtable. Airtable may provide review input or a governed proposal. PostgreSQL validates identity, contract version, authority, and reconciliation state before accepting any decision.

Actual Airtable fields, formulas, linked records, and record keys are **TBD-LIVE-VERIFICATION**. No base or table identifier is asserted here.

## Write rules

- Create is permitted only for an approved projection or governed intake record.
- Update is permitted only for a mutable projection using an approved stable key.
- Search/matching must use a governed key, not mutable display text.
- Airtable review values remain input until accepted by PostgreSQL.
- Credential references and webhook configuration are never placed in payloads or documentation.
- Failed, duplicate, conflicting, and replayed submissions follow the central reconciliation policy.

## Unresolved mapping

| Item | Status |
|---|---|
| Base identity | TBD-LIVE-VERIFICATION |
| Tables and field dictionary | TBD-LIVE-VERIFICATION |
| Primary and linked-record keys | TBD-LIVE-VERIFICATION |
| Search formulas and match semantics | TBD-LIVE-VERIFICATION |
| Create/update/upsert behavior | NEW-v1 boundary; live behavior TBD-LIVE-VERIFICATION |
| Automation activation/state | TBD-LIVE-VERIFICATION |
| Connection ownership and credential references | TBD-LIVE-VERIFICATION |

No Airtable records, base IDs, tokens, or account data are included.
