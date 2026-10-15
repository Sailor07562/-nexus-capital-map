# Existing kernel: integration-check boundary

Status: IMPLEMENTED CANDIDATE / PRODUCTION PROMOTION HELD.

This extends the existing stock-review gate and integration contract. It is not
a second kernel, mission registry, event ledger, authority store, or scheduler.
It implements classification-first discipline from the Nexus Operating System
Tightening Layer (2026-10-08). It does not amend that doctrine or register new
canonical event families. A validation profile is a test boundary, not a lane.

## Trust and authority

The pure Python gate accepts a candidate packet and a separate runtime snapshot.
It checks structure, current policy checksums, identity, classification, exact
route, authority scope, freshness, revision, replay identity, review, and
readback. Research completion invokes the existing stock-review validator;
there is no duplicate stock-validation implementation.

`STRUCTURE_PASS` is neither permission to act nor proof of source truth. A local
JSON file cannot authenticate an actor, reviewer, policy grant, evidence source,
database write, or readback. Checksums detect inconsistency, not fabrication.
The production adapter must resolve those inputs with its configured bounded
credentials and approved readers, and enforce policy at the actual write boundary.
Never accept runtime context, role, route, approval, mirror applicability, or
revision from the submitting user/agent. Never trust a prior gate result.

This candidate rejects `environment=live` until integration and independent
review prove that boundary. It cannot submit, prepare, cancel, replace, or retry
broker orders, transfer money, modify caps, perform canonical writes, grant
authority, activate workflows, dispatch missions, or certify itself for live use.
It has no network dependencies, database connection, secret input, or scheduler.

Existing PostgreSQL, bounded cloud trading, Tracker-owned operational records,
and controlled mirror relationships must be mapped by domain. Do not infer a
global cloud cutover or flatten those roles into a newly invented authority.
An existing public source snapshot can lag current private runtime policy;
historical paper-only documentation must not reset later bounded live authority.

## Required integration behavior

1. Obtain the existing mission/event identity, source version and approved
   idempotency key. An unknown duplicate-readback is not an empty result.
2. Capture an authenticated actor and current approved route from the existing
   registries. Classification answers purpose, object, family, lane, tags,
   protocol, owner and signal/noise/risk/action/hold before action.
3. Read policy, freshness bounds, current revision, open exceptions and source
   evidence. Fail closed on missing, stale, future-dated or conflicting inputs.
4. Run preflight. A HOLD stops the candidate path. Passing is only structural.
5. After separately authorized work, obtain independent review and canonical
   and required-mirror readbacks. A Slack ACK or successful send is not readback.
6. Run closure. Preserve original identity on replay; mismatched content is a
   conflict. Corrections use the existing linked-event mechanism.
7. Perform the existing governed compare-and-swap/write transaction. Snapshot
   validation alone cannot prevent a time-of-check/time-of-use race. An atomic
   revision/idempotency guard is a production admission requirement.
8. Record failures in the existing exception log; verify resolution before
   closing. Decision/outcome records retain expectation, actual result, evidence,
   interpretation and next-review trigger. No automatic investment promotion.

The packet lifecycle uses the existing integration contract's status vocabulary;
this checker does not run or replace the canonical mission state machine.
Closure requires successful processing, matched reconciliation, independent
review, no unresolved exceptions and the approved destination set. Empty mirror
sets require a specific existing applicability policy, not an author-selected
exemption. Projection hashes compare projected content, not unlike source bytes.

## Original-event and replay proof (candidate check v2)

The candidate check protocol is `NEXUS-KERNEL-INTEGRATION-CHECK-v2`; the existing
event envelope remains `NEXUS-INTEGRATION-CONTRACT-v1`. This source-only revision
tightens the candidate readback interface, not deployed producer permissions.

The immutable-intent checksum includes original `occurred_at`, original Nexus
`received_at`, lifecycle `contract_version`, and any unknown lifecycle fields.
Only `expected_revision` and the following progress fields are excluded:
`processing_status`, `review_status`, `reconciliation_status`, `error_status`,
`verification_state`, and `processed_at`. A replay attempt's receipt time belongs
in the existing separate attempt record; it must not overwrite original event
acceptance time. Changing immutable event bytes requires conflict handling or a
new linked correction. Full-packet review/readback hashes still cover progress.

`idempotency_readback=null` means the approved reader found no original record;
an absent property means the duplicate check is unknown. Neither can support
`processing_status=REPLAYED`, in preflight or closure. Every non-null readback
must include the original `event_id`, `idempotency_key`, `intent_sha256`, stable
canonical `record_ref`, source `version`, approved `authority_ref`, fresh
`read_at`, and nonempty `evidence_refs`. The trusted reader must derive the digest
from the stored original event, not echo the submitting packet or author hash.
Freshness applies to reading the original, not to its occurrence date.

Closure requires the original and current readbacks to identify the same
canonical record. Their versions may differ as mutable progress advances, but
original identity and intent must match. A matching original still makes every
duplicate preflight HOLD; it never permits a second execution. Passing replay
closure is only a structural check, not proof that an attempt was persisted,
authenticated, atomically deduplicated or recovered successfully.

There is no legacy-digest fallback: v1's lifecycle-omitting checksum cannot prove
immutable timestamps. Existing candidate snapshots must be reread/reviewed under
v2 and the current policy binding, deriving the digest from trusted original
bytes. Missing original evidence remains HOLD. No runtime migration, automatic
digest replacement, contract promotion or live deployment is included.

## Recovery and completion honesty

Only a known transient, non-financial failure within the runtime's approved
attempt limit may be labelled retry-eligible. The helper never retries.
Unknown submissions, credentials/authority failures, permanent errors and
conflicts remain HOLD; no financial retry is inferred from this gate.

The checked-in coverage map requires evidence for every named integration
boundary. Local unit tests, a sandbox receipt, deployment, authenticated negative
tests and production readback are different facts. UNKNOWN is not ABSENT.
Production coverage must remain blocked until exact bindings, independent
review, deny/bypass tests, rollback/recovery and receipts are all verified.

No production migrations, workflow activation, mandatory branch-protection
changes or remote export are authorized by this source artifact.
