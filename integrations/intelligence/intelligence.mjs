import { createHash } from 'node:crypto';

export const VERSION = '0.1.0';
export const STAGES = ['evidence', 'constraint', 'solution', 'spending', 'thesis'];
export const DIMENSIONS = ['materiality', 'timing', 'value_capture', 'connected_effects', 'disconfirmation', 'learning'];
export const EDGES = STAGES.slice(1).map((to, i) => `${STAGES[i]}->${to}`);
const BASIS = ['FACT', 'INFERENCE', 'UNRESOLVED'];
const EFFECTS = ['SUPPORTS', 'CHALLENGES', 'UNRESOLVED', 'NO_MATERIAL_IMPACT'];
const SPENDING_STATES = ['UNKNOWN', 'PROPOSED', 'FUNDED', 'APPROVED', 'CONTRACTED', 'REALIZED', 'DELAYED', 'CANCELLED'];
const object = x => x !== null && typeof x === 'object' && !Array.isArray(x);
const text = x => typeof x === 'string' && x.trim().length > 0;
const strings = x => Array.isArray(x) && x.every(text);
const date = x => typeof x === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(x) && !Number.isNaN(Date.parse(x)) && new Date(x).toISOString().slice(0, 10) === x;
const canonical = x => Array.isArray(x) ? x.map(canonical) : object(x) ? Object.fromEntries(Object.keys(x).sort().map(k => [k, canonical(x[k])])) : x;
export const fingerprint = x => createHash('sha256').update(JSON.stringify(canonical(x))).digest('hex');

export function emptyClaim() {
  return { statement: '', basis: 'UNRESOLVED', rationale: '', evidence_ids: [], unknowns: [] };
}

export function blankPacket() {
  return {
    schema_version: 1, case_id: 'NEW-CASE', revision: 1, revision_of: null,
    as_of: new Date().toISOString().slice(0, 10), synthetic: false,
    thesis: { id: '', version: '', assumption: '', effect: 'UNRESOLVED' },
    evidence: [],
    chain: Object.fromEntries(STAGES.map(k => [k, emptyClaim()])),
    links: Object.fromEntries(EDGES.map(k => [k, emptyClaim()])),
    dimensions: Object.fromEntries(DIMENSIONS.map(k => [k, emptyClaim()])),
    spending: { payer: null, mechanism: null, category: null, recipient: null, stage: 'UNKNOWN', timing: null },
    alternatives: [], counterevidence_ids: [], challenge_search: '',
    next_verification: '', change_reason: 'Initial assessment', outcome_observed: null,
  };
}

export function validate(packet) {
  const errors = [];
  const require = (ok, message) => { if (!ok) errors.push(message); };
  if (!object(packet)) return ['Packet must be a JSON object'];
  require(packet.schema_version === 1, 'schema_version must be 1');
  require(text(packet.case_id), 'case_id is required');
  require(Number.isInteger(packet.revision) && packet.revision > 0, 'revision must be a positive integer');
  require(packet.revision_of === null || (typeof packet.revision_of === 'string' && /^[a-f0-9]{64}$/.test(packet.revision_of)), 'revision_of must be null or a SHA-256 fingerprint');
  require(date(packet.as_of), 'as_of must be a valid YYYY-MM-DD date');
  require(typeof packet.synthetic === 'boolean', 'synthetic must be boolean');
  require(object(packet.thesis), 'thesis must be an object');
  for (const k of ['id', 'version', 'assumption']) require(typeof packet.thesis?.[k] === 'string', `thesis.${k} must be a string`);
  require(EFFECTS.includes(packet.thesis?.effect), 'Invalid thesis.effect');
  require(Array.isArray(packet.evidence), 'evidence must be an array');
  const ids = new Set();
  for (const [i, e] of (Array.isArray(packet.evidence) ? packet.evidence : []).entries()) {
    if (!object(e)) { errors.push(`evidence[${i}] must be an object`); continue; }
    for (const k of ['id', 'event_id', 'source', 'locator', 'claim']) require(text(e[k]), `evidence[${i}].${k} is required`);
    require(!ids.has(e.id), `Duplicate evidence id: ${e.id}`); ids.add(e.id);
    require(['PRIMARY', 'NEWS', 'COMMENTARY'].includes(e.source_type), `Invalid source_type: ${e.id}`);
    require(['VERIFIED', 'UNVERIFIED'].includes(e.verification), `Invalid verification: ${e.id}`);
    require(['CURRENT', 'AGING', 'STALE', 'SUPERSEDED'].includes(e.relevance), `Invalid relevance: ${e.id}`);
    require(date(e.date), `Invalid evidence date: ${e.id}`);
    require(date(e.review_after), `Invalid review_after: ${e.id}`);
    require(!(date(e.date) && date(packet.as_of)) || e.date <= packet.as_of, `Future evidence date: ${e.id}`);
    require(!(date(e.date) && date(e.review_after)) || e.review_after >= e.date, `review_after precedes evidence date: ${e.id}`);
    require(typeof e.synthetic === 'boolean', `synthetic must be boolean: ${e.id}`);
    require(packet.synthetic !== false || e.synthetic !== true, `Real case cannot contain synthetic evidence: ${e.id}`);
  }
  for (const [group, keys] of [['chain', STAGES], ['links', EDGES], ['dimensions', DIMENSIONS]]) {
    require(object(packet[group]), `${group} must be an object`);
    for (const key of keys) {
      const c = packet[group]?.[key];
      if (!object(c)) { errors.push(`${group}.${key} must be a claim object`); continue; }
      require(typeof c.statement === 'string' && typeof c.rationale === 'string', `${group}.${key}: statement and rationale must be strings`);
      require(BASIS.includes(c.basis), `${group}.${key}: invalid basis`);
      require(strings(c.evidence_ids), `${group}.${key}: evidence_ids must be a string array`);
      require(strings(c.unknowns), `${group}.${key}: unknowns must be a string array`);
      for (const id of (Array.isArray(c.evidence_ids) ? c.evidence_ids : [])) require(ids.has(id), `${group}.${key}: unknown evidence ${id}`);
    }
  }
  require(object(packet.spending), 'spending must be an object');
  for (const k of ['payer', 'mechanism', 'category', 'recipient', 'timing']) require(packet.spending?.[k] === null || text(packet.spending?.[k]), `spending.${k} must be nonempty text or null`);
  require(SPENDING_STATES.includes(packet.spending?.stage), 'Invalid spending.stage');
  require(strings(packet.alternatives), 'alternatives must be a string array');
  require(strings(packet.counterevidence_ids), 'counterevidence_ids must be a string array');
  for (const id of (Array.isArray(packet.counterevidence_ids) ? packet.counterevidence_ids : [])) require(ids.has(id), `Unknown counterevidence: ${id}`);
  for (const k of ['challenge_search', 'next_verification', 'change_reason']) require(typeof packet[k] === 'string', `${k} must be a string`);
  require(packet.outcome_observed === null || text(packet.outcome_observed), 'outcome_observed must be text or null');
  return errors;
}

export function assess(packet) {
  const errors = validate(packet);
  if (errors.length) throw new Error(`Invalid packet:\n${errors.join('\n')}`);
  const byId = new Map(packet.evidence.map(e => [e.id, e]));
  const usable = e => e.source_type === 'PRIMARY' && e.verification === 'VERIFIED' && e.relevance === 'CURRENT' && e.review_after >= packet.as_of;
  const gaps = [];
  const statuses = {};
  for (const [group, keys] of [['chain', STAGES], ['links', EDGES], ['dimensions', DIMENSIONS]]) {
    statuses[group] = {};
    for (const key of keys) {
      const claim = packet[group][key];
      const path = `${group}.${key}`;
      const missing = [];
      if (!text(claim.statement)) missing.push('Missing statement');
      if (!text(claim.rationale)) missing.push('Missing causal explanation');
      if (claim.basis === 'UNRESOLVED') missing.push('Reasoning remains unresolved');
      if (!claim.evidence_ids.some(id => usable(byId.get(id)))) missing.push('No current, reviewer-verified primary evidence');
      if (claim.unknowns.length) missing.push(...claim.unknowns.map(u => `Open question: ${u}`));
      statuses[group][key] = { state: missing.length ? 'UNRESOLVED' : 'DOCUMENTED_FOR_REVIEW', basis: claim.basis, gaps: missing };
      for (const reason of missing) gaps.push({ path, reason });
    }
  }
  for (const k of ['id', 'version', 'assumption']) if (!text(packet.thesis[k])) gaps.push({ path: `thesis.${k}`, reason: 'Thesis identity, version and assumption must be explicit' });
  if (packet.thesis.effect === 'UNRESOLVED') gaps.push({ path: 'thesis.effect', reason: 'Thesis impact unresolved' });
  for (const k of ['payer', 'mechanism', 'category', 'recipient', 'timing']) if (packet.spending[k] === null) gaps.push({ path: `spending.${k}`, reason: 'Spending pathway element unresolved' });
  if (packet.spending.stage === 'UNKNOWN') gaps.push({ path: 'spending.stage', reason: 'Spending stage unresolved' });
  if (!packet.alternatives.length) gaps.push({ path: 'alternatives', reason: 'Document credible alternatives, including delay or no spending where relevant' });
  if (!text(packet.challenge_search)) gaps.push({ path: 'challenge_search', reason: 'Record the scope and result of the search for contradictory evidence' });
  if (!text(packet.next_verification)) gaps.push({ path: 'next_verification', reason: 'Specify the next useful evidence request' });
  if (!text(packet.change_reason)) gaps.push({ path: 'change_reason', reason: 'Record why this assessment was created or revised' });
  if (packet.revision > 1 && !packet.revision_of) gaps.push({ path: 'revision_of', reason: 'Revision must link the previous packet fingerprint' });
  const events = new Map();
  for (const e of packet.evidence) events.set(e.event_id, [...(events.get(e.event_id) || []), e.id]);
  return {
    module_version: VERSION, packet_sha256: fingerprint(packet), case_id: packet.case_id,
    revision: packet.revision, as_of: packet.as_of, synthetic: packet.synthetic,
    readiness: gaps.length ? 'INCOMPLETE' : 'DOCUMENTED_FOR_REVIEW',
    factual_verification: 'NOT_PERFORMED_BY_MODULE', human_review_required: true,
    decision_authority: 'RESEARCH_REVIEW_ONLY', thesis_effect: packet.thesis.effect,
    effective_thesis_effect: gaps.length ? 'UNRESOLVED' : packet.thesis.effect,
    statuses, gaps,
    evidence_summary: { references: packet.evidence.length, underlying_events: events.size, events: Object.fromEntries(events) },
    next_verification: packet.next_verification || 'Resolve the first missing relationship and identify its required primary evidence.',
    warnings: [
      ...(packet.synthetic ? ['SYNTHETIC DEMONSTRATION — no real-world investment conclusion.'] : []),
      'Verification and source classification are supplied assertions; the module does not retrieve or authenticate sources.',
      'A documented chain is ready for review, not a proven thesis or permission to trade.',
      ...packet.evidence.filter(e => e.review_after < packet.as_of).map(e => `Evidence ${e.id} is overdue for review.`),
    ],
  };
}

export function compare(previous, current) {
  const errors = [...validate(previous), ...validate(current)];
  if (errors.length) throw new Error(`Cannot compare malformed packets: ${errors.join('; ')}`);
  if (previous.case_id !== current.case_id) throw new Error('Revision case_id must match');
  if (current.revision <= previous.revision) throw new Error('Revision number must increase');
  if (current.revision_of !== fingerprint(previous)) throw new Error('revision_of does not match the previous packet');
  const changes = [];
  const visit = (a, b, path) => {
    if (JSON.stringify(canonical(a)) === JSON.stringify(canonical(b))) return;
    if (object(a) && object(b)) for (const k of new Set([...Object.keys(a), ...Object.keys(b)])) visit(a[k], b[k], path ? `${path}.${k}` : k);
    else changes.push({ path, before: a ?? null, after: b ?? null });
  };
  visit(previous, current, '');
  return { previous_sha256: fingerprint(previous), current_sha256: fingerprint(current), change_reason: current.change_reason, changes };
}

const safe = value => String(value ?? 'Unresolved').replace(/[<>]/g, c => c === '<' ? '&lt;' : '&gt;');
export function render(packet, result) {
  const lines = [
    `# Nexus intelligence — ${safe(packet.case_id)}`,
    '', `Status: **${result.readiness}** · revision ${packet.revision} · ${packet.as_of}`,
    '', packet.synthetic ? '**SYNTHETIC DEMONSTRATION.**' : 'Research assessment. Human review required.',
    '', `Thesis: ${safe(packet.thesis.id)} / ${safe(packet.thesis.version)}`,
    `Assumption: ${safe(packet.thesis.assumption)}`,
    `Submitted effect: ${packet.thesis.effect}; review disposition: ${result.effective_thesis_effect}`,
  ];
  const section = (title, group, keys) => {
    lines.push('', `## ${title}`);
    for (const key of keys) {
      const c = packet[group][key];
      lines.push('', `### ${key.replaceAll('_', ' ')}`, `${result.statuses[group][key].state} · ${c.basis}`, '', safe(c.statement || 'Unresolved'), '', `Reasoning: ${safe(c.rationale || 'Not supplied')}`, `Evidence: ${safe(c.evidence_ids.join(', ') || 'None')}`);
      if (c.unknowns.length) lines.push(`Open questions: ${safe(c.unknowns.join('; '))}`);
    }
  };
  section('Evidence to thesis', 'chain', STAGES);
  section('Why the links hold', 'links', EDGES);
  lines.push('', '## Spending pathway');
  for (const [key, value] of Object.entries(packet.spending)) lines.push(`- ${key}: ${safe(value)}`);
  section('Six reasoning requirements', 'dimensions', DIMENSIONS);
  lines.push('', '## Alternatives and challenge', ...packet.alternatives.map(a => `- ${safe(a)}`), '', `Challenge search: ${safe(packet.challenge_search || 'Not documented')}`, `Counterevidence: ${safe(packet.counterevidence_ids.join(', ') || 'None supplied; this is not evidence of absence.')}`);
  lines.push('', '## Evidence register', `References: ${result.evidence_summary.references}; underlying events: ${result.evidence_summary.underlying_events}.`);
  for (const e of packet.evidence) lines.push('', `- ${safe(e.id)} / event ${safe(e.event_id)}: ${safe(e.claim)}`, `  Source: ${safe(e.source)}; locator: ${safe(e.locator)}`, `  ${e.date}; ${e.source_type}; ${e.verification}; ${e.relevance}; review after ${e.review_after}.`);
  lines.push('', '## Gaps and next verification');
  lines.push(...result.gaps.map(g => `- ${safe(g.path)}: ${safe(g.reason)}`));
  if (!result.gaps.length) lines.push('No structural gaps detected. Source truth and reasoning quality still require review.');
  lines.push('', safe(result.next_verification), '', '## Preserved decision context', safe(packet.change_reason), `Observed outcome: ${safe(packet.outcome_observed || 'Not yet observed')}`, `Previous fingerprint: ${packet.revision_of || 'Initial version'}`, `Packet SHA-256: ${result.packet_sha256}`, '', '## Limits', ...result.warnings.map(w => `- ${safe(w)}`));
  return lines.join('\n') + '\n';
}
