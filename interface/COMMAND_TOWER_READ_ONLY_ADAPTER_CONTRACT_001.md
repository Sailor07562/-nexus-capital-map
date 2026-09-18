# Command Tower Read-Only Adapter Contract 001

Anchor: #ANCHOR-NEXUS-COMMAND-TOWER-READ-ONLY-ADAPTER-001

Status: LOCAL CONTRACT — LIVE BINDING NOT AUTHORIZED

## Purpose

This contract defines the only approved shape of data delivered to the local
Command Tower interface. It is an adapter boundary: PostgreSQL remains
authoritative and the browser receives read-only, sanitized view output only.

## Connection Rules

- The current interface uses local mock data only.
- A future adapter may query only approved read-only views over an approved
  local service boundary; the browser never receives database credentials.
- No adapter endpoint may invoke a write gateway, queue action, workflow,
  promotion, trading function, or governance amendment.
- Missing, mismatched, or stale readback must render as `unknown` or `blocked`,
  never as success.

## Proposed View Bindings — Pending Live Readback

| Interface area | Proposed view contract | Minimum fields |
| --- | --- | --- |
| Command summary | `operations.v_command_tower` | cycle key, verification state, health summary, attention count, promotion count, observed at, evidence |
| System health | `operations.v_system_health` | service, authority system, environment, health state, verification state, observed at, evidence |
| Daily changes | `operations.v_today_summary` | summary date, event counts, open attention, pending promotions, latest verification |
| Attention queue | `operations.v_attention` | key, severity, summary, source, queue status, verification state, evidence |
| Backup health | `operations.v_backup_health` | backup key, scope, validation state, created/validated timestamps, storage reference, evidence |
| Workflow status | `operations.v_workflow_status` | workflow reference, outcome, verification state, observed at, receipt/evidence |
| Current cycle | `operations.v_operational_cycle` | cycle key, lifecycle status, owner, opened/closed timestamps, evidence |
| Promotion gates | `operations.v_pending_promotions` | key, source, target, action, gate status, authorization reference, rollback reference, evidence |
| Operator dashboard | `operations.v_operator_dashboard` | current-cycle state, critical attention, promotion gates, backup state, latest evidence |

`operations.v_daily_summary`, `operations.v_pending_reviews`, and
`operations.v_backup_status` are known historical naming candidates only. Do
not bind any name until target-specific discovery verifies the view definition,
owner, grants, and columns.

## Required Envelope

Every adapter response must use this shape:

```json
{
  "contract_version": "001",
  "data_mode": "mock | verified_readback | stale | blocked",
  "source_view": "qualified view name or null",
  "observed_at": "ISO-8601 timestamp or null",
  "evidence_reference": "sanitized reference or null",
  "rows": []
}
```

## Validation Gates Before Live Binding

1. Verify database identity, migration lineage, schema ownership, and view grants.
2. Verify that each source is an approved read-only view.
3. Compare actual columns with this contract and record any mapping change.
4. Test a sandbox adapter with no secrets in browser or repository output.
5. Confirm stale/missing/error states fail closed in the interface.
6. Obtain explicit Captain approval before any live local binding.

