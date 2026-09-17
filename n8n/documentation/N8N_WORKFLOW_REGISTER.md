# Nexus n8n Workflow Register

This register covers four exact local artifacts preserved as
`LOCAL-CANONICAL-CANDIDATE`. Live status is `UNVERIFIED` for every entry.
Artifact state is historical/local evidence only.

| Workflow | Repository file | Raw SHA-256 | Structural fingerprint | Artifact state | Sensitive classification | Pin data |
|---|---|---|---|---|---|---|
| POWL 012 — SEC Controlled Intake | `NEXUS-N8N-CAPITAL-MAP-012-POWL-SEC-Controlled-Intake.json` | `e3ffdbbd6433d3cfb06cf4753db5f286e93bbf3b72eeec377f92568432f4fbee` | `159b1d13d5d9c53cb2352d179da99b12d8b017038cce86f6d024a06f989f99f5` | Active in artifact | Credential-reference-only; no confirmed secret value | Empty |
| Review Console 013 — Authenticated Human Review Console | `NEXUS-N8N-CAPITAL-MAP-013-Authenticated-Human-Review-Console.json` | `5ee0cd27b440e14dd251694ae45138ca9f2dde61014ebfe10b6b4801b7ac55e5` | `6baa75a386bd439fe9fb4619a5cc7ab08f4bba96a1498c65483ecce8d6761009` | Inactive in artifact | Credential-reference-only; no confirmed secret value | Empty |
| XLP 014 — Official Holdings Intake | `NEXUS-N8N-CAPITAL-MAP-014-XLP-Official-Holdings-Intake.json` | `fb1a8f69ca598d69927d6ed7e151e85963431f8aa3ce229f917aea11b6a3a5d7` | `1bb02251c6b9c6436e14cd59cf6459594a4110a6cb106ae5e3d4ac160dadc49b` | Active in artifact | Credential-reference-only; no confirmed secret value | Empty |
| Event Ledger 007 — Orchestration | `NEXUS-N8N-WORKFLOW-007-EVENT-LEDGER-ORCHESTRATION.json` | `41320e311a4a18eb6163a4db1b38374c7c400c16bc923b98c17339d3bea3f800` | `4491b2482209a2cf79fe6a10cb132a37f238ebe9e809df31246349963410e506` | Inactive in artifact | Operational metadata; no confirmed credential reference or secret value | Empty |

These files retain workflow IDs, settings, node positions, credential-reference
objects, and other raw export metadata. No test/sandbox variants, historical
containers, encrypted credential exports, or Make blueprints are included.
