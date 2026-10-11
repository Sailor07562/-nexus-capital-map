"""Synthetic contracts only; no source truth, production, or money movement."""
import copy
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
import kernel_integration_gate as gate
import stock_review_gate as stock

stock_test_spec = importlib.util.spec_from_file_location('stock_fixtures', ROOT / 'tests/test_stock_review_gate.py')
stock_fixtures = importlib.util.module_from_spec(stock_test_spec)
stock_test_spec.loader.exec_module(stock_fixtures)
NOW = datetime.now(timezone.utc).replace(microsecond=0)


def time(offset=0):
    return (NOW + timedelta(seconds=offset)).isoformat().replace('+00:00', 'Z')


def bind_readbacks(packet, context):
    checksum = gate.subject_digest(packet)
    context['independent_review']['packet_sha256'] = checksum
    context['canonical_readback']['packet_sha256'] = checksum


def bind_original(packet, context):
    """Synthetic original-event readback, never an authenticated runtime proof."""
    canonical = context['canonical_readback']
    context['idempotency_readback'] = {
        'event_id': packet['identity']['event_id'],
        'idempotency_key': packet['identity']['idempotency_key'],
        'intent_sha256': gate.intent_digest(packet),
        'record_ref': canonical['record_ref'], 'version': canonical['version'],
        'authority_ref': canonical['authority_ref'],
        'read_at': time(-15), 'evidence_refs': ['test:original-readback']}


def fixture(profile='dot_intake'):
    identity = {'event_id': '00000000-0000-4000-8000-000000000001',
                'correlation_id': '00000000-0000-4000-8000-000000000002',
                'causation_id': None, 'mission_id': 'TEST-MISSION', 'object_id': 'TEST-OBJECT',
                'source_system': 'test-fixture', 'source_record_id': 'TEST-SOURCE',
                'source_version': '1', 'idempotency_key': 'test-only-key'}
    classification = {'item_type': 'TEST-EVIDENCE', 'event_family': 'TEST-FAMILY',
                      'lane_id': 'TEST-LANE', 'protocol_id': 'TEST-PROTOCOL', 'owner_id': 'TEST-OWNER',
                      'tags': ['#TEST'], 'purpose': 'Synthetic integration test', 'decoder': 'signal'}
    packet = {'schema_version': 1, 'policy_binding': gate.binding(), 'profile': profile,
              'operation': gate.PROFILES[profile][0], 'authority': gate.PROFILES[profile][1],
              'environment': 'sandbox', 'requested_effect': 'validate_only',
              'identity': identity, 'actor_id': 'TEST-AUTHOR', 'actor_role': 'dot',
              'classification': classification, 'expected_revision': 1,
              'evidence_refs': ['test:evidence:1'],
              'lifecycle': {'contract_version': gate.CONTRACT, 'processing_status': 'PROCESSED',
                            'review_status': 'APPROVED', 'reconciliation_status': 'MATCHED',
                            'error_status': 'NONE', 'verification_state': 'STRUCTURALLY_VERIFIED',
                            'occurred_at': time(-90), 'received_at': time(-80), 'processed_at': time(-60)}}
    if profile == 'research_completion':
        packet['research_packet'] = stock.finalize(stock_fixtures.evidence_packet())
    if profile in ('exception_resolution', 'decision_memory'):
        packet['outcome_link'] = {'original_record_ref': 'test:original',
                                 'expected_result': 'Synthetic expected outcome',
                                 'actual_result': 'Synthetic observed outcome',
                                 'interpretation': 'Synthetic comparison, not a financial decision',
                                 'next_review_trigger': 'A new verified result',
                                 'evidence_refs': ['test:outcome:1']}
    context = {'policy_binding': gate.binding(), 'environment': 'sandbox',
               'authenticated_actor_id': 'TEST-AUTHOR', 'authenticated_actor_role': 'dot',
               'allowed_profiles': [profile], 'authority_refs': ['test:authority'],
               'route': {**classification, 'profile': profile, 'evidence_refs': ['test:route'],
                         'canonical_authority_ref': 'test:existing-authority',
                         'required_mirrors': ['tracker', 'airtable', 'notion', 'drive'],
                         'mirror_policy_refs': ['test:applicability']},
               'current_revision': 1, 'observed_at': time(-10),
               'max_evidence_age_seconds': 300, 'freshness_policy_refs': ['test:freshness'],
               'submission_state': 'NOT_APPLICABLE', 'idempotency_readback': None, 'open_exceptions': [],
               'independent_review': {'reviewer_id': 'TEST-REVIEWER', 'verdict': 'PASS',
                                      'reviewed_at': time(-40), 'evidence_refs': ['test:review']},
               'canonical_readback': {'event_id': identity['event_id'], 'mission_id': identity['mission_id'],
                                      'idempotency_key': identity['idempotency_key'], 'record_ref': 'test:canonical',
                                      'version': '1', 'authority_ref': 'test:existing-authority',
                                      'read_at': time(-30), 'evidence_refs': ['test:canonical-read']},
               'mirror_readbacks': []}
    for name in context['route']['required_mirrors']:
        context['mirror_readbacks'].append({
            'surface': name, 'event_id': identity['event_id'], 'mission_id': identity['mission_id'],
            'canonical_version': '1', 'record_ref': 'test:' + name, 'status': 'MATCHED',
            'expected_projection_sha256': 'a' * 64, 'observed_projection_sha256': 'a' * 64,
            'mapping_refs': ['test:mapping:1'], 'evidence_refs': ['test:readback:' + name], 'read_at': time(-20)})
    if profile == 'ct_receipt_ingestion':
        context['financial_readback'] = {'event_id': identity['event_id'], 'status': 'RECONCILED',
                                         'evidence_refs': ['test:existing-financial-receipt']}
    bind_readbacks(packet, context)
    return packet, context


class KernelIntegrationTests(unittest.TestCase):
    def check(self, packet, context, phase='closure'):
        return gate.evaluate(packet, context, phase, now=NOW)

    def held(self, packet, context, code=None, phase='closure'):
        result = self.check(packet, context, phase)
        self.assertEqual(result['verdict'], 'HOLD', result)
        self.assertFalse(result['execution_authorized'])
        self.assertFalse(result['production_verified'])
        if code:
            self.assertIn(code, [x['code'] for x in result['errors']], result)

    def test_all_eight_profiles_close_only_structurally(self):
        self.assertEqual(gate.PROTOCOL, 'NEXUS-KERNEL-INTEGRATION-CHECK-v2')
        self.assertEqual(gate.CONTRACT, 'NEXUS-INTEGRATION-CONTRACT-v1')
        self.assertEqual(len(gate.PROFILES), 8)
        for profile in gate.PROFILES:
            with self.subTest(profile=profile):
                packet, context = fixture(profile)
                before = copy.deepcopy((packet, context))
                result = self.check(packet, context)
                self.assertEqual(result['verdict'], 'STRUCTURE_PASS', result)
                self.assertFalse(result['execution_authorized'])
                self.assertFalse(result['production_verified'])
                self.assertFalse(result['canonical_state_changed'])
                self.assertEqual((packet, context), before)

    def test_preflight_can_validate_incomplete_work_but_not_close_it(self):
        packet, context = fixture()
        packet['lifecycle'].update(processing_status='RECEIVED', review_status='PENDING',
                                   reconciliation_status='PENDING', processed_at=None)
        self.assertEqual(self.check(packet, context, 'preflight')['verdict'], 'STRUCTURE_PASS')
        self.held(packet, context, 'STATE')

    def test_missing_classification_fields_hold(self):
        for field in ('item_type', 'event_family', 'lane_id', 'protocol_id', 'owner_id', 'tags', 'purpose', 'decoder'):
            packet, context = fixture()
            del packet['classification'][field]
            with self.subTest(field=field):
                self.held(packet, context, phase='preflight')

    def test_forged_route_and_role_hold(self):
        packet, context = fixture()
        packet['classification']['lane_id'] = 'another-lane'
        self.held(packet, context, 'ROUTE')
        packet, context = fixture()
        packet['actor_role'] = 'captain'
        self.held(packet, context, 'ACTOR')

    def test_missing_runtime_authority_holds(self):
        packet, context = fixture()
        context['allowed_profiles'] = []
        self.held(packet, context, 'AUTHORITY')

    def test_broker_operations_never_pass_any_profile(self):
        for profile in gate.PROFILES:
            for operation in ('submit_order', 'prepare_order', 'cancel_order', 'replace_order',
                              'transfer', 'change_risk_caps', 'activate', 'retry_submission'):
                packet, context = fixture(profile)
                packet['operation'] = operation
                with self.subTest(profile=profile, operation=operation):
                    self.held(packet, context, 'OPERATION', 'preflight')

    def test_live_environment_never_self_certifies(self):
        packet, context = fixture()
        packet['environment'] = context['environment'] = 'live'
        context['production_verified'] = True
        self.held(packet, context, 'LIVE_BINDING_REQUIRED', 'preflight')

    def test_environment_mismatch_holds(self):
        packet, context = fixture()
        context['environment'] = 'live'
        self.held(packet, context, 'ENVIRONMENT')

    def test_mutating_effect_holds(self):
        packet, context = fixture()
        packet['requested_effect'] = 'write'
        self.held(packet, context, 'EFFECT')

    def test_missing_and_changed_policy_hold(self):
        packet, context = fixture()
        packet['policy_binding'] = {}
        self.held(packet, context, 'POLICY_DRIFT')
        packet, context = fixture()
        with tempfile.TemporaryDirectory() as directory:
            result = gate.evaluate(packet, context, root=Path(directory), now=NOW)
            self.assertEqual(result['verdict'], 'HOLD')
            self.assertEqual(result['errors'][0]['code'], 'POLICY_OR_PAYLOAD')

    def test_on_disk_policy_change_holds_even_if_packet_unchanged(self):
        packet, context = fixture()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in gate.POLICY_FILES:
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes((ROOT / name).read_bytes())
            target.write_text(target.read_text() + '\nSynthetic changed policy\n')
            result = gate.evaluate(packet, context, root=root, now=NOW)
            self.assertEqual(result['verdict'], 'HOLD')

    def test_stale_future_and_missing_runtime_snapshots_hold(self):
        for observed in (time(-301), time(1), None, '2026-10-11T07:00:00'):
            packet, context = fixture()
            context['observed_at'] = observed
            with self.subTest(observed=observed):
                self.held(packet, context, phase='preflight')

    def test_unapproved_freshness_bound_holds(self):
        for value in (True, 0, -1, '300', None):
            packet, context = fixture()
            context['max_evidence_age_seconds'] = value
            self.held(packet, context, 'FRESHNESS_POLICY')

    def test_clock_and_event_order_hold(self):
        packet, context = fixture()
        packet['lifecycle']['occurred_at'] = time(1)
        self.held(packet, context, 'TIME_ORDER')
        with self.assertRaises(ValueError):
            gate.evaluate(packet, context, now=datetime.now())

    def test_revision_conflicts_and_bool_hold(self):
        for value in (2, True, None):
            packet, context = fixture()
            context['current_revision'] = value
            self.held(packet, context, 'REVISION', 'preflight')

    def test_all_non_applicable_submission_states_hold(self):
        for state in ('SUBMISSION_UNKNOWN', 'SUBMITTED', 'FAILED', 'FILLED', None):
            packet, context = fixture()
            context['submission_state'] = state
            self.held(packet, context, 'SUBMISSION_HOLD', 'preflight')

    def test_duplicate_preflight_never_allows_second_execution(self):
        packet, context = fixture()
        bind_original(packet, context)
        self.held(packet, context, 'DUPLICATE_REUSE_ONLY', 'preflight')
        self.assertEqual(self.check(packet, context)['verdict'], 'STRUCTURE_PASS')

    def test_conflicting_replay_holds(self):
        packet, context = fixture()
        bind_original(packet, context)
        context['idempotency_readback']['intent_sha256'] = 'b' * 64
        self.held(packet, context, 'IDEMPOTENCY_CONFLICT')

    def test_replay_identity_survives_lifecycle_and_revision_updates(self):
        packet, context = fixture()
        original = copy.deepcopy(packet)
        original['lifecycle']['processing_status'] = 'RECEIVED'
        original['expected_revision'] = 0
        bind_original(original, context)
        self.assertEqual(self.check(packet, context)['verdict'], 'STRUCTURE_PASS')
        packet['evidence_refs'] = ['test:changed-immutable-evidence']
        bind_readbacks(packet, context)
        self.held(packet, context, 'IDEMPOTENCY_CONFLICT')

    def test_changed_original_timestamp_conflicts_for_every_profile(self):
        for profile in gate.PROFILES:
            for phase in ('preflight', 'closure'):
                packet, context = fixture(profile)
                bind_original(packet, context)
                packet['lifecycle']['occurred_at'] = time(-100)
                bind_readbacks(packet, context)
                with self.subTest(profile=profile, phase=phase):
                    self.held(packet, context, 'IDEMPOTENCY_CONFLICT', phase)

    def test_source_times_contract_and_unknown_lifecycle_fields_are_hashed(self):
        packet, _ = fixture()
        before = gate.intent_digest(packet)
        for field, value in (('occurred_at', time(-100)), ('received_at', time(-85)),
                             ('contract_version', 'different-contract'),
                             ('unknown_source_field', 'not-mutable-by-default')):
            changed = copy.deepcopy(packet)
            changed['lifecycle'][field] = value
            with self.subTest(field=field):
                self.assertNotEqual(gate.intent_digest(changed), before)
        self.assertEqual(gate.intent_digest(packet), before)

    def test_only_explicit_progress_fields_and_revision_are_mutable_in_digest(self):
        packet, _ = fixture()
        before = gate.intent_digest(packet)
        for field, value in (('processing_status', 'REPLAYED'), ('review_status', 'PENDING'),
                             ('reconciliation_status', 'PENDING'), ('error_status', 'TRANSIENT'),
                             ('verification_state', 'UNVERIFIED'), ('processed_at', time(-50))):
            changed = copy.deepcopy(packet)
            changed['lifecycle'][field] = value
            with self.subTest(field=field):
                self.assertEqual(gate.intent_digest(changed), before)
                self.assertNotEqual(gate.subject_digest(changed), gate.subject_digest(packet))
        changed = copy.deepcopy(packet)
        changed['expected_revision'] += 1
        self.assertEqual(gate.intent_digest(changed), before)

    def test_legacy_lifecycle_omitting_digest_is_not_accepted(self):
        packet, context = fixture()
        bind_original(packet, context)
        context['idempotency_readback']['intent_sha256'] = stock.digest({
            key: value for key, value in packet.items()
            if key not in ('lifecycle', 'expected_revision')})
        self.held(packet, context, 'IDEMPOTENCY_CONFLICT')

    def test_replayed_requires_original_readback_for_every_profile_and_phase(self):
        for profile in gate.PROFILES:
            for phase in ('preflight', 'closure'):
                packet, context = fixture(profile)
                packet['lifecycle']['processing_status'] = 'REPLAYED'
                bind_readbacks(packet, context)
                with self.subTest(profile=profile, phase=phase):
                    self.held(packet, context, 'REPLAY_PROOF_REQUIRED', phase)

    def test_replayed_with_missing_or_malformed_original_readback_holds(self):
        for value in (None, {}, [], False, 1, 'claimed-proof'):
            packet, context = fixture()
            packet['lifecycle']['processing_status'] = 'REPLAYED'
            context['idempotency_readback'] = value
            bind_readbacks(packet, context)
            with self.subTest(value=value):
                self.held(packet, context)
        del context['idempotency_readback']
        self.held(packet, context, 'IDEMPOTENCY_UNKNOWN')

    def test_replayed_original_proof_permits_only_structural_closure(self):
        for profile in gate.PROFILES:
            packet, context = fixture(profile)
            bind_original(packet, context)
            packet['lifecycle']['processing_status'] = 'REPLAYED'
            packet['lifecycle']['processed_at'] = time(-50)
            packet['expected_revision'] = context['current_revision'] = 2
            context['canonical_readback']['version'] = '2'
            for mirror in context['mirror_readbacks']:
                mirror['canonical_version'] = '2'
            bind_readbacks(packet, context)
            with self.subTest(profile=profile):
                before = copy.deepcopy((packet, context))
                result = self.check(packet, context)
                self.assertEqual(result['verdict'], 'STRUCTURE_PASS', result)
                for key in ('execution_authorized', 'production_verified', 'canonical_state_changed'):
                    self.assertIs(result[key], False)
                self.assertEqual((packet, context), before)
                self.held(packet, context, 'DUPLICATE_REUSE_ONLY', 'preflight')

    def test_original_readback_identity_and_digest_must_match(self):
        for field, value in (('event_id', '00000000-0000-4000-8000-000000000099'),
                             ('idempotency_key', 'different-key'), ('intent_sha256', 'b' * 64)):
            packet, context = fixture()
            bind_original(packet, context)
            context['idempotency_readback'][field] = value
            self.held(packet, context, 'IDEMPOTENCY_CONFLICT')

    def test_original_readback_requires_locator_version_and_authority(self):
        for field, value, code in (('record_ref', None, 'IDEMPOTENCY_LOCATOR'),
                                   ('version', None, 'IDEMPOTENCY_LOCATOR'),
                                   ('authority_ref', None, 'IDEMPOTENCY_AUTHORITY'),
                                   ('authority_ref', 'other-authority', 'IDEMPOTENCY_AUTHORITY')):
            packet, context = fixture()
            bind_original(packet, context)
            context['idempotency_readback'][field] = value
            with self.subTest(field=field, value=value):
                self.held(packet, context, code)

    def test_original_readback_requires_fresh_timestamp_and_evidence(self):
        for field, value, code in (('read_at', time(-301), 'STALE'),
                                   ('read_at', time(1), 'FUTURE'),
                                   ('read_at', None, 'TIMESTAMP'),
                                   ('evidence_refs', [], 'EVIDENCE')):
            packet, context = fixture()
            bind_original(packet, context)
            context['idempotency_readback'][field] = value
            with self.subTest(field=field, value=value):
                self.held(packet, context, code)

    def test_original_and_current_canonical_record_must_match(self):
        packet, context = fixture()
        bind_original(packet, context)
        context['idempotency_readback']['record_ref'] = 'test:other-canonical'
        self.held(packet, context, 'IDEMPOTENCY_LOCATOR')

    def test_replayed_proof_never_lifts_live_hold(self):
        packet, context = fixture()
        packet['lifecycle']['processing_status'] = 'REPLAYED'
        packet['environment'] = context['environment'] = 'live'
        bind_original(packet, context)
        bind_readbacks(packet, context)
        self.held(packet, context, 'LIVE_BINDING_REQUIRED')

    def test_failed_rejected_conflicted_states_cannot_advance(self):
        for field, value in (('error_status', 'AUTHORITY'), ('processing_status', 'DEAD_LETTER'),
                             ('review_status', 'REJECTED'), ('reconciliation_status', 'CONFLICT')):
            packet, context = fixture()
            packet['lifecycle'][field] = value
            self.held(packet, context, phase='preflight')

    def test_unknown_duplicate_check_is_not_empty(self):
        packet, context = fixture()
        del context['idempotency_readback']
        self.held(packet, context, 'IDEMPOTENCY_UNKNOWN')

    def test_empty_identity_and_self_causation_hold(self):
        for key in ('mission_id', 'source_record_id', 'source_version', 'event_id', 'idempotency_key'):
            packet, context = fixture()
            packet['identity'][key] = ''
            self.held(packet, context, 'IDENTITY')
        packet, context = fixture()
        packet['identity']['causation_id'] = packet['identity']['event_id']
        self.held(packet, context, 'LINEAGE')

    def test_risk_and_hold_require_review_even_at_preflight(self):
        for decoder in ('risk', 'hold'):
            packet, context = fixture()
            packet['classification']['decoder'] = decoder
            self.held(packet, context, 'DECODER_HOLD', 'preflight')

    def test_unresolved_exceptions_cannot_close(self):
        packet, context = fixture()
        context['open_exceptions'] = ['TEST-MISSING-READBACK']
        self.held(packet, context, 'OPEN_EXCEPTION')

    def test_existing_stock_gate_is_used(self):
        packet, context = fixture('research_completion')
        packet['research_packet']['metrics']['valuation']['status'] = 'unknown'
        bind_readbacks(packet, context)
        self.held(packet, context, 'STOCK_REVIEW')

    def test_research_status_flip_does_not_bypass_stock_gate(self):
        packet, context = fixture('research_completion')
        packet['research_packet'] = stock.template('TEST')
        packet['research_packet']['status'] = 'complete'
        bind_readbacks(packet, context)
        self.held(packet, context, 'STOCK_REVIEW')

    def test_missing_or_same_reviewer_holds(self):
        packet, context = fixture()
        context['independent_review']['reviewer_id'] = packet['actor_id']
        self.held(packet, context, 'INDEPENDENCE')
        context['independent_review'] = None
        self.held(packet, context, 'INDEPENDENCE')

    def test_reviewer_disagreement_holds(self):
        packet, context = fixture()
        context['independent_review']['verdict'] = 'HOLD'
        self.held(packet, context, 'REVIEW')

    def test_unverified_work_cannot_close(self):
        packet, context = fixture()
        packet['lifecycle']['verification_state'] = 'UNVERIFIED'
        bind_readbacks(packet, context)
        self.held(packet, context, 'VERIFICATION')

    def test_post_review_packet_change_holds(self):
        packet, context = fixture()
        packet['classification']['purpose'] = 'Changed purpose'
        self.held(packet, context, 'REVIEW_BINDING')

    def test_canonical_identity_version_payload_and_authority_hold(self):
        for key, value, code in (('event_id', 'wrong', 'CANONICAL_IDENTITY'),
                                 ('version', None, 'CANONICAL_LOCATOR'),
                                 ('packet_sha256', 'b' * 64, 'CANONICAL_PAYLOAD'),
                                 ('authority_ref', 'other-authority', 'CANONICAL_AUTHORITY')):
            packet, context = fixture()
            context['canonical_readback'][key] = value
            self.held(packet, context, code)

    def test_canonical_readback_before_processing_holds(self):
        packet, context = fixture()
        context['canonical_readback']['read_at'] = time(-70)
        self.held(packet, context, 'TIME_ORDER')

    def test_every_required_mirror_is_checked(self):
        for index in range(4):
            packet, context = fixture()
            context['mirror_readbacks'].pop(index)
            self.held(packet, context, 'MIRROR_SET')

    def test_duplicate_and_extra_mirrors_hold(self):
        packet, context = fixture()
        context['mirror_readbacks'].append(copy.deepcopy(context['mirror_readbacks'][0]))
        self.held(packet, context, 'MIRROR_SET')
        packet, context = fixture()
        context['mirror_readbacks'][0]['surface'] = 'unapproved-destination'
        self.held(packet, context, 'MIRROR_SET')

    def test_stale_or_changed_projection_holds(self):
        for key, value, code in (('canonical_version', '0', 'MIRROR_VERSION'),
                                 ('observed_projection_sha256', 'b' * 64, 'MIRROR_PAYLOAD'),
                                 ('read_at', time(-301), 'STALE')):
            packet, context = fixture()
            context['mirror_readbacks'][0][key] = value
            self.held(packet, context, code)

    def test_ack_does_not_equal_readback(self):
        packet, context = fixture()
        context['mirror_readbacks'][0]['status'] = 'ACK'
        self.held(packet, context, 'MIRROR_RECEIPT')

    def test_mirror_applicability_and_mapping_are_required(self):
        packet, context = fixture()
        context['route']['required_mirrors'] = []
        context['route']['mirror_policy_refs'] = []
        context['mirror_readbacks'] = []
        self.held(packet, context, 'EVIDENCE')
        packet, context = fixture()
        context['mirror_readbacks'][0]['mapping_refs'] = []
        self.held(packet, context, 'EVIDENCE')

    def test_ct_receipt_requires_existing_reconciliation(self):
        packet, context = fixture('ct_receipt_ingestion')
        context['financial_readback']['status'] = 'FILLED'
        self.held(packet, context, 'FINANCIAL_RECONCILIATION')

    def test_outcome_closure_cannot_omit_expectation_and_actual(self):
        for profile in ('exception_resolution', 'decision_memory'):
            for field in ('original_record_ref', 'expected_result', 'actual_result', 'next_review_trigger'):
                packet, context = fixture(profile)
                del packet['outcome_link'][field]
                bind_readbacks(packet, context)
                self.held(packet, context, 'OUTCOME_LINK')

    def test_only_bounded_nonfinancial_transient_retry_is_eligible(self):
        self.assertEqual(gate.retry_disposition('TRANSIENT', 0, 3, 'NOT_APPLICABLE'), 'BOUNDED_RETRY_ELIGIBLE')
        for error in ('AUTHORITY', 'CREDENTIAL', 'VALIDATION', 'CONFLICT', 'PERMANENT', 'UNKNOWN'):
            self.assertEqual(gate.retry_disposition(error, 0, 3, 'NOT_APPLICABLE'), 'HOLD_NO_RETRY')
        for state in ('SUBMISSION_UNKNOWN', 'FILLED', None):
            self.assertEqual(gate.retry_disposition('TRANSIENT', 0, 3, state), 'HOLD_NO_RETRY')
        for attempts in (3, 4, -1, True, None):
            self.assertEqual(gate.retry_disposition('TRANSIENT', attempts, 3, 'NOT_APPLICABLE'), 'HOLD_NO_RETRY')

    def test_malformed_nested_values_fail_closed_without_crashing(self):
        for field in ('identity', 'classification', 'lifecycle', 'profile', 'evidence_refs'):
            for value in (None, [], {}, 1, True):
                packet, context = fixture()
                packet[field] = value
                with self.subTest(field=field, value=value):
                    self.held(packet, context)
        for field in ('route', 'independent_review', 'canonical_readback', 'mirror_readbacks'):
            packet, context = fixture()
            context[field] = None
            self.held(packet, context)

    def test_non_object_and_invalid_phase_fail_closed(self):
        packet, context = fixture()
        self.held([], context, 'SHAPE')
        self.held(packet, [], 'SHAPE')
        self.held(packet, context, 'PHASE', 'execute')

    def test_cli_checks_input_without_mutating_files(self):
        packet, context = fixture()
        with tempfile.TemporaryDirectory() as directory:
            source, runtime = Path(directory) / 'packet.json', Path(directory) / 'context.json'
            source.write_text(json.dumps(packet))
            runtime.write_text(json.dumps(context))
            before = (source.read_bytes(), runtime.read_bytes())
            cmd = [sys.executable, str(ROOT / 'scripts/kernel_integration_gate.py'),
                   'closure', str(source), '--context', str(runtime)]
            result = subprocess.run(cmd, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(json.loads(result.stdout)['verdict'], 'STRUCTURE_PASS')
            self.assertEqual(before, (source.read_bytes(), runtime.read_bytes()))
            for bad in ('{', '{"schema_version":1,"schema_version":2}', '{"value":NaN}'):
                source.write_text(bad)
                result = subprocess.run(cmd, text=True, capture_output=True)
                self.assertEqual(result.returncode, 1)
                self.assertEqual(json.loads(result.stdout)['verdict'], 'HOLD')


if __name__ == '__main__':
    unittest.main()
