#!/usr/bin/env python3
"""File-based stock review completion gate. No network, database, or broker calls."""
import argparse
import copy
import hashlib
import json
import re
import sys
from datetime import date, datetime, timezone
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
DOCTRINE = Path('docs/governance/NEXUS_INVESTMENT_ANALYSIS_DOCTRINE_20261001.md')
DOCTRINE_ID = 'NDU-20261001-002'
CORE = ('revenue_growth', 'profitability', 'cash_generation', 'working_capital',
        'financial_strength', 'per_share_outcomes', 'valuation')
CONDITIONAL = ('backlog', 'book_to_bill', 'thesis_orders')
MEASUREMENT_FIELDS = ('metric', 'definition', 'unit', 'period', 'latest_result',
                      'prior_year_comparison', 'multiquarter_trend', 'benchmark',
                      'benchmark_status', 'interpretation', 'next_proof_point')
SUMMARY_FIELDS = ('business_assessment', 'valuation_assessment', 'downside',
                  'disconfirming_evidence', 'next_proof_point')


def text(value):
    return isinstance(value, str) and bool(value.strip()) and value.strip().lower() not in {
        'tbd', 'todo', 'unknown', 'n/a', 'pending', 'placeholder'}


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':'),
                                    allow_nan=False).encode()).hexdigest()


def load_doctrine(root=ROOT):
    """Always read the checkout's doctrine, never a remembered text or packet path."""
    data = (root / DOCTRINE).read_bytes()
    body = data.decode('utf-8')
    if f'**Doctrine ID:** {DOCTRINE_ID}' not in body or '## Stock-review workflow' not in body:
        raise ValueError('Required doctrine identity or workflow is missing')
    return body, {'id': DOCTRINE_ID, 'sha256': hashlib.sha256(data).hexdigest()}


def read_json(path):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f'Duplicate JSON key: {key}')
            result[key] = value
        return result
    def reject(value):
        raise ValueError(f'Invalid JSON constant: {value}')
    return json.loads(Path(path).read_text(encoding='utf-8'),
                      object_pairs_hook=unique, parse_constant=reject)


def template(ticker, root=ROOT):
    _, binding = load_doctrine(root)
    if not re.fullmatch(r'[A-Z0-9][A-Z0-9.-]{0,19}', ticker):
        raise ValueError('Use a valid uppercase ticker')
    return {
        'schema_version': 1, 'ticker': ticker, 'review_date': '', 'sector': '',
        'thesis': '', 'status': 'draft', 'doctrine': binding,
        'metrics': {name: {'status': 'unknown', 'reason': '',
                          'measurement': {**dict.fromkeys(MEASUREMENT_FIELDS, ''), 'sources': []}}
                    for name in CORE + CONDITIONAL},
        'price_context': {'value': None, 'currency': '', 'as_of': '', 'source_url': ''},
        'summary': {**dict.fromkeys(SUMMARY_FIELDS, ''), 'material_gaps': []},
    }


def valid_date(value):
    try:
        return isinstance(value, str) and date.fromisoformat(value).isoformat() == value
    except ValueError:
        return False


def valid_time(value):
    try:
        return isinstance(value, str) and datetime.fromisoformat(value.replace('Z', '+00:00')).tzinfo is not None
    except ValueError:
        return False


def public_url(value):
    if not isinstance(value, str):
        return False
    parsed = urlparse(value)
    return parsed.scheme == 'https' and bool(parsed.hostname) and not parsed.username and not parsed.password


def validate(packet, root=ROOT, require_complete=False):
    """Recompute completeness; status and a caller-supplied receipt are never proof."""
    _, binding = load_doctrine(root)
    errors = []
    def need(condition, message):
        if not condition:
            errors.append(message)
    if not isinstance(packet, dict):
        return ['Review must be a JSON object']
    need(type(packet.get('schema_version')) is int and packet['schema_version'] == 1, 'Unsupported schema_version')
    need(packet.get('doctrine') == binding, 'Doctrine binding missing or stale; reread doctrine and reassess')
    need(isinstance(packet.get('ticker'), str) and re.fullmatch(r'[A-Z0-9][A-Z0-9.-]{0,19}', packet['ticker']), 'Invalid ticker')
    need(packet.get('status') in ('draft', 'complete'), 'Invalid review status')
    complete = require_complete or packet.get('status') == 'complete'
    if complete:
        for field in ('thesis', 'sector'):
            need(text(packet.get(field)), f'Missing {field}')
        need(valid_date(packet.get('review_date')), 'Missing/invalid review_date')
    metrics = packet.get('metrics')
    if not isinstance(metrics, dict):
        return errors + ['Missing metrics object']
    need(set(metrics) == set(CORE + CONDITIONAL), 'Exactly the required metric keys must be present')
    for name in CORE + CONDITIONAL:
        item = metrics.get(name)
        if not isinstance(item, dict):
            errors.append(f'{name}: missing metric object')
            continue
        status = item.get('status')
        need(status in ('supported', 'unknown', 'not_applicable'), f'{name}: invalid evidence status')
        if status == 'unknown':
            need(not complete, f'{name}: evidence unknown; completion blocked')
            continue
        if status == 'not_applicable':
            need(text(item.get('reason')), f'{name}: applicability explanation required')
            if name in CONDITIONAL:
                continue
            # Core questions may use a sector-specific substitute, but cannot disappear.
        measure = item.get('measurement')
        if not isinstance(measure, dict):
            errors.append(f'{name}: missing measurement or sector substitute')
            continue
        for field in MEASUREMENT_FIELDS:
            need(text(measure.get(field)), f'{name}: missing {field}')
        need(measure.get('benchmark_status') in ('proposed', 'approved'), f'{name}: benchmark status must be proposed or approved')
        sources = measure.get('sources')
        if not isinstance(sources, list) or not sources:
            errors.append(f'{name}: primary evidence source required')
            continue
        for source in sources:
            if not isinstance(source, dict):
                errors.append(f'{name}: invalid source object')
                continue
            need(public_url(source.get('url')), f'{name}: HTTPS source URL required (no embedded credentials)')
            need(source.get('type') in ('filing', 'earnings_release', 'earnings_call'), f'{name}: primary source type required')
            need(valid_date(source.get('published_on')), f'{name}: source publication date required')
            need(text(source.get('locator')), f'{name}: source page/section locator required')
            if valid_date(source.get('published_on')) and valid_date(packet.get('review_date')):
                need(source['published_on'] <= packet['review_date'], f'{name}: source postdates review')
    if complete:
        summary = packet.get('summary')
        if not isinstance(summary, dict):
            errors.append('Missing summary')
        else:
            for field in SUMMARY_FIELDS:
                need(text(summary.get(field)), f'Summary missing {field}')
            need(summary.get('material_gaps') == [], 'Material gaps remain; completion blocked')
        price = packet.get('price_context')
        if not isinstance(price, dict):
            errors.append('Missing price context')
        else:
            value = price.get('value')
            need(type(value) in (int, float) and 0 < value < float('inf'), 'Positive finite price required')
            need(text(price.get('currency')), 'Price currency required')
            need(valid_time(price.get('as_of')), 'Price as_of requires timezone-aware timestamp')
            need(public_url(price.get('source_url')), 'Price source URL required')
            if valid_time(price.get('as_of')) and valid_date(packet.get('review_date')):
                need(datetime.fromisoformat(price['as_of'].replace('Z', '+00:00')).date() <= date.fromisoformat(packet['review_date']), 'Price postdates review')
    if packet.get('status') == 'complete':
        receipt = packet.get('gate_receipt')
        payload = {k: v for k, v in packet.items() if k != 'gate_receipt'}
        need(isinstance(receipt, dict) and receipt.get('payload_sha256') == digest(payload)
             and receipt.get('doctrine') == binding and valid_time(receipt.get('completed_at')),
             'Completion receipt missing or does not match current payload/doctrine')
    return errors


def finalize(packet, root=ROOT):
    candidate = copy.deepcopy(packet)
    if not isinstance(candidate, dict):
        raise ValueError('Review must be a JSON object')
    # Validate an existing complete packet too, rather than silently repairing tampering.
    errors = validate(candidate, root, require_complete=True)
    if errors:
        raise ValueError('\n'.join(errors))
    candidate.pop('gate_receipt', None)
    candidate['status'] = 'complete'
    candidate['gate_receipt'] = {
        'payload_sha256': digest(candidate), 'doctrine': candidate['doctrine'],
        'completed_at': datetime.now(timezone.utc).isoformat(),
    }
    return candidate


def write_new(path, data):
    """Exclusive creation: a failed check never overwrites a previous review."""
    with Path(path).open('x', encoding='utf-8') as stream:
        json.dump(data, stream, indent=2, allow_nan=False)
        stream.write('\n')


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    begin = sub.add_parser('begin')
    begin.add_argument('ticker')
    begin.add_argument('output', type=Path)
    check = sub.add_parser('check')
    check.add_argument('input', type=Path)
    finish = sub.add_parser('complete')
    finish.add_argument('input', type=Path)
    finish.add_argument('output', type=Path)
    sub.add_parser('check-repository')
    args = parser.parse_args(argv)
    try:
        # Every entrypoint loads the doctrine, including an empty repository check.
        body, _ = load_doctrine()
        if args.command == 'begin':
            write_new(args.output, template(args.ticker))
            print(body)
            print(f'\nDRAFT created: {args.output}; complete is blocked until evidence is supplied.')
        elif args.command == 'complete':
            write_new(args.output, finalize(read_json(args.input)))
            print(f'COMPLETE: {args.output}; evidence structure checked, not investment approval.')
        else:
            files = [args.input] if args.command == 'check' else sorted((ROOT / 'reviews/stock').rglob('*.json'))
            if args.command == 'check-repository' and not (ROOT / 'reviews/stock').is_dir():
                raise ValueError('Required reviews/stock directory is missing')
            errors = []
            completed = 0
            for path in files:
                if path.is_symlink():
                    raise ValueError(f'Symlink review is not permitted: {path}')
                packet = read_json(path)
                errors.extend(f'{path}: {error}' for error in validate(packet))
                completed += int(isinstance(packet, dict) and packet.get('status') == 'complete')
            if errors:
                raise ValueError('\n'.join(errors))
            print(f'PASS: {len(files)} review packet(s), {completed} complete; draft is not complete.')
        return 0
    except (OSError, ValueError, TypeError) as exc:
        print(f'BLOCKED: {exc}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
