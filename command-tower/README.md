# Nexus Command Tower

This directory contains the reviewed Command Tower read-only integration artifacts.

## Current state

- Architecture remains frozen.
- PostgreSQL semantic authority is preserved.
- Target: `127.0.0.1:5432`, database `postgres`, schema `nexus`.
- Role: `nexus_command_tower_ro`.
- Eight approved views and eight aggregate summaries were refreshed through the bounded role.
- Migration lineage passed at version `262` with `262` non-empty `sha256` values.
- All eight approved view definitions passed catalog-hash verification.
- No row data export, writes, schema changes, migrations, workflow changes, or trading actions are included.
- The static HTML UI is fixture-compatible and intentionally has no direct browser-to-PostgreSQL connection.
- The local non-writing sandbox package test passed; its receipt is `CommandTower-Sandbox-Test-Receipt.md`.
- The scalar-only status payload contract passed local verification; it is not a live API.
- A loopback-only status endpoint self-test passed; it serves fixture or approved live scalar payloads and rejects write methods.
- The bounded live status adapter passed a fresh read-only refresh through `nexus_command_tower_ro`; it emits eight aggregate summaries with no row export or write capability.
- The loopback status endpoint passed a self-test against the approved live scalar payload; the browser remains disconnected from PostgreSQL.
- When served by the loopback endpoint, `CommandTower.html` hydrates the bounded live scalar panel from `GET /status`; opening the file directly remains fixture-safe.
- Event Ledger Workflow 007 passed a bounded n8n Sandbox run with governed record/readback/idempotent replay; broader activation remains held.
- The Workflow 007 receipt has a Tracker-shaped review projection with no guessed fields, no row key, and no write path.

## Verification entry points

- `Verify-CommandTowerReadOnlyAdapter.ps1`
- `Verify-CommandTowerMigrationAndObjects.ps1`
- `CommandTower-Live-ReadOnly-Binding-Evidence.md`
- `CommandTower-Migration-Object-Verification.md`
- `Invoke-CommandTowerSandboxTest.ps1`
- `CommandTower-Sandbox-Test-Receipt.md`
- `CommandTower-Status-Payload-Contract.md`
- `command-tower-status-payload.json`
- `Verify-CommandTowerStatusPayload.ps1`
- `CommandTower-Status-Payload-Verification.md`
- `Serve-CommandTowerStatus.mjs`
- `Verify-CommandTowerStatusEndpoint.ps1`
- `CommandTower-Status-Endpoint-Verification.md`
- `Invoke-CommandTowerLiveStatusReadOnly.ps1`
- `Verify-CommandTowerLiveStatusAdapter.ps1`
- `CommandTower-Live-Status-Adapter-Verification.md`
- `Verify-CommandTowerLiveStatusEndpoint.ps1`
- `CommandTower-Live-Status-Endpoint-Verification.md`
- `Verify-CommandTowerFreezeContinuity.ps1`
- `CommandTower-Freeze-Continuity-Verification.md`
- `CommandTower-Event-Ledger-Readiness-Review.md`
- `Verify-CommandTowerEventLedgerCandidate.ps1`
- `CommandTower-Event-Ledger-Readiness-Verification.md`
- `CommandTower-Event-Ledger-Sandbox-Run-Receipt.md`
- `CommandTower-Tracker-Event-Projection-Contract.md`
- `command-tower-tracker-event-projection.json`
- `Verify-CommandTowerTrackerEventProjection.ps1`
- `CommandTower-Tracker-Event-Projection-Verification.md`

The adapter remains read-only and promotion-gated. Do not use these artifacts to authorize trades, transfers, deployments, or production promotion.
