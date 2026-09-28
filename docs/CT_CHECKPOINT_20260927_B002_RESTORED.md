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

## Header identity restored

The Command Tower header includes the restored Nexus Tree emblem, landscape
backdrop, and glowing North Star marker. These assets are part of the checked-in
frontend surface:

- `frontend/assets/nexus-tree-emblem-v1.png`
- `frontend/assets/command-tower-nexus-landscape-v1.png`

The Tree and North Star belong in the header identity treatment. Do not move
them into a separate dashboard card during a future restore.

## Future restore runbook

Use this section if the Command Tower regresses to B-001 or loses its
PostgreSQL verification again.

1. Preserve the current checkout first. If it contains uncommitted work, stop
   and save that work before restoring.
2. Return to the known-good checkpoint:

   ```powershell
   git switch --detach CT-B002-RESTORED-20260927
   git show -s --format='%H %D %s' CT-B002-RESTORED-20260927
   ```

   The restored source must contain the B-002 contract and
   `nexus_command_tower_ro` role check. Do not rebuild the verification from
   the older B-001 TCP-only implementation.
3. Confirm the local ignored `.env` provides the connection settings without
   printing or committing the password:
   `NEXUS_POSTGRES_HOST`, `NEXUS_POSTGRES_PORT`,
   `NEXUS_POSTGRES_DATABASE`, `NEXUS_POSTGRES_PASSWORD`, and `NEXUS_PSQL_PATH`.
4. Start the app using the local environment:

   ```powershell
   node --env-file=.env app/server.js
   ```

5. Open `http://127.0.0.1:8080/api/live-status` and accept PostgreSQL as
   restored only when all of these are true:

   - `contract` is `B-002 authenticated read-only PostgreSQL verification`.
   - PostgreSQL `state` is `verified`.
   - The evidence reports `current_user=nexus_command_tower_ro`.
   - The evidence reports the exact query
     `SELECT current_user, current_database();`.
6. If the result is `blocked` or `failed`, stop. Do not fall back to TCP-only
   proof, change passwords or privileges, edit `pg_hba.conf`, run migrations,
   mutate n8n, or call a broker.
7. Record the dated endpoint result in a new checkpoint receipt and commit it.
   Keep this checkpoint tag as the restore anchor unless a later verified
   checkpoint is explicitly created.
