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

### NDU-20261001-002

| Field | Value |
|---|---|
| Update ID | `NDU-20261001-002` |
| Title | Investment Analysis Doctrine — Stock Review Standard |
| Date | 2026-10-01 |
| Type | `RESEARCH`, `GOVERNANCE`, `WORKFLOW` |
| Status | `ADOPTED` — user-directed research standard |
| Source | User-directed stock-analysis framework discussion and instruction to add it to Nexus |
| Artifact | [NEXUS_INVESTMENT_ANALYSIS_DOCTRINE_20261001.md](NEXUS_INVESTMENT_ANALYSIS_DOCTRINE_20261001.md) |
| Summary | Every stock review uses company-specific financial evidence, multiquarter trends, primary sources, cash generation, financial strength, per-share outcomes, and valuation. Backlog, book-to-bill, and data-center demand apply where relevant. |
| Affects | Individual-stock research, thesis reviews, review templates, and documented stock-review workflow |
| Authority Impact | Research-documentation requirement only; preserves PostgreSQL operational authority and all existing trading, broker, capital, and promotion controls. |
| Next Action | Open the doctrine at the start of a stock review and complete its evidence record and reusable checklist before finalizing the conclusion. |
| Inheritance Note | Future Nexus stock-review templates and agents should inherit this standard. Runtime loading/enforcement requires separate implementation and verification. |
| Supersedes | None |
| Related Updates | `NDU-20261001-001`; existing source-verification and investment-review controls |

### NDU-20261002-001

| Field | Value |
|---|---|
| Update ID | `NDU-20261002-001` |
| Title | Supabase First Architecture Transition |
| Date | 2026-10-02 |
| Status | `APPROVED_TARGET`; implementation `CUTOVER_PENDING` |
| Source | Owner-approved architecture decision and authenticated remote verification |
| Artifact | [NEXUS_SUPABASE_FIRST_ARCHITECTURE_TRANSITION_20261002.md](NEXUS_SUPABASE_FIRST_ARCHITECTURE_TRANSITION_20261002.md) |
| Summary | Selects remote Supabase as the future primary operating database; retains GitHub for versioned source, Drive for evidence and recovery, and a verified future testing/recovery role for local PostgreSQL. |
| Authority Impact | Authorizes transition preparation; existing deployed authority and gateway contracts remain pending verified cutover. Adds no broker, trading, transfer, payment, capital or automatic-promotion permission. |
| Next Action | Map ownership, verify independent recovery, reconcile local-only records when the laptop is available, and align contracts before cutover. |
| Supersedes | None at this transition stage |

[Remote decision and verification receipt](https://drive.google.com/file/d/1-xQWdJy8Sz6dJndH1gRNzG0e65Apno5A/view?usp=drivesdk).
