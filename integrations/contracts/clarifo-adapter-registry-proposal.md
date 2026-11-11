# Clarifo adapter registry proposal (not applied)

This proposal is for review with draft PR #39. It is deliberately not written to the canonical registry.

| Field | Proposed value |
|---|---|
| adapter_code | `clarifo_nexus_adapter_v2` |
| adapter_name | Clarifo packet intake |
| adapter_type | api_service |
| direction | inbound |
| applicability_status | verification_required |
| authentication_mode | credential_reference |
| credential_class | server_side_secret_reference |
| canonical_write_authority | false until approved end-to-end verification |
| automatic_promotion_authority | false |
| execution_authority | false |
| network_posture | unresolved pending endpoint and network review |
| allowed_operations | [] until the append RPC, authentication, and readback are approved |
| prohibited_operations | `automatic_promotion`, `thesis_promotion`, `trade_execution`, `broker_execution`, `packet_update`, `packet_delete`, `direct_table_write` |

## Required verification sequence

1. Review and apply the proposed append RPC only after migration and security review.
2. Implement a dedicated server-side Edge Function that invokes only that RPC; do not expose service-role credentials to Clarifo or clients.
3. Verify request authentication, input validation, network posture, duplicate behavior, and readback using synthetic data.
4. Run an authorized end-to-end append using an explicitly approved test packet; confirm pending review and both action flags false.
5. Record a `security` verification event and an `end_to_end` event with the exact evidence reference. Mark the registry verified and grant the single append capability only after those checks pass and the human governance owner approves.

The live registry's allowed applicability states are `verification_required`, `verified_applicable`, `not_applicable`, and `superseded`. Verification event statuses include `pass`, `fail`, `blocked`, and `not_run`. A registry row marked `verified_applicable` requires both `verified_by` and `verified_at`.

## Current state

No Clarifo registry row or verification event exists. The current service role has no table INSERT privilege; the proposed RPC is unapplied. No production write, adapter registration, or packet refresh has occurred.
