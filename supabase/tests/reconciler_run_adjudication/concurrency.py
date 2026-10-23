#!/usr/bin/env python3
"""Sandbox-only PostgreSQL adjudication concurrency checks; stdlib + Docker CLI.

The caller creates and migrates a disposable ct_adjudication_* database first.
Every run inserts fresh synthetic UUIDs. No cleanup deletes or production calls.
"""
import argparse
import concurrent.futures
import contextlib
import datetime
import json
import queue
import re
import subprocess
import sys
import threading
import time
import uuid
from pathlib import Path
from sandbox_guard import validate_container, validate_version


class SQLFailure(RuntimeError):
    def __init__(self, returncode, stdout, stderr):
        super().__init__(stderr.strip() or 'psql failed with exit ' + str(returncode))
        self.returncode, self.stdout, self.stderr = returncode, stdout, stderr


class Session:
    """One persistent psql connection, synchronized using explicit output markers."""
    def __init__(self, harness, label):
        self.harness = harness
        self.process = subprocess.Popen(harness.psql_command(), stdin=subprocess.PIPE,
                                        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                        text=True, bufsize=1)
        self.output = queue.Queue()
        self.errors = []

        def read_stdout():
            for line in self.process.stdout:
                self.output.put(line.rstrip('\r\n'))
            self.output.put(None)

        def read_stderr():
            for line in self.process.stderr:
                self.errors.append(line)

        self.stdout_thread = threading.Thread(target=read_stdout, daemon=True)
        self.stderr_thread = threading.Thread(target=read_stderr, daemon=True)
        self.stdout_thread.start()
        self.stderr_thread.start()
        self.execute(harness.session_setup(label))

    def execute(self, sql, timeout=12):
        marker = 'CT_SYNC_' + uuid.uuid4().hex
        self.process.stdin.write(sql + '\n\\echo ' + marker + '\n')
        self.process.stdin.flush()
        lines = []
        deadline = time.monotonic() + timeout
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError('psql sentinel not reached')
            try:
                line = self.output.get(timeout=remaining)
            except queue.Empty:
                raise TimeoutError('psql sentinel not reached') from None
            if line is None:
                self.process.wait(timeout=2)
                self.stderr_thread.join(timeout=2)
                raise SQLFailure(self.process.returncode, '\n'.join(lines), ''.join(self.errors))
            if line == marker:
                return '\n'.join(lines).strip()
            lines.append(line)

    def close(self):
        if self.process.poll() is None:
            try:
                self.process.stdin.write('ROLLBACK;\n\\q\n')
                self.process.stdin.flush()
                self.process.wait(timeout=4)
            except (BrokenPipeError, OSError, subprocess.TimeoutExpired):
                self.process.terminate()
                self.process.wait(timeout=4)
        self.stdout_thread.join(timeout=2)
        self.stderr_thread.join(timeout=2)

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.close()


class Harness:
    def __init__(self, args):
        self.args = args
        self.results = []
        self.namespace = uuid.uuid4().hex[:12]
        self.run_ids = {}

    def psql_command(self):
        return ['docker', '--context', 'desktop-linux', 'exec', '-i', self.args.container, 'psql', '-X', '-qAt',
                '-v', 'ON_ERROR_STOP=1', '-v', 'VERBOSITY=verbose',
                '-U', self.args.user, '-d', self.args.database]

    def session_setup(self, label):
        name = 'ct_adj_' + self.namespace + '_' + label
        if not re.fullmatch(r'[A-Za-z0-9_]+', name):
            raise ValueError('Invalid synthetic application name')
        return ("SET statement_timeout='10s'; SET lock_timeout='6s'; "
                "SET idle_in_transaction_session_timeout='20s'; "
                "SET application_name='" + name + "'; SET ROLE postgres;")

    def run(self, sql, label='probe', timeout=15):
        completed = subprocess.run(self.psql_command(),
                                   input=self.session_setup(label) + '\n' + sql + '\n',
                                   capture_output=True, text=True, timeout=timeout)
        if completed.returncode:
            raise SQLFailure(completed.returncode, completed.stdout, completed.stderr)
        return completed.stdout.strip()

    def expect_error(self, sql, sqlstate, label):
        try:
            self.run(sql, label)
        except SQLFailure as error:
            if re.search(r'\b' + re.escape(sqlstate) + r'\b', error.stderr):
                return sqlstate
            raise AssertionError('Expected SQLSTATE ' + sqlstate + '; got ' + str(error)) from error
        raise AssertionError('Expected SQLSTATE ' + sqlstate + '; statement succeeded')

    def synthetic_run(self, label):
        run_id = 'c7231023-' + str(uuid.uuid4())[9:]
        self.run_ids[label] = run_id
        self.run(self.event_sql(run_id, 'started'), 'seed_' + label)
        return run_id

    @staticmethod
    def event_sql(run_id, event_type):
        state = 'running' if event_type == 'started' else 'completed'
        timestamp = "clock_timestamp()-interval '5 minutes'" if event_type == 'started' else 'clock_timestamp()'
        return ("SELECT nexus_live_trading.record_reconciler_run_event("
                f"'{run_id}'::uuid,'{event_type}','{state}',0,0,0,'[]'::jsonb,"
                f"'sandbox-concurrency-{run_id}',{timestamp});")

    @staticmethod
    def adjudication_sql(run_id):
        return ("SELECT nexus_live_trading.adjudicate_reconciler_run("
                f"'{run_id}'::uuid,'abandoned','Synthetic sandbox concurrency adjudication',"
                "'{\"reference\":\"sandbox-evidence-001\"}'::jsonb,'Captain');")

    def counts(self, run_id):
        sql = ("SELECT json_build_object('started',"
               f"(SELECT count(*) FROM nexus_live_trading.reconciler_run_events WHERE run_id='{run_id}' AND event_type='started'),"
               "'finished',"
               f"(SELECT count(*) FROM nexus_live_trading.reconciler_run_events WHERE run_id='{run_id}' AND event_type='finished'),"
               "'adjudications',"
               f"(SELECT count(*) FROM nexus_live_trading.reconciler_run_adjudications WHERE run_id='{run_id}'));" )
        return json.loads(self.run(sql))

    def check_counts(self, run_id, expected):
        actual = self.counts(run_id)
        if actual != expected:
            raise AssertionError('Unexpected synthetic evidence counts: ' + json.dumps(actual))
        return actual

    def wait_for_writer_relation_lock(self, label, future):
        application_name = 'ct_adj_' + self.namespace + '_' + label
        sql = ("SELECT count(*) FROM pg_catalog.pg_stat_activity a "
               "JOIN pg_catalog.pg_locks l ON l.pid=a.pid "
               f"WHERE a.datname=current_database() AND a.application_name='{application_name}' "
               "AND a.wait_event_type='Lock' AND l.locktype='relation' "
               "AND l.relation='nexus_live_trading.reconciler_run_events'::regclass "
               "AND l.mode='RowExclusiveLock' AND NOT l.granted;")
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if future.done():
                future.result()
                raise AssertionError('Writer finished without waiting for adjudicator lock')
            # Test sessions authenticate as the sandbox administrator, then SET
            # ROLE postgres. The intentionally non-superuser postgres fixture
            # cannot inspect the administrator-owned sessions' wait_event fields.
            # Reset only this fresh read-only observer connection; execution
            # sessions remain under the migration owner's restricted identity.
            if self.run('RESET ROLE; ' + sql, 'lock_observer') == '1':
                return True
            # Bounded polling of an observed lock condition, not a timing assertion.
            time.sleep(0.025)
        raise TimeoutError('Expected writer relation-lock wait was not observed')

    def guard(self):
        if not re.fullmatch(r'nexus-ct-adjudication-[A-Za-z0-9-]+', self.args.container):
            raise ValueError('Only an isolated adjudication sandbox container is permitted')
        if not re.fullmatch(r'ct_adjudication_[a-zA-Z0-9_]+', self.args.database):
            raise ValueError('Only a disposable ct_adjudication_* database is permitted')
        if self.args.user != 'ct_adjudication_sandbox':
            raise ValueError('Only the sandbox database login is permitted')
        inspected = subprocess.run(['docker', '--context', 'desktop-linux', 'inspect',
                                    self.args.container], capture_output=True, text=True, check=True, timeout=10)
        validate_container(json.loads(inspected.stdout)[0], self.args.container)
        validate_version(self.run("SELECT current_setting('server_version_num');"))
        state = json.loads(self.run("SELECT json_build_object('database',current_database(),"
                                   "'current_user',current_user,'migration_installed',"
                                   "to_regclass('nexus_live_trading.reconciler_run_adjudications') IS NOT NULL);"))
        if state != {'database': self.args.database, 'current_user': 'postgres', 'migration_installed': True}:
            raise RuntimeError('Sandbox identity or installed migration mismatch')

    def writer_committed_before_adjudication(self):
        run_id = self.synthetic_run('committed_finish')
        with Session(self, 'old_snapshot') as adjudicator:
            adjudicator.execute("BEGIN ISOLATION LEVEL READ COMMITTED; SELECT count(*) FROM nexus_live_trading.reconciler_run_events;")
            self.run(self.event_sql(run_id, 'finished'), 'committed_writer')
            try:
                adjudicator.execute(self.adjudication_sql(run_id))
            except SQLFailure as error:
                if not re.search(r'\b22023\b', error.stderr) or 'finished_run_rejected' not in error.stderr:
                    raise AssertionError('Committed finish was not correctly rejected') from error
            else:
                raise AssertionError('Adjudication admitted a committed finished run')
        return {'sqlstate': '22023', 'prior_transaction_read': True,
                'counts': self.check_counts(run_id, {'started': 1, 'finished': 1, 'adjudications': 0})}

    def active_writer_rejects_adjudication(self):
        run_id = self.synthetic_run('active_writer')
        with Session(self, 'active_writer_holder') as writer:
            writer.execute('BEGIN; ' + self.event_sql(run_id, 'finished'))
            state = self.expect_error(self.adjudication_sql(run_id), '55P03', 'busy_adjudicator')
            writer.execute('COMMIT;')
        return {'sqlstate': state,
                'counts': self.check_counts(run_id, {'started': 1, 'finished': 1, 'adjudications': 0})}

    def adjudicator_blocks_then_preserves_late_finish(self):
        run_id = self.synthetic_run('late_finish')
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
            with Session(self, 'adjudicator_holder') as adjudicator:
                adjudicator.execute('BEGIN; ' + self.adjudication_sql(run_id))
                label = 'blocked_writer'
                future = pool.submit(self.run, self.event_sql(run_id, 'finished'), label)
                observed = self.wait_for_writer_relation_lock(label, future)
                adjudicator.execute('COMMIT;')
                future.result(timeout=12)
        return {'writer_ungranted_relation_lock_observed': observed,
                'real_finish_preserved': True,
                'counts': self.check_counts(run_id, {'started': 1, 'finished': 1, 'adjudications': 1})}

    def concurrent_adjudications_reject_busy_then_duplicate(self):
        run_id = self.synthetic_run('duplicate')
        with Session(self, 'first_adjudicator') as first:
            first.execute('BEGIN; ' + self.adjudication_sql(run_id))
            busy = self.expect_error(self.adjudication_sql(run_id), '55P03', 'second_busy')
            first.execute('COMMIT;')
        duplicate = self.expect_error(self.adjudication_sql(run_id), '23505', 'second_duplicate')
        return {'active_sqlstate': busy, 'committed_sqlstate': duplicate,
                'counts': self.check_counts(run_id, {'started': 1, 'finished': 0, 'adjudications': 1})}

    def transaction_snapshot_isolation_rejected(self):
        run_id = self.synthetic_run('isolation_rejected')
        states = {}
        for level in ('REPEATABLE READ', 'SERIALIZABLE'):
            statement = ('BEGIN ISOLATION LEVEL ' + level + '; '
                         'SELECT count(*) FROM nexus_live_trading.reconciler_run_events; '
                         + self.adjudication_sql(run_id) + ' COMMIT;')
            states[level] = self.expect_error(statement, '25001', level.lower().replace(' ', '_'))
            self.check_counts(run_id, {'started': 1, 'finished': 0, 'adjudications': 0})
        self.run(self.event_sql(run_id, 'finished'), 'isolation_genuine_finish')
        return {'rejected_isolations': states,
                'counts': self.check_counts(run_id, {'started': 1, 'finished': 1, 'adjudications': 0})}

    def execute(self):
        self.guard()
        cases = [self.writer_committed_before_adjudication,
                 self.active_writer_rejects_adjudication,
                 self.adjudicator_blocks_then_preserves_late_finish,
                 self.concurrent_adjudications_reject_busy_then_duplicate,
                 self.transaction_snapshot_isolation_rejected]
        for case in cases:
            details = case()
            self.results.append({'test': case.__name__, 'status': 'PASS', **details})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--container', default='nexus-ct-adjudication-20261023-c3266cf9')
    parser.add_argument('--database', required=True)
    parser.add_argument('--user', default='ct_adjudication_sandbox')
    parser.add_argument('--output', '--outputpath', dest='output')
    args = parser.parse_args()
    harness = Harness(args)
    report = {'suite': 'reconciler_run_adjudication_concurrency',
              'container': args.container, 'database': args.database,
              'started_utc': datetime.datetime.now(datetime.timezone.utc).isoformat()}
    exit_code = 0
    try:
        harness.execute()
        report['status'] = 'PASS'
    except Exception as error:
        report['status'] = 'FAIL'
        report['error_type'] = type(error).__name__
        report['error'] = str(error)
        exit_code = 1
    report['tests'] = harness.results
    report['synthetic_run_ids'] = harness.run_ids
    report['completed_utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    payload = json.dumps(report, indent=2) + '\n'
    if args.output:
        Path(args.output).write_text(payload, encoding='utf-8')
    print(payload, end='')
    return exit_code


if __name__ == '__main__':
    sys.exit(main())
