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
- This is an authenticated sandbox read test only. It does not prove unattended source collection, evidence admission, research packet creation, alert publication, or acknowledgment receipt correlation.

## Current gates
- Readiness remains `NOT_READY`; POWL remains paused.
- No bounded SEC source fetch or scheduled collection has been run.
- The receipt path requires a synthetic delivery receipt and a proven event/evidence/packet/delivery-key correlation before acknowledgment testing.
- Retention duration and cleanup authority remain unapproved; synthetic test rows are preserved.
- Cloud n8n credential/TLS repair remains separate and unresolved. SSL validation must remain enabled.
- Any future production intake must use the existing governed canonical intake RPC, with a verified restricted caller; do not create a parallel production schema or write directly to canonical tables.

## Safety boundary
No canonical production changes, trading activity, broker actions, workflow activation, scheduled collection, or publication are authorized by this pilot status.