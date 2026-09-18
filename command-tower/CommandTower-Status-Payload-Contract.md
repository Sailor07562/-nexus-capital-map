# Command Tower Status Payload Contract

Status: implementation-ready, read-only payload contract

Captured: 2026-09-18

This contract defines the bounded status shape that a future local read-only status API may expose. The checked-in payload is a fixture-compatible artifact for review and testing; it is not a live endpoint and does not authorize direct browser-to-PostgreSQL access.

## Boundary

- PostgreSQL remains semantic authority.
- The payload may contain target identity, gate state, scalar counts, and safety flags.
- The payload must not contain unrestricted rows, credentials, tokens, order instructions, or write controls.
- `write_capability`, `row_data_exported`, and `writes_attempted` must remain explicit safety fields.
- `promotion_state` remains `HOLD` until a separate human-approved promotion decision.
- A future live adapter requires a separate implementation review and fresh readback evidence.

## Payload shape

| Field | Meaning | Constraint |
|---|---|---|
| `schema_version` | Payload contract version | Integer; changes require review |
| `source_mode` | Evidence source mode | Must identify bounded read-only fixture or approved readback |
| `target` | PostgreSQL target identity | Exact approved local target only |
| `read_only` | Adapter safety state | Must be `true` |
| `view_count` / `summary_count` | Approved surface counts | Eight and eight for this package |
| `row_data_exported` | Row export safety flag | Must be `false` |
| `writes_attempted` | Write safety flag | Must be `false` |
| `write_capability` | Capability boundary | Must be `false` |
| `gates` | Human-readable readiness states | Evidence-backed only |
| `promotion_state` | Promotion boundary | `HOLD` in this phase |
| `architecture_state` | Freeze state | `FROZEN` |

The payload is intentionally scalar-only. It is suitable for a local status surface, not for investment decisions, evidence admission, deployment, promotion, or trading execution.

