# Repository Governance

## Authority and system boundaries

1. Production PostgreSQL remains the operational data authority.
2. GitHub is the version-control, provenance, recovery, and change-history
   layer.
3. n8n remains the orchestration and workflow execution layer.
4. Tracker and Airtable remain operational visibility and integration layers.
5. GitHub does not independently acquire authority to modify production
   PostgreSQL or n8n.

## Controlled change

6. Changes are developed on branches or worktrees and reviewed before
   promotion to `main`.
7. Existing production artifacts must be inventoried and sanitized before
   import into this repository.
8. Secrets and credentials are prohibited from Git.
9. Production database dumps are prohibited from Git.

Sanitized, reviewed source artifacts may be versioned when they contain no
secrets, credentials, production dumps, or uncontrolled personal data. Safe
templates must use placeholders and must not contain live values.

## Governing priorities

The following priorities govern design and operation:

- Governance > Automation
- Relational > Blob
- Replay-safe > Fast
- Controlled writes > Direct writes

These priorities apply to migrations, workflow design, research-lane
processing, and tracker integrations. Validation, provenance, and review must
remain possible even when automation is unavailable.

## Doctrine registry

### NDU-20261001-001

| Field | Value |
|---|---|
| Update ID | `NDU-20261001-001` |
| Title | Capability Expansion Governance Doctrine |
| Date | 2026-10-01 |
| Type | `FP`, `AUTHORITY`, `GOVERNANCE`, `LESSON` |
| Status | `ADOPTED` |
| Source | User-directed governance decision in ChatGPT |
| Artifact | [NEXUS_CAPABILITY_EXPANSION_GOVERNANCE_DOCTRINE_20261001.md](NEXUS_CAPABILITY_EXPANSION_GOVERNANCE_DOCTRINE_20261001.md) |
| Summary | Capability expansion triggers governance review before authority expansion. Governance strengthens across Observe → Interpret → Record → Promote → Act. New capability does not imply new authority. |
| Affects | Nexus governance, agent authority, connectors/plugins, adapters, databases, cloud execution, financial connections, payment capabilities, automation, promotion controls, canonical storage, external actions |
| Authority Impact | Restrictive control: requires governance review before newly available capability receives expanded authority. Grants no new execution, trading, payment, transfer, capital, canonical-write, or automatic-promotion authority. |
| Next Action | Apply this doctrine as a required review gate whenever Nexus discovers or receives a materially new capability. |
| Inheritance Note | Future Nexus and replacement agents/components must treat capability discovery as a governance event and inherit the narrowest existing authority until reviewed. |
| Supersedes | None |
| Related Updates | Existing Nexus authority, integration change-control, governance-of-governance, and inheritance doctrines |

Sources: [Drive doctrine](https://drive.google.com/file/d/1D0zBZ0FFArGlsUGBINFfefWJg2j0qiAd/view)
and [Drive registry addendum](https://drive.google.com/file/d/1NKE7_6Xhd-SSkYmEr8PZ-xjtTva2BKc_/view).

`ADOPTED` records the source doctrine's status. Repository promotion still
requires the controlled-change review above. Versioning this entry grants no
new runtime authority and leaves existing trading, transfer, payment, capital,
canonical-write, and automatic-promotion controls unchanged.

## Durable additions and retrieval

User-directed requirement, 2026-10-01. Implementation acceptance requirement;
runtime enforcement is not established by this documentation.

Important additions include material research findings and candidate assessments,
mission decisions and checkpoints, verified capability changes, corrections,
and changed blockers or next actions. Before describing one as embedded in Nexus:

1. Reuse the existing mission/entity identity and record, or create a governed
   record only when none exists. Preserve prior evidence and correction history.
2. Record the finding/change, source references, effective and recorded dates,
   verification state, uncertainty, mission/entity links, next allowed action,
   blockers, and applicable authority boundary.
3. Route writes through the existing authorized writer. PostgreSQL remains
   operational authority; authorized staging must be labeled as staging.
   Adapter projections reference source record IDs and do not become a second
   authority. Store sensitive evidence only in its approved location.
4. Read back the write and verify retrieval by mission ID and relevant entity
   key (for example a ticker). The result must expose evidence and next action
   without depending on conversation memory. Reuse applicable verified receipts;
   repeat a check only for a changed path or concrete gap.
5. Report separately: recorded, readback verified, retrieval verified, and
   canonical promotion if applicable. If a destination or adapter is unavailable,
   record the pending handoff in authorized staging and disclose the blocker;
   do not claim embedding, synchronization, or completion.

Session continuation starts by retrieving the relevant existing mission record.
An empty search or inaccessible source does not establish that a record is absent.
Chat acknowledgments, tags, screenshots, and carryovers can be evidence, but alone
do not prove admission into Nexus or successful retrieval.

### Mission retrieval adapter contract

Assess existing adapter coverage before registering another adapter. The required
bounded read capability accepts a mission ID or entity key and returns matching
record IDs, source location, finding/status, evidence references, verification
time/freshness, next allowed action, and blockers. It preserves multiple matches,
conflicts, missing-source coverage, and staging versus canonical distinctions.

Use approved views or an authorized service; do not expose a general SQL endpoint.
Retrieval grants no write, thesis-promotion, trading, or execution authority.
A separate adapter is warranted only if existing adapters cannot satisfy this
contract within their boundaries. Register its source/target, owner/writer
dependency, authorization, failure behavior, and evidence receipt through normal
review before calling it operational.
