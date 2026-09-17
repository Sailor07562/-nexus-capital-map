# Field Authority Matrix

This matrix is **NEW-v1** governance unless explicitly marked **EVIDENCE-BACKED**. It defines permitted roles, not proof of current live implementation.

| Field/domain | PostgreSQL | n8n | Make | Tracker | Airtable |
|---|---|---|---|---|---|
| Canonical `event_id` | AUTHORITATIVE | DERIVED/PASS-THROUGH | DERIVED/PASS-THROUGH | DISPLAY/PROJECTION | DISPLAY/PROJECTION |
| Source identifiers | AUTHORITATIVE after acceptance | INPUT/PASS-THROUGH | INPUT/PASS-THROUGH | DISPLAY/PROJECTION | INPUT for review |
| Event timestamps | AUTHORITATIVE | INPUT/DERIVED | INPUT/DERIVED | DISPLAY/PROJECTION | DISPLAY/PROJECTION |
| Processing status | AUTHORITATIVE | DERIVED execution state | DERIVED execution outcome | DISPLAY/PROJECTION | DISPLAY/PROJECTION |
| Review decision | AUTHORITATIVE after approval | ORCHESTRATION only | NO-WRITE | INPUT/DISPLAY | INPUT pending approval |
| Reconciliation status | AUTHORITATIVE | DERIVED/reporting | NO-WRITE | DISPLAY/PROJECTION | DISPLAY/PROJECTION |
| Confidence | AUTHORITATIVE after verification | CALCULATION/PASS-THROUGH | DERIVED legacy value | DISPLAY/PROJECTION | INPUT pending approval |
| Error state | AUTHORITATIVE | DERIVED/reporting | DERIVED execution outcome | DISPLAY/PROJECTION | DISPLAY/PROJECTION |
| Tracker row/key | AUTHORITATIVE mapping reference | DERIVED | INPUT/integration | DISPLAY/PROJECTION | NO-WRITE |
| Airtable record key | AUTHORITATIVE mapping reference | DERIVED | INPUT/integration | NO-WRITE | DISPLAY/PROJECTION |
| Raw evidence reference | AUTHORITATIVE provenance | INPUT/PASS-THROUGH | INPUT/PASS-THROUGH | DISPLAY/PROJECTION | DISPLAY/PROJECTION |
| Execution metadata | Stored when approved | AUTHORITATIVE for n8n execution | AUTHORITATIVE for Make execution | NO-WRITE | NO-WRITE |
| Credentials and secrets | NO-WRITE | NO-WRITE to payloads | NO-WRITE to payloads | NO-WRITE | NO-WRITE |

`AUTHORITATIVE`, `DERIVED`, `DISPLAY/PROJECTION`, `INPUT`, and `NO-WRITE` are contract roles. Tracker and Airtable inputs must pass through validation and approval before PostgreSQL acceptance.

Actual field names, keys, and current implementation remain **TBD-LIVE-VERIFICATION**.
