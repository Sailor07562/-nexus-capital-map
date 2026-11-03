#!/usr/bin/env python3
"""Pure engine-input diagnostics; no reader, endpoint or execution authority.

Both inputs are unauthenticated snapshots. Requirements describe an existing
scope and its recorded rules; this module does not approve or register them.
"""
import argparse
import json
import re
import sys
from datetime import datetime
from pathlib import Path

import stock_review_gate as stock

PROTOCOL = 'NEXUS-ENGINE-READINESS-PROJECTION-v1'
MAX_COMPONENTS = 64
MAX_SOURCE_TIMES = 10000
MAX_ASSETS = 1000
IDENTIFIER = re.compile(r'[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}')
SYMBOL = re.compile(r'[A-Z0-9][A-Z0-9.-]{0,31}')
UTC_TIME = re.compile(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z')
COMPONENT_BINDING = ('component_id', 'component_kind', 'source_object', 'source_revision',
                     'scope_ref', 'scope_revision', 'timestamp_meaning')
LIVE_COMPONENT_KINDS = frozenset({'portfolio_read', 'symbol_eligibility',
                                  'command_authentication', 'confirmation_boundary',
                                  'receipt_reconciliation'})
LIVE_BINDING = ('route_id', 'route_revision', 'operator_id', 'reader_id', 'authority_ref')
LIVE_CONTROLS = {
    'requires_exact_confirmation': True, 'requires_action_time_ticket': True,
    'requires_reconciliation': True, 'cash_only': True,
    'automatic_trading_enabled': False, 'transfers_enabled': False,
    'margin_enabled': False, 'short_sales_enabled': False,
    'options_enabled': False, 'crypto_enabled': False,
}
PAPER_MODES = ('human_approval_gated', 'sandbox_automated')
PARENT_MODES = ('paper_approval_gated', 'sandbox_automated')


def identifier(value):
    return value if isinstance(value, str) and IDENTIFIER.fullmatch(value) else None


def timestamp(value):
    if not isinstance(value, str) or not UTC_TIME.fullmatch(value):
        return None
    try:
        return datetime.fromisoformat(value.replace('Z', '+00:00'))
    except ValueError:
        return None


def _report():
    return {
        'protocol': PROTOCOL, 'verdict': 'HOLD',
        'runtime_status': 'HOLD_UNAUTHENTICATED',
        'authentication_verified': False, 'execution_authorized': False,
        'production_verified': False, 'canonical_state_changed': False,
        'broker_action_authorized': False, 'automatic_promotion': False,
        'evaluated_at': None, 'engine_id': None, 'engine_revision': None, 'scope': None,
        'required_input_set': None,
        'components': [], 'live_boundary': None, 'paper_boundary': None, 'errors': [],
    }


def _issue(errors, code, index=None):
    # Only fixed codes and numeric positions: never echo an exception, payload,
    # invalid timestamp, unknown key or caller-supplied diagnostic text.
    issue = {'code': code}
    if index is not None:
        issue['component_index'] = index
    errors.append(issue)


def _freshness_rule(rule):
    return (isinstance(rule, dict)
            and all(identifier(rule.get(k)) for k in ('rule_id', 'revision', 'approval_ref'))
            and rule.get('approval_status') == 'APPROVED'
            and type(rule.get('max_age_seconds')) is int
            and rule['max_age_seconds'] > 0)


def _component(observed, required, index, clock, errors, scope_resolved):
    out = {'component_index': index, **dict.fromkeys(COMPONENT_BINDING),
           'input_state': 'INVALID', 'source_status': 'UNKNOWN', 'freshness': 'UNASSESSED',
           'read_at': None, 'row_count': None, 'missing_timestamp_count': None,
           'invalid_timestamp_count': None, 'oldest_observed_at': None,
           'latest_observed_at': None, 'oldest_age_seconds': None,
           'freshness_rule_id': None, 'freshness_rule_revision': None,
           'freshness_approval_ref': None, 'max_age_seconds': None}
    if not isinstance(observed, dict):
        _issue(errors, 'COMPONENT_SHAPE', index)
        return out
    for key in COMPONENT_BINDING:
        out[key] = identifier(observed.get(key))
    binding_ok = (scope_resolved and isinstance(required, dict)
                  and all(out[k] is not None and out[k] == required.get(k)
                          for k in COMPONENT_BINDING))
    if not binding_ok:
        _issue(errors, 'COMPONENT_BINDING', index)
    status = observed.get('source_status')
    if status in ('CLEAR', 'BLOCKED', 'UNKNOWN'):
        out['source_status'] = status
    if status != 'CLEAR':
        _issue(errors, 'SOURCE_STATUS_BLOCKED' if status == 'BLOCKED' else 'SOURCE_STATUS_UNKNOWN', index)

    read_at = timestamp(observed.get('read_at'))
    read_ok = read_at is not None and read_at <= clock
    if read_at is not None:
        out['read_at'] = observed['read_at']
    if not read_ok:
        _issue(errors, 'READ_TIME', index)
    state = observed.get('read_status')
    times = observed.get('required_source_times')
    if state == 'UNAVAILABLE':
        out['input_state'] = 'UNAVAILABLE'
        _issue(errors, 'INPUT_UNAVAILABLE', index)
        if times is not None:
            _issue(errors, 'UNAVAILABLE_WITH_ROWS', index)
        return out
    if state != 'AVAILABLE' or not isinstance(times, list):
        _issue(errors, 'SOURCE_TIMES_REQUIRED', index)
        return out
    if len(times) > MAX_SOURCE_TIMES:
        _issue(errors, 'SOURCE_TIMES_LIMIT', index)
        return out

    out['row_count'] = len(times)
    out['missing_timestamp_count'] = sum(value is None for value in times)
    parsed = [(value, timestamp(value)) for value in times if value is not None]
    out['invalid_timestamp_count'] = sum(value is None for _, value in parsed)
    valid = [(raw, value) for raw, value in parsed if value is not None]
    out['input_state'] = 'EMPTY' if not times else 'PRESENT'
    if not times:
        _issue(errors, 'INPUT_EMPTY', index)
    if out['missing_timestamp_count']:
        _issue(errors, 'SOURCE_TIME_MISSING', index)
    if out['invalid_timestamp_count']:
        _issue(errors, 'SOURCE_TIME_INVALID', index)
    if valid:
        oldest = min(valid, key=lambda item: item[1])
        latest = max(valid, key=lambda item: item[1])
        out['oldest_observed_at'], out['latest_observed_at'] = oldest[0], latest[0]
        out['oldest_age_seconds'] = (clock - oldest[1]).total_seconds()
        if latest[1] > clock:
            _issue(errors, 'SOURCE_TIME_FUTURE', index)
        if read_at is not None and latest[1] > read_at:
            _issue(errors, 'SOURCE_AFTER_READ', index)

    rule = required.get('freshness_rule') if isinstance(required, dict) else None
    if not _freshness_rule(rule):
        _issue(errors, 'FRESHNESS_RULE_UNRESOLVED', index)
        return out
    out.update(freshness_rule_id=rule['rule_id'], freshness_rule_revision=rule['revision'],
               freshness_approval_ref=rule['approval_ref'], max_age_seconds=rule['max_age_seconds'])
    complete = (bool(times) and len(valid) == len(times) and read_ok
                and all(value <= read_at for _, value in valid))
    if complete and binding_ok:
        if out['oldest_age_seconds'] > rule['max_age_seconds']:
            out['freshness'] = 'STALE'
            _issue(errors, 'SOURCE_STALE', index)
        else:
            out['freshness'] = 'FRESH'
    return out


def _live_boundary(observed, resolution, errors):
    start = len(errors)
    out = {'status': 'UNASSESSED', 'environment': None, **dict.fromkeys(LIVE_BINDING),
           **dict.fromkeys(LIVE_CONTROLS), 'scope_decision_ref': None,
           'scope_decision_revision': None}
    if not isinstance(observed, dict):
        _issue(errors, 'LIVE_BOUNDARY_REQUIRED')
        return out
    for key in LIVE_BINDING:
        out[key] = identifier(observed.get(key))
    if observed.get('environment') == 'alpaca_live':
        out['environment'] = 'alpaca_live'
    else:
        _issue(errors, 'LIVE_ENVIRONMENT')
    for key, expected in LIVE_CONTROLS.items():
        value = observed.get(key)
        if type(value) is bool:
            out[key] = value
        if value is not expected:
            _issue(errors, 'LIVE_CONTROL_BOUNDARY')
    resolved = (isinstance(resolution, dict)
                and resolution.get('approval_status') == 'APPROVED'
                and resolution.get('operation') == 'ct_live_readiness'
                and all(identifier(resolution.get(k)) for k in ('decision_ref', 'revision'))
                and all(out[k] is not None and resolution.get(k) == out[k] for k in LIVE_BINDING))
    if not resolved:
        _issue(errors, 'LIVE_SCOPE_UNRESOLVED')
    else:
        out['scope_decision_ref'] = resolution['decision_ref']
        out['scope_decision_revision'] = resolution['revision']
    out['status'] = 'CONSISTENT' if len(errors) == start else 'HOLD'
    return out


def _asset_scope(observed, required, index, errors):
    """Dynamic broker/approval intersection, never a hardcoded ticker list.

    Asset metadata is a supplied readback, not fetched or authenticated here.
    Holdings are irrelevant to whether an additional stock can be assessed.
    """
    rows = observed.get('assets')
    scope = required.get('asset_scope') if isinstance(required, dict) else None
    if not (isinstance(rows, list) and 1 <= len(rows) <= MAX_ASSETS
            and isinstance(scope, list) and 1 <= len(scope) <= MAX_ASSETS):
        _issue(errors, 'ASSET_SCOPE_UNRESOLVED', index)
        return []
    expected = {}
    for entry in scope:
        if not isinstance(entry, dict) or not identifier(entry.get('asset_id')):
            _issue(errors, 'ASSET_SCOPE_SHAPE', index)
        elif entry['asset_id'] in expected:
            _issue(errors, 'ASSET_SCOPE_DUPLICATE', index)
        else:
            expected[entry['asset_id']] = entry
    result, seen, symbols, asset_times = [], set(), set(), []
    for position, asset in enumerate(rows):
        start = len(errors)
        item = {'asset_index': position, 'asset_id': None, 'symbol': None,
                'status': 'HOLD', 'broker_status': None, 'tradable': None,
                'fractionable': None, 'fractional_required': None,
                'observed_at': None, 'approval_ref': None, 'approval_revision': None}
        result.append(item)
        if not isinstance(asset, dict):
            _issue(errors, 'ASSET_SHAPE', index)
            continue
        asset_id = identifier(asset.get('asset_id'))
        symbol = asset.get('symbol')
        symbol = symbol if isinstance(symbol, str) and SYMBOL.fullmatch(symbol) else None
        item.update(asset_id=asset_id, symbol=symbol)
        if asset_id in seen or symbol in symbols:
            _issue(errors, 'ASSET_DUPLICATE', index)
        seen.add(asset_id)
        symbols.add(symbol)
        rule = expected.get(asset_id, {})
        if asset_id is None or symbol is None or rule.get('symbol') != symbol:
            _issue(errors, 'ASSET_IDENTITY', index)
        approved = (rule.get('approval_status') == 'APPROVED'
                    and rule.get('live_enabled') is True
                    and all(identifier(rule.get(k)) for k in ('approval_ref', 'approval_revision'))
                    and type(rule.get('fractional_required')) is bool)
        if not approved:
            _issue(errors, 'ASSET_NOT_APPROVED', index)
        else:
            item.update(approval_ref=rule['approval_ref'], approval_revision=rule['approval_revision'],
                        fractional_required=rule['fractional_required'])
        status = asset.get('status')
        item['broker_status'] = status if status in ('active', 'inactive') else None
        for key in ('tradable', 'fractionable'):
            if type(asset.get(key)) is bool:
                item[key] = asset[key]
        if (asset.get('asset_class') != 'us_equity' or status != 'active'
                or item['tradable'] is not True or item['fractionable'] is None):
            _issue(errors, 'BROKER_ASSET_INELIGIBLE', index)
        if rule.get('fractional_required') is True and item['fractionable'] is not True:
            _issue(errors, 'FRACTIONAL_ASSET_REQUIRED', index)
        observed_at = asset.get('observed_at')
        if timestamp(observed_at) is None:
            _issue(errors, 'ASSET_OBSERVATION_TIME', index)
        else:
            item['observed_at'] = observed_at
            asset_times.append(observed_at)
        if len(errors) == start:
            item['status'] = 'CONSISTENT'
    if set(expected) != seen:
        _issue(errors, 'ASSET_SET_MISMATCH', index)
    times = observed.get('required_source_times')
    if not (isinstance(times, list) and len(asset_times) == len(rows) == len(times)
            and all(timestamp(value) is not None for value in times)
            and sorted(asset_times) == sorted(times)):
        _issue(errors, 'ASSET_TIME_COVERAGE', index)
    return result


def _paper_boundary(observed, resolution, errors):
    start = len(errors)
    out = {'status': 'UNASSESSED', 'parent_mode': None, 'policy_mode': None,
           'policy_id': None, 'policy_revision': None, 'connection_id': None,
           'connection_revision': None, 'policy_requires_confirmation': None,
           'connection_requires_confirmation': None, 'effective_confirmation_required': None,
           'connection_submission_enabled': None, 'policy_status': None,
           'policy_environment': None, 'connection_environment': None,
           'policy_live_enabled': None, 'connection_live_enabled': None,
           'scope_decision_ref': None,
           'scope_decision_revision': None}
    if not isinstance(observed, dict):
        _issue(errors, 'PAPER_BOUNDARY_REQUIRED')
        return out
    policy = observed.get('policy')
    connection = observed.get('connection')
    if not isinstance(policy, dict) or not isinstance(connection, dict):
        _issue(errors, 'PAPER_BOUNDARY_SHAPE')
        return out
    parent = observed.get('parent_mode')
    mode = policy.get('mode')
    out['parent_mode'] = parent if parent in PARENT_MODES else None
    out['policy_mode'] = mode if mode in PAPER_MODES else None
    out.update(policy_id=identifier(policy.get('policy_id')),
               policy_revision=identifier(policy.get('revision')),
               connection_id=identifier(connection.get('connection_id')),
               connection_revision=identifier(connection.get('revision')))
    for destination, source, key in (
            ('policy_requires_confirmation', policy, 'requires_human_confirmation'),
            ('connection_requires_confirmation', connection, 'requires_human_confirmation'),
            ('connection_submission_enabled', connection, 'order_submission_enabled'),
            ('policy_live_enabled', policy, 'live_trading_enabled'),
            ('connection_live_enabled', connection, 'live_trading_enabled')):
        if type(source.get(key)) is bool:
            out[destination] = source[key]
        else:
            _issue(errors, 'PAPER_FLAG_UNKNOWN')
    if out['parent_mode'] is None or out['policy_mode'] is None:
        _issue(errors, 'PAPER_MODE_UNKNOWN')
    if mode == 'human_approval_gated' and out['policy_requires_confirmation'] is not True:
        _issue(errors, 'PAPER_CONFIRMATION_CONFLICT')
    if all(type(out[k]) is bool for k in
           ('policy_requires_confirmation', 'connection_requires_confirmation')):
        out['effective_confirmation_required'] = (
            out['policy_requires_confirmation'] or out['connection_requires_confirmation']
            or mode == 'human_approval_gated')
    status = policy.get('status')
    out['policy_status'] = status if status in ('active', 'paused', 'retired') else None
    if status != 'active':
        _issue(errors, 'PAPER_POLICY_INACTIVE')
    if out['connection_submission_enabled'] is not True:
        _issue(errors, 'PAPER_CONNECTION_BLOCKED')
    if policy.get('connection_id') != out['connection_id'] or out['connection_id'] is None:
        _issue(errors, 'PAPER_CONNECTION_BINDING')
    for prefix, source in (('policy', policy), ('connection', connection)):
        if source.get('environment') in ('alpaca_paper', 'alpaca_live'):
            out[prefix + '_environment'] = source['environment']
        if source.get('environment') != 'alpaca_paper' or source.get('live_trading_enabled') is not False:
            _issue(errors, 'PAPER_ONLY_BOUNDARY')

    # A difference between parent and child modes is never silently approved.
    # The separate reader must supply the existing exact scope decision.
    resolved = (isinstance(resolution, dict)
                and resolution.get('approval_status') == 'APPROVED'
                and resolution.get('operation') == 'paper_order_submission'
                and all(identifier(resolution.get(k)) for k in ('decision_ref', 'revision'))
                and all(out[k] is not None and resolution.get(k) == out[k]
                        for k in ('parent_mode', 'policy_mode', 'policy_id', 'policy_revision',
                                  'connection_id', 'connection_revision',
                                  'policy_requires_confirmation', 'connection_requires_confirmation',
                                  'connection_submission_enabled'))
                and all(type(resolution.get(k)) is bool for k in
                        ('policy_requires_confirmation', 'connection_requires_confirmation',
                         'connection_submission_enabled')))
    if resolved:
        out['scope_decision_ref'] = resolution['decision_ref']
        out['scope_decision_revision'] = resolution['revision']
    else:
        _issue(errors, 'PAPER_SCOPE_UNRESOLVED')
    out['status'] = 'CONSISTENT' if len(errors) == start else 'HOLD'
    return out


def project(snapshot, requirements=None, *, evaluated_at=None):
    """Describe consistency within a declared input scope, never admission.

    Source times are one timestamp (or null) per required input row, selected
    by the named existing scope. No live data or rules are fetched or inferred.
    Caller identity, source truth and scope completeness cannot be authenticated
    here. A STRUCTURE_PASS still has runtime_status HOLD_UNAUTHENTICATED.
    """
    report = _report()
    errors = report['errors']
    clock = timestamp(evaluated_at)
    if clock is None:
        _issue(errors, 'EVALUATION_TIME_REQUIRED')
        return report
    report['evaluated_at'] = evaluated_at
    try:
        stock.digest([snapshot, requirements])
    except (ValueError, TypeError, RecursionError):
        _issue(errors, 'INPUT_JSON')
        return report
    if not isinstance(snapshot, dict):
        _issue(errors, 'SNAPSHOT_REQUIRED')
        return report
    requirements = requirements if isinstance(requirements, dict) else {}
    scope = snapshot.get('scope')
    if scope in ('ct_live', 'paper') and requirements.get('scope') == scope:
        report['scope'] = scope
    else:
        _issue(errors, 'OPERATION_SCOPE_UNRESOLVED')
    for key in ('engine_id', 'engine_revision'):
        report[key] = identifier(snapshot.get(key))
        if report[key] is None or report[key] != requirements.get(key):
            _issue(errors, 'ENGINE_BINDING')

    input_set = requirements.get('required_input_set')
    set_resolved = (isinstance(input_set, dict)
                    and all(identifier(input_set.get(k)) for k in ('set_id', 'revision', 'approval_ref'))
                    and input_set.get('approval_status') == 'APPROVED'
                    and report['scope'] is not None
                    and all(report[k] is not None and input_set.get(k) == report[k]
                            and requirements.get(k) == report[k]
                            for k in ('engine_id', 'engine_revision', 'scope')))
    if set_resolved:
        report['required_input_set'] = {k: input_set[k] for k in ('set_id', 'revision', 'approval_ref')}
    else:
        _issue(errors, 'INPUT_SET_UNRESOLVED')

    required = requirements.get('components')
    required_by_id = {}
    if not isinstance(required, list) or not 1 <= len(required) <= MAX_COMPONENTS:
        _issue(errors, 'REQUIRED_SCOPE_UNRESOLVED')
    else:
        for item in required:
            if not isinstance(item, dict) or not all(identifier(item.get(k)) for k in COMPONENT_BINDING):
                _issue(errors, 'REQUIRED_COMPONENT_SHAPE')
                set_resolved = False
            elif (item.get('required') is not True or item.get('empty_semantics') != 'HOLD'
                  or item['timestamp_meaning'] not in ('source_observation', 'read_receipt')):
                _issue(errors, 'INPUT_SEMANTICS_UNRESOLVED')
                set_resolved = False
            elif item['component_id'] in required_by_id:
                _issue(errors, 'REQUIRED_COMPONENT_DUPLICATE')
                set_resolved = False
            else:
                required_by_id[item['component_id']] = item
    components = snapshot.get('components')
    if not isinstance(components, list) or not 1 <= len(components) <= MAX_COMPONENTS:
        _issue(errors, 'OBSERVED_COMPONENTS_REQUIRED')
        components = []
    seen = set()
    for index, item in enumerate(components):
        component_id = identifier(item.get('component_id')) if isinstance(item, dict) else None
        if component_id in seen:
            _issue(errors, 'OBSERVED_COMPONENT_DUPLICATE', index)
        if component_id not in required_by_id:
            _issue(errors, 'UNEXPECTED_COMPONENT', index)
        seen.add(component_id)
        report['components'].append(_component(
            item, required_by_id.get(component_id), index, clock, errors, set_resolved))
        if (report['scope'] == 'ct_live' and isinstance(item, dict)
                and item.get('component_kind') == 'symbol_eligibility'):
            report['components'][-1]['assets'] = _asset_scope(
                item, required_by_id.get(component_id), index, errors)
    if set(required_by_id) - seen:
        _issue(errors, 'REQUIRED_COMPONENT_MISSING')
    if report['scope'] == 'ct_live':
        kinds = {item['component_kind'] for item in required_by_id.values()}
        if not LIVE_COMPONENT_KINDS <= kinds:
            _issue(errors, 'LIVE_COMPONENT_COVERAGE')
        report['live_boundary'] = _live_boundary(
            snapshot.get('live_boundary'), requirements.get('live_scope_resolution'), errors)
    elif report['scope'] == 'paper':
        report['paper_boundary'] = _paper_boundary(
            snapshot.get('paper_boundary'), requirements.get('paper_scope_resolution'), errors)
    if not errors:
        report['verdict'] = 'STRUCTURE_PASS'
    return report


class PrivateArgumentParser(argparse.ArgumentParser):
    def error(self, message):
        raise ValueError('Invalid diagnostic arguments')


def main(argv=None):
    parser = PrivateArgumentParser(description=__doc__)
    parser.add_argument('snapshot', type=Path)
    parser.add_argument('--requirements', type=Path)
    parser.add_argument('--at', required=True, help='Explicit UTC Z evaluation time')
    try:
        args = parser.parse_args(argv)
        report = project(stock.read_json(args.snapshot),
                         stock.read_json(args.requirements) if args.requirements else None,
                         evaluated_at=args.at)
    except (OSError, ValueError, TypeError, RecursionError):
        report = _report()
        _issue(report['errors'], 'INPUT_OR_ARGUMENTS')
    print(json.dumps(report, indent=2, allow_nan=False))
    return 0 if report['verdict'] == 'STRUCTURE_PASS' else 1


if __name__ == '__main__':
    sys.exit(main())
