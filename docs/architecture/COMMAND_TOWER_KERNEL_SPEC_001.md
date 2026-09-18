# Command Tower Kernel Specification 001

Anchor: #ANCHOR-NEXUS-COMMAND-TOWER-KERNEL-001

Status: DESIGN FROZEN — IMPLEMENTATION NOT YET PROMOTED

## Mission

The Kernel is the single coordination layer for Command Tower. It records and
surfaces operational state across Nexus without becoming the authority for the
underlying systems.

It answers five operator questions:

1. What is currently live?
2. What is frozen or protected?
3. What needs attention?
4. What is eligible to move?
5. What evidence supports that status?

## Authority Boundary

| Concern | Kernel responsibility | Authoritative source |
| --- | --- | --- |
| Live relational facts | Index and display verified status | PostgreSQL |
| Change/recovery lineage | Link version and checkpoint references | GitHub |
| Human-readable maps/backups | Link archive references | Google Drive |
| Workflow status | Record sanitized workflow health and run evidence | n8n/Docker |
| Work coordination | Surface queues and open gates | Airtable/Tracker |
| Approval | Record declared approval status | Captain |

The Kernel must not silently overwrite any source system, infer a verification,
or authorize its own promotion.

## Core Objects

| Object | Purpose | Minimum state fields |
| --- | --- | --- |
| Operating cycle | Groups a governed period of work | cycle ID, status, opened/closed timestamps, owner |
| Service registry | Identifies a system/component and health | service ID, system, environment, health, last verified |
| Attention item | Records an actionable observation | item ID, severity, source, evidence, disposition |
| Promotion item | Controls a proposed change/state move | item ID, source, target, risk, authorization, gate status |
| Backup record | Preserves recovery references | backup ID, scope, location, validation, created timestamp |
| Operator log | Append-only record of operator-facing events | event ID, event type, actor, evidence, timestamp |

## State Vocabulary

Use only the following verification states until formally amended:

| State | Meaning |
| --- | --- |
| `verified` | Direct readback or tool evidence is recorded |
| `inferred` | Reasoned, but lacks direct verification evidence |
| `unknown` | No reliable evidence has been captured |
| `failed` | A verification or execution attempt produced failure evidence |
| `blocked` | A required access, approval, or gate is absent |
| `frozen` | Deliberately protected from change |

## Non-Negotiable Kernel Rules

- Every displayed status carries an evidence reference or is `unknown`.
- Operator-log events are append-only and replay-safe.
- A promotion item cannot advance without the gate sequence in
  `docs/operating-protocols/PROMOTION_PROTOCOL_001.md`.
- Read-only aggregation is the default; controlled writes require a separate
  authorized implementation artifact.
- No credentials, tokens, raw financial records, or unfiltered exports enter
  the Kernel repository.

## Intended Implementation Order

1. Create a reviewable PostgreSQL `operations` schema migration draft.
2. Add append-only operational-event ledger design.
3. Add read-only operational views:
   `v_command_tower`, `v_system_health`, `v_today_summary`, `v_attention`,
   and `v_workflow_status`.
4. Validate in the designated sandbox before any production consideration.
5. Build the local read-oriented interface, then redacted n8n workflow links.

