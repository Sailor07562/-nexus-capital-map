# Read-only research receipt adapter

Status: SOURCE CANDIDATE. No deployment, authentication or runtime admission.

`scripts/research_receipt_adapter.py` carries an already recovered research
packet into the existing `research_completion` preflight without rewriting it.
It does not reconstruct missing research from receipt labels, re-finalize a
stock review, invent event IDs or register a new lane. The existing integration
contract v1 and candidate validator v2 remain unchanged.

## Three separate inputs

| Input | Purpose | Never inferred from it |
| --- | --- | --- |
| Documentary observation | Exact saved receipt/mission/review IDs, native references, capture time and separate research/valuation/investment statuses | Actor, event UUID, event version, approval, route or idempotency |
| Original packet | Existing versioned event with original identity, lifecycle, policy binding and machine-readable research payload | Missing fields; no defaulting, timestamp refresh or current-policy rebinding |
| Separate context | Existing gate context plus `receipt_binding`, recovered by an approved reader | Authentication from a local file or a submitter's claim |

The adapter input protocol identifies a source-code interface, not a new
canonical event contract, registry or authority record. Its API returns a deep
copy of the original packet only on `STRUCTURE_PASS`; otherwise it returns no
candidate. Neither result permits submission. No source data is fetched and no
state is written. Runtime admission remains `HOLD_UNAUTHENTICATED` in all cases.

The observation requires `observation_kind` equal to
`DOCUMENTARY_RECEIPT_READBACK_NOT_RUNTIME_ENVELOPE`, `captured_at` in UTC Z form,
`receipt_id`, `mission_id`, `reviewer_receipt_id`, `research_status=COMPLETE`,
explicit `valuation_status` and `investment_status`, and distinct `source_refs`.
Extra documentary fields remain part of the observation fingerprint, never
authority inputs. Investment HOLD and valuation CONDITIONAL do not become a
research decoder decision, and a conditional review display is not promoted to
an approved runtime review.

## Receipt binding snapshot

The separate context must contain `receipt_binding` with all of these fields:

| Fields | Required relationship |
| --- | --- |
| `receipt_id`, `mission_id` | Match the observed receipt; mission also matches the original packet |
| `source_system`, `source_record_id`, `source_version` | Match the original packet's source identity; source record and receipt IDs need not be identical |
| `observation_sha256` | Digest of the complete documentary observation |
| `packet_sha256` | Existing gate's complete packet digest |
| `research_packet_sha256` | Digest of the complete embedded research packet, including its stock gate receipt |
| `record_ref`, `mapping_version`, `mapping_refs`, `evidence_refs` | Versioned, explicit native receipt-to-event linkage from existing records |
| `review_receipt_id`, `reviewer_id`, `review_evidence_refs` | Original recorded review bound to a resolved principal distinct from the packet author |
| `read_at` | UTC Z read time between observation capture and context capture, within the separately supplied runtime freshness policy |

Digests use the existing stock/kernel canonical JSON implementation. They are
consistency fingerprints, not signatures, approved idempotency keys, event
revisions or proof of source truth. A support-model hash/version is a different
artifact and is never substituted. A read timestamp is not original occurrence
or acceptance time. The adapter preserves those event timestamps and all unknown
packet fields, keeping original subject/intent hashes unchanged.

This build does not implement the approved reader. An independently resolved
review principal is required structurally, but the CLI cannot authenticate it.
Exact-packet independent review, canonical/mirror readbacks and atomic write
admission remain in the existing closure/runtime boundary. An original duplicate
still produces the existing preflight HOLD; the adapter never re-executes it.

## Run privately

```sh
python3 -B scripts/research_receipt_adapter.py /private/receipt-observation.json
python3 -B scripts/research_receipt_adapter.py /private/receipt-observation.json --packet /private/original-packet.json --context /private/reader-snapshot.json
python3 -B -m unittest discover -s tests -p 'test_*.py'
```

With only a receipt, the first command returns HOLD and identifies the missing
envelope/context. It does not create partial or invented event data. The second
checks explicit linkage and invokes the unchanged kernel preflight, which invokes
the unchanged stock-review gate. Missing duplicate-readback remains unknown,
not `null`; missing exception context remains unknown, not an empty list. Live
environment remains HOLD, never silently relabelled as sandbox.

CLI exit 0 means structural consistency only; exit 1 means HOLD. Output contains
diagnostics and fingerprints, not supplied business payloads or private paths.
The nested `gate_result` is a bounded projection, not the raw validator report:
known status fields and error codes are retained, while every error detail is
replaced with a fixed message. Unknown codes become `GATE_DIAGNOSTIC`; extra
fields and nested diagnostic objects are omitted rather than stringified.
Malformed or contradictory gate reports fail closed. This includes policy-file
and stock-validator exception paths, which can otherwise contain private paths,
URLs or supplied text. The existing kernel and stock validators are unchanged;
their direct CLI output is outside this adapter's reporting boundary.

The API does not mutate inputs; the CLI does not write files. Private receipts,
runtime snapshots and reviewer identities must stay outside the public source
repository. Tests contain synthetic evidence only. No extra dependency,
credential, endpoint, scheduler, migration, grant, database write or financial
operation is included.
