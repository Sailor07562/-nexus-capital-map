# Command Tower Integration Mapping Contract

Status: review-ready, read-only contract

Captured: 2026-09-18

This contract records the mapping boundary discovered from live metadata and bounded reads. It does not authorize writes, promotion, schema changes, or live capital action.

## Authority map

| Surface | Verified identity | Command Tower role | Semantic authority | Current state |
|---|---|---|---|---|
| PostgreSQL | `127.0.0.1:5432` / `postgres` / `nexus` | Canonical relational read source | PostgreSQL | Bounded view and aggregate fixture readback passed; live UI binding intentionally disabled |
| Airtable | `LB Nexus_Sandbox_v1` / `appl14dXK5cUtvZt8` | Structured registry and evidence surface | PostgreSQL remains authority | Metadata verified; 73 tables; no live binding |
| Tracker Sandbox | `Nexus_Registry_v1 — TRACKER SANDBOX COPY — 2026-07-09` / `1czF0GkfnILFA1w-jEtFa7VyGjbGKpc0RPFV32S3_irY` | Operational visibility and controlled test surface | PostgreSQL remains authority | 53 tabs; bounded reads verified; no write path |
| GitHub | `Sailor07562/-nexus-capital-map` | Versioned source and governance vault | Git history for source only | Remote push/readback remains unverified |
| n8n / Docker | Sandbox `localhost:5678`; Production `localhost:5680` | Workflow execution surface | PostgreSQL and governance gates remain authority | Hold; no workflow change |

## Bounded field and tab mapping

### Airtable sandbox

The following fields are display/readback candidates only:

| Airtable table | Fields | Command Tower use |
|---|---|---|
| `Dashboard_Status` | `Domain`, `Status`, `Severity`, `Last_Review`, `Notes`, `Status_ENUM`, `Severity_ENUM` | Surface health and attention summaries |
| `Governance_Command_Center` | `Command_ID`, `Command_Name`, `Governance_Domain`, `Infrastructure_Layer`, `Command_Status`, `Update_Priority`, `Permission_Gate`, `Speculation_Temperature` | Governance queue and permission state |
| `Airtable_Readback_Seal_Log` | `Readback_ID`, `Readback_Title`, `Verified_Object_Type`, `Verified_Object_Name`, `Verification_Action`, `Verification_Status` | Evidence/readback status |
| `Validation_Log` | `Validation_ID`, `Source`, `Target`, `Status`, `Outcome`, `Review_Date`, `Notes` | Validation history |
| `Nexus_Test_Intake` | `Signal_Title`, `Source_URL`, `Raw_Status`, `Intake_Method`, `Test_Notes` | Sandbox intake test visibility only |

These fields are not investment authority, evidence-admission authority, deployment authority, or trading authority.

### Tracker Sandbox

The exact visible tabs and bounded reads currently verified are:

| Tab | Verified read | Command Tower use |
|---|---|---|
| `Index` | Header plus active status-rule rows | Registry index and vocabulary health |
| `Authority` | Exact header structure | Authority-map reference; no inferred rows |
| `Test Log` | Bounded test history, including readback and blocked-gate outcomes | Evidence and continuity queue |

The remaining tabs are discoverable metadata, not automatically bindable data. Each future tab requires an exact header/range read before inclusion.

## Adapter envelope

Every future read-only adapter record must carry:

```text
surface_id
surface_type
observed_at
identity
authority
state
source_reference
field_or_tab_reference
readback_status
promotion_status
write_capability = false
```

The adapter must preserve `write_capability = false` until a separately approved implementation changes that boundary.

## Hard rules

1. PostgreSQL remains the semantic authority.
2. Airtable remains sandbox registry/evidence infrastructure.
3. Tracker remains operational visibility/test infrastructure.
4. No guessed tabs, fields, IDs, or ranges.
5. No Airtable or Sheets writes from the Command Tower adapter.
6. No adapter binding through the current PostgreSQL superuser.
7. No promotion claim without evidence readback and human approval.
8. No architecture amendment is implied by this mapping contract.

## Open gates

- Approve and create the bounded PostgreSQL role through the secure local credential path.
- Read back the role privileges and transaction mode. **Passed.**
- Read back the approved existing Nexus views. **Passed: 8 of 8 present with rows.**
- Review the mapping contract against the existing Nexus Integration Contract v1.
- Keep the fixture-backed scalar summaries bounded; any future live adapter requires a separate implementation review and re-verification.


