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

## Durable records and mission retrieval

Important findings, mission checkpoints, and capability changes follow the
[durable additions and retrieval requirement](../docs/governance/REPOSITORY_GOVERNANCE.md#durable-additions-and-retrieval).
Each applicable adapter must identify its authoritative source record, authorized
writer or staging handoff, and readback/retrieval evidence. A read-only adapter
does not gain write authority from this requirement.

Mission/entity retrieval is a required coverage assessment, not a newly active
adapter. Evaluate existing paths against the linked mission retrieval contract
before adding a registry entry. Preserve the aggregate-only status boundary;
detailed evidence retrieval needs a separately authorized read path where that
boundary cannot support it. No adapter state in this inventory is upgraded by
this documentation.

### Coverage assessment — 2026-10-01

Scope: repository contracts and checked-in reader at main commit
`633acf54a46491678c2780770f15e3e85efbfd58`, plus the MOS-005 architecture
document. This is not a live database or deployed-adapter census.

| Existing path | Evidence | Mission retrieval coverage |
|---|---|---|
| Company Evidence Search | [Machine registry](command-tower-adapter-registry.json), research intake sources and Research Radar packet target | Source discovery; no documented canonical mission-ID/entity lookup |
| Command Tower live status | [Status contract](CommandTower-Status-Payload-Contract.md) and [reader](Invoke-CommandTowerLiveStatusReadOnly.ps1) | Scalar aggregate queries over eight approved views; no mission lookup parameter or detailed finding/evidence response |
| NCMS Trade Log projection | Machine registry, submission-receipt target-only upsert | Trade receipt projection; not general mission retrieval |
| Airtable registry / GitHub provenance | Machine registry, metadata and version-history boundaries | Supporting lineage; not canonical PostgreSQL mission retrieval |
| PostgreSQL authority / n8n / Paper receipts | Machine registry, canonical-store and bounded execution/intake roles | Source or writer dependencies, not a documented consumer mission-retrieval interface |

[MOS-005 Read-First Architecture](https://docs.google.com/document/d/1OZXpBYOxZTSD5qNd-tvZz9mIDL21XjiPdjWrM8-uI4c/edit)
already designs missions, packets, receipts, verifications, links, and read views.
The retrieved September 24 document is a draft, not current deployment evidence.
Later implementation reports must be checked against the execution receipt and
live schema; do not rerun its draft migration or create a parallel mission store.

**Recommendation:** reuse the existing Mission Registry and add a distinct,
bounded mission-retrieval interface if deployed coverage is absent. Do not widen
the aggregate-only status contract or misclassify external research intake as
canonical mission retrieval. A separate logical adapter can reuse existing
service infrastructure; it need not be another server.

**Next implementation gate:** inspect the latest MOS-005 execution receipt,
deployed mission/entity relationships, available approved read views and reader
grants. Identify the exact source fields for findings, evidence, verification,
next action and blockers. Then bind the retrieval contract to those actual
objects using parameterized, bounded reads. Until that inspection, schema names,
routes, role grants, and a new official registry entry remain unspecified.

**GEV acceptance case:** query by GEV, preserve all linked mission matches, and
retrieve the reported candidate assessment with its actual evidence and next
action if present. Do not substitute older watchlist records for the assessment.
An empty or incomplete result must report source coverage and unresolved state,
not declare the mission absent. Verify a retrieved mission again by its returned
ID. Existing completed engine tests do not need to be repeated.

**Persistence dependency:** retrieval cannot repair an addition that was never
recorded. The existing authorized mission writer must supply the durable record
and receipt; the retrieval interface remains read-only.

Assessment outcome: documented coverage gap; separate retrieval interface
recommended, deployed coverage and live GEV recovery unverified. Official adapter
count and all runtime states remain unchanged.
