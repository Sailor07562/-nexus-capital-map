# Reconciler run adjudication: review and sandbox evidence

Mission: `NEXUS-CT-RECONCILER-ADJUDICATION-20261023-001`.
Scope: build and disposable sandbox validation only. No deployment or trading authority.

## Source custody

- Canonical repository: `Sailor07562/-nexus-capital-map`.
- Main baseline: `06c7a072dae2dc2e5abf4111ceeb2abaae8080aa`.
- Feature branch: `feat/ct-reconciler-adjudication-20261023`.
- Read-only production catalog source: Supabase project `husnmxgsxasoinhklpfx`,
  PostgreSQL 17.6. Registered head observed:
  `20261011094020_ct_policy_driven_symbol_growth_20261011`.
- Generated with Supabase CLI 2.122.0:
  `supabase migration new ct_reconciler_run_adjudication_20261023`.
- New migration:
  `20261023165658_ct_reconciler_run_adjudication_20261023.sql`.
  This is the timestamped Supabase lineage, not PostgreSQL migration 125.

`baseline_catalog.json` contains schema definitions and ACL metadata, no production
rows. `baseline.sql` copies the original event relation, writer, health view and
runtime function, with reduced synthetic dependencies. Its generator and separately
captured runtime definition make that boundary inspectable. This does not recreate
the entire Supabase migration history, REST gateway, Edge Functions, broker or CT UI.
The September recovery branch and original Drive backup are not inputs to this build.

## Added and changed objects

All objects are in `nexus_live_trading`:

- New table `reconciler_run_adjudications`: UUID primary key, unique run ID,
  generated fixed `started_event_type`, bounded disposition/reason/evidence/human
  actor, copied `started_at`, server-assigned adjudication/recording times and
  authenticated database `recorded_by`. The FK targets existing `(run_id,event_type)`.
- New trigger function `validate_reconciler_run_adjudication()` and BEFORE INSERT
  trigger `reconciler_run_adjudications_validate`.
- New statement trigger `reconciler_run_adjudications_append_only` rejects UPDATE,
  DELETE and TRUNCATE using the unchanged existing rejection function.
- New controlled interface
  `adjudicate_reconciler_run(uuid,text,text,jsonb,text) RETURNS uuid`.
- Existing `v_reconciler_health`: the stale-start count gains an exclusion for
  an explicit `abandoned` adjudication. Column names/types, the two-minute cutoff,
  other counts, ordering, observations, ACL and `security_invoker=true` stay intact.

No existing writer, runtime function, event constraint, role membership, trading
gate, or historical migration is changed. No event or adjudication row is inserted
by the migration. The new table's primary/unique indexes are the only new indexes.

## Controlled interface and validation

Parameters, in order: run UUID, disposition, reason, structured evidence, claimed
human actor. Only `abandoned` is accepted. Reason must be trimmed, 16–2048 characters.
Evidence must be a JSON object of at most 16,384 bytes with a string `reference`
whose trimmed length is 8–512 characters; optional additional fields remain within
that total bound. References/evidence must contain no credentials. Actor must match
`^[A-Za-z0-9][A-Za-z0-9_.:@/-]{2,127}$`. The human actor is a claim made by the trusted
administrator; `recorded_by=session_user` identifies the database session.

The VOLATILE insert validator requires READ COMMITTED, then obtains SHARE ROW
EXCLUSIVE on the event table with NOWAIT before reading. This conflicts with an
event writer's INSERT lock without altering its code. A missing start, any existing
finish, or a start not strictly older than two minutes is rejected. The statement
timestamp matches the view's cutoff; long statements reject conservatively.
Server audit fields override caller values. The FK and constraints provide
additional integrity checks. A genuine late finish can still append afterward.

Use a short, one-statement administrative transaction. The lock covers the entire
event table until transaction end; never leave an adjudication transaction open.
No retry loop, automatic recovery worker, scheduler, public RPC, or service-role
execution grant is introduced. Each eventual adjudication needs its own governed
evidence and scoped authority. This build supplies no production invocation.

| Outcome | SQLSTATE / posture |
|---|---|
| Accepted | New UUID; one immutable adjudication |
| Duplicate run | `23505`; safe rejection, original receipt unchanged |
| Missing start, finished run, recent start | `22023` |
| Invalid bounded field | `23514` or `23502` |
| Active event writer/adjudicator | `55P03`; no row accepted |
| Repeatable Read / Serializable | `25001` |
| Attempt to mutate append-only rows | `55000` |
| Ordinary caller | `42501` |

Table and function ownership stays `postgres`; API roles and PUBLIC receive no
privileges. RLS is enabled with no policies. Both new functions are SECURITY INVOKER
with a fixed `pg_catalog` search path. A final ACL assertion rejects unexpected
custom default grants. Privileged owners/admins remain a trust boundary; RLS does
not protect against an administrator deliberately disabling enforcement.

## Migration replay and drift

The file is an explicit transaction with bounded DDL lock/statement timeouts. It
requires the existing owner-only health read path and its exact catalog definition.
Use LF source and a byte-preserving SQL transport. Changed baseline definitions
fail with `55000`; an already installed table fails with `42710`. The migration
does not use IF NOT EXISTS to conceal drift or modify the migration ledger itself.
Normal deployment tooling must own the ledger in a separately authorized mission.
Tests force an error at the final ACL check and verify all preceding DDL/view edits
roll back. Replaying an installed migration rejects without changing data or schema.

## Running the disposable validation

Prerequisite: a dedicated PostgreSQL 17 container, Docker context `desktop-linux`,
name beginning `nexus-ct-adjudication-`, network `none`, no host ports or binds,
read-only root, and tmpfs PGDATA. It must use the isolated local administrator
`ct_adjudication_sandbox`; no production credentials may be present.

Run `python run_validation.py --container <isolated-container-name> --output <new-evidence-directory>`.
The launcher checks isolation, creates fresh uniquely named synthetic databases,
applies the fixture and migration, executes 30 rollback-isolated scenarios, checks
replay, transaction rollback and literal-drift rejection, then runs five concurrent/transaction-isolation
scenarios. It never accepts a network URL, resets a database, links Supabase or
invokes deployment tooling. Stop only this dedicated container after collecting
the receipt; tmpfs storage is disposable. Raw command/result logs remain evidence.

Seven guard tests also run under optimized Python. Both entrypoints share explicit
isolation/version checks, so `python -O` cannot disable them. Launcher exit codes:
0 = all acceptance passed; 1 = test/execution failure; 2 = completed validation with
an unmet baseline acceptance criterion. JSON includes `acceptance_passed=false`
and `review_required=true` when the critical-alert gap remains.

Production was 17.6; this mission's sandbox is PostgreSQL 17.11. Native PostgreSQL
catalog/ACL tests were used. Supabase CLI advisors/full-stack integration were not
run against this network-isolated PostgreSQL-only fixture. No advisor or migration
command was directed at production.

## Known baseline discrepancy

The exact copied production `nexus_ct_live_command.runtime_snapshot()` checks a
recent completed run, zero stale starts, zero unreconciled claims, and existing
authority/policy controls. It does **not** read `critical_alert_count_24h`.
Required scenario 11 therefore reports `BASELINE_GAP` if an otherwise healthy
synthetic runtime reports ready with an alert. The alert count must remain 1 and
the runtime definition must remain byte-identical. This is an unmet acceptance
expectation, not a PASS and not a new regression introduced by the migration.
Changing that runtime policy is outside this scoped health-view change.

Review must resolve or explicitly disposition that gap before any promotion claim.
Adjudication alone is not current health, fresh broker evidence, trading authority,
an approved order, or proof that automatic recovery succeeded.

Design references: PostgreSQL [locking](https://www.postgresql.org/docs/17/explicit-locking.html)
and [function volatility](https://www.postgresql.org/docs/17/xfunc-volatility.html);
Supabase [function security](https://supabase.com/docs/guides/database/functions).
File custody follows [the repository protocol](../../../../docs/governance/FILE_CUSTODY_PROTOCOL.md).

## Required acceptance mapping

| Requirement | Evidence case(s) |
|---|---|
| 1. Normal start/finish | SQL 29 |
| 2. Recent unfinished run | SQL 2, 24 |
| 3. Stale unfinished run | SQL 1 before adjudication |
| 4. Valid append-only adjudication | SQL 1, 23, 30 |
| 5. Duplicate | SQL 5; competing-adjudicator concurrency case |
| 6. Completed run rejected | SQL 3; committed-finish concurrency case |
| 7. Nonexistent run rejected | SQL 4 |
| 8. Invalid disposition | SQL 6 |
| 9. Invalid reason/evidence/actor | SQL 7–9, 25–26 |
| 10. Unreconciled claim retains HOLD | SQL 12 |
| 11. Critical alert retains HOLD | SQL 11: unmet baseline expectation; alert count preserved |
| 12. Partial adjudication of multiple stale runs | SQL 10 |
| 13. Ordinary roles cannot forge rows | SQL 19–21 |
| 14. Clean application and safe replay | Launcher apply; cases 140–142 |
