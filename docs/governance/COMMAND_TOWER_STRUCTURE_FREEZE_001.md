# Command Tower Structure Freeze 001

Anchor: #ANCHOR-NEXUS-COMMAND-TOWER-STRUCTURE-001

Status: FROZEN

## Scope

Command Tower is the read-oriented operator and governance layer surrounding
the frozen Nexus core. It coordinates what is live, frozen, verified, and
movable; it does not replace PostgreSQL or directly alter the core.

## Frozen Boundaries

- Nexus Architecture v1.0 remains frozen; changes require formal amendment.
- PostgreSQL remains the live system of record.
- GitHub is the governed recovery, traceability, and version vault.
- Drive remains the human-readable archive and backup/document home.
- n8n, Docker, Airtable, and Tracker retain their operational roles.

## Permitted Command Tower Work

- Read-only discovery and state indexing
- Governance and operating-protocol documentation
- Sanitized repo consolidation
- Read-only verification queries and views, once expressly authorized
- Interface and workflow design that does not modify live systems

## Prohibited Without Explicit Captain Authorization

- Production or live PostgreSQL changes
- Promotion to a higher environment or operating state
- Authority-moving, destructive, or cleanup actions
- Secret-bearing exports, raw dumps, or financial-account data

