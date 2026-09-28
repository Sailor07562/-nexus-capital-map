# Command Tower Checkpoint — B-002 Restored

Date: 2026-09-27

Checkpoint ID: `CT-B002-RESTORED-20260927`

Base anchor: `CT-RESTORE-V6-20260927`

Implementation commit: `6a92d43c16ba6e71160f2f1bc71f25f5897ce710`

## Restored behavior

`GET /api/live-status` now verifies PostgreSQL only by invoking the local
`psql` client as `nexus_command_tower_ro` and executing exactly:

```sql
SELECT current_user, current_database();
```

The Command Tower UI labels the surface B-002 and reports PostgreSQL as
`B-002 VERIFIED` only when the authenticated query succeeds and returns
`current_user=nexus_command_tower_ro`.

## Verification receipt

Endpoint: `http://127.0.0.1:8080/api/live-status`

Observed response:

```text
contract: B-002 authenticated read-only PostgreSQL verification
PostgreSQL state: verified
summary: B-002 VERIFIED: authenticated as nexus_command_tower_ro and read-only identity query succeeded.
evidence: current_user=nexus_command_tower_ro; current_database=postgres; query=SELECT current_user, current_database();
```

Static checks passed:

- JavaScript syntax checks for `app/config.js`, `app/live-status.js`,
  `app/server.js`, and `frontend/app.js`.
- `git diff --check` before commit.

## Boundaries confirmed

- No SQL writes, DDL, migrations, or privilege changes were performed.
- No n8n mutation or broker action was performed.
- The PostgreSQL status path does not expose the local credential in the
  response or logs.
- B-001 TCP-only PostgreSQL behavior is retained only as historical protocol
  documentation; B-002 is the active contract.
