# Nexus Command Tower — Source Path Map

**Record date:** 2026-09-19  
**Repository:** Sailor07562/-nexus-capital-map  
**Status:** ACTIVE / GOVERNED

## Purpose

Define the canonical source paths used by Nexus Command Tower so operational components are distinguishable from source-of-truth systems, sandboxes, backups, and execution layers.

## Source Path Map

| Component | Role | Canonical Path / System | Authority |
|---|---|---|---|
| GitHub | Versioned code, SQL, governance docs, engine/lane files, handoffs | `Sailor07562/-nexus-capital-map` | Governed source repository |
| PostgreSQL | Relational operational state and Capital Map data | Nexus PostgreSQL environment | Database source of truth for implemented relational state |
| n8n | Workflow orchestration and governed automation | Nexus n8n environment | Execution/orchestration layer |
| Airtable — Nexus_Sandbox_v1 | Operational Airtable sandbox | `Nexus_Sandbox_v1` | Operational Airtable |
| Airtable — LB Operations Tracker | LB autonomous operations logging/tracking | `LB Operations Tracker` | LB operations tracker |
| Tracker / Sheets | Nexus Capital Tracker sandbox and operational tracking | Nexus Tracker ecosystem | Tracking / sandbox layer |
| Google Drive | Freeze-point backups and retained packages | Nexus backup folders | Backup / retention layer |
| Command Tower | Cross-system operating view | `command-tower/` in GitHub plus connected operational systems | Coordination layer |

## Operating Doctrine

1. Governance precedes automation.
2. GitHub does not replace PostgreSQL, Airtable, Tracker, n8n, or Drive; it consolidates versioned source artifacts.
3. Database changes are considered executed only after live capability verification and successful execution.
4. Sandbox and production identities must remain explicit.
5. Major changes require a freeze point and backup.
6. Command Tower coordinates the ecosystem; it does not silently redefine source-of-truth ownership.

## Verification

This file was written as the GitHub write-access retest after reconnecting the ChatGPT GitHub integration. The prior blocker was `403 Resource not accessible by integration`.

Target operation log: `CT-OPS-20260919-003`.
