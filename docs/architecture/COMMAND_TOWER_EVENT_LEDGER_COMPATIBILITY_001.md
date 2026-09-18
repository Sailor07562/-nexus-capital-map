# Command Tower Event Ledger Compatibility 001

Anchor: #ANCHOR-NEXUS-COMMAND-TOWER-EVENT-LEDGER-001

Status: COMPATIBILITY SPECIFICATION — NO DATABASE CHANGE

## Decision

Command Tower will not rebuild, rename, or modify the verified Nexus event
ledger and its protected gateway pattern. It consumes only governed evidence
from the established ledger and, when later authorized, can maintain a
separate operational ledger for Command Tower state.

## Protected Existing Foundation

The existing Nexus pattern remains authoritative for Nexus events:

- `nexus_constitution.record_nexus_event(...)`
- `nexus_constitution.read_nexus_event(text)`
- gateway-only access with `SECURITY DEFINER` and locked `search_path`
- restricted execution; direct table DML and direct ledger reads blocked
- append-only protection against `UPDATE` and `DELETE`
- replay through the same correlation ID returns the same event ID

No Command Tower artifact may assume the gateway signature, owner, grants, or
underlying table name without live readback.

## Command Tower Consumption Contract

When a verified read-only access path is approved, Command Tower may reference
only these minimum, sanitized fields:

| Field | Requirement |
| --- | --- |
| event identifier | Stable, canonical event ID |
| correlation identifier | Used to establish replay lineage |
| event type | Validated event classification |
| outcome/status | Explicit observed outcome, never inferred as verified |
| occurred/recorded timestamp | Source timestamp with timezone |
| evidence/receipt reference | Durable pointer to tool or gateway readback |
| source/workflow reference | Provenance link; credentials excluded |

## Separate Command Tower Ledger Gate

`operations.operational_events` and `operations.operator_log` are draft
structures only. They may be implemented only after a sandbox test proves:

1. no collision with the protected Nexus ledger;
2. idempotency keyed by an immutable correlation identifier;
3. append-only mutation controls;
4. gateway-only controlled writes and read-only presentation access;
5. receipts with write and independent readback evidence;
6. direct table access denied to runtime roles.

## Required Replay Test

`Manual Trigger → Record Nexus Event → Read Nexus Event → Verify Payload →
Replay Same Correlation ID → Verify Identical event_id → Receipt`

This is a validation sequence, not an instruction to modify the existing
workflow. Workflow 006 remains archived evidence; Workflow 007 remains HOLD.

