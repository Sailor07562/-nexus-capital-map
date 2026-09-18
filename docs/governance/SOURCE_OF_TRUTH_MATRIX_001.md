# Source of Truth Matrix 001

Anchor: #ANCHOR-NEXUS-COMMAND-TOWER-SOT-001

| Domain | Authoritative system | Command Tower role | Change rule |
| --- | --- | --- | --- |
| Live relational facts | PostgreSQL | Read, index, verify, and surface status | Never alter without explicit authorization and readback |
| SQL/migrations/governance history | GitHub repository | Version, review, checkpoint, and recover | Sanitized commits only |
| Human-readable maps and backups | Google Drive | Reference archive and recovery location | Preserve canonical artifacts; do not silently recreate |
| Workflow execution | n8n/Docker | Observe, document, and govern promotion | Export only redacted workflows |
| Operational registers | Airtable/Tracker | Coordinate statuses and work queues | Record provenance and timestamp |
| Operator decisions | Captain | Final approval and execution authority | Text locks the approved action; readback verifies |

## Conflict Rule

When sources disagree, do not reconcile by assumption. Preserve the conflict,
record the evidence, and defer to the authoritative system for that domain.

