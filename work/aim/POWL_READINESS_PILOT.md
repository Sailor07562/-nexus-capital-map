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

## Current blocker
Supabase sandbox Edge Function deployment was blocked by platform safety checks. No Edge Function is deployed. Review and deploy only through approved development/CI gates.
