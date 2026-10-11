# Existing Nexus kernel: integration gate

Implementation candidate. No new kernel, registry, scheduler or canonical store.
No live deployment. All eight integration profiles remain **UNVERIFIED for
production wiring to this gate**, even where their upstream systems already work.

Read [BOUNDARY.md](BOUNDARY.md) first. [coverage.json](coverage.json) lists every
profile, regression test and missing production proof. It is a source/test
coverage checklist, not the runtime mission registry. Existing identities and
per-domain authority must be preserved.

```sh
python3 -m unittest discover -s tests -p 'test_*.py' -v
python3 scripts/stock_review_gate.py check-repository
python3 scripts/kernel_integration_gate.py binding
python3 scripts/kernel_integration_gate.py preflight /private/packet.json --context /private/runtime-snapshot.json
python3 scripts/kernel_integration_gate.py closure /private/packet.json --context /private/runtime-snapshot.json
```

Both checks are non-mutating. Exit 0 means `STRUCTURE_PASS`, not permission to
execute or production verification. Exit 1 means HOLD. Policy checksums are
loaded from the actual checkout on every call. The implementation reuses the
existing stock-review gate for research completion. No additional dependency
installation is required.

The synthetic fixtures in `tests/test_kernel_integration_gate.py` show the
packet/context interface for all profiles. They are not research, real receipts,
live authority or canonical registry IDs. Private evidence and runtime snapshots
stay outside this public repository. The CLI only emits validation errors and
bounded status, not supplied business payloads.

## Integration sequence

An existing adapter resolves approved identity, route, authenticated actor,
policy, freshness and state; calls preflight; obeys HOLD; performs only separately
authorized work through the existing controlled gateway; obtains independent
review and canonical/mirror readbacks; and calls closure before reporting success.
The final state change must use the runtime's atomic revision and idempotency
guard. This package does not supply that database transaction or replace it.

The approved upstream idempotency key is passed through; no new production key
formula is established. Candidate check **v2** commits original occurrence and
acceptance times, contract identity and unknown lifecycle fields in its intent
checksum. Only explicitly listed progress fields and the expected revision are
excluded; see [the replay boundary](BOUNDARY.md#original-event-and-replay-proof-candidate-check-v2).
The full-packet hash binds review and canonical readback to the current check.
These are consistency checks, never cryptographic attestations of source truth.

A repeated preflight returns HOLD with `DUPLICATE_REUSE_ONLY`; fetch the original
receipt rather than execute again. `REPLAYED` requires a non-null original-event
readback with matching identity and immutable intent, canonical locator/version,
approved authority, fresh read timestamp and evidence. Closure binds that original
to the same current canonical record. A null original lookup is valid only for
non-replayed work; a missing lookup is unknown. Changed source content is a
conflict or linked correction, not permission to overwrite history. V1 candidate
digests are not accepted as a fallback; re-read trusted original evidence and
review under v2 before use. No live consumer or database state is migrated here.

## Read-only research receipt adapter

The [read-only research receipt adapter](RESEARCH_RECEIPT_ADAPTER.md) checks an
explicit receipt-to-original-packet binding and preserves the original packet.
It reuses this gate; it does not create missing identity or authenticate a JSON
snapshot. Its runtime status remains HOLD, even on a structural pass.

## Read-only live readiness diagnostics

The [engine readiness projection](ENGINE_READINESS.md) prioritizes CT live-path
diagnostics: portfolio visibility, symbol eligibility, authentication, exact
confirmation controls and receipt reconciliation. It checks supplied source
times and separate requirements without fetching data or granting authority.
Paper is a separate optional scope and cannot determine live readiness.
All reports retain `HOLD_UNAUTHENTICATED`; no endpoint or gate binding is added.

## What remains outside this build

The separately scoped [private sandbox reader](sandbox/README.md) observes
existing cloud controls through a restricted database role. It does not call
this Python gate or satisfy authenticated packet/context integration, and it
does not lift any production-wiring or federation HOLD.

- Authenticated cloud hosting and wiring of the real completion/write boundaries.
- Existing Mission Registry / lane / event-family schema bindings and writer ownership.
- Atomic persistence, outbox delivery, real concurrency and restart recovery.
- Current trigger/heartbeat liveness and alerts; no replacement schedules created.
- Independent code review, governed source promotion and production approval.
- Validation of source truth and analytical quality; structural checks cannot do it.

Live packets intentionally HOLD. Removing that guard is a separate reviewed
change after the ten promotion requirements are met. No money-moving code exists.
