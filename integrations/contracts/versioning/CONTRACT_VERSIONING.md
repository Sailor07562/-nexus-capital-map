# Contract Versioning

The governed identifier is:

```text
NEXUS-INTEGRATION-CONTRACT-v1
```

This is **NEW-v1** policy.

## Compatibility

- Additive, backward-compatible fields may be introduced within a major contract version only with documentation and validation.
- Changing identity, authority, requiredness, enum semantics, field meaning, or write behavior is a breaking change.
- Breaking changes require a new major contract version and a migration/deprecation plan.
- Producers and consumers must declare the contract version they emit or consume.

## Change control

- Every contract change requires a reviewed GitHub pull request.
- PostgreSQL schema changes require a versioned migration, validation, and source-authority review.
- n8n and Make workflow changes must identify affected contract fields and preserve raw-artifact provenance.
- Tracker and Airtable mapping changes require a mapping-version update and reconciliation plan.
- GitHub preservation does not authorize import, activation, execution, or modification of live workflows.

## Compatibility still unresolved

The following are **TBD-LIVE-VERIFICATION**:

- existing PostgreSQL column types and UUID compatibility;
- current workflow contract-version behavior;
- Tracker and Airtable schema/version mechanisms;
- migration requirements for event and reconciliation storage;
- deprecation windows and rollback procedures;
- live producer/consumer inventory.

No database migration or live configuration change is part of Contract v1 documentation.
