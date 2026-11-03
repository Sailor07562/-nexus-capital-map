# Kernel replay consistency repair — 2026-10-11

Status: AUTHOR-TESTED SOURCE CANDIDATE / EXACT-HEAD RE-REVIEW REQUIRED.
Existing draft [PR #33](https://github.com/Sailor07562/-nexus-capital-map/pull/33).
Parent published head: `f4c19ca820788d1537b1c3f387a9c19e5641ce72`.

## Findings and reproduction

The independent source review identified one confirmed P2 and one separate
replay-proof contract gap. Both accepted paths were reproduced locally against
the parent source before the fix, using synthetic fixtures only:

1. Changing only original `occurred_at` from fixture `time(-90)` to `time(-100)`
   and rebinding the current review/canonical hashes retained the same old
   intent digest. Closure incorrectly returned `STRUCTURE_PASS` despite a
   readback of the original intent.
2. Changing processing status to `REPLAYED`, rebinding current hashes and leaving
   `idempotency_readback=null` returned `STRUCTURE_PASS`. This second item was a
   proof-contract clarification, not a demonstrated production exploit.

The new regression tests were run against the unfixed source and failed on
these cases. No runtime replay, canonical write or financial action was tried.

## Repair

- Candidate check protocol advances to `NEXUS-KERNEL-INTEGRATION-CHECK-v2`.
  The existing integration event contract remains v1; no live contract or
  consumer is migrated by this source publication.
- Immutable intent includes original source occurrence and Nexus acceptance
  times, lifecycle contract identity and unknown future fields. Only six
  explicit progress fields and expected revision are excluded. A replay's own
  receipt timestamp belongs in its separately recorded attempt.
- `REPLAYED` now requires an original-event readback in both phases. All
  non-null original readbacks require matching identity/key/intent, a canonical
  locator and version, approved authority, fresh read time and evidence.
- Original and current canonical readbacks must name the same record at
  closure; mutable progress versions may advance. Duplicate preflight remains
  HOLD even with matching proof.
- There is no legacy-digest compatibility fallback. The boundary documents
  trusted-reader provenance, re-review under current policy, and failure to
  advance when original evidence cannot be recovered.

These are structural checks only. An author-supplied context is not authenticated
evidence. Reader authentication, separate attempt persistence, atomic uniqueness,
write-boundary enforcement and actual recovery remain unverified requirements.

## Author verification

Commands, from the repository root:

```sh
python3 -m unittest discover -s tests -p 'test_*.py'
python3 scripts/stock_review_gate.py check-repository
git diff --check
```

- **84 tests passed**, including the previous 72 and 12 added regression methods.
  The 15 stock-review tests are included in 84, not an additional suite count.
- Timestamp conflict and missing replay proof are exercised across all eight
  profiles and both phases. Positive replay closure checks retain false
  execution/production/state-change flags and input immutability.
- Further regressions cover explicit progress exclusions, unknown immutable
  fields, legacy digests, identity, locator, authority, stale/future/missing read
  timestamps, missing evidence, original/current record mismatch and live HOLD.
- Existing stock-review repository check passes with zero packets/zero complete;
  this is not completed research. Whitespace/diff check passes.

Remote publication byte parity, CI runs and the exact new head belong in the PR
publication receipt after publication. These local results do not pre-clear
independent re-review.

## Unchanged boundaries

No database/migration/grant/RLS change, credential change, deployment, merge,
branch-protection change, new mission/registry/scheduler, lane population or
financial action. The previously approved private sandbox reader is unchanged.
All eight production bindings and the authoritative eleven-lane mapping remain
unresolved; broader integration remains HOLD. Separate existing live-trading
authority is unchanged and is not governed by this candidate's HOLD.
