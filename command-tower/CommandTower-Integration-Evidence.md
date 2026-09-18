# Command Tower Integration Evidence

Captured: 2026-09-18 14:12 America/Los_Angeles

Scope: read-only discovery only. No PostgreSQL migration, restore, write, connector mutation, promotion, or automation change was performed.

## PostgreSQL

- Target: `127.0.0.1:5432`, database `postgres`
- Server: PostgreSQL `18.4`
- Catalog user read back: `postgres`
- Role attributes: superuser, create-role, create-database, login
- `transaction_read_only`: `off`
- `default_transaction_read_only`: `off`
- `nexus` schema: present
- `operations` schema: not present
- Migration lineage: 262 applied rows; maximum version 262
- PostgreSQL views: existing `nexus` view inventory read successfully
- Extensions observed: `pgcrypto 1.4`, `plpgsql 1.0`

Binding decision: **BLOCKED**. The current credential is a superuser and is not a bounded read-only binding role. The Command Tower remains disconnected from live PostgreSQL data.

## Bounded read-only role gate

- Role created: `nexus_command_tower_ro`
- Role session: `current_user=nexus_command_tower_ro`
- Role attributes: non-superuser, cannot create roles, cannot create databases, cannot replicate, cannot bypass row-level security
- Database access: `CONNECT` verified
- Schema access: `nexus USAGE` verified; `nexus CREATE` denied
- Data access: `SELECT` verified on existing Nexus tables; `INSERT`, `UPDATE`, and `DELETE` denied
- Session safety: `transaction_read_only=on`; `default_transaction_read_only=on`
- Default privileges: unchanged
- Schema/data/migration/workflow state: unchanged

Binding decision: **ROLE GATE PASSED**. The next read-only step is limited to approved existing Nexus views; no Command Tower schema or live write path is being introduced.

## First read-only view readback

- Role session: `current_user=nexus_command_tower_ro`
- Session modes: `transaction_read_only=on`, `default_transaction_read_only=on`
- Approved views checked: 8
- Views present: 8 of 8
- Views with at least one row: 8 of 8
- Row data exported: false
- Writes attempted: false

Verified view set:

- `nexus.v_capital_map_operating_summary`
- `nexus.v_broker_connection_health`
- `nexus.v_automation_intake_queue`
- `nexus.v_research_radar_governance_health`
- `nexus.v_research_radar_state_status`
- `nexus.v_paper_order_policy_health`
- `nexus.v_signal_lineage`
- `nexus.v_shadow_mode_summary`

Binding decision: **VIEW READBACK PASSED / BOUNDED FIXTURE ACTIVE**. The Command Tower may expose only verified view metadata and aggregate-only summary fields; it must not export unrestricted row data or create new database objects.

### Aggregate-only summary readback

- Evidence: `command-tower-summary-readback.json`
- Mode: bounded aggregate-only readback
- Approved views summarized: 8 of 8
- Payload: scalar counts and safety flags only; no row values were exported.
- `row_data_exported`: `false`
- `writes_attempted`: `false`
- Summary highlights: 2 capital-map records; 5 Research Radar lanes and 24 sources; 2 paper-order policies with 0 submitted orders; 1 shadow experiment with 14 intents and 0 order-submission attempts; 9 evidenced signals.

The aggregate fixture is rendered in `CommandTower.html`. Live browser-to-PostgreSQL binding remains intentionally disabled.

### Approved live refresh

- Approval: exact target and bounded scope approved on 2026-09-18.
- Execution evidence: `CommandTower-Live-ReadOnly-Binding-Evidence.md`.
- Refresh result: 8 approved views and 8 aggregate summaries through `nexus_command_tower_ro`.
- Safety result: read-only transaction, no row export, no write path, and no writes attempted.
- Browser boundary: the static UI remains disconnected from PostgreSQL and renders the bounded fixture-compatible payload.

## Airtable

- Base: `LB Nexus_Sandbox_v1`
- Base ID: `appl14dXK5cUtvZt8`
- Permission level: `create`
- Connectivity: ping passed
- Tables discovered: 73
- Governance/readback surfaces present include `Dashboard_Status`, `Governance_Command_Center`, `Validation_Log`, `Promotion_Log`, `Airtable_Readback_Seal_Log`, `Airtable_Authority_Warning_Labels`, and `Nexus_Test_Intake`.
- Sample readback: `Nexus_Test_Intake` contains three records; the controlled sandbox fixture explicitly preserves PostgreSQL authority and denies production or promotion authority.

Binding decision: **METADATA VERIFIED / NO LIVE BINDING**. Airtable remains a structured sandbox registry and evidence surface, not semantic authority.

## Tracker Sandbox

- Spreadsheet: `Nexus_Registry_v1 — TRACKER SANDBOX COPY — 2026-07-09`
- Spreadsheet ID: `1czF0GkfnILFA1w-jEtFa7VyGjbGKpc0RPFV32S3_irY`
- Visible tabs discovered: 53
- Exact tabs read: `Index`, `Authority`, `Test Log`
- `Index` readback: status vocabulary rows were present and active.
- `Authority` readback: exact header structure was confirmed; no guessed tabs or ranges were used.
- `Test Log` readback: tracker continuity, readback, and promotion-boundary test history was present, including blocked workflow-gate records.

Binding decision: **METADATA AND BOUNDED READBACK VERIFIED / NO WRITE PATH**. The dated copy is the controlled Tracker Sandbox surface; it is not PostgreSQL authority.

## Command Tower gate outcome

The next direct browser-binding or promotion step is not authorized by discovery alone. The bounded local refresh is approved and passed; the following remain required for broader binding or promotion:

1. A bounded non-superuser read-only PostgreSQL role. **Passed.**
2. Explicit target identity and environment approval. **Passed:** exact local target and bounded view/aggregate scope approved.
3. Checksum-aware migration and object inventory evidence. **Passed:** 262 migration rows with non-empty `sha256` values; maximum version 262; all 8 approved views present with definition hashes.
4. A verified Last Known Good backup and restoration reference. **Passed:** migration-262 ZIP, Drive metadata, SHA-256, and 2,227-line restore list verified; no restore executed.
5. A reviewed mapping contract for Airtable and Tracker fields.

## Review artifact

The proposed bounded role contract is recorded in `CommandTower-Postgres-ReadOnly-Role-Proposal.sql`. Every database statement in that file is commented out. It contains no password and was not executed.

The architecture remains frozen. This evidence only updates operational state and does not amend the design. The detailed gate record is `CommandTower-Last-Known-Good-Verification.md`.


