# Command Tower Read-Only View Contract 001

Anchor: #ANCHOR-NEXUS-COMMAND-TOWER-READ-ONLY-VIEWS-001

Status: CONTRACT FROZEN — IMPLEMENTATION DEFERRED

## Purpose

The operator interface consumes read-only, evidence-bearing summaries. Views
must not become a new source of truth, grant write paths, or conceal unknown
and blocked states.

## Required View Outputs

| Contract name | Operator question answered | Minimum output |
| --- | --- | --- |
| `v_command_tower` | What is live, frozen, blocked, and needing attention? | cycle, system, verification state, health, attention count, promotion count, evidence timestamp |
| `v_system_health` | Which services are healthy or degraded? | service, environment, authority system, health, verification state, last observed, evidence |
| `v_today_summary` | What changed in the current operating period? | date, events by outcome, open attention, pending promotions, latest verification |
| `v_attention` | What requires a decision or follow-up? | severity, summary, source, verification state, queue status, owner/evidence |
| `v_backup_health` | Is a recoverable checkpoint evidenced? | backup scope, source, validation state, created/validated timestamps, storage reference |
| `v_workflow_status` | Which governed workflow state is known? | workflow reference, latest outcome, verification state, receipt/evidence, observed timestamp |
| `v_operational_cycle` | Which governed cycle is active? | cycle key, lifecycle status, owner, opened/closed, evidence |
| `v_pending_promotions` | What may move and what blocks it? | source, target, action, gate state, authorization, rollback, evidence |
| `v_operator_dashboard` | What is the concise command summary? | current-cycle state, health summary, critical attention, promotion gates, backup state |

## View Rules

- All view rows carry a source/evidence reference and observation timestamp.
- `verified`, `inferred`, `unknown`, `failed`, `blocked`, and `frozen` remain
  visibly distinct.
- Analytics and decision summaries may use only `verified` facts unless clearly
  labelled otherwise.
- Views are read-only presentation contracts; no `INSTEAD OF` triggers or
  writable-view patterns.
- View definitions, ownership, and grants require discovery of the actual
  PostgreSQL target and roles before implementation.

