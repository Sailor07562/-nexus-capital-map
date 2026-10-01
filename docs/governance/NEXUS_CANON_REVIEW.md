# Nexus Canon Review

Status: review candidate; not merged or promoted.

Basis: `origin/main` at `d7193d55d0f1e5b0ca71b9e43926d2c5aa8e747d`.

This branch adds the Foundation and Engine canon as governed documentation. The
documents preserve the repository boundaries: PostgreSQL remains semantic
authority, n8n remains executor, Command Tower remains read-only cockpit, human
authority remains the action boundary, and live trading/capital movement remain
disabled by default.

The Capital Deployment Engine remains `distributed_control`; this change does
not create standalone deployment authority. The documents contain no secrets,
production dumps, raw exports, broker credentials, or executable trade path.

Review gates:

- verify document ownership and destination under `docs/governance/`;
- compare wording against current Foundation, Engine, and repository doctrine;
- confirm no promotion of candidate or distributed-control engines is implied;
- merge only after explicit repository review.
