# Engine readiness diagnostics

Status: SOURCE CANDIDATE. **CT live trading is the priority.** Paper diagnostics
are a separate explicitly selected scope. Neither scope grants execution rights.

`scripts/engine_readiness.py` projects supplied observations and separately
supplied requirements into a bounded diagnostic report. It does not collect
data, call the kernel, authenticate a caller, connect an endpoint, approve a
policy, select a trade or submit an order. It preserves the existing kernel,
stock validator and research receipt adapter unchanged.

Even `STRUCTURE_PASS` means consistency within the **declared input scope** only.
`runtime_status` is always `HOLD_UNAUTHENTICATED`; authentication, production,
execution, state-change, broker-action and automatic-promotion flags are false.
No result from this tool may replace the existing live confirmation boundary.

## Live scope first

Both inputs must explicitly name `scope=ct_live`. Requirements must cover these
five diagnostic categories with existing, versioned source/component identities:

| Category | Evidence the future approved reader must resolve |
| --- | --- |
| `portfolio_read` | Current account/position visibility through the existing authenticated portfolio path, with its real observation time |
| `symbol_eligibility` | Current broker and CT eligibility for the selected scope; eligibility is independent of whether a stock is already held |
| `command_authentication` | Approved operator, reader and route evidence; a role label or successful public health response is insufficient |
| `confirmation_boundary` | Existing exact human confirmation and action-time ticket controls, with cash-only and disabled automatic-trading restrictions |
| `receipt_reconciliation` | Existing receipt and reconciliation state; unresolved broker outcomes remain blocked, never retry instructions |

These are diagnostic categories, not new engine, lane, mission or route IDs.
The requirements snapshot must identify the actual approved current input set.
The checker can detect omissions from that declared set, but cannot prove the
set itself is authoritative or complete. No production identities or freshness
windows are shipped with the code.

Requirements also need an existing `required_input_set`: `set_id`, `revision`,
`approval_ref`, `approval_status=APPROVED`, and matching `engine_id`,
`engine_revision` and `scope`. Missing set approval leaves ages visible but all
freshness UNASSESSED. This records the owner-approved scope decision; a file
containing these fields still cannot prove approval.

Live boundary fields are `environment=alpaca_live`, `route_id`, `route_revision`,
`operator_id`, `reader_id` and `authority_ref`. The separate
`live_scope_resolution` must match all five identity fields and include
`decision_ref`, `revision`, `approval_status=APPROVED` and
`operation=ct_live_readiness`. This is a recorded configuration decision for
diagnostics, **not an action-time trade ticket**.

The boundary must explicitly record these booleans:

- True: `requires_exact_confirmation`, `requires_action_time_ticket`,
  `requires_reconciliation`, `cash_only`.
- False: `automatic_trading_enabled`, `transfers_enabled`, `margin_enabled`,
  `short_sales_enabled`, `options_enabled`, `crypto_enabled`.

Unknown or conflicting controls HOLD. Files and matching identifiers do not
authenticate these assertions. The real controlled workflow still owns every
order's approval, cash/cap checks, broker state, idempotency and reconciliation.

## Additional stocks without a source-code ticker list

The live `symbol_eligibility` component carries an `assets` array. Its matching
requirement carries `asset_scope`. Additional stocks are supplied through these
existing-reader snapshots, not added to an allowlist in this Python source.
Current holdings are not an eligibility condition. The test suite adds several
new synthetic symbols to the same fixture without any implementation change.

Each observed asset supplies `asset_id`, `symbol`, `asset_class`, `status`,
`tradable`, `fractionable` and `observed_at`. The adapter must preserve the broker
asset ID and canonical symbol; `asset_id` corresponds to Alpaca's `id` and
`asset_class` to its `class`. A symbol change never silently reuses an approval
for a different asset. Supported diagnostic symbols are uppercase letters,
digits, dots and hyphens, up to 32 characters. This validation syntax is not a
claim that every such string is a broker asset.

Each matching `asset_scope` entry requires `asset_id`, `symbol`,
`approval_status=APPROVED`, `live_enabled=true`, `approval_ref`,
`approval_revision` and explicit boolean `fractional_required`. The named
approval must come from the existing Nexus permission records. Broker
tradability alone never grants Nexus live enablement.

The observed asset must be active, `us_equity`, tradable, and carry a boolean
fractionable flag. Fractional or notional eligibility additionally requires
fractionable=true when that usage is requested. Whole-share eligibility does
not require fractionability and does not automatically convert an order type.
This is a basic metadata check, not complete account/order eligibility: market
sessions, halts, special asset restrictions, cash, order limits and exact trade
terms remain enforced by the existing live workflow and its trusted reader.

Asset IDs and symbols must be unique, and the observed and approved asset sets
must match. Every asset observation time must occur exactly once in the
component's `required_source_times` multiset, including repeated timestamps for
different assets. Old metadata cannot be hidden behind a fresh aggregate time.
The diagnostic limit is 1,000 assets per checked scope; this is not a portfolio
capacity or trading-universe limit. No partial scope may be presented as complete.

Broker interface references: [asset lookup by ID or symbol](https://docs.alpaca.markets/us/reference/get-v2-assets-symbol_or_asset_id)
and [fractional asset eligibility](https://docs.alpaca.markets/us/docs/fractional-trading).
These describe the reader's data source; this module performs no broker request.

The later deployment must make CT's selectable universe consume existing live
enablement records plus current broker eligibility, independently of holdings.
UI, command preparation and execution must agree on the same asset identity and
policy revision. Adding a stock should require its existing governance workflow
and data entry, not another ticker-specific code patch. This source candidate
does not remove deployed CT symbol restrictions or activate new symbols.

## Common observation and requirements interface

Both objects require matching `engine_id`, `engine_revision`, `scope` and
nonempty `components` arrays. Each component in both arrays must carry matching
`component_id`, `component_kind`, `source_object`, `source_revision`,
`scope_ref`, `scope_revision` and `timestamp_meaning`. The scope identifies the existing selection of
**current required input records**, rather than all historical rows.

Every requirement must explicitly declare `required=true`,
`empty_semantics=HOLD` and `timestamp_meaning=source_observation` or
`read_receipt`. This version supports only required, nonempty diagnostic
observations. Optional or empty-allowed semantics need a separately reviewed
implementation; they are not silently accepted or invented. A read receipt's
timestamp describes that receipt, never the age of underlying business data.
The reader must select source observations wherever actual source age is needed.

Each observed component additionally supplies:

| Field | Meaning |
| --- | --- |
| `read_status` | `AVAILABLE` or `UNAVAILABLE`; an unavailable read must omit `required_source_times` or set it to null |
| `source_status` | `CLEAR`, `BLOCKED` or `UNKNOWN`, resolved by the approved source-specific reader; fresh timestamps cannot turn BLOCKED into CLEAR |
| `read_at` | Explicit UTC Z time of this read; never a replacement for source observation times |
| `required_source_times` | One UTC Z observation time or null per required input record; an empty list is an evidenced empty selection, not an unavailable read |

The report's `row_count` counts these required observations, **not positions or
shares**. For portfolio visibility, a successful account/positions read receipt
can be a required observation even when the account has no holdings. The future
reader must preserve that distinction; absence of holdings does not prohibit
researching or preparing a separately authorized new-stock trade.

Each required component has a separate `freshness_rule` object with `rule_id`,
`revision`, `approval_ref`, `approval_status=APPROVED` and a positive integer
`max_age_seconds`. These must come from an existing approved rule. Missing or
unapproved rules produce `UNASSESSED`, retaining source ages and admission HOLD.
Boolean, floating-point and zero age bounds are rejected. No default age rule is
invented and no approval is inferred from an observation.

The API requires explicit `evaluated_at`; the CLI requires `--at`. Timestamps
must be full UTC Z timestamps, optionally with 1–6 fractional-second digits.
Missing, invalid, future or read-before-source times HOLD. Oldest and newest
required observations remain separate; **any required stale row blocks the
component**. The age limit is inclusive. A recently read old source remains old.

Empty selections, unavailable reads, unknown/blocked source status, missing,
extra or duplicate components, and changed source/scope revisions all HOLD.
Limits are 64 components and 10,000 required source times per component; excess
input HOLDs instead of silently dropping rows or declaring partial coverage.

## Separate paper scope

`scope=paper` in both inputs selects the optional paper diagnostic. A live check
does not consume paper policies or paper connection flags. A disabled paper
connection therefore cannot determine the separately governed CT live result.

The observation's `paper_boundary` contains `parent_mode`, `policy` and
`connection`. Parent mode is `paper_approval_gated` or `sandbox_automated`.
Policy fields: `policy_id`, `revision`, `connection_id`, `status`, `mode`,
`requires_human_confirmation`, `environment`, `live_trading_enabled`.
Connection fields: `connection_id`, `revision`, `requires_human_confirmation`,
`order_submission_enabled`, `environment`, `live_trading_enabled`.
Policy mode is `human_approval_gated` or `sandbox_automated`.

An active policy cannot override disabled connection submission. Both objects
must explicitly be paper-only with live flags false. Gated policy mode requires
confirmation true; either policy or connection requiring confirmation keeps it
required. Parent mode and policy mode remain separate in the report.

The requirements' `paper_scope_resolution` requires `decision_ref`, `revision`,
`approval_status=APPROVED`, `operation=paper_order_submission`, plus exact matching
`parent_mode`, `policy_mode`, `policy_id`, `policy_revision`, `connection_id`,
`connection_revision`, `policy_requires_confirmation`,
`connection_requires_confirmation` and `connection_submission_enabled`.
Those three flags must be booleans. Missing resolution remains HOLD; it never
silently resolves parent/child differences or supplies live authority.

## Private execution and output

```sh
python3 -B scripts/engine_readiness.py /private/live-observations.json --requirements /private/existing-requirements.json --at 2030-01-01T00:00:00Z
python3 -B -m unittest discover -s tests -p 'test_*.py'
```

The date above and all fixtures in `tests/test_engine_readiness.py` are synthetic.
`live_fixture()` illustrates the live interface; `fixture()` covers the separate
paper interface. Do not populate production requirements from test fixtures.
CLI exit 0 is structural consistency only; exit 1 is HOLD.

The report intentionally includes valid supplied identity/reference fields,
valid timestamps, counts, ages, known statuses and boundary flags. Identifiers
are bounded to 128 characters drawn from letters, digits, underscore, dot,
colon and hyphen, starting with a letter or digit. It does not emit raw business
payloads, unknown fields, invalid timestamp text, paths or exception messages.
Do not place secrets in identity fields. Private reports and actual snapshots
stay outside the public repository. Unknown fields are never authority inputs.

Strict JSON rejects duplicate keys and non-finite values. CLI input/argument
failures produce fixed codes without echoing filenames or supplied arguments.
Inputs are not modified; the CLI writes only its report to stdout.

## Remaining integration proof

The approved reader, actual mobile response, authenticated negative tests,
operation-bound proof, private database principal, read-only transaction,
freshness policies and effective privileges remain outside this build. Real
clock trust, source truth, atomic admission and check/use races remain runtime
responsibilities. No source-only diagnostic satisfies them. Live and paper
scope cannot be silently relabelled to obtain a passing report.

No credentials, dependencies, registry, scheduler, migration, grants, broker
calls, worker activation or deployment are added by this candidate.
