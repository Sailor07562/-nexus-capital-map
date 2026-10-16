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

## Deployment evidence and remaining blockers
As of 2026-10-16, a read-only Supabase management inventory check of sandbox `luodznqacfqyhskmuvjo` independently confirms `aim-powl-readiness` v3 and `aim-powl-ack` v1 are ACTIVE with `verify_jwt=true`, corroborating the October 16 Slack/Dot deployment report. This confirms deployment metadata, not acknowledgment behavior or complete integration.

After [PR #34](https://github.com/Sailor07562/-nexus-capital-map/pull/34) merged on 2026-10-15, the manually triggered [authenticated endpoint smoke test, run 38798030695](https://github.com/Sailor07562/-nexus-capital-map/actions/runs/38798030695) passed at commit `06c7a072dae2dc2e5abf4111ceeb2abaae8080aa`. Its [endpoint job receipt](https://github.com/Sailor07562/-nexus-capital-map/actions/runs/38798030695/job/116639484150) confirms unauthenticated readiness requests were rejected (401/403) and an authenticated readiness read returned the expected mission, `read_only=true`, `unattended_execution_verified=false`, and `governance_readiness=NOT_READY`.

Collector integration and unattended source-to-alert end-to-end evidence remain unresolved; endpoint deployment and this manual read do not establish autonomous execution or satisfy all acceptance tests and governance gates. Governance readiness remains **NOT_READY**. Preserve sandbox isolation and JWT authentication; no production, trading, broker, or capital-execution authority is granted.
