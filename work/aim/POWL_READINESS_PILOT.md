# Nexus A.I.M. POWL Readiness Pilot

Status: SANDBOX ONLY. No trading or production authority.

Canonical Supabase: husnmxgsxasoinhklpfx (do not modify).
Sandbox Supabase: luodznqacfqyhskmuvjo.

Mission: NEXUS-AIM-POWL-PILOT-20261015-001

## Existing sandbox sources
- aim.missions
- aim.evidence
- aim.risk_exceptions
- aim.delivery_receipts
- aim.governance_gate_reviews
- aim.worker_event_inbox
- aim.v_mission_readiness_v1
- aim.v_governance_readiness_v1

## Readiness worker contract
A read-only worker must:
1. Authenticate the caller with an approved service identity.
2. Query mission and governance readiness views.
3. Fail closed if either read is unavailable, stale, or unauthorized.
4. Return evidence count, risk count, delivery state and governance state.
5. Never claim autonomous execution based on database status alone.
6. Never modify canonical production, trading routes or broker controls.

## Acceptance tests
- Missing or invalid identity is rejected.
- Unknown mission is not reported healthy.
- Missing evidence, risk or acknowledgment remains NOT_READY.
- Acknowledgment alone cannot promote a mission.
- Duplicate event identifiers do not create duplicate records.
- Simulated database unavailability fails closed.
- An unattended source-to-alert run requires separate end-to-end evidence.

## Deployment and verification readback (2026-10-19 UTC)
- Sandbox Edge Function `aim-powl-readiness` is deployed ACTIVE at version 3 with `verify_jwt=true`.
- Sandbox Edge Function `aim-powl-ack` is deployed ACTIVE at version 1 with `verify_jwt=true`. Its acknowledgment path has not been invoked or end-to-end tested.
- The existing GitHub Actions workflow `.github/workflows/aim-powl-endpoint-smoke.yml` was rerun in run [38798030695](https://github.com/Sailor07562/-nexus-capital-map/actions/runs/38798030695); latest job attempt 117893766095 completed successfully.
- The smoke test confirmed unauthenticated rejection and an authenticated read for this mission. Its assertions passed: `read_only=true`, `unattended_execution_verified=false`, and `governance_readiness=NOT_READY`.
- Read-only database inspection found `public.aim_ack_delivery_receipt_v1` is SECURITY INVOKER with a fixed `pg_catalog, aim` search path. It updates only a matching receipt ID, mission ID, original message ID, and `SENT` status; it requires acknowledgment text `Acknowledge`. An already acknowledged matching receipt is returned idempotently.
- `aim.delivery_receipts` has RLS enabled with no policies. `anon` and `authenticated` have no table or RPC access; `service_role` can read/update the receipt table and execute the RPC but cannot insert receipts.
- Current sandbox readback found two receipt rows, both already `ACKNOWLEDGED`; there is no `SENT` receipt to use for a controlled transition test. No acknowledgment RPC was called.
- The receipt table has no direct event, evidence, packet, or delivery-key correlation. This is an observed schema gap, not a verified failure of an end-to-end consumer.
- The authenticated read test proves only a read-only sandbox readiness response. It does not prove unattended source collection, evidence admission, research packet creation, alert publication, or acknowledgment receipt correlation.

## Current gates and state reconciliation
- The readiness endpoint reports `readiness=ACKNOWLEDGED_NOT_AUTONOMY_VERIFIED`, `governance_readiness=NOT_READY`, `verified_evidence=1`, `open_risks=1`, and one sent/one acknowledged receipt. These are sandbox database values; they do not mean a workflow or source collector is active.
- `aim.v_mission_readiness_v1.mission_status` directly aliases the stored `aim.missions.status` field. The mission row says `RUNNING`, but this is not a live execution check. Separate runtime checks for `cloud_research_runner`, `alert_delivery_pipeline`, and `automatic_recovery` are all `UNKNOWN`; operational POWL remains paused.
- Gate G5 remains `PENDING`, with no reviewer or review timestamp and review note “Slack SENT, not ACKNOWLEDGED,” although the pilot-mission receipt row and readiness view report an acknowledgment. The receipt row links to Slack parent message `1792081548.902049`; Slack readback confirms the parent message and one Captain 👍 reaction, while the thread has no replies. The database acknowledgment uses source `slack_parent_marker` and the parent message ID. This supports receipt acknowledgment but does not change G5's unreviewed status; the discrepancy remains for an authorized reviewer.
- The gate table has RLS enabled with no policies; `service_role` has no table privileges and no review RPC exists. The review trigger prohibits direct PASS inserts and requires evidence URI, reviewer, and timestamp when changing a gate to PASS. No gate write was attempted.
- All six gate reviews remain `PENDING`. A database trigger blocks mission promotion to `VERIFIED` or `CLOSED` unless all six gates are `PASS` and an acknowledged receipt exists; no gate promotion was attempted.
- Readiness remains `NOT_READY`; POWL remains paused.
- No bounded SEC source fetch or scheduled collection has been run.
- A synthetic acknowledgment round trip requires an approved fixture-creation path for a `SENT` row, a defined event/evidence/packet/delivery-key correlation contract, and an approved retention/cleanup rule. Do not use owner-level SQL to manufacture test data.
- Retention duration and cleanup authority remain unapproved; existing synthetic test rows are preserved.
- Cloud n8n credential/TLS repair remains separate and unresolved. SSL validation must remain enabled.
- Any future production intake must use the existing governed canonical intake RPC, with a verified restricted caller; do not create a parallel production schema or write directly to canonical tables.

## Safety boundary
No canonical production changes, trading activity, broker actions, workflow activation, scheduled collection, or publication are authorized by this pilot status.