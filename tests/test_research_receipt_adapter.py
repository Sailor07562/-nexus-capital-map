"""Synthetic adapter tests. No real research, credentials or source truth."""
import ast
import copy
import io
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
import research_receipt_adapter as adapter
import kernel_integration_gate as gate
import stock_review_gate as stock
from test_kernel_integration_gate import bind_original, fixture, NOW, time


def inputs():
    packet, context = fixture('research_completion')
    observation = {
        'observation_kind': adapter.OBSERVATION_KIND,
        'captured_at': time(-15), 'receipt_id': 'TEST-RECEIPT',
        'mission_id': 'TEST-MISSION', 'research_status': 'COMPLETE',
        'valuation_status': 'CONDITIONAL', 'investment_status': 'HOLD',
        'reviewer_receipt_id': 'TEST-REVIEW',
        'reviewer_display': 'Independent reviewer role label',
        'reviewer_verdict_display': 'AGREE conditional',
        'support_model_version_display': 'TEST-MODEL-v1',
        'support_model_sha256_reported': 'a' * 64,
        'source_refs': ['test:native-receipt', 'test:native-review'],
    }
    context['receipt_binding'] = {
        'receipt_id': observation['receipt_id'], 'mission_id': observation['mission_id'],
        'observation_sha256': stock.digest(observation),
        'packet_sha256': gate.subject_digest(packet),
        'research_packet_sha256': stock.digest(packet['research_packet']),
        **{key: packet['identity'][key]
           for key in ('source_system', 'source_record_id', 'source_version')},
        'record_ref': 'test:existing-receipt-link', 'mapping_version': '1',
        'mapping_refs': ['test:existing-mapping'], 'evidence_refs': ['test:receipt-link'],
        'review_receipt_id': observation['reviewer_receipt_id'],
        'reviewer_id': 'TEST-REVIEWER', 'review_evidence_refs': ['test:review-principal'],
        'read_at': time(-10),
    }
    return observation, packet, context


class ResearchReceiptAdapterTests(unittest.TestCase):
    def check(self, observation, packet=None, context=None):
        return adapter.adapt(observation, packet, context, now=NOW)

    def held(self, observation, packet=None, context=None, code=None):
        candidate, result = self.check(observation, packet, context)
        self.assertIsNone(candidate)
        self.assertEqual(result['verdict'], 'HOLD', result)
        self.assertEqual(result['runtime_status'], 'HOLD_UNAUTHENTICATED')
        for field in ('authentication_verified', 'execution_authorized',
                      'production_verified', 'canonical_state_changed'):
            self.assertFalse(result[field])
        if code:
            issues = result['errors'] + (result['gate_result'] or {}).get('errors', [])
            self.assertIn(code, [issue['code'] for issue in issues], result)
        return result

    def test_complete_synthetic_binding_passes_only_structurally(self):
        observation, packet, context = inputs()
        before = copy.deepcopy((observation, packet, context))
        candidate, result = self.check(observation, packet, context)
        self.assertEqual(result['verdict'], 'STRUCTURE_PASS', result)
        self.assertEqual(result['gate_result']['protocol'], gate.PROTOCOL)
        self.assertEqual(result['gate_result']['phase'], 'preflight')
        self.assertEqual(result['runtime_status'], 'HOLD_UNAUTHENTICATED')
        for field in ('authentication_verified', 'execution_authorized',
                      'production_verified', 'canonical_state_changed'):
            self.assertFalse(result[field])
        self.assertEqual((observation, packet, context), before)
        self.assertEqual(candidate, packet)
        candidate['identity']['event_id'] = 'test-copy-modified'
        self.assertEqual((observation, packet, context), before)

    def test_receipt_alone_never_creates_an_envelope_or_context(self):
        observation, packet, context = inputs()
        observation.update(packet=packet, context=context, execution_authorized=True)
        result = self.held(observation, code='ENVELOPE_REQUIRED')
        self.assertIn('CONTEXT_REQUIRED', [error['code'] for error in result['errors']])
        self.assertIsNone(result['gate_result'])

    def test_missing_packet_or_context_is_explicit(self):
        observation, packet, context = inputs()
        self.held(observation, None, context, 'ENVELOPE_REQUIRED')
        self.held(observation, packet, None, 'CONTEXT_REQUIRED')

    def test_wrong_observation_shapes_hold(self):
        for value in (None, [], 'COMPLETE', 1, True):
            with self.subTest(value=value):
                self.held(value, code='OBSERVATION')

    def test_wrong_envelope_context_and_binding_shapes_hold(self):
        for value in (None, [], 'COMPLETE', 1, True, {}):
            observation, packet, context = inputs()
            with self.subTest(value=value):
                self.held(observation, value, context, 'ENVELOPE_REQUIRED')
                self.held(observation, packet, value, 'CONTEXT_REQUIRED')
                context['receipt_binding'] = value
                self.held(observation, packet, context, 'RECEIPT_BINDING_REQUIRED')

    def test_nonfinite_and_nonjson_api_inputs_hold(self):
        for value in (float('nan'), float('inf'), {1, 2}):
            for target in (0, 1, 2):
                items = inputs()
                items[target]['untrusted_extra'] = value
                with self.subTest(value=value, target=target):
                    self.held(*items, code='INPUT')

    def test_circular_input_holds(self):
        observation, _, _ = inputs()
        observation['cycle'] = observation
        self.held(observation, code='INPUT')

    def test_wrong_clock_holds(self):
        candidate, result = adapter.adapt(inputs()[0], now=NOW.replace(tzinfo=None))
        self.assertIsNone(candidate)
        self.assertEqual(result['errors'][0]['code'], 'CLOCK')

    def test_missing_required_observation_fields_hold(self):
        for key in ('observation_kind', 'captured_at', 'receipt_id', 'mission_id',
                    'reviewer_receipt_id', 'research_status', 'valuation_status',
                    'investment_status', 'source_refs'):
            observation, packet, context = inputs()
            del observation[key]
            with self.subTest(key=key):
                self.held(observation, packet, context)

    def test_bad_native_refs_hold_without_throwing(self):
        for value in ([], ['test:x', 'test:x'], [{}], [None], ['unknown'], 'test:x'):
            observation, packet, context = inputs()
            observation['source_refs'] = value
            self.held(observation, packet, context, 'SOURCE_REFS')

    def test_future_observation_holds(self):
        observation, packet, context = inputs()
        observation['captured_at'] = time(1)
        self.held(observation, packet, context, 'OBSERVATION_TIME')

    def test_status_only_research_does_not_pass_existing_stock_gate(self):
        observation, packet, context = inputs()
        packet['research_packet'] = {'schema_version': 1, 'ticker': 'TEST', 'status': 'complete'}
        context['receipt_binding']['packet_sha256'] = gate.subject_digest(packet)
        context['receipt_binding']['research_packet_sha256'] = stock.digest(packet['research_packet'])
        self.held(observation, packet, context, 'STOCK_REVIEW')

    def test_original_statuses_are_not_translated_into_approval(self):
        observation, packet, context = inputs()
        candidate, result = self.check(observation, packet, context)
        self.assertEqual(result['verdict'], 'STRUCTURE_PASS')
        self.assertEqual(observation['investment_status'], 'HOLD')
        self.assertEqual(observation['valuation_status'], 'CONDITIONAL')
        self.assertEqual(observation['reviewer_verdict_display'], 'AGREE conditional')
        self.assertEqual(candidate['classification']['decoder'], 'signal')
        self.assertNotIn('valuation_status', candidate)

    def test_hold_decoder_is_not_cleared(self):
        observation, packet, context = inputs()
        packet['classification']['decoder'] = 'hold'
        self.held(observation, packet, context, 'DECODER_HOLD')
        self.assertEqual(packet['classification']['decoder'], 'hold')

    def test_other_profiles_and_operations_do_not_pass(self):
        observation, _, _ = inputs()
        packet, context = fixture('dot_intake')
        self.held(observation, packet, context, 'RESEARCH_PROFILE')
        for operation in ('submit_order', 'prepare_order', 'transfer', 'activate', 'project'):
            observation, packet, context = inputs()
            packet['operation'] = operation
            self.held(observation, packet, context, 'OPERATION')

    def test_live_cannot_be_downgraded_to_sandbox(self):
        observation, packet, context = inputs()
        packet['environment'] = context['environment'] = 'live'
        self.held(observation, packet, context, 'LIVE_BINDING_REQUIRED')
        self.assertEqual(packet['environment'], 'live')

    def test_missing_binding_fields_each_hold(self):
        for key in inputs()[2]['receipt_binding']:
            observation, packet, context = inputs()
            del context['receipt_binding'][key]
            with self.subTest(key=key):
                self.held(observation, packet, context)

    def test_cross_mission_receipt_cannot_bind(self):
        observation, packet, context = inputs()
        observation['mission_id'] = 'OTHER-MISSION'
        context['receipt_binding']['mission_id'] = 'OTHER-MISSION'
        context['receipt_binding']['observation_sha256'] = stock.digest(observation)
        self.held(observation, packet, context, 'MISSION_BINDING')

    def test_exact_hashes_reject_receipt_and_packet_drift(self):
        observation, packet, context = inputs()
        observation['investment_status'] = 'BUY'
        self.held(observation, packet, context, 'OBSERVATION_BINDING')
        observation, packet, context = inputs()
        packet['lifecycle']['occurred_at'] = time(-120)
        self.held(observation, packet, context, 'PACKET_BINDING')

    def test_model_hash_is_not_research_packet_hash(self):
        observation, packet, context = inputs()
        context['receipt_binding']['research_packet_sha256'] = observation['support_model_sha256_reported']
        self.held(observation, packet, context, 'RESEARCH_BINDING')

    def test_mismatched_binding_values_hold(self):
        for key in ('receipt_id', 'mission_id', 'source_system', 'source_record_id',
                    'source_version', 'observation_sha256', 'packet_sha256',
                    'research_packet_sha256'):
            observation, packet, context = inputs()
            context['receipt_binding'][key] = 'OTHER-VALUE'
            with self.subTest(key=key):
                self.held(observation, packet, context)

    def test_malformed_binding_evidence_holds(self):
        for key in ('evidence_refs', 'mapping_refs', 'review_evidence_refs'):
            for value in ([], [{}], 'test:x', ['test:x', 'test:x'], ['unknown']):
                observation, packet, context = inputs()
                context['receipt_binding'][key] = value
                self.held(observation, packet, context, 'BINDING_PROVENANCE')

    def test_source_identity_is_not_derived_from_model_or_receipt(self):
        for key in ('event_id', 'source_version', 'idempotency_key'):
            observation, packet, context = inputs()
            del packet['identity'][key]
            before = copy.deepcopy(packet)
            self.held(observation, packet, context, 'IDENTITY')
            self.assertEqual(packet, before)

    def test_missing_timestamps_and_policy_are_not_filled(self):
        for section, key, code in (('lifecycle', 'occurred_at', 'TIMESTAMP'),
                                   ('lifecycle', 'received_at', 'TIMESTAMP'),
                                   ('lifecycle', 'contract_version', 'CONTRACT')):
            observation, packet, context = inputs()
            del packet[section][key]
            self.held(observation, packet, context, code)
            self.assertNotIn(key, packet[section])
        observation, packet, context = inputs()
        del packet['policy_binding']
        self.held(observation, packet, context, 'POLICY_DRIFT')
        self.assertNotIn('policy_binding', packet)

    def test_reviewer_resolution_and_independence_required(self):
        for reviewer in ('', 'unknown', None, 'TEST-AUTHOR', {}):
            observation, packet, context = inputs()
            context['receipt_binding']['reviewer_id'] = reviewer
            self.held(observation, packet, context, 'REVIEWER_BINDING')
        observation, packet, context = inputs()
        context['receipt_binding']['review_receipt_id'] = 'OTHER-REVIEW'
        self.held(observation, packet, context, 'REVIEW_RECEIPT_BINDING')

    def test_binding_read_time_must_be_fresh_and_follow_observation(self):
        for offset in (-301, -16, -5, 1):
            observation, packet, context = inputs()
            context['receipt_binding']['read_at'] = time(offset)
            self.held(observation, packet, context, 'BINDING_FRESHNESS')
        for value in (None, 0, True, '300'):
            observation, packet, context = inputs()
            context['max_evidence_age_seconds'] = value
            self.held(observation, packet, context, 'BINDING_FRESHNESS')

    def test_unknown_duplicate_and_exception_checks_are_not_empty(self):
        for key, code in (('idempotency_readback', 'IDEMPOTENCY_UNKNOWN'),
                          ('open_exceptions', 'OPEN_EXCEPTION')):
            observation, packet, context = inputs()
            del context[key]
            self.held(observation, packet, context, code)
            self.assertNotIn(key, context)

    def test_original_duplicate_never_emits_a_second_candidate(self):
        observation, packet, context = inputs()
        bind_original(packet, context)
        self.held(observation, packet, context, 'DUPLICATE_REUSE_ONLY')

    def test_replayed_without_original_proof_stays_held(self):
        observation, packet, context = inputs()
        packet['lifecycle']['processing_status'] = 'REPLAYED'
        context['receipt_binding']['packet_sha256'] = gate.subject_digest(packet)
        self.held(observation, packet, context, 'REPLAY_PROOF_REQUIRED')

    def test_forged_authentication_flags_never_promote_runtime_status(self):
        observation, packet, context = inputs()
        for value in (observation, packet, context):
            value['authentication_verified'] = True
            value['production_verified'] = True
            value['execution_authorized'] = True
        context['receipt_binding']['observation_sha256'] = stock.digest(observation)
        context['receipt_binding']['packet_sha256'] = gate.subject_digest(packet)
        candidate, result = self.check(observation, packet, context)
        self.assertIsNotNone(candidate)
        self.assertEqual(result['verdict'], 'STRUCTURE_PASS')
        self.assertEqual(result['runtime_status'], 'HOLD_UNAUTHENTICATED')
        for field in ('authentication_verified', 'production_verified', 'execution_authorized'):
            self.assertFalse(result[field])

    def test_adapter_never_recompletes_or_rebinds_research(self):
        observation, packet, context = inputs()
        with patch.object(stock, 'finalize', side_effect=AssertionError('must not complete')):
            candidate, result = self.check(observation, packet, context)
        self.assertEqual(result['verdict'], 'STRUCTURE_PASS', result)
        self.assertEqual(candidate['research_packet'], packet['research_packet'])

    def test_missing_policy_files_fail_closed(self):
        with tempfile.TemporaryDirectory() as folder:
            candidate, result = adapter.adapt(*inputs(), now=NOW, root=Path(folder))
        self.assertIsNone(candidate)
        self.assertEqual(result['verdict'], 'HOLD')
        self.assertEqual(result['gate_result']['errors'][0]['code'], 'POLICY_OR_PAYLOAD')
        self.assertNotIn(str(folder), json.dumps(result))

    def test_nested_policy_exceptions_do_not_expose_private_text(self):
        values = inputs()
        private = '/private/SYNTHETIC-PATH https://example.invalid/?token=SYNTHETIC-TOKEN'
        for exception in (OSError, ValueError, TypeError):
            with self.subTest(exception=exception.__name__):
                with patch.object(gate, 'binding', side_effect=exception(private)):
                    result = self.held(*values, code='POLICY_OR_PAYLOAD')
                self.assertNotIn(private, json.dumps(result))
                self.assertNotIn('SYNTHETIC-', json.dumps(result))

    def test_nested_stock_exceptions_do_not_expose_private_text(self):
        values = inputs()
        private = 'C:\\private\\SYNTHETIC-PATH https://example.invalid/SYNTHETIC-TOKEN'
        for exception in (OSError, ValueError, TypeError, AttributeError):
            with self.subTest(exception=exception.__name__):
                with patch.object(stock, 'validate', side_effect=exception(private)):
                    result = self.held(*values, code='STOCK_REVIEW')
                self.assertNotIn('SYNTHETIC-', json.dumps(result))

    def test_nested_stock_messages_are_not_copied_even_as_objects(self):
        values = inputs()
        messages = ['SYNTHETIC-BUSINESS-TEXT', {'nested': ['SYNTHETIC-PRIVATE-URL']}]
        with patch.object(stock, 'validate', return_value=messages):
            result = self.held(*values, code='STOCK_REVIEW')
        self.assertEqual(len(result['gate_result']['errors']), 2)
        self.assertNotIn('SYNTHETIC-', json.dumps(result))

    def test_projection_drops_unknown_fields_and_untrusted_error_codes(self):
        values = inputs()
        checked = gate.evaluate(values[1], values[2], now=NOW)
        checked['verdict'] = 'HOLD'
        checked['SYNTHETIC-SECRET-KEY'] = {'value': 'SYNTHETIC-SECRET-VALUE'}
        checked['errors'] = [
            {'code': 'POLICY_OR_PAYLOAD', 'detail': {'nested': 'SYNTHETIC-DETAIL'},
             'traceback': 'SYNTHETIC-TRACEBACK'},
            {'code': 'SYNTHETIC_SECRET_CODE', 'detail': 'SYNTHETIC-DETAIL'},
            {'code': {'unexpected': 'SYNTHETIC-SECRET'}},
            'SYNTHETIC-INVALID-ISSUE',
        ]
        before = copy.deepcopy(checked)
        with patch.object(gate, 'evaluate', return_value=checked):
            result = self.held(*values, code='POLICY_OR_PAYLOAD')
        self.assertEqual(checked, before)
        self.assertNotIn('SYNTHETIC', json.dumps(result))
        self.assertEqual([issue['code'] for issue in result['gate_result']['errors']],
                         ['POLICY_OR_PAYLOAD'] + ['GATE_DIAGNOSTIC'] * 3)
        self.assertEqual(set(result['gate_result']),
                         {'protocol', 'phase', 'verdict', 'execution_authorized',
                          'production_verified', 'canonical_state_changed', 'errors'})

    def test_malformed_or_contradictory_gate_reports_fail_closed(self):
        values = inputs()
        valid = gate.evaluate(values[1], values[2], now=NOW)
        changes = [('protocol', 'SYNTHETIC-SECRET'), ('phase', 'SYNTHETIC-SECRET'),
                   ('verdict', 'SYNTHETIC-SECRET'), ('errors', 'SYNTHETIC-SECRET'),
                   ('errors', [{'code': 'STOCK_REVIEW', 'detail': 'SYNTHETIC-SECRET'}]),
                   ('verdict', 'HOLD'), ('execution_authorized', True),
                   ('production_verified', True), ('canonical_state_changed', True)]
        malformed = [None, [], 'SYNTHETIC-SECRET', {},
                     *[dict(valid, **{key: value}) for key, value in changes]]
        for checked in malformed:
            with self.subTest(checked=checked):
                with patch.object(gate, 'evaluate', return_value=checked):
                    result = self.held(*values, code='GATE_INPUT')
                self.assertIsNone(result['gate_result'])
                self.assertNotIn('SYNTHETIC-', json.dumps(result))

    def test_privacy_projection_preserves_gate_decisions_and_code_order(self):
        for mutate in (lambda packet, context: None,
                       lambda packet, context: context.pop('idempotency_readback'),
                       lambda packet, context: context.update(allowed_profiles=[]),
                       lambda packet, context: packet.update(environment='live')):
            observation, packet, context = inputs()
            mutate(packet, context)
            context['receipt_binding']['packet_sha256'] = gate.subject_digest(packet)
            original = gate.evaluate(packet, context, now=NOW)
            before = copy.deepcopy((observation, packet, context))
            candidate, result = self.check(observation, packet, context)
            self.assertEqual(result['verdict'], original['verdict'])
            self.assertEqual(result['gate_result']['verdict'], original['verdict'])
            self.assertEqual([issue['code'] for issue in result['gate_result']['errors']],
                             [issue['code'] for issue in original['errors']])
            self.assertEqual((observation, packet, context), before)
            if original['verdict'] == 'HOLD':
                self.assertIsNone(candidate)
            else:
                self.assertEqual(candidate, packet)

    def test_diagnostic_code_allowlist_covers_current_gate(self):
        tree = ast.parse((ROOT / 'scripts/kernel_integration_gate.py').read_text())
        codes = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
                if node.func.id == 'need' and len(node.args) >= 2:
                    self.assertIsInstance(node.args[1], ast.Constant)
                    codes.add(node.args[1].value)
            if isinstance(node, ast.Dict):
                for key, value in zip(node.keys, node.values):
                    if isinstance(key, ast.Constant) and key.value == 'code':
                        if isinstance(value, ast.Constant):
                            codes.add(value.value)
                        else:
                            self.assertIsInstance(value, ast.Name)
                            self.assertEqual(value.id, 'code')
        self.assertTrue(codes <= adapter.GATE_DIAGNOSTIC_CODES,
                        codes - adapter.GATE_DIAGNOSTIC_CODES)

    def test_cli_nested_failures_are_private_on_stdout_and_stderr(self):
        values = inputs()
        before = copy.deepcopy(values)
        private = '/private/SYNTHETIC-PATH https://example.invalid/?key=SYNTHETIC-TOKEN'
        for target, method, code in ((gate, 'binding', 'POLICY_OR_PAYLOAD'),
                                     (stock, 'validate', 'STOCK_REVIEW')):
            stdout, stderr = io.StringIO(), io.StringIO()
            with patch.object(stock, 'read_json', side_effect=values), \
                    patch.object(target, method, side_effect=OSError(private)), \
                    patch.object(sys, 'stdout', stdout), patch.object(sys, 'stderr', stderr):
                status = adapter.main(['observation.json', '--packet', 'packet.json',
                                       '--context', 'context.json'])
            self.assertEqual(status, 1)
            report = json.loads(stdout.getvalue())
            self.assertEqual(report['verdict'], 'HOLD')
            self.assertIn(code, [issue['code'] for issue in report['gate_result']['errors']])
            self.assertNotIn('SYNTHETIC-', stdout.getvalue() + stderr.getvalue())
            self.assertEqual(stderr.getvalue(), '')
            self.assertEqual(values, before)

    def test_existing_gate_is_called_and_its_hold_obeyed(self):
        observation, packet, context = inputs()
        with patch.object(gate, 'evaluate', wraps=gate.evaluate) as check:
            self.check(observation, packet, context)
            check.assert_called_once_with(packet, context, 'preflight', now=NOW, root=gate.ROOT)
        context['allowed_profiles'] = []
        self.held(observation, packet, context, 'AUTHORITY')

    def test_malformed_nested_data_holds_instead_of_crashing(self):
        observation, packet, context = inputs()
        packet['classification']['decoder'] = {'unexpected': 'shape'}
        self.held(observation, packet, context)
        packet['research_packet']['metrics']['valuation']['status'] = []
        self.held(observation, packet, context)

    def test_unknown_event_fields_and_replay_digest_remain_unchanged(self):
        observation, packet, context = inputs()
        packet['future_field'] = {'immutable': 'test'}
        packet['lifecycle']['future_timestamp'] = time(-100)
        context['receipt_binding']['packet_sha256'] = gate.subject_digest(packet)
        candidate, result = self.check(observation, packet, context)
        self.assertEqual(result['verdict'], 'STRUCTURE_PASS', result)
        self.assertEqual(gate.subject_digest(candidate), gate.subject_digest(packet))
        self.assertEqual(gate.intent_digest(candidate), gate.intent_digest(packet))

    def test_repeat_is_deterministic_without_input_mutation(self):
        values = inputs()
        before = copy.deepcopy(values)
        self.assertEqual(self.check(*values), self.check(*values))
        self.assertEqual(values, before)

    def test_cli_emits_report_not_private_payload(self):
        with tempfile.TemporaryDirectory() as folder:
            paths = [Path(folder) / name for name in ('observation.json', 'packet.json', 'context.json')]
            values = inputs()
            for path, value in zip(paths, values):
                path.write_text(json.dumps(value), encoding='utf-8')
            command = [sys.executable, '-B', str(ROOT / 'scripts/research_receipt_adapter.py'),
                       str(paths[0]), '--packet', str(paths[1]), '--context', str(paths[2])]
            result = subprocess.run(command, capture_output=True, text=True, check=False)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            output = json.loads(result.stdout)
            self.assertEqual(output['verdict'], 'STRUCTURE_PASS')
            for value in ('TEST-RECEIPT', 'TEST-REVIEWER', 'test:native-receipt', str(folder)):
                self.assertNotIn(value, result.stdout)
            self.assertEqual([stock.read_json(path) for path in paths], list(values))

    def test_cli_missing_invalid_duplicate_and_nonfinite_json_hold(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'private-input.json'
            command = [sys.executable, '-B', str(ROOT / 'scripts/research_receipt_adapter.py'), str(path)]
            for value in (None, '{bad', '{"a":1,"a":2}', '{"secret":"PRIVATE-VALUE","n":NaN}'):
                if value is not None:
                    path.write_text(value, encoding='utf-8')
                result = subprocess.run(command, capture_output=True, text=True, check=False)
                self.assertEqual(result.returncode, 1)
                self.assertEqual(json.loads(result.stdout)['errors'][0]['code'], 'INPUT')
                self.assertNotIn('PRIVATE-VALUE', result.stdout + result.stderr)
                self.assertNotIn(str(folder), result.stdout + result.stderr)

    def test_source_has_no_network_database_writer_or_completion_capability(self):
        source = (ROOT / 'scripts/research_receipt_adapter.py').read_text()
        tree = ast.parse(source)
        imports = {name.name for node in ast.walk(tree) if isinstance(node, ast.Import) for name in node.names}
        imports.update(node.module for node in ast.walk(tree) if isinstance(node, ast.ImportFrom))
        self.assertEqual(imports, {'argparse', 'copy', 'json', 'sys', 'datetime', 'pathlib',
                                   'kernel_integration_gate', 'stock_review_gate'})
        forbidden = {'finalize', 'write_new', 'write_text', 'write_bytes', 'open', 'connect',
                     'urlopen', 'request', 'system', 'Popen', 'uuid4', 'execute', 'commit'}
        for node in ast.walk(tree):
            if isinstance(node, ast.Call):
                name = node.func.attr if isinstance(node.func, ast.Attribute) else getattr(node.func, 'id', None)
                self.assertNotIn(name, forbidden)


if __name__ == '__main__':
    unittest.main()
