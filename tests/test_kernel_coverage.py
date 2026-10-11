"""Inventory omissions and status inflation must be visible in review/CI."""
import ast
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
import kernel_integration_gate as gate


class CoverageTests(unittest.TestCase):
    def test_every_gate_profile_has_an_explicit_coverage_entry(self):
        coverage = json.loads((ROOT / 'integrations/kernel/coverage.json').read_text())
        self.assertEqual(set(coverage['profiles']), set(gate.PROFILES))
        methods = {node.name for node in ast.walk(ast.parse(
            (ROOT / 'tests/test_kernel_integration_gate.py').read_text())) if isinstance(node, ast.FunctionDef)}
        for profile, entry in coverage['profiles'].items():
            with self.subTest(profile=profile):
                self.assertIn(entry['test'], methods)
                self.assertTrue(entry['next_proof'].strip())
                self.assertEqual(entry['production_wiring'], 'UNVERIFIED')

    def test_candidate_cannot_silently_claim_production_readiness(self):
        coverage = json.loads((ROOT / 'integrations/kernel/coverage.json').read_text())
        self.assertIs(coverage['production_ready'], False)
        self.assertEqual(set(coverage['promotion_requirements']), {
            'canonical_bindings', 'authenticated_context', 'atomic_revision_and_replay',
            'independent_review', 'negative_authority_tests', 'source_promotion',
            'sandbox_end_to_end', 'recovery_and_resume', 'health_and_alerts', 'rollback_and_live_approval'})

    def test_candidate_contains_no_network_dispatch_or_write_capability(self):
        tree = ast.parse((ROOT / 'scripts/kernel_integration_gate.py').read_text())
        imports = {alias.name.split('.')[0] for node in ast.walk(tree)
                   if isinstance(node, ast.Import) for alias in node.names}
        imports |= {node.module.split('.')[0] for node in ast.walk(tree)
                    if isinstance(node, ast.ImportFrom) and node.module}
        self.assertTrue(imports <= {'argparse', 'hashlib', 'json', 're', 'sys', 'datetime',
                                    'pathlib', 'uuid', 'stock_review_gate'})
        forbidden = {'write', 'write_text', 'write_bytes', 'write_new', 'unlink',
                     'execute', 'connect', 'urlopen', 'request', 'submit_order',
                     'cancel_order', 'replace_order', 'eval', 'exec', '__import__'}
        for node in ast.walk(tree):
            if isinstance(node, ast.Call):
                name = node.func.attr if isinstance(node.func, ast.Attribute) else (
                    node.func.id if isinstance(node.func, ast.Name) else '')
                self.assertNotIn(name, forbidden)


if __name__ == '__main__':
    unittest.main()
