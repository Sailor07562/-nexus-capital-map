"""Synthetic source-only diagnostics; no account, policy or runtime proof."""
import copy
import json
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
import engine_readiness as readiness

NOW = datetime(2030, 1, 1, tzinfo=timezone.utc)


def stamp(offset=0):
    return (NOW + timedelta(seconds=offset)).isoformat().replace('+00:00', 'Z')


def fixture():
    snapshot = {'engine_id': 'TEST-ENGINE', 'engine_revision': '2', 'scope': 'paper', 'components': []}
    requirements = {'engine_id': 'TEST-ENGINE', 'engine_revision': '2', 'scope': 'paper', 'components': []}
    requirements['required_input_set'] = {
        'set_id': 'TEST-INPUT-SET', 'revision': '1', 'approval_ref': 'TEST-SET-APPROVAL',
        'approval_status': 'APPROVED', 'engine_id': 'TEST-ENGINE', 'engine_revision': '2', 'scope': 'paper'}
    for name in ('TEST-INTAKE', 'TEST-PORTFOLIO', 'TEST-EVIDENCE'):
        binding = {'component_id': name, 'component_kind': name, 'source_object': 'test.source_' + name,
                   'source_revision': '1', 'scope_ref': 'TEST-CURRENT-INPUTS-' + name,
                   'scope_revision': '3', 'timestamp_meaning': 'source_observation'}
        snapshot['components'].append({**binding, 'read_at': stamp(-1),
                                       'read_status': 'AVAILABLE', 'source_status': 'CLEAR',
                                       'required_source_times': [stamp(-20), stamp(-30)]})
        requirements['components'].append({**binding, 'required': True, 'empty_semantics': 'HOLD', 'freshness_rule': {
            'rule_id': 'TEST-AGE-' + name, 'revision': '4',
            'approval_ref': 'TEST-APPROVAL', 'approval_status': 'APPROVED',
            'max_age_seconds': 60}})
    snapshot['paper_boundary'] = {
        'parent_mode': 'paper_approval_gated',
        'policy': {'policy_id': 'TEST-POLICY', 'revision': '1', 'status': 'active',
                   'mode': 'human_approval_gated', 'requires_human_confirmation': True,
                   'connection_id': 'TEST-CONNECTION', 'environment': 'alpaca_paper',
                   'live_trading_enabled': False},
        'connection': {'connection_id': 'TEST-CONNECTION', 'revision': '1',
                       'requires_human_confirmation': True, 'order_submission_enabled': True,
                       'environment': 'alpaca_paper', 'live_trading_enabled': False},
    }
    requirements['paper_scope_resolution'] = {
        'decision_ref': 'TEST-SCOPE-DECISION', 'revision': '1',
        'approval_status': 'APPROVED', 'operation': 'paper_order_submission',
        'parent_mode': 'paper_approval_gated', 'policy_mode': 'human_approval_gated',
        'policy_id': 'TEST-POLICY', 'policy_revision': '1',
        'connection_id': 'TEST-CONNECTION', 'connection_revision': '1',
        'policy_requires_confirmation': True, 'connection_requires_confirmation': True,
        'connection_submission_enabled': True,
    }
    return snapshot, requirements


def live_fixture():
    snapshot, requirements = fixture()
    snapshot['scope'] = requirements['scope'] = 'ct_live'
    requirements['required_input_set']['scope'] = 'ct_live'
    template_snapshot = snapshot['components'][0]
    template_requirement = requirements['components'][0]
    snapshot['components'] = []
    requirements['components'] = []
    for kind in sorted(readiness.LIVE_COMPONENT_KINDS):
        s, r = copy.deepcopy((template_snapshot, template_requirement))
        for value in (s, r):
            value.update(component_id='TEST-' + kind, component_kind=kind,
                         source_object='test.' + kind, scope_ref='TEST-SCOPE-' + kind,
                         timestamp_meaning='read_receipt')
        snapshot['components'].append(s)
        requirements['components'].append(r)
        if kind == 'symbol_eligibility':
            s['required_source_times'] = [stamp(-30)]
            s['assets'] = [{'asset_id': 'TEST-ASSET-1', 'symbol': 'TEST1',
                            'asset_class': 'us_equity', 'status': 'active',
                            'tradable': True, 'fractionable': True, 'observed_at': stamp(-30)}]
            r['asset_scope'] = [{'asset_id': 'TEST-ASSET-1', 'symbol': 'TEST1',
                                 'approval_status': 'APPROVED', 'live_enabled': True,
                                 'approval_ref': 'TEST-ASSET-APPROVAL', 'approval_revision': '1',
                                 'fractional_required': True}]
    snapshot['live_boundary'] = {
        'environment': 'alpaca_live', 'route_id': 'TEST-LIVE-ROUTE', 'route_revision': '1',
        'operator_id': 'TEST-OPERATOR', 'reader_id': 'TEST-READER',
        'authority_ref': 'TEST-LIVE-AUTHORITY', **readiness.LIVE_CONTROLS}
    requirements['live_scope_resolution'] = {
        'decision_ref': 'TEST-LIVE-SCOPE', 'revision': '1', 'approval_status': 'APPROVED',
        'operation': 'ct_live_readiness',
        **{k: snapshot['live_boundary'][k] for k in readiness.LIVE_BINDING}}
    # A live observation does not need a paper policy or paper connection.
    del snapshot['paper_boundary']
    del requirements['paper_scope_resolution']
    return snapshot, requirements


class EngineReadinessTests(unittest.TestCase):
    def check(self, snapshot, requirements=None, at=None):
        result = readiness.project(snapshot, requirements, evaluated_at=stamp() if at is None else at)
        self.assertEqual(result['runtime_status'], 'HOLD_UNAUTHENTICATED')
        for key in ('authentication_verified', 'execution_authorized', 'production_verified',
                    'canonical_state_changed', 'broker_action_authorized', 'automatic_promotion'):
            self.assertIs(result[key], False)
        return result

    def held(self, snapshot, requirements=None, code=None, at=None):
        result = self.check(snapshot, requirements, at)
        self.assertEqual(result['verdict'], 'HOLD', result)
        if code:
            self.assertIn(code, [e['code'] for e in result['errors']], result)
        return result

    def test_consistent_inputs_have_no_runtime_authority_or_mutation(self):
        snapshot, requirements = fixture()
        original = copy.deepcopy((snapshot, requirements))
        result = self.check(snapshot, requirements)
        self.assertEqual(result['verdict'], 'STRUCTURE_PASS', result)
        self.assertEqual(result['errors'], [])
        self.assertTrue(all(c['freshness'] == 'FRESH' for c in result['components']))
        self.assertEqual(result['components'][0]['oldest_age_seconds'], 30)
        self.assertEqual(result['paper_boundary']['status'], 'CONSISTENT')
        result['components'][0]['component_id'] = 'MODIFIED-REPORT'
        self.assertEqual((snapshot, requirements), original)

    def test_live_scope_is_primary_without_any_paper_input(self):
        s, r = live_fixture()
        original = copy.deepcopy((s, r))
        result = self.check(s, r)
        self.assertEqual(result['verdict'], 'STRUCTURE_PASS', result)
        self.assertEqual(result['live_boundary']['status'], 'CONSISTENT')
        self.assertIsNone(result['paper_boundary'])
        self.assertEqual((s, r), original)

    def test_disabled_paper_connection_does_not_control_live_diagnostics(self):
        s, r = live_fixture()
        paper, paper_rules = fixture()
        paper['paper_boundary']['connection']['order_submission_enabled'] = False
        s['paper_boundary'] = paper['paper_boundary']
        r['paper_scope_resolution'] = paper_rules['paper_scope_resolution']
        result = self.check(s, r)
        self.assertEqual(result['verdict'], 'STRUCTURE_PASS', result)
        self.assertIsNone(result['paper_boundary'])

    def test_live_confirmation_cash_and_disabled_automation_controls_fail_closed(self):
        for key, expected in readiness.LIVE_CONTROLS.items():
            for value in (not expected, None, int(expected)):
                s, r = live_fixture()
                s['live_boundary'][key] = value
                self.held(s, r, 'LIVE_CONTROL_BOUNDARY')

    def test_live_identity_route_and_reader_must_match_separate_resolution(self):
        for key in readiness.LIVE_BINDING:
            s, r = live_fixture()
            s['live_boundary'][key] = 'TEST-OTHER'
            self.held(s, r, 'LIVE_SCOPE_UNRESOLVED')
        s, r = live_fixture()
        r['live_scope_resolution']['operation'] = 'live_order_submission'
        self.held(s, r, 'LIVE_SCOPE_UNRESOLVED')

    def test_live_scope_must_cover_all_five_input_categories(self):
        for kind in readiness.LIVE_COMPONENT_KINDS:
            s, r = live_fixture()
            s['components'] = [c for c in s['components'] if c['component_kind'] != kind]
            r['components'] = [c for c in r['components'] if c['component_kind'] != kind]
            self.held(s, r, 'LIVE_COMPONENT_COVERAGE')

    def test_fresh_failed_live_authentication_or_reconciliation_still_holds(self):
        for kind in ('command_authentication', 'receipt_reconciliation', 'symbol_eligibility'):
            s, r = live_fixture()
            c = next(c for c in s['components'] if c['component_kind'] == kind)
            c['source_status'] = 'BLOCKED'
            result = self.held(s, r, 'SOURCE_STATUS_BLOCKED')
            self.assertTrue(all(c['freshness'] == 'FRESH' for c in result['components']))

    def test_live_missing_policy_and_old_portfolio_remain_visible(self):
        s, r = live_fixture()
        index = next(i for i,c in enumerate(s['components']) if c['component_kind'] == 'portfolio_read')
        s['components'][index]['required_source_times'] = [stamp(-600)]
        self.held(s, r, 'SOURCE_STALE')
        del r['components'][index]['freshness_rule']
        c = self.held(s, r, 'FRESHNESS_RULE_UNRESOLVED')['components'][index]
        self.assertEqual(c['freshness'], 'UNASSESSED')
        self.assertEqual(c['oldest_age_seconds'], 600)

    def test_live_boundary_unknown_or_paper_environment_holds(self):
        s, r = live_fixture()
        self.held({**s, 'live_boundary': None}, r, 'LIVE_BOUNDARY_REQUIRED')
        s['live_boundary']['environment'] = 'alpaca_paper'
        self.held(s, r, 'LIVE_ENVIRONMENT')

    def test_live_and_paper_scope_cannot_be_silently_relabelled(self):
        s, r = live_fixture()
        r['scope'] = 'paper'
        result = self.held(s, r, 'OPERATION_SCOPE_UNRESOLVED')
        self.assertIsNone(result['live_boundary'])
        self.assertIsNone(result['paper_boundary'])

    def test_missing_source_status_cannot_be_inferred_from_fresh_timestamps(self):
        s, r = live_fixture()
        del s['components'][0]['source_status']
        self.held(s, r, 'SOURCE_STATUS_UNKNOWN')

    def test_input_set_approval_and_scope_are_required_before_freshness(self):
        for key, value in (('approval_status', 'PENDING'), ('revision', None),
                           ('approval_ref', None), ('scope', 'paper'), ('engine_revision', '0')):
            s, r = live_fixture()
            r['required_input_set'][key] = value
            result = self.held(s, r, 'INPUT_SET_UNRESOLVED')
            self.assertTrue(all(c['freshness'] == 'UNASSESSED' for c in result['components']))
            self.assertTrue(all(c['oldest_age_seconds'] == 30 for c in result['components']))

    def test_optional_empty_and_timestamp_semantics_are_never_guessed(self):
        for key, value in (('required', None), ('required', False), ('required', 1),
                           ('empty_semantics', None), ('empty_semantics', 'ALLOW'),
                           ('timestamp_meaning', 'last_modified')):
            s, r = live_fixture()
            r['components'][0][key] = value
            result = self.held(s, r, 'INPUT_SEMANTICS_UNRESOLVED')
            self.assertTrue(all(c['freshness'] == 'UNASSESSED' for c in result['components']))

    def test_empty_holdings_need_a_read_receipt_not_a_position_requirement(self):
        s, r = live_fixture()
        c = next(c for c in s['components'] if c['component_kind'] == 'portfolio_read')
        c['required_source_times'] = [stamp(-5)]
        c['positions'] = []
        result = self.check(s, r)
        self.assertEqual(result['verdict'], 'STRUCTURE_PASS', result)
        self.assertNotIn('positions', json.dumps(result))

    def test_new_stocks_are_data_driven_and_do_not_require_holdings(self):
        s, r = live_fixture()
        s['positions'] = []
        i = next(i for i,c in enumerate(s['components']) if c['component_kind'] == 'symbol_eligibility')
        for number, symbol in enumerate(('NEW2', 'NEXT.B', 'GROW-3'), start=2):
            asset = copy.deepcopy(s['components'][i]['assets'][0])
            rule = copy.deepcopy(r['components'][i]['asset_scope'][0])
            for item in (asset, rule):
                item.update(asset_id='TEST-ASSET-' + str(number), symbol=symbol)
            s['components'][i]['assets'].append(asset)
            s['components'][i]['required_source_times'].append(asset['observed_at'])
            r['components'][i]['asset_scope'].append(rule)
            result = self.check(s, r)
            self.assertEqual(result['verdict'], 'STRUCTURE_PASS', result)
            self.assertEqual(len(result['components'][i]['assets']), number)

    def test_broker_eligibility_does_not_create_nexus_live_approval(self):
        for key, value in (('live_enabled', False), ('approval_status', 'PENDING'),
                           ('approval_ref', None), ('approval_revision', None),
                           ('fractional_required', 1)):
            s, r = live_fixture()
            c = next(c for c in r['components'] if c['component_kind'] == 'symbol_eligibility')
            c['asset_scope'][0][key] = value
            self.held(s, r, 'ASSET_NOT_APPROVED')

    def test_inactive_untradable_wrong_class_and_fractional_mismatch_hold(self):
        for key, value, code in (
                ('status', 'inactive', 'BROKER_ASSET_INELIGIBLE'),
                ('tradable', False, 'BROKER_ASSET_INELIGIBLE'),
                ('tradable', 1, 'BROKER_ASSET_INELIGIBLE'),
                ('asset_class', 'crypto', 'BROKER_ASSET_INELIGIBLE'),
                ('fractionable', False, 'FRACTIONAL_ASSET_REQUIRED')):
            s, r = live_fixture()
            c = next(c for c in s['components'] if c['component_kind'] == 'symbol_eligibility')
            c['assets'][0][key] = value
            self.held(s, r, code)

    def test_whole_share_eligibility_does_not_require_fractionable(self):
        s, r = live_fixture()
        i = next(i for i,c in enumerate(s['components']) if c['component_kind'] == 'symbol_eligibility')
        s['components'][i]['assets'][0]['fractionable'] = False
        r['components'][i]['asset_scope'][0]['fractional_required'] = False
        self.assertEqual(self.check(s, r)['verdict'], 'STRUCTURE_PASS')

    def test_asset_identity_and_corporate_action_changes_need_new_binding(self):
        for key, value in (('asset_id', 'TEST-REPLACEMENT'), ('symbol', 'RENAMED')):
            s, r = live_fixture()
            c = next(c for c in s['components'] if c['component_kind'] == 'symbol_eligibility')
            c['assets'][0][key] = value
            self.held(s, r, 'ASSET_IDENTITY')

    def test_asset_times_cannot_hide_older_metadata_behind_fresh_summary(self):
        s, r = live_fixture()
        c = next(c for c in s['components'] if c['component_kind'] == 'symbol_eligibility')
        c['assets'][0]['observed_at'] = stamp(-600)
        self.held(s, r, 'ASSET_TIME_COVERAGE')
        c['required_source_times'] = [stamp(-600)]
        self.held(s, r, 'SOURCE_STALE')

    def test_asset_scope_missing_duplicate_or_missing_observed_member_holds(self):
        s, r = live_fixture()
        i = next(i for i,c in enumerate(s['components']) if c['component_kind'] == 'symbol_eligibility')
        rule = r['components'][i].pop('asset_scope')
        self.held(s, r, 'ASSET_SCOPE_UNRESOLVED')
        r['components'][i]['asset_scope'] = rule + copy.deepcopy(rule)
        self.held(s, r, 'ASSET_SCOPE_DUPLICATE')
        r['components'][i]['asset_scope'][-1]['asset_id'] = 'TEST-MISSING'
        self.held(s, r, 'ASSET_SET_MISMATCH')

    def test_private_asset_fields_and_invalid_symbols_are_not_emitted(self):
        s, r = live_fixture()
        c = next(c for c in s['components'] if c['component_kind'] == 'symbol_eligibility')
        c['assets'][0]['private_payload'] = {'token': 'PRIVATE-CANARY'}
        self.assertNotIn('PRIVATE-CANARY', json.dumps(self.check(s, r)))
        c['assets'][0]['symbol'] = '/PRIVATE-CANARY?token=secret'
        self.assertNotIn('PRIVATE-CANARY', json.dumps(self.held(s, r, 'ASSET_IDENTITY')))

    def test_new_intake_cannot_clear_stale_portfolio(self):
        s, r = fixture()
        s['components'][0]['required_source_times'] = [stamp(-2)]
        s['components'][1]['required_source_times'] = [stamp(-120)]
        result = self.held(s, r, 'SOURCE_STALE')
        self.assertEqual([c['freshness'] for c in result['components']], ['FRESH', 'STALE', 'FRESH'])

    def test_mixed_age_rows_use_oldest_required_input(self):
        s, r = fixture()
        s['components'][1]['required_source_times'] = [stamp(-2), stamp(-61)]
        c = self.held(s, r, 'SOURCE_STALE')['components'][1]
        self.assertEqual(c['oldest_observed_at'], stamp(-61))
        self.assertEqual(c['latest_observed_at'], stamp(-2))
        self.assertEqual(c['row_count'], 2)

    def test_exact_age_boundary_and_fractional_overrun(self):
        s, r = fixture()
        s['components'][0]['required_source_times'] = [stamp(-60)]
        self.assertEqual(self.check(s, r)['verdict'], 'STRUCTURE_PASS')
        s['components'][0]['required_source_times'] = [stamp(-60.000001)]
        self.held(s, r, 'SOURCE_STALE')

    def test_missing_or_unapproved_rule_is_unassessed_not_fresh(self):
        for rule in (None, {}, {'max_age_seconds': 999999}):
            s, r = fixture()
            r['components'][0]['freshness_rule'] = rule
            c = self.held(s, r, 'FRESHNESS_RULE_UNRESOLVED')['components'][0]
            self.assertEqual(c['freshness'], 'UNASSESSED')
            self.assertEqual(c['oldest_age_seconds'], 30)
        for key, value in (('approval_status', 'PENDING'), ('revision', None),
                           ('approval_ref', None), ('max_age_seconds', True),
                           ('max_age_seconds', 0), ('max_age_seconds', 1.5)):
            s, r = fixture()
            r['components'][0]['freshness_rule'][key] = value
            self.held(s, r, 'FRESHNESS_RULE_UNRESOLVED')

    def test_missing_required_scope_cannot_be_inferred_from_observation(self):
        s, r = fixture()
        self.held(s, code='REQUIRED_SCOPE_UNRESOLVED')
        r['components'] = []
        self.held(s, r, 'REQUIRED_SCOPE_UNRESOLVED')

    def test_missing_and_unexpected_components_hold(self):
        s, r = fixture()
        s['components'].pop()
        self.held(s, r, 'REQUIRED_COMPONENT_MISSING')
        s, r = fixture()
        s['components'][0]['component_id'] = 'TEST-UNEXPECTED'
        self.held(s, r, 'UNEXPECTED_COMPONENT')

    def test_duplicate_observed_or_required_components_hold(self):
        s, r = fixture()
        s['components'].append(copy.deepcopy(s['components'][0]))
        self.held(s, r, 'OBSERVED_COMPONENT_DUPLICATE')
        s, r = fixture()
        r['components'].append(copy.deepcopy(r['components'][0]))
        self.held(s, r, 'REQUIRED_COMPONENT_DUPLICATE')

    def test_scope_source_and_engine_revision_mismatches_hold(self):
        for key in readiness.COMPONENT_BINDING:
            s, r = fixture()
            s['components'][0][key] = 'TEST-OTHER'
            c = self.held(s, r, 'COMPONENT_BINDING')['components'][0]
            self.assertEqual(c['freshness'], 'UNASSESSED')
        for key in ('engine_id', 'engine_revision'):
            s, r = fixture()
            s[key] = 'TEST-OTHER'
            self.held(s, r, 'ENGINE_BINDING')

    def test_null_and_invalid_timestamps_are_counted_without_echo(self):
        s, r = fixture()
        secret = '/private/credentials?token=CANARY'
        s['components'][0]['required_source_times'] = [stamp(-3), None, secret, '2030-02-31T00:00:00Z']
        result = self.held(s, r, 'SOURCE_TIME_INVALID')
        c = result['components'][0]
        self.assertEqual((c['row_count'], c['missing_timestamp_count'], c['invalid_timestamp_count']), (4, 1, 2))
        self.assertEqual(c['freshness'], 'UNASSESSED')
        self.assertNotIn(secret, json.dumps(result))

    def test_future_source_and_source_after_read_hold(self):
        s, r = fixture()
        s['components'][0]['required_source_times'] = [stamp(1)]
        self.held(s, r, 'SOURCE_TIME_FUTURE')
        s['components'][0]['required_source_times'] = [stamp(-0.5)]
        self.held(s, r, 'SOURCE_AFTER_READ')

    def test_invalid_missing_and_future_read_times_hold(self):
        for value in (None, '2030-01-01', stamp(1), True):
            s, r = fixture()
            s['components'][0]['read_at'] = value
            c = self.held(s, r, 'READ_TIME')['components'][0]
            self.assertEqual(c['freshness'], 'UNASSESSED')

    def test_retrieval_time_never_replaces_source_observation(self):
        s, r = fixture()
        s['components'][0]['read_at'] = stamp()
        s['components'][0]['required_source_times'] = [None]
        c = self.held(s, r, 'SOURCE_TIME_MISSING')['components'][0]
        self.assertIsNone(c['oldest_observed_at'])
        self.assertIsNone(c['oldest_age_seconds'])

    def test_empty_and_unavailable_are_distinct(self):
        s, r = fixture()
        s['components'][0]['required_source_times'] = []
        c = self.held(s, r, 'INPUT_EMPTY')['components'][0]
        self.assertEqual((c['input_state'], c['row_count']), ('EMPTY', 0))
        s['components'][0].update(read_status='UNAVAILABLE', required_source_times=None)
        c = self.held(s, r, 'INPUT_UNAVAILABLE')['components'][0]
        self.assertEqual(c['input_state'], 'UNAVAILABLE')
        self.assertIsNone(c['row_count'])
        s['components'][0]['required_source_times'] = []
        self.held(s, r, 'UNAVAILABLE_WITH_ROWS')

    def test_source_times_must_be_present_and_bounded(self):
        s, r = fixture()
        del s['components'][0]['required_source_times']
        self.held(s, r, 'SOURCE_TIMES_REQUIRED')
        s['components'][0]['required_source_times'] = [stamp(-2)] * (readiness.MAX_SOURCE_TIMES + 1)
        self.held(s, r, 'SOURCE_TIMES_LIMIT')

    def test_active_policy_cannot_override_disabled_connection(self):
        s, r = fixture()
        s['paper_boundary']['connection']['order_submission_enabled'] = False
        r['paper_scope_resolution']['connection_submission_enabled'] = False
        p = self.held(s, r, 'PAPER_CONNECTION_BLOCKED')['paper_boundary']
        self.assertIs(p['connection_submission_enabled'], False)
        self.assertEqual(p['policy_status'], 'active')

    def test_sandbox_mode_requires_exact_scope_resolution(self):
        s, r = fixture()
        p = s['paper_boundary']['policy']
        p.update(mode='sandbox_automated', requires_human_confirmation=False)
        self.held(s, r, 'PAPER_SCOPE_UNRESOLVED')
        r['paper_scope_resolution'].update(policy_mode='sandbox_automated', policy_requires_confirmation=False)
        result = self.check(s, r)
        self.assertEqual(result['verdict'], 'STRUCTURE_PASS')
        self.assertIs(result['paper_boundary']['effective_confirmation_required'], True)
        self.assertEqual(result['paper_boundary']['parent_mode'], 'paper_approval_gated')
        self.assertEqual(result['paper_boundary']['policy_mode'], 'sandbox_automated')

    def test_policy_and_connection_flags_must_match_resolution(self):
        s, r = fixture()
        s['paper_boundary']['connection']['requires_human_confirmation'] = False
        self.held(s, r, 'PAPER_SCOPE_UNRESOLVED')
        r['paper_scope_resolution']['connection_requires_confirmation'] = 0
        self.held(s, r, 'PAPER_SCOPE_UNRESOLVED')

    def test_paper_never_accepts_live_or_unknown_environment_flags(self):
        for section in ('policy', 'connection'):
            for key, value in (('environment', 'alpaca_live'), ('live_trading_enabled', True),
                               ('live_trading_enabled', 0), ('environment', None)):
                s, r = fixture()
                s['paper_boundary'][section][key] = value
                self.held(s, r, 'PAPER_ONLY_BOUNDARY')

    def test_inactive_policy_and_confirmation_conflict_hold(self):
        s, r = fixture()
        s['paper_boundary']['policy']['status'] = 'paused'
        self.held(s, r, 'PAPER_POLICY_INACTIVE')
        s, r = fixture()
        s['paper_boundary']['policy']['requires_human_confirmation'] = False
        self.held(s, r, 'PAPER_CONFIRMATION_CONFLICT')

    def test_unknown_flags_and_policy_connection_mismatch_hold(self):
        s, r = fixture()
        s['paper_boundary']['connection']['order_submission_enabled'] = 1
        self.held(s, r, 'PAPER_FLAG_UNKNOWN')
        s, r = fixture()
        s['paper_boundary']['policy']['connection_id'] = 'TEST-OTHER'
        self.held(s, r, 'PAPER_CONNECTION_BINDING')

    def test_missing_or_wrong_paper_resolution_and_boundary_hold(self):
        s, r = fixture()
        self.held({**s, 'paper_boundary': None}, r, 'PAPER_BOUNDARY_REQUIRED')
        for value in (None, {}, {'approval_status': 'APPROVED'}):
            r['paper_scope_resolution'] = value
            self.held(s, r, 'PAPER_SCOPE_UNRESOLVED')
        for key, value in (('operation', 'live_order_submission'), ('policy_revision', '2'),
                           ('connection_revision', '2'), ('approval_status', 'PENDING')):
            s, r = fixture()
            r['paper_scope_resolution'][key] = value
            self.held(s, r, 'PAPER_SCOPE_UNRESOLVED')

    def test_unknown_fields_payloads_and_diagnostics_are_not_copied(self):
        s, r = fixture()
        canary = 'PRIVATE-CANARY:/secret?token=hidden'
        for target in (s, r, s['components'][0], r['components'][0],
                       s['paper_boundary'], s['paper_boundary']['policy']):
            target['raw_error'] = {'secret': [canary]}
            target['execution_authorized'] = True
        result = self.check(s, r)
        self.assertEqual(result['verdict'], 'STRUCTURE_PASS')
        self.assertNotIn(canary, json.dumps(result))
        s['engine_id'] = canary
        self.assertNotIn(canary, json.dumps(self.held(s, r, 'ENGINE_BINDING')))

    def test_malformed_shapes_and_nonfinite_api_inputs_hold(self):
        s, r = fixture()
        for value in (None, [], 'private input', True):
            self.held(value, r, 'SNAPSHOT_REQUIRED')
        for value in (None, [], {}, True):
            s, r = fixture()
            s['components'] = [value]
            self.held(s, r)
        for value in (float('nan'), float('inf'), Path('/private/file')):
            s, r = fixture()
            s['extra'] = value
            self.held(s, r, 'INPUT_JSON')
        s['extra'] = s
        self.held(s, r, 'INPUT_JSON')

    def test_explicit_strict_evaluation_time_is_required(self):
        s, r = fixture()
        self.assertEqual(readiness.project(s, r)['errors'][0]['code'], 'EVALUATION_TIME_REQUIRED')
        for value in ('', '2030-01-01', '2030-01-01T00:00:00+00:00', '2030-02-31T00:00:00Z'):
            self.held(s, r, 'EVALUATION_TIME_REQUIRED', value)

    def test_cli_success_and_missing_rule_exit_with_private_output(self):
        s, r = fixture()
        with tempfile.TemporaryDirectory() as directory:
            snapshot = Path(directory) / 'snapshot.json'
            requirements = Path(directory) / 'requirements.json'
            snapshot.write_text(json.dumps(s))
            requirements.write_text(json.dumps(r))
            command = [sys.executable, '-B', str(ROOT / 'scripts/engine_readiness.py'),
                       str(snapshot), '--at', stamp()]
            p = subprocess.run(command + ['--requirements', str(requirements)], capture_output=True, text=True)
            self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
            self.assertEqual(json.loads(p.stdout)['runtime_status'], 'HOLD_UNAUTHENTICATED')
            p = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(p.returncode, 1)
            self.assertNotIn(directory, p.stdout + p.stderr)
            self.assertEqual(p.stderr, '')

    def test_cli_bad_json_missing_file_and_bad_arguments_do_not_leak(self):
        with tempfile.TemporaryDirectory(prefix='PRIVATE-CANARY-') as directory:
            path = Path(directory) / 'PRIVATE-CANARY.json'
            command = [sys.executable, '-B', str(ROOT / 'scripts/engine_readiness.py')]
            for raw in ('{"PRIVATE-CANARY":1,"PRIVATE-CANARY":2}', '{"x":NaN}', '{"x":1e999}', 'PRIVATE-CANARY'):
                path.write_text(raw)
                p = subprocess.run(command + [str(path), '--at', stamp()], capture_output=True, text=True)
                self.assertEqual(p.returncode, 1)
                self.assertNotIn('PRIVATE-CANARY', p.stdout + p.stderr)
                self.assertEqual(p.stderr, '')
            path.unlink()
            for args in ([str(path), '--at', stamp()], ['--PRIVATE-CANARY'], [str(path)]):
                p = subprocess.run(command + args, capture_output=True, text=True)
                self.assertEqual(p.returncode, 1)
                self.assertNotIn('PRIVATE-CANARY', p.stdout + p.stderr)
                self.assertEqual(json.loads(p.stdout)['verdict'], 'HOLD')


if __name__ == '__main__':
    unittest.main()
