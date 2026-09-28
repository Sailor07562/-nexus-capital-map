# Intelligence prototype build receipt

Date: 2026-09-28
Version: 0.1.0
State: Built as an isolated, executable repository module; live integration pending.

## Delivered

- Five-stage evidence -> constraint -> solution -> spending -> thesis contract, including four explicit causal relationships.
- Six reasoning dimensions: materiality, timing, value capture, connected effects, disconfirmation and learning.
- Human/AI reasoning prompt with explicit source and uncertainty requirements.
- Dependency-free Node.js library and CLI with input validation, event deduplication, evidence currency checks and incomplete-case reporting.
- JSON/Markdown review packets with separate input, assessment and completion receipt.
- Revision fingerprint checks and field-level comparison without overwriting prior runs.
- Sanitized synthetic example and basic mechanical smoke check.

## Execution evidence

Executed on Node.js v24.19.0 in the development workspace:

1. `node integrations/intelligence/smoke.mjs` — passed synthetic assembly, missing-link handling, invalid-reference rejection, stale/news-only evidence handling, synthetic separation and revision lineage.
2. `node integrations/intelligence/cli.mjs assess integrations/intelligence/synthetic-example.json --out <development-run-directory>` — exited 0; readiness DOCUMENTED_FOR_REVIEW; gaps 0; synthetic true; review files written.

This is a mechanical build check. No real issuer, project, investment conclusion or production behavior was verified. Node 18+ is the intended minimum based on the built-in APIs used; this run used Node 24.19.0. Windows execution has not been checked.

## Next phase

The user's sequence is build -> test -> refine. Test a real evidence case and an incomplete case, evaluate reasoning quality, then refine the contract and map the module to verified existing Nexus fields. A deployed model provider, evidence acquisition workflow, canonical PostgreSQL persistence and Command Tower projection are not part of this prototype.

The module checks supplied reasoning and declared provenance. It does not independently verify sources, generate causal analysis from raw news, or grant action authority. Repository promotion remains subject to the existing branch review process.
