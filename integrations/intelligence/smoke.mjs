import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { assess, blankPacket, compare, fingerprint } from './intelligence.mjs';

const sample = JSON.parse(await readFile(new URL('./synthetic-example.json', import.meta.url), 'utf8'));
const original = fingerprint(sample);
assert.equal(assess(sample).readiness, 'DOCUMENTED_FOR_REVIEW');
assert.equal(assess(sample).synthetic, true);
assert.equal(assess(sample).evidence_summary.references, 5);
assert.equal(assess(sample).evidence_summary.underlying_events, 4);
assert.equal(assess(blankPacket()).readiness, 'INCOMPLETE');

const missing = structuredClone(sample);
missing.spending.payer = null;
assert.equal(assess(missing).effective_thesis_effect, 'UNRESOLVED');
const broken = structuredClone(sample);
broken.links['solution->spending'].evidence_ids = ['UNKNOWN-ID'];
assert.throws(() => assess(broken), /unknown evidence/);
const stale = structuredClone(sample);
stale.evidence.forEach(e => e.review_after = '2026-09-10');
assert.equal(assess(stale).readiness, 'INCOMPLETE');
const news = structuredClone(sample);
news.evidence.forEach(e => e.source_type = 'NEWS');
assert.equal(assess(news).readiness, 'INCOMPLETE');
const disguised = structuredClone(sample);
disguised.synthetic = false;
assert.throws(() => assess(disguised), /synthetic evidence/);

const revision = structuredClone(sample);
revision.revision = 2;
revision.revision_of = original;
revision.change_reason = 'Synthetic refinement: payer now unresolved.';
revision.spending.payer = null;
assert.ok(compare(sample, revision).changes.some(c => c.path === 'spending.payer'));
assert.equal(fingerprint(sample), original);
revision.revision_of = '0'.repeat(64);
assert.throws(() => compare(sample, revision), /does not match/);
console.log('PASS: synthetic execution, missing links, source references, currency, news-only evidence, synthetic separation and revision lineage.');

