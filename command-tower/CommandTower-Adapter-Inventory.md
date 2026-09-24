# Nexus Command Tower — Official Adapter Inventory

Status: **OFFICIAL**  
Inventory date: **2026-09-24**  
Machine-readable registry: `command-tower-adapter-registry.json`  
Semantic authority: **PostgreSQL**

## Scope

This inventory is the authoritative list of Command Tower adapter paths. An adapter is a bounded bridge that reads, projects, executes, receives, or exposes approved state between Nexus authority and a named operational surface.

Google Drive is intentionally excluded from this inventory. Google Drive is part of the **Integration Fabric**: it stores evidence, backups, archives, freeze packages, and recovery references. It is not an adapter, semantic authority, execution surface, or trading surface.

## Official adapter paths

| ID | Adapter | Direction | Source → target | State | Boundary |
|---|---|---|---|---|---|
| `postgres-authority` | PostgreSQL authority | canonical store | n8n / approved functions → `nexus` | `VERIFIED` | PostgreSQL remains semantic authority; no credentials in registry |
| `n8n-sandbox-executor` | n8n Sandbox executor | execution | Workflow 015 / Sandbox → PostgreSQL + bounded Paper endpoint | `ACTIVE · BOUNDED` | Workflow-scoped; Paper-only; no live trading or transfer authority |
| `alpaca-paper-receipt` | Alpaca Paper receipt | receipt intake | Alpaca Paper response → n8n → PostgreSQL | `PAPER-ONLY` | Human approval and current allowlist required; no retry inferred |
| `command-tower-status` | Command Tower live status | read | PostgreSQL approved views → loopback status → Command Tower | `VERIFIED` | `nexus_command_tower_ro`; aggregate-only; writes disabled |
| `ncms-trade-log-projection` | NCMS Trade Log projection | projection | PostgreSQL submission receipts → NCMS Sandbox `Trade Log` | `WIRED · FIRST RECEIPT PENDING` | Target-only upsert by Event ID; PostgreSQL remains canonical |
| `github-provenance` | GitHub provenance | version / review | Repository and PR history → source and governance vault | `VERIFIED` | Reviewable source history; no runtime execution authority |
| `airtable-registry` | Airtable registry | read / registry | Airtable Sandbox metadata → operational registry visibility | `BOUNDED READ` | Metadata/evidence surface; PostgreSQL remains authority |
| `company-evidence-search` | Company Evidence Search | research intake | Official filings, regulators, ISO/RTO, and authorized Drive evidence → Research Radar packet | `DEFINED · READ-ONLY` | No credentials, broker, order, trade, transfer, thesis-promotion, or direct PostgreSQL writes |

## Integration Fabric boundary

| Surface | Classification | Function |
|---|---|---|
| Google Drive | Integration Fabric | Evidence retrieval, backup/archive storage, freeze packages, Last Known Good references, and recovery continuity |

Drive may be a source or destination referenced by an adapter, such as `company-evidence-search`, without becoming an adapter itself.

## Global controls

- PostgreSQL remains semantic authority.
- Command Tower browser access remains aggregate/read-only; no direct browser-to-PostgreSQL connection.
- Alpaca remains Paper-only and human-approval gated.
- n8n remains an executor, not an authority.
- No adapter grants authority to promote a thesis, submit a live order, move funds, or promote to production.
- Credentials are not stored in the inventory.

## Change control

Adding, removing, or reclassifying an adapter requires an updated registry entry, a bounded evidence receipt, and review through the normal GitHub workflow. Reclassifying Google Drive as Integration Fabric does not change database schemas, workflows, credentials, trading controls, or execution authority.
