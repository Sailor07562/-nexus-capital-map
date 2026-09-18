# Command Tower Read-only Binding Approval Request

Status: **APPROVED AND EXECUTED AS BOUNDED LIVE REFRESH**

Approval received: 2026-09-18. Live refresh completed: 2026-09-18T14:39:29-07:00.

This record requests authorization for the first live read-only adapter binding. It does not authorize writes, schema changes, migrations, workflow changes, credential changes, trading, transfers, or promotion.

## Proposed target

- Host: `127.0.0.1`
- Port: `5432`
- Database: `postgres`
- Semantic schema: `nexus`
- Role: `nexus_command_tower_ro`
- Environment: local PostgreSQL sandbox / governed read-only inspection

## Allowed operation

- Connect using the bounded non-superuser role.
- Read only the eight approved Nexus views already verified in `command-tower-view-readback.json`.
- Read only the approved aggregate summary fields defined in `Read-CommandTowerSummaries.ps1`.
- Render fixture-compatible summaries in the Command Tower UI.

## Prohibited operation

- Any INSERT, UPDATE, DELETE, DDL, migration, grant, role, default-privilege, or configuration change.
- Any Airtable, Tracker, GitHub, n8n, brokerage, trading, transfer, or promotion action.
- Any unrestricted row export or credential persistence.
- Any restore or overwrite of the live database.

## Approval statement

Approved statement: “Approve the bounded read-only binding to 127.0.0.1:5432, database postgres, schema nexus, using nexus_command_tower_ro, limited to the eight approved views and aggregate summaries.”

Execution evidence: `command-tower-summary-readback.json`. The refresh completed through the bounded role with 8 summaries, `row_data_exported=false`, and `writes_attempted=false`. The browser UI remains fixture-backed by design; no browser-to-database connection was introduced.


