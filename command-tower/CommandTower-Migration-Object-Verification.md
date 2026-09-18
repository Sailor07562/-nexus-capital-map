# Command Tower Migration and Object Verification

Status: **PASS**

Verified: `2026-09-18T16:08:32-07:00`

## Migration lineage

- Registry: `nexus.schema_migrations`
- Rows: `262`
- Minimum version: `1`
- Maximum version: `262`
- Expected maximum: `262`
- Integrity field: `sha256`
- Non-empty checksums: `262`
- Aggregate checksum digest: `c57aafa41719ea1b81db193e480b6fd5`
- Checksum gate: **PASS**

## Approved object inventory

All 8 approved views are present as PostgreSQL views and returned a non-empty definition hash through the bounded role:

- `nexus.v_capital_map_operating_summary`
- `nexus.v_broker_connection_health`
- `nexus.v_automation_intake_queue`
- `nexus.v_research_radar_governance_health`
- `nexus.v_research_radar_state_status`
- `nexus.v_paper_order_policy_health`
- `nexus.v_signal_lineage`
- `nexus.v_shadow_mode_summary`

Object gate: **PASS**

## Safety result

- Role: `nexus_command_tower_ro`
- Row data exported: `false`
- Writes attempted: `false`
- Schema or data changed: `false`
- Migrations changed: `false`
- No definitions, migrations, grants, workflows, credentials, Airtable, Tracker, GitHub, brokerage, trading, transfer, or promotion state was changed.

Source evidence: `command-tower-migration-object-evidence.json`.


