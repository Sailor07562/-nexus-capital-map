# Private sandbox readiness reader

Scope: an authenticated **database-session reader**, not an Edge Function,
public RPC, mobile endpoint, kernel dispatcher, or execution gate.

The owner approved this sandbox-only reader on 2026-10-11. It uses the existing
authenticated cloud management connection, then explicitly switches to the
non-login `nexus_kernel_sandbox_ro` role inside a read-only transaction. No
password, API key, browser session, new service, or production connection is
introduced. The management connection itself remains administrative: this
reader does not sandbox arbitrary SQL sent through that separate connection.

## Boundary

- One private `SECURITY INVOKER` / `STABLE` function, empty search path.
- One non-login role with no superuser, role creation, database creation,
  replication, RLS bypass, or inherited elevated role.
- Column-level SELECT on seven existing sandbox control/metadata tables,
  with role-specific SELECT-only RLS policies. No research payload columns.
- Singleton policies select the existing environment, control and contract
  keys; the four lane tables expose only identifiers/safety fields for counts.
- No grant to `anon`, `authenticated`, `authenticator`, `service_role`, or
  `PUBLIC`. No API schema exposure. Only the existing administrative `postgres`
  session receives explicit, non-inherited membership in the new reader role.
- No table creation, business-record insert/update/delete, lane population,
  canonical write, federation activation, automatic promotion or trading.
- Caller must explicitly assume the reader role and use a read-only
  transaction. An administrative direct call is deliberately rejected.

The function reports a successful **read** separately from operational readiness.
It always reports `kernel_integration_status=HOLD`, `execution_authorized=false`
and `production_verified=false`. It does not authenticate a kernel packet,
establish authoritative lane/profile bindings, validate an investment, or call
the Python gate. That later adapter remains a separate blocked integration.

`captured_at` is the database observation time, not refreshed source evidence.
The stored control observation time is returned separately. Empty counts are
not completed lanes; an empty safety count is not a populated federation.

## Use and verification

Run `read.sql` through the connected Supabase SQL tool against the verified
existing sandbox project only. Do not submit this reader's DDL to the live
project. The migration also rejects a non-sandbox environment.

`verify.sql` checks the installed role, grants, policies and function. Native
database denial tests additionally verify wrong roles, non-read-only invocation,
forbidden columns, existing mutating functions and no-op DML. Source regression
tests are not substitutes for these database tests.

`denial-cases.json` records the native negative cases. Run each in a separate
transaction, assume its stated role, execute its fixed statement and ROLLBACK.
Expect the exact PostgreSQL SQLSTATE, not merely any error. The DML cases use
`WHERE false` so even an unexpected permission regression cannot change records.
Database-role tests do not prove JWT, browser-session or HTTP authentication.

The migration file is generated with pinned Supabase CLI 2.120.0. Deployment
uses the authenticated migration tool, not a copied credential or a CLI login.
The additive migration is sandbox-only; it does not promote PR source to main.

`rollback.sql` removes only this reader's function, policies, grants and role.
It uses no CASCADE, DROP OWNED, table deletion or business-record mutation.
Rehearse it in a transaction and ROLLBACK; do not commit a rollback without
appropriate scope. Concurrent/new dependencies must fail visibly.

The existing federation HOLD and missing canonical mappings remain unchanged.
