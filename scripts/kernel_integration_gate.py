#!/usr/bin/env python3
"""Validation-only adapter boundary for the existing Nexus kernel.

No network, canonical writes, dispatch, broker operations, or authority grants.
The CLI checks supplied snapshots, not their authenticity. Production adapters
must obtain context from authenticated, authorized readers, not packet authors.
"""
import argparse
import hashlib
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from uuid import UUID

import stock_review_gate as stock

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = 'NEXUS-INTEGRATION-CONTRACT-v1'
PROTOCOL = 'NEXUS-KERNEL-INTEGRATION-CHECK-v2'
POLICY_FILES = (
    'docs/governance/REPOSITORY_GOVERNANCE.md',
    'integrations/contracts/NEXUS_INTEGRATION_CONTRACT_V1.md',
    'integrations/contracts/RECONCILIATION_POLICY.md',
    'integrations/kernel/BOUNDARY.md',
    str(stock.DOCTRINE),
)
# Validation profiles, NOT new canonical lane IDs, event families, or adapters.
PROFILES = {
    'dot_intake': ('research', 'research_only'),
    'email_alert': ('classify', 'decision_support'),
    'research_completion': ('complete_research', 'research_only'),
    'ct_receipt_ingestion': ('ingest_receipt', 'receipt_only'),
    'stack_sync': ('project', 'projection_only'),
    'exception_resolution': ('record_resolution', 'decision_support'),
    'reconciliation': ('reconcile', 'receipt_only'),
    'decision_memory': ('record_outcome', 'decision_support'),
}
DECODERS = ('signal', 'noise', 'risk', 'action', 'hold')
PROCESSING = ('RECEIVED', 'PROCESSING', 'PROCESSED', 'FAILED', 'DEAD_LETTER', 'REPLAYED')
REVIEW = ('NOT_REQUIRED', 'PENDING', 'APPROVED', 'REJECTED', 'DEFERRED')
RECONCILIATION = ('NOT_REQUIRED', 'PENDING', 'MATCHED', 'CONFLICT', 'MANUAL_REVIEW')
ERROR = ('NONE', 'TRANSIENT', 'VALIDATION', 'AUTHORITY', 'CONFLICT', 'PERMANENT')
VERIFICATION = ('UNVERIFIED', 'STRUCTURALLY_VERIFIED', 'HUMAN_VERIFIED', 'LIVE_VERIFIED')
# Only these lifecycle fields describe mutable progress. Original source and
# acceptance times, contract identity and unknown future fields stay committed.
MUTABLE_PROGRESS_FIELDS = frozenset((
    'processing_status', 'review_status', 'reconciliation_status',
    'error_status', 'verification_state', 'processed_at',
))


def timestamp(value):
    if not isinstance(value, str) or not re.fullmatch(
            r'\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{1,6})?Z', value):
        return None
    try:
        return datetime.fromisoformat(value.replace('Z', '+00:00'))
    except ValueError:
        return None


def ident(value):
    return isinstance(value, str) and bool(re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.:/#-]{0,199}', value))


def uuid(value):
    try:
        return isinstance(value, str) and str(UUID(value)) == value
    except ValueError:
        return False


def sha(value):
    return isinstance(value, str) and bool(re.fullmatch(r'[0-9a-f]{64}', value))


def binding(root=ROOT):
    """Bind to real checked-out policy bytes on EVERY evaluation."""
    return {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in POLICY_FILES}


def subject_digest(packet):
    return stock.digest(packet)


def intent_digest(packet):
    """Exclude only explicit progress; never discard immutable event timestamps."""
    intent = {key: value for key, value in packet.items() if key != 'expected_revision'}
    lifecycle = packet.get('lifecycle')
    if isinstance(lifecycle, dict):
        intent['lifecycle'] = {key: value for key, value in lifecycle.items()
                               if key not in MUTABLE_PROGRESS_FIELDS}
    return stock.digest(intent)


def retry_disposition(error, attempts, limit, submission_state):
    """Advice only. No sleeping, replay, submitting, or automatic retries."""
    if submission_state != 'NOT_APPLICABLE':
        return 'HOLD_NO_RETRY'
    if type(attempts) is not int or type(limit) is not int or not 0 <= attempts < limit:
        return 'HOLD_NO_RETRY'
    return 'BOUNDED_RETRY_ELIGIBLE' if error == 'TRANSIENT' else 'HOLD_NO_RETRY'


def evaluate(packet, context, phase='preflight', *, now=None, root=ROOT):
    """Validate a candidate against a separate runtime snapshot.

    STRUCTURE_PASS is deliberately not LIVE_VERIFIED or permission to act.
    Readers/authentication/atomic writes remain the existing runtime's job.
    No supplied status can turn this function into an execution capability.
    """
    errors = []

    def need(condition, code, detail):
        if not condition:
            errors.append({'code': code, 'detail': detail})

    def obj(value, label):
        need(isinstance(value, dict), 'SHAPE', label + ' must be an object')
        return value if isinstance(value, dict) else {}

    def refs(value, label, nonempty=True):
        valid = isinstance(value, list) and all(stock.text(x) for x in value)
        if valid:
            valid = len(value) == len(set(value)) and (bool(value) or not nonempty)
        need(valid, 'EVIDENCE', label + ' requires distinct nonblank references')
        return value if valid else []

    def fresh(value, label, max_age):
        time = timestamp(value)
        need(time is not None, 'TIMESTAMP', label + ' requires a UTC Z timestamp')
        if time is not None:
            need(time <= clock, 'FUTURE', label + ' is in the future')
            if type(max_age) is int and max_age > 0:
                need(0 <= (clock - time).total_seconds() <= max_age,
                     'STALE', label + ' exceeds the bound supplied by runtime policy')
        return time

    def result():
        return {'protocol': PROTOCOL, 'phase': phase,
                'verdict': 'HOLD' if errors else 'STRUCTURE_PASS',
                'execution_authorized': False, 'production_verified': False,
                'canonical_state_changed': False, 'errors': errors}

    clock = now or datetime.now(timezone.utc)
    if not isinstance(clock, datetime) or clock.tzinfo is None:
        raise ValueError('now must be timezone-aware')
    need(phase in ('preflight', 'closure'), 'PHASE', 'Unknown check phase')
    packet = obj(packet, 'packet')
    context = obj(context, 'context')
    need(type(packet.get('schema_version')) is int and packet.get('schema_version') == 1,
         'SCHEMA', 'Unsupported schema version')
    try:
        expected_binding = binding(root)
        digest = subject_digest(packet)
    except (OSError, ValueError, TypeError) as exc:
        errors.append({'code': 'POLICY_OR_PAYLOAD', 'detail': str(exc)})
        return result()
    need(packet.get('policy_binding') == expected_binding, 'POLICY_DRIFT', 'Policy binding missing or changed')
    need(context.get('policy_binding') == expected_binding, 'POLICY_DRIFT', 'Runtime policy binding missing or changed')
    profile = packet.get('profile')
    spec = PROFILES.get(profile) if isinstance(profile, str) else None
    need(spec is not None, 'PROFILE', 'Unrecognized validation profile')
    if spec:
        need(packet.get('operation') == spec[0], 'OPERATION', 'Operation is outside this profile')
        need(packet.get('authority') == spec[1], 'AUTHORITY', 'Authority must match the bounded profile')
    need(packet.get('environment') in ('sandbox', 'live'), 'ENVIRONMENT', 'Environment must be explicit')
    need(context.get('environment') == packet.get('environment'), 'ENVIRONMENT', 'Environment mismatch')
    if packet.get('environment') == 'live':
        need(False, 'LIVE_BINDING_REQUIRED', 'Candidate gate has no certified live integration; deployment remains held')
    need(packet.get('requested_effect') == 'validate_only', 'EFFECT', 'This gate may only validate')

    identity = obj(packet.get('identity'), 'identity')
    for key in ('mission_id', 'object_id', 'source_system', 'source_record_id', 'source_version', 'idempotency_key'):
        need(ident(identity.get(key)), 'IDENTITY', key + ' requires stable identity')
    need(uuid(identity.get('event_id')), 'IDENTITY', 'event_id requires a canonical UUID')
    need(uuid(identity.get('correlation_id')), 'IDENTITY', 'correlation_id requires a canonical UUID')
    need(identity.get('causation_id') is None or uuid(identity.get('causation_id')),
         'IDENTITY', 'Invalid causation_id')
    need(identity.get('event_id') != identity.get('causation_id'), 'LINEAGE', 'An event cannot cause itself')
    for key in ('actor_id', 'actor_role'):
        need(ident(packet.get(key)), 'ACTOR', key + ' is required')
    need(packet.get('actor_id') == context.get('authenticated_actor_id'), 'ACTOR', 'Actor differs from runtime identity')
    need(packet.get('actor_role') == context.get('authenticated_actor_role'), 'ACTOR', 'Role differs from runtime identity')
    allowed = context.get('allowed_profiles')
    need(isinstance(allowed, list) and all(isinstance(x, str) for x in allowed)
         and isinstance(profile, str) and profile in allowed, 'AUTHORITY', 'Runtime does not allow this profile')
    refs(context.get('authority_refs'), 'Runtime authority')

    classification = obj(packet.get('classification'), 'classification')
    route = obj(context.get('route'), 'runtime route')
    for key in ('item_type', 'event_family', 'lane_id', 'protocol_id', 'owner_id'):
        need(ident(classification.get(key)), 'CLASSIFICATION', key + ' is required')
        need(classification.get(key) == route.get(key) and ident(route.get(key)),
             'ROUTE', key + ' differs from the existing approved route')
    tags = refs(classification.get('tags'), 'Classification tags')
    need(tags == route.get('tags'), 'ROUTE', 'Tags must match the route, not invent a new registry')
    need(classification.get('decoder') in DECODERS, 'CLASSIFICATION', 'A data-decoder result is required')
    need(classification.get('decoder') not in ('risk', 'hold'), 'DECODER_HOLD', 'Risk/HOLD requires the existing review path')
    refs(route.get('evidence_refs'), 'Existing route')
    need(route.get('profile') == profile, 'ROUTE', 'Profile does not match route')
    need(stock.text(classification.get('purpose')), 'CLASSIFICATION', 'Purpose is required')

    lifecycle = obj(packet.get('lifecycle'), 'lifecycle')
    need(lifecycle.get('contract_version') == CONTRACT, 'CONTRACT', 'Use the existing integration envelope')
    for key, choices in (('processing_status', PROCESSING), ('review_status', REVIEW),
                         ('reconciliation_status', RECONCILIATION), ('error_status', ERROR),
                         ('verification_state', VERIFICATION)):
        need(lifecycle.get(key) in choices, 'STATE', 'Invalid ' + key)
    need(lifecycle.get('error_status') == 'NONE', 'ERROR_HOLD', 'Unresolved error must use the existing exception path')
    need(lifecycle.get('processing_status') not in ('FAILED', 'DEAD_LETTER'),
         'STATE_HOLD', 'Failed/dead-letter work needs an approved recovery path')
    need(lifecycle.get('review_status') not in ('REJECTED', 'DEFERRED'),
         'REVIEW_HOLD', 'Rejected/deferred review cannot advance')
    need(lifecycle.get('reconciliation_status') not in ('CONFLICT', 'MANUAL_REVIEW'),
         'RECONCILIATION_HOLD', 'Reconciliation conflict cannot advance')
    occurred = timestamp(lifecycle.get('occurred_at'))
    received = timestamp(lifecycle.get('received_at'))
    need(occurred is not None and received is not None, 'TIMESTAMP', 'Occurrence and acceptance timestamps required')
    if occurred is not None and received is not None:
        need(occurred <= received <= clock, 'TIME_ORDER', 'Occurrence/acceptance order invalid')
    max_age = context.get('max_evidence_age_seconds')
    need(type(max_age) is int and max_age > 0, 'FRESHNESS_POLICY', 'Runtime must supply an approved freshness bound')
    refs(context.get('freshness_policy_refs'), 'Freshness policy')
    fresh(context.get('observed_at'), 'Runtime snapshot', max_age)
    refs(packet.get('evidence_refs'), 'Packet evidence')
    expected_revision = packet.get('expected_revision')
    need(type(expected_revision) is int and expected_revision >= 0, 'REVISION', 'Expected revision is required')
    need(type(context.get('current_revision')) is int and expected_revision == context.get('current_revision'),
         'REVISION', 'Concurrent change or missing current revision; reread before action')
    need(context.get('submission_state') == 'NOT_APPLICABLE', 'SUBMISSION_HOLD',
         'Submission/unknown submission must stay at the existing financial reconciliation boundary')

    prior = context.get('idempotency_readback')
    if lifecycle.get('processing_status') == 'REPLAYED':
        need(isinstance(prior, dict) and bool(prior), 'REPLAY_PROOF_REQUIRED',
             'REPLAYED requires a readback of the original canonical event and immutable intent')
    if prior is not None:
        prior = obj(prior, 'idempotency_readback')
        need(prior.get('event_id') == identity.get('event_id') and prior.get('intent_sha256') == intent_digest(packet)
             and prior.get('idempotency_key') == identity.get('idempotency_key'),
             'IDEMPOTENCY_CONFLICT', 'Existing key must retain the event and immutable intent')
        need(ident(prior.get('record_ref')) and ident(prior.get('version')),
             'IDEMPOTENCY_LOCATOR', 'Original canonical record and version required')
        need(prior.get('authority_ref') == route.get('canonical_authority_ref')
             and stock.text(route.get('canonical_authority_ref')),
             'IDEMPOTENCY_AUTHORITY', 'Original event must come from the approved canonical authority')
        refs(prior.get('evidence_refs'), 'Original-event readback')
        fresh(prior.get('read_at'), 'Original-event readback', max_age)
        if phase == 'preflight':
            need(False, 'DUPLICATE_REUSE_ONLY', 'Do not execute again; obtain the original canonical receipt')
    need('idempotency_readback' in context, 'IDEMPOTENCY_UNKNOWN', 'Duplicate check has not been performed')
    need(context.get('open_exceptions') == [], 'OPEN_EXCEPTION', 'Unresolved exceptions prevent a pass')

    if profile == 'research_completion':
        research = packet.get('research_packet')
        need(isinstance(research, dict) and research.get('status') == 'complete',
             'STOCK_REVIEW', 'Completed review required from the existing stock-review gate')
        try:
            for issue in stock.validate(research, root, require_complete=True):
                errors.append({'code': 'STOCK_REVIEW', 'detail': issue})
        except (OSError, ValueError, TypeError, AttributeError) as exc:
            errors.append({'code': 'STOCK_REVIEW', 'detail': str(exc)})

    if phase == 'closure':
        need(classification.get('decoder') not in ('risk', 'hold'), 'DECODER_HOLD', 'Risk/HOLD cannot be closed as successful')
        need(lifecycle.get('processing_status') in ('PROCESSED', 'REPLAYED'), 'STATE', 'Processing is not complete')
        need(lifecycle.get('reconciliation_status') == 'MATCHED', 'STATE', 'Reconciliation is not matched')
        need(lifecycle.get('error_status') == 'NONE', 'STATE', 'An error remains')
        need(lifecycle.get('verification_state') in ('STRUCTURALLY_VERIFIED', 'HUMAN_VERIFIED', 'LIVE_VERIFIED'),
             'VERIFICATION', 'Unverified work cannot close')
        processed = timestamp(lifecycle.get('processed_at'))
        need(processed is not None, 'TIMESTAMP', 'Processed timestamp required')
        if received is not None and processed is not None:
            need(received <= processed <= clock, 'TIME_ORDER', 'Processing timestamp invalid')
        review = obj(context.get('independent_review'), 'independent_review')
        need(ident(review.get('reviewer_id')) and review.get('reviewer_id') != packet.get('actor_id'),
             'INDEPENDENCE', 'A separate reviewer is required')
        need(review.get('verdict') == 'PASS' and lifecycle.get('review_status') == 'APPROVED',
             'REVIEW', 'Independent review missing or not approved')
        need(review.get('packet_sha256') == digest, 'REVIEW_BINDING', 'Review must address these exact packet bytes')
        refs(review.get('evidence_refs'), 'Independent review')
        fresh(review.get('reviewed_at'), 'Independent review', max_age)
        canonical = obj(context.get('canonical_readback'), 'canonical_readback')
        for key in ('event_id', 'mission_id', 'idempotency_key'):
            need(canonical.get(key) == identity.get(key), 'CANONICAL_IDENTITY', 'Canonical ' + key + ' mismatch')
        need(canonical.get('packet_sha256') == digest, 'CANONICAL_PAYLOAD', 'Canonical payload checksum mismatch')
        need(ident(canonical.get('record_ref')) and ident(canonical.get('version')),
             'CANONICAL_LOCATOR', 'Canonical record and version required')
        if prior is not None:
            need(prior.get('record_ref') == canonical.get('record_ref'),
                 'IDEMPOTENCY_LOCATOR', 'Original and current readbacks must identify the same canonical record')
        need(canonical.get('authority_ref') == route.get('canonical_authority_ref')
             and stock.text(route.get('canonical_authority_ref')), 'CANONICAL_AUTHORITY', 'Canonical authority mismatch')
        canonical_time = fresh(canonical.get('read_at'), 'Canonical readback', max_age)
        if canonical_time is not None and processed is not None:
            need(canonical_time >= processed, 'TIME_ORDER', 'Canonical readback predates processing')
        refs(canonical.get('evidence_refs'), 'Canonical readback')
        required = refs(route.get('required_mirrors'), 'Required mirror list', nonempty=False)
        refs(route.get('mirror_policy_refs'), 'Required-mirror applicability policy')
        mirrors = context.get('mirror_readbacks')
        need(isinstance(mirrors, list), 'MIRROR', 'Mirror readbacks must be a list')
        mirrors = mirrors if isinstance(mirrors, list) else []
        seen = set()
        for raw in mirrors:
            mirror = obj(raw, 'mirror_readback')
            name = mirror.get('surface')
            need(isinstance(name, str) and name in required and name not in seen,
                 'MIRROR_SET', 'Unexpected or duplicate mirror')
            if isinstance(name, str):
                seen.add(name)
            for key in ('event_id', 'mission_id'):
                need(mirror.get(key) == identity.get(key), 'MIRROR_IDENTITY', 'Mirror ' + key + ' mismatch')
            need(mirror.get('canonical_version') == canonical.get('version'), 'MIRROR_VERSION', 'Mirror version is stale')
            need(mirror.get('expected_projection_sha256') == mirror.get('observed_projection_sha256')
                 and sha(mirror.get('expected_projection_sha256')), 'MIRROR_PAYLOAD', 'Projection/readback mismatch')
            need(mirror.get('status') == 'MATCHED' and stock.text(mirror.get('record_ref')),
                 'MIRROR_RECEIPT', 'A send/ACK is not a matched destination readback')
            refs(mirror.get('mapping_refs'), 'Versioned projection mapping')
            refs(mirror.get('evidence_refs'), 'Mirror readback')
            mirror_time = fresh(mirror.get('read_at'), 'Mirror readback', max_age)
            if mirror_time is not None and canonical_time is not None:
                need(mirror_time >= canonical_time, 'TIME_ORDER', 'Mirror readback predates canonical readback')
        need(seen == set(required), 'MIRROR_SET', 'At least one required destination has no readback')
        if profile == 'ct_receipt_ingestion':
            financial = obj(context.get('financial_readback'), 'financial_readback')
            need(financial.get('status') == 'RECONCILED', 'FINANCIAL_RECONCILIATION', 'Existing CT receipt must already be reconciled')
            need(financial.get('event_id') == identity.get('event_id'), 'FINANCIAL_IDENTITY', 'Financial receipt identity mismatch')
            refs(financial.get('evidence_refs'), 'Financial reconciliation')
        if profile in ('exception_resolution', 'decision_memory'):
            link = obj(packet.get('outcome_link'), 'outcome_link')
            for key in ('original_record_ref', 'expected_result', 'actual_result', 'interpretation', 'next_review_trigger'):
                need(stock.text(link.get(key)), 'OUTCOME_LINK', key + ' is required')
            refs(link.get('evidence_refs'), 'Outcome linkage')
    return result()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('binding', help='Print current policy checksums; not approval')
    for name in ('preflight', 'closure'):
        command = sub.add_parser(name)
        command.add_argument('packet', type=Path)
        command.add_argument('--context', type=Path, required=True,
                             help='Trusted adapter snapshot; CLI cannot authenticate this file')
    args = parser.parse_args(argv)
    try:
        if args.command == 'binding':
            value = binding()
        else:
            value = evaluate(stock.read_json(args.packet), stock.read_json(args.context), args.command)
        print(json.dumps(value, indent=2, allow_nan=False))
        return 1 if value.get('verdict') == 'HOLD' else 0
    except (OSError, ValueError, TypeError) as exc:
        print(json.dumps({'verdict': 'HOLD', 'execution_authorized': False,
                          'errors': [{'code': 'INPUT', 'detail': str(exc)}]}))
        return 1


if __name__ == '__main__':
    sys.exit(main())
