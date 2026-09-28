# B-002 — Authenticated PostgreSQL Verification

Status: AUTHORIZED IMPLEMENTATION

## Purpose

Extend `GET /api/live-status` with a bounded PostgreSQL identity check that
proves the Command Tower can authenticate as `nexus_command_tower_ro`.

## Verification contract

- The app invokes the local `psql` client as `nexus_command_tower_ro`.
- The only SQL sent by this check is:

  ```sql
  SELECT current_user, current_database();
  ```

- PostgreSQL is `B-002 VERIFIED` only when authentication succeeds and the
  returned `current_user` is exactly `nexus_command_tower_ro`.
- Credentials are read from the local ignored environment and never returned
  in the status payload or logs.

## Boundaries

- No SQL writes, DDL, migrations, or privilege changes.
- No n8n mutation, broker action, trade, or transfer.
- A missing credential or host is `blocked`; authentication/query failure is
  `failed`.
