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

## Deployment and verification evidence

- On 2026-10-16, a read-only Supabase management inventory check of sandbox `luodznqacfqyhskmuvjo` confirmed `aim-powl-readiness` v3 and `aim-powl-ack` v1 are ACTIVE with `verify_jwt=true`. This confirms deployment metadata; it does not establish acknowledgment behavior or complete integration.
- The existing GitHub Actions workflow `.github/workflows/aim-powl-endpoint-smoke.yml` ran manually in [run 38798030695](https://github.com/Sailor07562/-nexus-capital-map/actions/runs/38798030695), at commit `06c7a072dae2dc2e5abf4111ceeb2abaae8080aa`. The endpoint job passed: unauthenticated readiness requests were rejected (401/403), and an authenticated readiness read returned this mission with `read_only=true`, `unattended_execution_verified=false`, and `governance_readiness=NOT_READY`.
- The authenticated read proves only a read-only sandbox readiness response. It does not prove unattended source collection, evidence admission, research packet creation, alert publication, acknowledgment receipt correlation, or all acceptance tests and governance gates.

## Sandbox receipt and gate findings (readback 2026-10-19 UTC)

- Read-only database inspection found `public.aim_ack_delivery_receipt_v1` is SECURITY INVOKER with a fixed `pg_catalog, aim` search path. It updates only a matching receipt ID, mission ID, original message ID, and `SENT` status; it requires acknowledgment text `Acknowledge`. An already acknowledged matching receipt is returned idempotently.
- `aim.delivery_receipts` has RLS enabled with no policies. `anon` and `authenticated` have no table or RPC access; `service_role` can read/update the receipt table and execute the RPC but cannot insert receipts.
- The readback found two receipt rows, both already `ACKNOWLEDGED`; no `SENT` receipt was available for a controlled transition test, and no acknowledgment RPC was called.
- The receipt table has no direct event, evidence, packet, or delivery-key correlation. This is an observed schema gap, not a verified end-to-end consumer failure.
- A synthetic acknowledgment round trip requires an approved fixture-creation path for a `SENT` row, a defined event/evidence/packet/delivery-key correlation contract, and an approved retention/cleanup rule. Do not use owner-level SQL to manufacture test data.
- Retention duration and cleanup authority remain unapproved; existing synthetic test rows are preserved.

## Current gates and state reconciliation (readback 2026-10-19 UTC)

- The readiness endpoint reported `readiness=ACKNOWLEDGED_NOT_AUTONOMY_VERIFIED`, `governance_readiness=NOT_READY`, `verified_evidence=1`, `open_risks=1`, and one sent/one acknowledged receipt. These are sandbox database values; they do not mean a workflow or source collector is active.
- `aim.v_mission_readiness_v1.mission_status` directly aliases stored `aim.missions.status`. The mission row said `RUNNING`, but this is not a live execution check. Separate runtime checks for `cloud_research_runner`, `alert_delivery_pipeline`, and `automatic_recovery` were all `UNKNOWN`; operational POWL remains paused.
- Gate G5 was `PENDING`, with no reviewer or review timestamp and review note “Slack SENT, not ACKNOWLEDGED,” although the pilot-mission receipt row and readiness view reported an acknowledgment. The receipt row linked to Slack parent message `1792081548.902049`; Slack readback confirmed the parent message and one Captain 👍 reaction, while the thread had no replies. The database acknowledgment used source `slack_parent_marker` and the parent message ID. This supports receipt acknowledgment but does not change G5's unreviewed status; the discrepancy remains for an authorized reviewer.
- The gate table had RLS enabled with no policies; `service_role` had no table privileges and no review RPC existed. The review trigger prohibited direct PASS inserts and required evidence URI, reviewer, and timestamp when changing a gate to PASS. No gate write was attempted.
- All six gate reviews remained `PENDING`. A database trigger blocks mission promotion to `VERIFIED` or `CLOSED` unless all six gates are `PASS` and an acknowledged receipt exists; no gate promotion was attempted.
- Readiness remains **NOT_READY**; POWL remains paused.
- No bounded SEC source fetch or scheduled collection had been run.
- Cloud n8n credential/TLS repair remains separate and unresolved. SSL validation must remain enabled.
- Any future production intake must use the existing governed canonical intake RPC, with a verified restricted caller; do not create a parallel production schema or write directly to canonical tables.

## Safety boundary

No canonical production changes, trading activity, broker actions, workflow activation, scheduled collection, or publication are authorized by this pilot status. Preserve sandbox isolation and JWT authentication; no production, trading, broker, or capital-execution authority is granted.
