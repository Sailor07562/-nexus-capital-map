"""Source regressions only; native role tests are separate deployment evidence."""
import re
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'integrations/kernel/sandbox'
MIGRATIONS = list((BASE / 'supabase/migrations').glob('*_nexus_kernel_sandbox_reader.sql'))


class SandboxReaderSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        assert len(MIGRATIONS) == 1
        cls.sql = MIGRATIONS[0].read_text()
        cls.body = cls.sql.split('AS $reader$')[1].split('$reader$;')[0]

    def test_no_mutation_or_dynamic_sql_in_reader(self):
        self.assertNotRegex(self.body, r'(?i)\b(insert|update|delete|truncate|execute|dblink|http)\b')
        self.assertNotIn('SECURITY DEFINER', self.sql.upper())
        self.assertIn('SECURITY INVOKER', self.sql)
        self.assertIn("SET search_path = ''", self.sql)
        self.assertIn('SET row_security = on', self.sql)
        self.assertIn('\nSTABLE\n', self.sql)

    def test_role_has_no_login_or_elevated_privileges(self):
        self.assertRegex(self.sql, r'CREATE ROLE nexus_kernel_sandbox_ro NOLOGIN NOINHERIT NOSUPERUSER\s+NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;')
        self.assertIn('TO postgres WITH INHERIT FALSE, SET TRUE', self.sql)

    def test_only_seven_column_scoped_table_grants(self):
        grants = re.findall(r'GRANT SELECT \((.*?)\)\s+ON nexus_sandbox\.(\w+) TO nexus_kernel_sandbox_ro;', self.sql, re.S)
        self.assertEqual(len(grants), 7)
        self.assertEqual({name for _, name in grants}, {
            'environment_control', 'federated_control_status', 'federated_sync_contract',
            'federated_lane_registry', 'federated_lane_state',
            'federated_authority_matrix', 'federated_resume_checkpoint'})
        self.assertNotRegex(self.sql, r'(?i)GRANT\s+(ALL|INSERT|UPDATE|DELETE|CREATE)\b')
        for columns, _ in grants:
            self.assertFalse({'resume_reason', 'source_reference', 'next_action', 'blocker',
                              'last_known_state', 'lane_name', 'state_source'} &
                             {column.strip() for column in columns.split(',')})

    def test_policies_are_select_only_for_reader(self):
        policies = re.findall(r'CREATE POLICY kernel_reader_select ON (.*?);', self.sql, re.S)
        self.assertEqual(len(policies), 7)
        for policy in policies:
            self.assertIn('FOR SELECT TO nexus_kernel_sandbox_ro', policy)
            self.assertNotIn('WITH CHECK', policy)
        self.assertIn("USING (environment_name = 'nexus_supabase_sandbox')", self.sql)
        self.assertIn("USING (control_id = 'FED-CONTROL-001')", self.sql)
        self.assertIn("USING (contract_id = 'FED-SYNC-CONTRACT-001')", self.sql)

    def test_explicit_role_and_readonly_transaction_required(self):
        self.assertIn("current_user <> 'nexus_kernel_sandbox_ro'", self.body)
        self.assertIn("current_setting('transaction_read_only') <> 'on'", self.body)
        self.assertIn("RAISE SQLSTATE '42501'", self.body)
        self.assertIn("RAISE SQLSTATE '25006'", self.body)
        self.assertIn('BEGIN READ ONLY;', (BASE / 'read.sql').read_text())

    def test_installation_is_fail_closed_and_non_destructive(self):
        self.assertIn("canonical_status = 'NON_CANONICAL'", self.sql)
        self.assertIn("to_regnamespace('nexus_live_trading') IS NOT NULL", self.sql)
        self.assertIn("to_regrole('nexus_kernel_sandbox_ro') IS NOT NULL", self.sql)
        uncommented = re.sub(r'--[^\n]*', '', self.sql)
        self.assertNotRegex(uncommented, r'(?i)\b(create or replace|drop|disable row level)\b')

    def test_successful_read_never_promotes_kernel(self):
        for expected in ["'kernel_integration_status', 'HOLD'", "'kernel_bindings', 'UNVERIFIED'",
                         "'execution_authorized', false", "'production_verified', false",
                         "'canonical_state_changed', false", "'KERNEL_BINDINGS_UNVERIFIED'"]:
            self.assertIn(expected, self.body)
        self.assertIn('INTO STRICT env', self.body)
        self.assertIn('INTO STRICT ctl', self.body)
        self.assertIn('INTO STRICT contract', self.body)

    def test_api_roles_and_public_cannot_execute(self):
        self.assertIn('REVOKE ALL ON FUNCTION nexus_sandbox.kernel_readiness() FROM PUBLIC;', self.sql)
        self.assertIn('FROM anon, authenticated, service_role, authenticator;', self.sql)
        self.assertNotRegex(self.sql, r'(?i)GRANT[^;]*\bTO\s+(anon|authenticated|service_role|authenticator|public)\b')

    def test_rollback_exactly_matches_new_grants_and_policies(self):
        rollback = (BASE / 'rollback.sql').read_text()
        expected = re.findall(r'GRANT SELECT \((.*?)\)\s+ON (\S+) TO nexus_kernel_sandbox_ro;', self.sql, re.S)
        revoked = re.findall(r'REVOKE SELECT \((.*?)\)\s+ON (\S+) FROM nexus_kernel_sandbox_ro;', rollback, re.S)
        normalize = lambda pairs: {(re.sub(r'\s+', '', cols), table) for cols, table in pairs}
        self.assertEqual(normalize(expected), normalize(revoked))
        self.assertEqual(rollback.count('DROP POLICY kernel_reader_select ON '), 7)
        self.assertNotRegex(re.sub(r'--[^\n]*', '', rollback), r'(?i)\b(cascade|drop owned|drop table|delete|truncate)\b')

    def test_native_denials_have_exact_codes_and_safe_noop_dml(self):
        cases = json.loads((BASE / 'denial-cases.json').read_text())['cases']
        self.assertEqual(len(cases), 13)
        self.assertEqual(len({case['name'] for case in cases}), len(cases))
        for case in cases:
            self.assertIn(case['expected'], {'42501', '25006'})
            self.assertIn(case['role'], {None, 'anon', 'authenticated', 'service_role',
                                       'authenticator', 'nexus_kernel_sandbox_ro'})
            if re.search(r'\b(INSERT|UPDATE|DELETE)\b', case['sql']):
                self.assertIn('WHERE false', case['sql'])
            self.assertNotRegex(case['sql'], r'(?i)\b(truncate|drop|grant|revoke)\b')

    def test_read_ends_without_persisting_a_session_role(self):
        read = (BASE / 'read.sql').read_text()
        self.assertIn('SET LOCAL ROLE nexus_kernel_sandbox_ro;', read)
        self.assertTrue(read.rstrip().endswith('ROLLBACK;'))


if __name__ == '__main__':
    unittest.main()
