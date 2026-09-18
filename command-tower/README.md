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

The adapter remains read-only and promotion-gated. Do not use these artifacts to authorize trades, transfers, deployments, or production promotion.
