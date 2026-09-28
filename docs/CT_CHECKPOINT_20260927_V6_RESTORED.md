# Command Tower Checkpoint — v6 Restored Read-Only Surface

Date: 2026-09-27

Checkpoint ID: `CT-RESTORE-V6-20260927`

## Purpose

Lock the restored Command Tower state after recovery from a placeholder/shell regression.

This checkpoint preserves the working CT surface that restores:

- actual reconciled portfolio / stocks view
- XLP holding and Paper receipt readback
- Tools inventory
- Adapters inventory
- State Research Radar data lane
- clickable local and external evidence links

## Runtime

- Local URL: `http://127.0.0.1:8080`
- App command: `node --env-file=.env app/server.js`
- Mode: read-only cockpit

## Restored routes

- `/api/live-status`
- `/api/capital-snapshot`
- `/api/portfolio`
- `/api/stocks`
- `/api/xlp-receipt`
- `/api/tools`
- `/api/adapters`
- `/api/data`

## Restored evidence file routes

- `/evidence/file/capital-map-html`
- `/evidence/file/decision-engine-csv`
- `/evidence/file/state-lane-pack`
- `/evidence/file/state-migration-124`
- `/evidence/file/xlp-workflow`
- `/evidence/file/xlp-submission-receipt`
- `/evidence/file/xlp-ledger-receipt`
- `/evidence/state-pdf/<known state PDF filename>`

Evidence routes are constrained to known local files and the known State Research Radar PDF folder.

## Verified surface counts

- Portfolio holdings: 14
- Portfolio accounts represented: 3
- Captured securities value: `$4,452.18`
- XLP holding value: `$100.14`
- XLP client order: `NEXUS-XLP-PAPER-20260922-001`
- XLP ledger state: `expired`
- XLP filled quantity: `0`
- n8n workflows: 26
- active n8n workflows: 7
- Command Tower scripts: 19
- CT read-only endpoints: 6
- PostgreSQL read-only approved views: 8
- external integration surfaces: 2
- connector files: 6
- Thread Adapter routes: 11
- State Research rows surfaced: 7
- PostgreSQL-seeded State Research Radar lanes: 5
- saved State Research PDF filings: 10

## Boundaries

This checkpoint does not authorize:

- SQL writes
- n8n workflow mutation
- scraper deployment
- broker submission
- trade action
- transfer/money movement
- thesis promotion

Command Tower remains a read-only visibility surface. PostgreSQL remains semantic authority; n8n remains executor; broker actions remain separately gated.

## Recovery instruction

If Command Tower regresses again, return to the Git checkpoint/tag associated with this receipt before rebuilding from scratch.

Use this checkpoint as the known-good restored CT v6 state.
