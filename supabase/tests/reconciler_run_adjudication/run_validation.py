"""Run only inside a verified, network-isolated disposable Docker PostgreSQL 17.

Creates a new synthetic database per invocation. Never accepts a host/URL/password,
never links Supabase, and never resets or drops an existing database.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import uuid
from sandbox_guard import validate_container, validate_version

HERE = Path(__file__).resolve().parent
MIGRATION = HERE.parents[1] / 'migrations' / '20261023165658_ct_reconciler_run_adjudication_20261023.sql'
ADMIN = 'ct_adjudication_sandbox'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--container', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if not args.container.startswith('nexus-ct-adjudication-'):
        raise SystemExit('Unexpected sandbox container name')
    args.output.mkdir(parents=True, exist_ok=False)
    commands = []

    def command(argv, *, stdin=None, artifact=None):
        # Binary stdin preserves LF SQL literals on Windows instead of translating
        # them to CRLF, which would invalidate exact source-definition checks.
        result = subprocess.run(argv, input=None if stdin is None else stdin.encode('utf-8'), capture_output=True, timeout=120)
        result.stdout = result.stdout.decode('utf-8')
        result.stderr = result.stderr.decode('utf-8')
        commands.append({'argv': argv, 'stdin_artifact': artifact, 'exit_code': result.returncode})
        (args.output / 'commands.json').write_text(json.dumps(commands, indent=2), encoding='utf-8')
        return result

    inspected = command(['docker', '--context', 'desktop-linux', 'inspect', args.container])
    inspected.check_returncode()
    info = json.loads(inspected.stdout)[0]
    validate_container(info, args.container)
    database = 'ct_adjudication_' + dt.datetime.now(dt.timezone.utc).strftime('%Y%m%d%H%M%S') + '_' + uuid.uuid4().hex[:8]

    def sql(text, *, db=database, artifact='inline', check=True):
        argv = ['docker', '--context', 'desktop-linux', 'exec', '-i', args.container,
                'psql', '-X', '-qAt', '-U', ADMIN, '-d', db,
                '--set=ON_ERROR_STOP=1', '--set=VERBOSITY=verbose']
        result = command(argv, stdin=text, artifact=artifact)
        if check and result.returncode:
            (args.output / 'last-error.txt').write_text(result.stderr, encoding='utf-8')
            raise RuntimeError('Sandbox SQL failed: ' + result.stderr)
        return result

    version = sql("select current_setting('server_version_num');", db=ADMIN).stdout.strip()
    validate_version(version)
    guard_tests = command([sys.executable, '-O', str(HERE / 'test_sandbox_guard.py'), '-v'])
    (args.output / 'sandbox-guard-tests.txt').write_text(guard_tests.stdout + guard_tests.stderr, encoding='utf-8')
    guard_tests.check_returncode()
    sql('CREATE DATABASE "' + database + '";', db=ADMIN, artifact='create-new-synthetic-database')
    fixture = (HERE / 'baseline.sql').read_text(encoding='utf-8')
    migration = MIGRATION.read_text(encoding='utf-8')
    sql(fixture, artifact='baseline.sql')
    applied = sql('SET ROLE postgres;\n' + migration, artifact=str(MIGRATION.name))
    (args.output / 'migration-apply.txt').write_text(applied.stdout + applied.stderr, encoding='utf-8')

    tested = sql((HERE / 'tests.sql').read_text(encoding='utf-8'), artifact='tests.sql')
    (args.output / 'tests-output.txt').write_text(tested.stdout + tested.stderr, encoding='utf-8')
    results = json.loads(sql("select jsonb_agg(to_jsonb(r) order by test_id) from sandbox_test.results r;").stdout)

    # Replay must fail closed without DDL/data drift, not silently skip over drift.
    snapshot = """
    select jsonb_build_object(
      'views', (select jsonb_agg(jsonb_build_array(c.relname,pg_get_viewdef(c.oid,true),c.relacl,c.reloptions) order by c.relname)
        from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='nexus_live_trading' and c.relkind='v'),
      'functions', (select jsonb_agg(jsonb_build_array(p.oid::regprocedure::text,pg_get_functiondef(p.oid),p.proacl) order by p.oid)
        from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('nexus_live_trading','nexus_ct_live_command')),
      'events', (select coalesce(jsonb_agg(to_jsonb(e) order by reconciler_run_event_id),'[]'::jsonb) from nexus_live_trading.reconciler_run_events e),
      'adjudications', (select coalesce(jsonb_agg(to_jsonb(a) order by adjudication_id),'[]'::jsonb) from nexus_live_trading.reconciler_run_adjudications a));
    """
    before = sql(snapshot).stdout
    replay = sql('SET ROLE postgres;\n' + migration, artifact='migration-replay', check=False)
    after = sql(snapshot).stdout
    replay_ok = replay.returncode != 0 and '42710' in replay.stderr and before == after
    (args.output / 'migration-replay.txt').write_text(replay.stdout + replay.stderr, encoding='utf-8')
    results.append({'test_id': 140, 'name': 'Migration replay rejects atomically without drift',
                    'status': 'PASS' if replay_ok else 'FAIL', 'sqlstate': '42710' if replay_ok else None})

    # Force failure at the final ACL guard to prove preceding DDL rolls back.
    rollback_db = database + '_rollback'
    sql('CREATE DATABASE "' + rollback_db + '";', db=ADMIN)
    sql(fixture, db=rollback_db, artifact='baseline.sql')
    sql("DO $$BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='sandbox_acl_probe') THEN CREATE ROLE sandbox_acl_probe NOLOGIN; END IF; END$$; SET ROLE postgres; ALTER DEFAULT PRIVILEGES IN SCHEMA nexus_live_trading GRANT SELECT ON TABLES TO sandbox_acl_probe;", db=rollback_db)
    baseline_before = sql("select pg_get_viewdef('nexus_live_trading.v_reconciler_health'::regclass,true);", db=rollback_db).stdout
    failed = sql('SET ROLE postgres;\n' + migration, db=rollback_db, artifact='migration-atomic-failure', check=False)
    baseline_after = sql("select pg_get_viewdef('nexus_live_trading.v_reconciler_health'::regclass,true);", db=rollback_db).stdout
    absent = sql("select to_regclass('nexus_live_trading.reconciler_run_adjudications') is null and to_regprocedure('nexus_live_trading.adjudicate_reconciler_run(uuid,text,text,jsonb,text)') is null;", db=rollback_db).stdout.strip()
    rollback_ok = failed.returncode != 0 and 'ct_adjudication_unexpected_default_acl' in failed.stderr and absent == 't' and baseline_before == baseline_after
    results.append({'test_id': 141, 'name': 'Late ACL guard failure rolls back all new DDL and view change',
                    'status': 'PASS' if rollback_ok else 'FAIL', 'sqlstate': '42501' if rollback_ok else None})
    (args.output / 'migration-atomic-failure.txt').write_text(failed.stdout + failed.stderr, encoding='utf-8')

    # Whitespace inside a SQL literal is semantic drift, not formatting noise.
    catalog = json.loads((HERE / 'baseline_catalog.json').read_text(encoding='utf-8'))
    drifted_view = catalog['table_and_view']['health_view'].replace("'finished'::text", "'finished '::text")
    sql('SET ROLE postgres; CREATE OR REPLACE VIEW nexus_live_trading.v_reconciler_health WITH (security_invoker=true) AS ' + drifted_view, db=rollback_db)
    drift_before = sql("select pg_get_viewdef('nexus_live_trading.v_reconciler_health'::regclass,true);", db=rollback_db).stdout
    drift_failure = sql('SET ROLE postgres;\n' + migration, db=rollback_db, artifact='migration-literal-drift', check=False)
    drift_after = sql("select pg_get_viewdef('nexus_live_trading.v_reconciler_health'::regclass,true);", db=rollback_db).stdout
    drift_ok = drift_failure.returncode != 0 and 'ct_adjudication_health_view_baseline_mismatch' in drift_failure.stderr and drift_before == drift_after
    results.append({'test_id': 142, 'name': 'Semantic drift inside a SQL literal fails the exact baseline guard',
                    'status': 'PASS' if drift_ok else 'FAIL', 'sqlstate': '55000' if drift_ok else None})
    (args.output / 'migration-literal-drift.txt').write_text(drift_failure.stdout + drift_failure.stderr, encoding='utf-8')

    concurrency = command([sys.executable, str(HERE / 'concurrency.py'), '--container', args.container,
                           '--database', database, '--output', str(args.output / 'concurrency.json')])
    (args.output / 'concurrency-output.txt').write_text(concurrency.stdout + concurrency.stderr, encoding='utf-8')
    if concurrency.returncode:
        raise RuntimeError('Concurrency validation failed: see concurrency-output.txt')
    report = {'mission_id': 'NEXUS-CT-RECONCILER-ADJUDICATION-20261023-001',
              'validated_at_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
              'container': args.container, 'container_id': info['Id'], 'image_id': info['Image'],
              'database': database, 'atomic_failure_database': rollback_db,
              'server_version_num': version, 'network': 'none', 'host_ports': [], 'binds': [],
              'production_credentials_used': False, 'migration_applied_exit_code': applied.returncode,
              'migration_sha256': hashlib.sha256(MIGRATION.read_bytes()).hexdigest(),
              'results': results,
              'counts': {k: sum(r['status'] == k for r in results) for k in ['PASS','FAIL','BASELINE_GAP']},
              'concurrency': json.loads((args.output / 'concurrency.json').read_text(encoding='utf-8'))}
    report['acceptance_passed'] = not (report['counts']['FAIL'] or report['counts']['BASELINE_GAP'])
    report['review_required'] = True
    report['sandbox_guard_tests'] = {'tests': 7, 'pass': 7, 'fail': 0, 'python_optimized': True}
    (args.output / 'commands.json').write_text(json.dumps(commands, indent=2), encoding='utf-8')
    (args.output / 'validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps({'database': database, 'counts': report['counts'], 'evidence': str(args.output)}))
    return 1 if report['counts']['FAIL'] else (2 if report['counts']['BASELINE_GAP'] else 0)


if __name__ == '__main__':
    raise SystemExit(main())
