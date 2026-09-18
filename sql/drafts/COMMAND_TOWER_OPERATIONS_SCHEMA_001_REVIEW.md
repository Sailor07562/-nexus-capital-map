# Command Tower Operations Schema Draft 001 — Review Gate

Anchor: #ANCHOR-NEXUS-COMMAND-TOWER-OPERATIONS-SCHEMA-001

Status: SAFE-HOLD / REQUIRES DISCOVERY

## Draft Scope

The paired SQL draft defines an isolated `operations` schema for the Command
Tower Kernel. It does not rename, replace, or assign a version to any existing
Nexus migration. It deliberately excludes views, privileges, triggers, event
immutability enforcement, integrations, and all live execution.

## Required Before Sandbox Test

- Verify the exact database identity and PostgreSQL version.
- Read `nexus.schema_migrations` to reconcile migration lineage; no inference
  from historical labels or current-candidate artifacts.
- Read schema ownership and required roles/grants.
- Capture a Last Known Good backup/checkpoint and restoration reference.
- Map dependencies against existing Nexus, Tracker, Room Registry, and
  `nexus_constitution` objects.
- Record an approved sandbox target and rollback plan.

## Required Before Any Promotion

Follow `DISCOVER → FREEZE → MAP → CHANGE → TEST → VERIFY → PROMOTE`, then the
Command Tower promotion protocol. A sandbox result is not production approval.

