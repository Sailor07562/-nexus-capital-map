# Clarifo adapter sandbox verification receipt

Date: 2026-11-11 UTC  
GitHub review: draft PR #39, head branch `codex/clarifo-packet-ingest-draft`  
Supabase branch: `clarifo-adapter-review` (`b2af7eff-3c41-4283-84b4-800bb1d2308a`, project ref `hrwajxelmvtxbmgmgclh`)  
Environment: isolated, non-persistent, no production data  
Applied branch migration: `20261111010316 / clarifo_packet_append_draft_sandbox`

## Scope and limitation

The development branch did not contain the canonical `nexus` schema (0 Nexus tables). A synthetic packet table was created using the live Clarifo table's inspected columns, checks, unique packet-key constraint, RLS setting, and service-role grant boundary. Only this test table and the draft append function were applied to the branch.

The Supabase branch status reported `MIGRATIONS_FAILED`. Branch PostgreSQL logs show a separate startup baseline error for a view referencing missing `nexus.paper_order_proposals`. The branch database remained reachable and the Clarifo test migration was recorded successfully. This branch was not a full-schema clone.

## Checks

| Check | Result | Evidence |
|---|---|---|
| Call append RPC as `service_role` with synthetic packet | PASS | Outcome `inserted`, packet ID `0cf83992-2389-4af0-98e6-47442279f145` |
| Repeat same `packet_key` with changed JSON (original draft behavior) | PASS, limited | Outcome `duplicate`, same packet ID; original `revision: 1` retained. This established no overwrite only; it did **not** establish collision-aware verification and was superseded by the PR correction below. |
| Pending and no-action state | PASS | `evidence_open`, `pending_human_review`, promotion false, trade false |
| Database retrieval time | PASS | Timestamp assigned by table default; caller cannot supply it through RPC |
| Direct table INSERT as `service_role` | PASS | Privilege false; attempted INSERT rejected with SQLSTATE `42501` |
| Invalid ticker rejected | PASS | RPC rejected malformed ticker with SQLSTATE `22023` |
| Edge Function deployment | PASS | Active version 1 on development branch, `verify_jwt=true`, SHA-256 `e80290a60f54450f819b3a6832d0af85d285cc937d7d5f1186ca704cbf214601` |
| Edge Function HTTP invocation/readback | NOT RUN | No Supabase function-invocation tool or intake secret is available in this session; function remains fail-closed |

## Production boundary

No SQL was applied to the canonical project. No production Edge Function was deployed, no production registry row or verification event was added, and no Clarifo packet was written or changed. The sandbox branch and synthetic test row were deleted after verification to stop hourly charges. The branch list now contains only main.

## Next gate

Resolve the canonical schema's Data API/RPC exposure and approved packet handoff. Then repeat the end-to-end check in a faithful development schema before considering any production migration or registry authorization.


## PR #39 collision-handling correction (2026-11-11)

The draft now adds a nullable content_hash column (legacy rows without a hash fail closed), computes SHA-256 in PostgreSQL over the key, adapter version, all envelope metadata, and full packet JSON, and checks every stored field after locking a duplicate-key row. Exact matches return identical; mismatches return conflict; no duplicate updates occur. The Edge Function verifies the complete readback, stored hash, and pending/no-action states. The handoff now requires same-key reconciliation before returning a receipt after uncertain outcomes.

Local Node regression suite: **5 passed** (exact retry, changed JSON/metadata conflict, concurrent same-key model, uncertain-response retry model, and SQL source assertions). These are application/model tests; the concurrent and uncertain-response cases were not executed against PostgreSQL or the HTTP function.

Still unverified: actual SQL migration/function execution after adding content_hash; real concurrent database calls; real Edge Function invocation/readback; Deno type check (dependency fetch blocked by this environment's network restriction). No canonical Supabase writes, deployment, permission change, or merge occurred.
