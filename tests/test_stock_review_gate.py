"""Synthetic evidence exercises workflow failures; it is never a real stock review."""
import copy
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('gate', ROOT / 'scripts/stock_review_gate.py')
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


def evidence_packet():
    packet = gate.template('TEST')
    packet.update(review_date='2026-10-01', sector='Synthetic test sector', thesis='Synthetic test thesis')
    for name, item in packet['metrics'].items():
        if name in gate.CONDITIONAL:
            item.update(status='not_applicable', reason='Synthetic fixture has no project-order business.')
        else:
            item['status'] = 'supported'
            item['measurement'] = {
                **{field: 'Synthetic test evidence' for field in gate.MEASUREMENT_FIELDS},
                'benchmark_status': 'proposed',
                'sources': [{'url': 'https://example.com/synthetic-filing', 'type': 'filing',
                             'published_on': '2026-09-30', 'locator': 'Synthetic section 1'}],
            }
    packet['summary'] = {**{field: 'Synthetic test assessment' for field in gate.SUMMARY_FIELDS}, 'material_gaps': []}
    packet['price_context'] = {'value': 10, 'currency': 'USD', 'as_of': '2026-10-01T12:00:00-07:00',
                               'source_url': 'https://example.com/synthetic-price'}
    return packet


class GateTests(unittest.TestCase):
    def test_begin_loads_actual_doctrine_and_blocks_completion(self):
        packet = gate.template('POWL')
        self.assertEqual(packet['doctrine'], gate.load_doctrine()[1])
        self.assertEqual(gate.validate(packet), [])
        with self.assertRaises(ValueError):
            gate.finalize(packet)

    def test_complete_and_readback(self):
        original = evidence_packet()
        result = gate.finalize(original)
        self.assertEqual(original['status'], 'draft')
        self.assertEqual(result['status'], 'complete')
        self.assertEqual(gate.validate(result), [])

    def test_direct_status_flip_fails(self):
        packet = evidence_packet()
        packet['status'] = 'complete'
        self.assertTrue(any('receipt' in e for e in gate.validate(packet)))

    def test_mutation_after_completion_fails(self):
        packet = gate.finalize(evidence_packet())
        packet['summary']['downside'] = 'Changed downside after receipt'
        self.assertTrue(any('receipt' in e for e in gate.validate(packet)))

    def test_recomputed_receipt_cannot_hide_missing_evidence(self):
        packet = gate.finalize(evidence_packet())
        del packet['metrics']['cash_generation']
        packet['gate_receipt']['payload_sha256'] = gate.digest({k: v for k, v in packet.items() if k != 'gate_receipt'})
        self.assertTrue(any('cash_generation' in e for e in gate.validate(packet)))

    def test_missing_source_and_trend_block(self):
        for field, value in [('sources', []), ('multiquarter_trend', '')]:
            with self.subTest(field=field):
                packet = evidence_packet()
                packet['metrics']['revenue_growth']['measurement'][field] = value
                with self.assertRaises(ValueError):
                    gate.finalize(packet)

    def test_unknown_and_material_gaps_block(self):
        packet = evidence_packet()
        packet['metrics']['cash_generation']['status'] = 'unknown'
        with self.assertRaises(ValueError):
            gate.finalize(packet)
        packet = evidence_packet()
        packet['summary']['material_gaps'] = ['Cash flow not reconciled']
        with self.assertRaises(ValueError):
            gate.finalize(packet)

    def test_core_cannot_be_removed_by_not_applicable(self):
        packet = evidence_packet()
        packet['metrics']['cash_generation'] = {'status': 'not_applicable', 'reason': 'Sector-specific method needed'}
        with self.assertRaises(ValueError):
            gate.finalize(packet)

    def test_sector_substitute_is_supported(self):
        packet = evidence_packet()
        packet['metrics']['cash_generation'].update(status='not_applicable', reason='Using documented sector substitute')
        self.assertEqual(gate.validate(gate.finalize(packet)), [])

    def test_conditional_not_applicable_needs_reason(self):
        packet = evidence_packet()
        packet['metrics']['backlog']['reason'] = ''
        with self.assertRaises(ValueError):
            gate.finalize(packet)

    def test_doctrine_missing_or_changed_blocks(self):
        packet = evidence_packet()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with self.assertRaises(OSError):
                gate.finalize(packet, root)
            (root / gate.DOCTRINE).parent.mkdir(parents=True)
            (root / gate.DOCTRINE).write_text(gate.load_doctrine()[0] + '\nChanged rule\n')
            with self.assertRaises(ValueError):
                gate.finalize(packet, root)

    def test_invalid_prices_and_future_source_block(self):
        for value in [None, True, 0, -1, float('inf'), '10']:
            packet = evidence_packet()
            packet['price_context']['value'] = value
            with self.subTest(value=value), self.assertRaises(ValueError):
                gate.finalize(packet)
        packet = evidence_packet()
        packet['metrics']['valuation']['measurement']['sources'][0]['published_on'] = '2026-10-02'
        with self.assertRaises(ValueError):
            gate.finalize(packet)

    def test_malformed_duplicate_and_nan_json_block(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'input.json'
            for body in ['{', '{"status":"draft","status":"complete"}', '{"value":NaN}']:
                path.write_text(body)
                with self.subTest(body=body), self.assertRaises(ValueError):
                    gate.read_json(path)

    def test_cli_failure_writes_no_output_and_preserves_input(self):
        with tempfile.TemporaryDirectory() as directory:
            source, output = Path(directory) / 'draft.json', Path(directory) / 'complete.json'
            source.write_text(json.dumps(gate.template('POWL')))
            before = source.read_bytes()
            result = subprocess.run([sys.executable, str(ROOT / 'scripts/stock_review_gate.py'),
                                     'complete', str(source), str(output)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 1)
            self.assertIn('BLOCKED', result.stderr)
            self.assertFalse(output.exists())
            self.assertEqual(source.read_bytes(), before)

    def test_exclusive_output_preserves_existing_review(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'complete.json'
            path.write_text('existing review')
            with self.assertRaises(FileExistsError):
                gate.write_new(path, gate.finalize(evidence_packet()))
            self.assertEqual(path.read_text(), 'existing review')


if __name__ == '__main__':
    unittest.main()
