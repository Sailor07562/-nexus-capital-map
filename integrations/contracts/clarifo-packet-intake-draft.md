# Clarifo packet intake adapter (draft)

Status: implementation draft only; not registered, deployed, or authorized for canonical writes.

## Verified target contract

Canonical target: `nexus.clarifo_ingestion_packets`.

Required fields: `packet_key` (unique), `adapter_version`, `ticker`, `company_name`, `instrument_type`, `research_lane`, and `packet_json`. Optional fields: `market`, `cik`.

The adapter must always set:
- `evidence_status = evidence_open`
- `review_status = pending_human_review`
- `thesis_promotion_allowed = false`
- `trade_action_allowed = false`

Packet history is append-only. A repeated `packet_key` is an idempotency conflict and must never update an existing row. The current latest-packet view uses newest retrieval time and excludes explicitly superseded rows; the adapter does not supersede older packets.

## Draft implementation boundary

The proposed Edge Function accepts one already assembled Clarifo packet. It does not scrape Clarifo, interpret filings, create evidence adjudications, link thesis cards, or authorize promotion/trading. The caller must provide source citations inside `packet_json`.

Before deployment, verify:
1. Supabase REST exposure for the `nexus` schema and table.
2. A dedicated credential and least-privilege database role limited to packet INSERT and required readback.
3. Database constraints/triggers and required evidence/source structure.
4. Authenticated Clarifo export or an approved operator handoff.
5. Registry entry and verification receipt with canonical write scope expressly approved.

The runtime is intentionally not deployable from this draft alone. Do not add a service-role key to client code, GitHub, workflow files, or Clarifo. Do not deploy until the five checks above are resolved and the registry has been updated through governance.
