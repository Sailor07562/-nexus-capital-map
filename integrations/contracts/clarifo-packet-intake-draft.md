# Clarifo packet intake adapter (draft)

Status: reviewable design and database primitive draft only; not registered, deployed, or authorized for canonical writes.

## Nexus connection

Active project: Nexus Capital Map #DOT #SLK, ID `e0c55e0c-8910-42e2-bc81-eaf82ebe6b27`. Canonical system: Nexus/Supabase. The active relationship to NEXUS COMMAND TOWER assigns capital research to this project and routing, approvals, and execution status to Command Tower.

## Verified target contract

Canonical target: `nexus.clarifo_ingestion_packets`. The live table has a unique `packet_key`, requires the packet metadata and JSON fields, and defaults review to pending.

The live registry currently contains only `supabase_sandbox`; it has no canonical write authority. The Clarifo packet table has RLS enabled with a read-only policy for Command Tower. Database grants show `service_role` has SELECT but not INSERT. The live Edge Function list contains no Clarifo function. Direct PostgREST insertion by the current service role is therefore not an authorized or available write path.

Required packet state:
- `evidence_status = evidence_open`
- `review_status = pending_human_review`
- `thesis_promotion_allowed = false`
- `trade_action_allowed = false`

Packet history is append-only. A repeated `packet_key` must never update an existing row. The latest-packet view uses retrieval time and excludes explicitly superseded rows; this adapter does not supersede older packets. The database assigns the retrieval timestamp so a caller cannot backdate or future-date a packet. Source-period dates belong inside the cited packet evidence.

## Proposed bounded write path

The SQL draft adds one SECURITY DEFINER function with an empty search path and fully qualified table references. It validates required fields, writes one packet row with the fixed pending/no-action states, handles duplicate keys without updating, and grants EXECUTE only to `service_role`. It does not grant table-level INSERT to API roles.

This is a privileged database boundary and remains an unapplied draft. Before any application:
1. Have the function reviewed against the complete live constraints, triggers, ownership, and migration lineage.
2. Verify the `nexus` schema is exposed for RPC or define an approved invocation route.
3. Establish a separate Edge Function credential boundary and authenticate an approved packet handoff.
4. Define source-evidence structure and whether a packet-only append is sufficient; this draft does not populate normalized evidence or financial-fact tables.
5. Add a registry entry and verification receipt explicitly authorizing only this append operation.

The proposed Edge Function accepts one already assembled Clarifo packet. It does not scrape Clarifo, interpret filings, create evidence adjudications, link thesis cards, supersede prior packets, or authorize promotion/trading. Do not put a service-role key in client code, GitHub, workflow files, or Clarifo. Production records and workflows remain untouched by this branch.
