# Stock review entrypoint

Use the executable gate, which reads the current checkout's
[doctrine](../../docs/governance/NEXUS_INVESTMENT_ANALYSIS_DOCTRINE_20261001.md)
on every call. It does not depend on conversational memory.

```sh
python3 scripts/stock_review_gate.py begin TICKER path/to/draft.json
python3 scripts/stock_review_gate.py check path/to/draft.json
python3 scripts/stock_review_gate.py complete path/to/draft.json path/to/completed.json
```

Run these from the repository root. On Windows, `python` can replace `python3`.
The output's parent directory must exist. Output files are created exclusively;
the command never overwrites an earlier review. `begin` prints the full doctrine
and creates a draft containing every required evidence field and its doctrine
SHA-256. Read the doctrine, fill the draft, then run `complete`.

`check` allows explicitly incomplete drafts; a draft is never a completed review.
`complete` refuses unknown evidence, missing required fields, unsupported core
omissions, unresolved material gaps, missing valuation/price context, or a stale
doctrine binding. Conditional metrics may be marked `not_applicable` with a reason;
core questions require a fully sourced sector substitute if not directly applicable.
The gate checks source metadata structure, not source truth or analytical quality.

Sources use `url`, `type` (`filing`, `earnings_release`, or `earnings_call`),
`published_on` (YYYY-MM-DD), and `locator` (page or section). Benchmarks use
`proposed` or `approved`. Values and comparisons are explanatory strings, allowing
units, definitions, fiscal periods, and sector-specific measures without invented
universal numeric cutoffs. Price timestamps require a timezone.

If doctrine changes, create a new draft against the new checkout and reassess the
evidence before completion. Do not merely edit the old hash to hide a policy change.
The receipt is a consistency checksum, not a signature or proof of human review.
Validation recomputes all requirements, even when a receipt is present.

## Repository enforcement boundary

Only sanitized, public-source review JSON belongs in this **public repository**.
Keep holdings, account data, personal circumstances, and private evidence in the
authorized private research store. The gate can process local files outside Git.

GitHub Actions automatically runs tests and validates all `*.json` packets under
this directory, recursively, on pull requests and pushes to main. Use JSON here
for machine-checked reviews; prose elsewhere is not covered by this validator.
An empty collection is reported as zero reviews, not as a completed stock analysis.

The `stock-review-gate` check must be required in branch protection/rulesets to
prevent a failed check from being merged. Merely installing the workflow does
not establish that protection; verify the repository setting separately. The
gate cannot stop an administrator changing its code or bypassing repository rules.

No historical PostgreSQL migration, live database, n8n workflow, broker boundary,
or Command Tower runtime is changed by this file-based gate. A live engine must
invoke equivalent validation at its actual completion/write boundary before
system-wide enforcement can be claimed. The current live completion path has
not been verified from this environment.
