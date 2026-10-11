#!/usr/bin/env python3
"""Read-only documentary receipt handoff into the existing kernel contract.

Accepts observations and separately recovered packet/context snapshots. Never
creates an event, finalizes research, fetches a source, authenticates a caller,
or writes anything. Even STRUCTURE_PASS leaves runtime admission on HOLD.
"""
import argparse
import copy
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

import kernel_integration_gate as gate
import stock_review_gate as stock

PROTOCOL = 'NEXUS-RESEARCH-RECEIPT-ADAPTER-v1'
OBSERVATION_KIND = 'DOCUMENTARY_RECEIPT_READBACK_NOT_RUNTIME_ENVELOPE'
# Output vocabulary only, not a second validator or authority policy. Unknown
# future codes receive a fixed fallback; never echo caller/exception text.
GATE_DIAGNOSTIC_CODES = frozenset({
    'ACTOR', 'AUTHORITY', 'CANONICAL_AUTHORITY', 'CANONICAL_IDENTITY',
    'CANONICAL_LOCATOR', 'CANONICAL_PAYLOAD', 'CLASSIFICATION', 'CONTRACT',
    'DECODER_HOLD', 'DUPLICATE_REUSE_ONLY', 'EFFECT', 'ENVIRONMENT', 'ERROR_HOLD',
    'EVIDENCE', 'FINANCIAL_IDENTITY', 'FINANCIAL_RECONCILIATION',
    'FRESHNESS_POLICY', 'FUTURE', 'IDEMPOTENCY_AUTHORITY', 'IDEMPOTENCY_CONFLICT',
    'IDEMPOTENCY_LOCATOR', 'IDEMPOTENCY_UNKNOWN', 'IDENTITY', 'INDEPENDENCE',
    'INPUT', 'LINEAGE', 'LIVE_BINDING_REQUIRED', 'MIRROR', 'MIRROR_IDENTITY',
    'MIRROR_PAYLOAD', 'MIRROR_RECEIPT', 'MIRROR_SET', 'MIRROR_VERSION',
    'OPEN_EXCEPTION', 'OPERATION', 'OUTCOME_LINK', 'PHASE', 'POLICY_DRIFT',
    'POLICY_OR_PAYLOAD', 'PROFILE', 'RECONCILIATION_HOLD', 'REPLAY_PROOF_REQUIRED',
    'REVIEW', 'REVIEW_BINDING', 'REVIEW_HOLD', 'REVISION', 'ROUTE', 'SCHEMA',
    'SHAPE', 'STALE', 'STATE', 'STATE_HOLD', 'STOCK_REVIEW', 'SUBMISSION_HOLD',
    'TIMESTAMP', 'TIME_ORDER', 'VERIFICATION',
})


def private_gate_report(checked):
    """Project known status fields and codes without copying raw diagnostics.

    Details, nested objects, extra keys and exception strings are never traversed
    or stringified. Invalid report shapes fail closed at the existing boundary.
    The original gate result and every supplied input remain untouched.
    """
    flags = ('execution_authorized', 'production_verified', 'canonical_state_changed')
    if not (isinstance(checked, dict)
            and checked.get('protocol') == gate.PROTOCOL
            and checked.get('phase') == 'preflight'
            and checked.get('verdict') in ('HOLD', 'STRUCTURE_PASS')
            and all(checked.get(key) is False for key in flags)
            and isinstance(checked.get('errors'), list)
            and bool(checked['errors']) == (checked['verdict'] == 'HOLD')):
        raise ValueError('Invalid existing-gate diagnostic shape')
    result = {key: checked[key] for key in ('protocol', 'phase', 'verdict', *flags)}
    result['errors'] = []
    for issue in checked['errors']:
        code = issue.get('code') if isinstance(issue, dict) else None
        safe_code = code if isinstance(code, str) and code in GATE_DIAGNOSTIC_CODES else 'GATE_DIAGNOSTIC'
        result['errors'].append({
            'code': safe_code,
            'detail': 'Existing gate check failed; raw diagnostic details withheld.',
        })
    return result


def adapt(observation, packet=None, context=None, *, now=None, root=gate.ROOT):
    """Return (unchanged candidate copy or None, diagnostic report).

    The observation is documentary data, NEVER the runtime context. A future
    approved reader must recover the packet and context.receipt_binding from
    trusted original records. Local JSON, matching hashes and role labels are
    not authentication. No identity, route, timestamp, policy or status default
    is inserted into the candidate, even when the missing value seems obvious.
    """
    errors = []
    report = {
        'protocol': PROTOCOL, 'verdict': 'HOLD',
        'runtime_status': 'HOLD_UNAUTHENTICATED',
        'authentication_verified': False, 'execution_authorized': False,
        'production_verified': False, 'canonical_state_changed': False,
        'observation_sha256': None, 'packet_sha256': None,
        'gate_result': None, 'errors': errors,
    }

    def need(condition, code, detail):
        if not condition:
            errors.append({'code': code, 'detail': detail})

    def refs(value):
        return (isinstance(value, list) and bool(value)
                and all(stock.text(item) for item in value)
                and len(value) == len(set(value)))

    def stable(value):
        return gate.ident(value) and stock.text(value)

    clock = now or datetime.now(timezone.utc)
    if not isinstance(clock, datetime) or clock.tzinfo is None:
        need(False, 'CLOCK', 'A timezone-aware diagnostic clock is required')
        return None, report

    if not isinstance(observation, dict):
        need(False, 'OBSERVATION', 'A documentary observation object is required')
        return None, report
    try:
        report['observation_sha256'] = stock.digest(observation)
        if packet is not None:
            report['packet_sha256'] = gate.subject_digest(packet)
        # Reject non-JSON/non-finite API inputs as well as strict CLI JSON.
        if context is not None:
            stock.digest(context)
    except (TypeError, ValueError, RecursionError):
        need(False, 'INPUT', 'Inputs must be finite JSON data')
        return None, report

    need(observation.get('observation_kind') == OBSERVATION_KIND,
         'OBSERVATION', 'Documentary observations must not impersonate runtime envelopes')
    for key in ('receipt_id', 'mission_id', 'reviewer_receipt_id'):
        need(stable(observation.get(key)), 'RECEIPT_IDENTITY', key + ' is required')
    need(observation.get('research_status') == 'COMPLETE', 'RESEARCH_STATUS',
         'This adapter checks saved research completion, not a new completion request')
    for key in ('valuation_status', 'investment_status'):
        need(stock.text(observation.get(key)), 'STATUS_SEPARATION', key + ' must remain explicit')
    need(refs(observation.get('source_refs')), 'SOURCE_REFS', 'Native source references are required')
    captured = gate.timestamp(observation.get('captured_at'))
    need(captured is not None and captured <= clock, 'OBSERVATION_TIME',
         'Observation capture time must be a non-future UTC Z timestamp')

    packet_present = isinstance(packet, dict) and bool(packet)
    context_present = isinstance(context, dict) and bool(context)
    need(packet_present, 'ENVELOPE_REQUIRED',
         'Recover the original versioned packet; receipt labels cannot supply it')
    need(context_present, 'CONTEXT_REQUIRED',
         'A separate approved-reader context snapshot is required')
    if not packet_present or not context_present:
        return None, report

    # The existing gate remains the sole event/stock validator. Never repair
    # policy drift, complete a stock packet, rewrite LIVE as sandbox, or fill
    # missing duplicate/exception readbacks before calling it.
    try:
        checked = gate.evaluate(packet, context, 'preflight', now=clock, root=root)
        report['gate_result'] = private_gate_report(checked)
    except (OSError, ValueError, TypeError, AttributeError, KeyError, RecursionError):
        need(False, 'GATE_INPUT', 'Existing validator rejected the supplied snapshot shape')
        return None, report
    need(packet.get('profile') == 'research_completion', 'RESEARCH_PROFILE',
         'Only the existing research_completion profile is supported')

    identity = packet.get('identity')
    identity = identity if isinstance(identity, dict) else {}
    need(identity.get('mission_id') == observation.get('mission_id'),
         'MISSION_BINDING', 'Observation and original event must identify the same mission')
    binding = context.get('receipt_binding')
    if not isinstance(binding, dict) or not binding:
        need(False, 'RECEIPT_BINDING_REQUIRED',
             'Recover explicit native receipt, original event and research-payload linkage')
        return None, report

    # These are checked, not invented. The binding is a reader snapshot of an
    # existing relationship, not a new registry entry or a production approval.
    for key in ('receipt_id', 'mission_id'):
        need(binding.get(key) == observation.get(key) and stable(binding.get(key)),
             'RECEIPT_BINDING', key + ' does not match the observed receipt')
    for key in ('source_system', 'source_record_id', 'source_version'):
        need(binding.get(key) == identity.get(key) and stable(binding.get(key)),
             'SOURCE_BINDING', key + ' does not match the original event source')
    need(binding.get('observation_sha256') == report['observation_sha256'],
         'OBSERVATION_BINDING', 'Binding must address this exact documentary observation')
    need(binding.get('packet_sha256') == report['packet_sha256'],
         'PACKET_BINDING', 'Binding must address the original packet without rewriting it')
    research = packet.get('research_packet')
    need(isinstance(research, dict)
         and binding.get('research_packet_sha256') == stock.digest(research),
         'RESEARCH_BINDING', 'Bind the machine-readable research packet, not a support-model hash')
    for key in ('record_ref', 'mapping_version'):
        need(stable(binding.get(key)), 'BINDING_PROVENANCE', key + ' is required')
    for key in ('evidence_refs', 'mapping_refs', 'review_evidence_refs'):
        need(refs(binding.get(key)), 'BINDING_PROVENANCE', key + ' is required')
    need(binding.get('review_receipt_id') == observation.get('reviewer_receipt_id')
         and stable(binding.get('review_receipt_id')), 'REVIEW_RECEIPT_BINDING',
         'Resolve the recorded review receipt without promoting its display verdict')
    need(stable(binding.get('reviewer_id'))
         and binding.get('reviewer_id') != packet.get('actor_id'),
         'REVIEWER_BINDING', 'A separate resolved reviewer principal is required, not a role label')

    # No guessed freshness window and no substitution of observation time for
    # original event occurrence/acceptance. These clocks have different roles.
    read_at = gate.timestamp(binding.get('read_at'))
    observed_at = gate.timestamp(context.get('observed_at'))
    max_age = context.get('max_evidence_age_seconds')
    need(read_at is not None and captured is not None and observed_at is not None
         and type(max_age) is int and max_age > 0
         and captured <= read_at <= observed_at <= clock
         and 0 <= (clock - read_at).total_seconds() <= max_age,
         'BINDING_FRESHNESS', 'Binding must be freshly read between observation capture and context capture')

    if not errors and checked.get('verdict') == 'STRUCTURE_PASS':
        report['verdict'] = 'STRUCTURE_PASS'
        # Preserve every original field, including future/unknown fields, so
        # the existing immutable-intent/replay checksums cannot silently change.
        return copy.deepcopy(packet), report
    return None, report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('observation', type=Path)
    parser.add_argument('--packet', type=Path,
                        help='Recovered original packet; never synthesized from receipt labels')
    parser.add_argument('--context', type=Path,
                        help='Separate reader snapshot; this CLI cannot authenticate a file')
    args = parser.parse_args(argv)
    try:
        _, report = adapt(
            stock.read_json(args.observation),
            stock.read_json(args.packet) if args.packet else None,
            stock.read_json(args.context) if args.context else None)
    except (OSError, ValueError, TypeError, RecursionError):
        # Do not expose a private path, raw input, receipt contents or secrets.
        _, report = adapt(None)
        report['errors'] = [{'code': 'INPUT', 'detail': 'Cannot read strict finite JSON inputs'}]
    print(json.dumps(report, indent=2, allow_nan=False))
    return 0 if report['verdict'] == 'STRUCTURE_PASS' else 1


if __name__ == '__main__':
    sys.exit(main())
