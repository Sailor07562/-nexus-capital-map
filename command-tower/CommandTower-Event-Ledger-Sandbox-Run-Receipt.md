# Command Tower Event Ledger Sandbox Run Receipt

Status: **PASS — SANDBOX RUN VERIFIED**

Captured: 2026-09-18 15:25:06 America/Los_Angeles

## Run identity

- Runtime: n8n Sandbox at `127.0.0.1:5678`
- Workflow: `NEXUS-N8N-WORKFLOW-007-EVENT-LEDGER-ORCHESTRATION`
- Workflow ID: `HxoI0JcfI1ysCnCB`
- Trigger: manual sandbox execution
- n8n execution ID: `147`
- Result: Succeeded in `570ms`
- Saved execution size: `15KB`

## Verified workflow path

The successful final node, `Verify Replay and Issue Receipt`, only completes after the workflow has:

1. Recorded the event through `nexus_constitution.record_nexus_event`.
2. Read the event through `nexus_constitution.read_nexus_event`.
3. Matched the recorded and read-back event IDs and payload fields.
4. Replayed the same idempotency key and matched the original event ID.

The n8n execution page reported success for all seven workflow nodes. The run therefore passed the candidate's governed record, readback, payload verification, and idempotent replay checks.

## Safety boundary

- Sandbox runtime only; Production `127.0.0.1:5680` was not used.
- No workflow activation, schedule, credential change, migration, or schema change was performed.
- No broker, order, transfer, promotion, or trading node was involved.
- The approved event-ledger gateway write was the only intended data mutation.
- Architecture remains **FROZEN**.

Broader workflow activation, scheduling, production promotion, and downstream Tracker integration remain on hold pending separate approval and evidence.

