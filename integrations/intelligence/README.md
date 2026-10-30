# Nexus intelligence prototype v0.1

Build first, then test and refine. This module implements the evidence-to-thesis assessment contract inside the existing repository's integrations area. It is not registered as a new production Engine or official adapter.

## What runs

`intelligence.mjs` exposes `blankPacket`, `validate`, `assess`, `compare`, `render` and `fingerprint`. `cli.mjs` creates case templates, prepares an AI reasoning prompt, and writes review packets from completed cases. It uses Node.js built-ins only (Node 18+); no package installation, API key or network connection is required.

The reasoning is supplied by a human or AI using `REASONING_PROMPT.md`. The module validates and assembles that reasoning; it does not autonomously understand raw articles or authenticate sources. No model provider is wired into this prototype.

## Run from repository root (PowerShell or a shell)

```powershell
node integrations/intelligence/cli.mjs init my-case.json
node integrations/intelligence/cli.mjs prompt my-case.json
node integrations/intelligence/cli.mjs assess my-case.json --out intelligence-runs
```

Populate the case with source records and the five-stage reasoning, manually or using the printed prompt with an authorized AI. The empty template intentionally produces an incomplete review until populated. A synthetic example is available:

```powershell
node integrations/intelligence/cli.mjs assess integrations/intelligence/synthetic-example.json --out intelligence-runs
```

Each successful run creates a new directory containing `input.json`, `assessment.json`, `review.md` and `receipt.json`. A revised case additionally produces `changes.json`:

```powershell
node integrations/intelligence/cli.mjs assess revised-case.json --out intelligence-runs --prior intelligence-runs/PREVIOUS_RUN/input.json
```

Set `revision_of` to the previous assessment's `packet_sha256`, increment the revision and record `change_reason`. A mismatched case or fingerprint is rejected. These are local development receipts, not canonical Nexus IDs. Files are preserved by default, not cryptographically immutable storage. Only runs with `receipt.json` marked completed are complete; a failed write can leave a partial directory.

Keep actual evidence, case inputs and generated runs outside Git. Only sanitized synthetic fixtures belong in this public repository.

## Input contract

Start with `init`; the template is the authoritative field shape for schema version 1. Each claim has `statement`, `basis`, `rationale`, `evidence_ids` and `unknowns`. Claim groups are the five chain stages, their four causal links and all six reasoning dimensions.

Evidence records have `id`, `event_id`, `source`, `locator`, `claim`, `date`, `review_after`, `source_type` (PRIMARY/NEWS/COMMENTARY), `verification` (VERIFIED/UNVERIFIED), `relevance` (CURRENT/AGING/STALE/SUPERSEDED), and `synthetic` (boolean). Dates use YYYY-MM-DD. Verification and relevance are supplied by a reviewer; the program does not certify them. `review_after` is chosen for that evidence's context, not a universal expiry period.

The evaluator requires current, reviewer-verified primary evidence for each resolved claim. An overdue review date, unresolved relationship, missing spending element or open question makes the packet INCOMPLETE. An inference can be documented for review without becoming a fact. Multiple references are grouped by event_id. Contradictory evidence and no-material-impact findings remain visible.

`DOCUMENTED_FOR_REVIEW` describes completeness of declared relationships only. It does not mean true, investment-ready, approved or production-verified. Synthetic cases always retain a prominent synthetic flag. Proposed spending may support an expectation only; it must not be rendered as realized revenue. Structural checks cannot detect every semantic contradiction.

## Existing Nexus integration boundary

Intended placement: approved evidence export -> authorized reasoning step -> this pure assessment module -> human review packet. An n8n host can call an approved local wrapper or import the module where supported; the module itself neither deploys a workflow nor writes to PostgreSQL. Source outputs are portable JSON and Markdown.

PostgreSQL remains canonical. Before live wiring, map fields to actual mission, evidence and thesis contracts. Do not guess table names, check-constraint values or authority enums. Command Tower can later consume a reviewed projection through its existing read-only adapter; no browser-to-database connection is added.

No SQL migration, live database write, n8n activation, Command Tower replacement or broker operation is included. GitHub governance requires branch review before main promotion. The saved build is available for the subsequent test-and-refine cycle.

## Basic execution check

```powershell
node integrations/intelligence/smoke.mjs
```

This only checks mechanical behavior using synthetic data. Real evidence quality, usefulness, integration and thesis reasoning await the user's subsequent testing phase.
