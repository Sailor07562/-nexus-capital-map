# NEXUS ENGINE CANON

Created: 2026-09-22

Status: review candidate; not authoritative until merged through repository review.

## Prime rule

An Engine is not a vibe, a script, or a workflow.

An Engine is a governed capability with a declared purpose, explicit boundaries, receipts, and a visible authority surface.

If it cannot be inspected, bounded, and stopped, it is not an Engine yet.

## Engine admission standard

Every Nexus Engine must answer eight questions before promotion:

1. What need does this engine serve?
2. What problem is it allowed to solve?
3. What evidence may it use?
4. What may it observe, calculate, recommend, propose, or execute?
5. What is forbidden no matter what?
6. Where does it log receipts?
7. What promotes it from sandbox to paper to production?
8. Where does it stop and ask for human authority?

## Current engine map

### 1. Scraper / Intake Engine

Purpose: gather approved source packets into the governed intake queue.

Current state: live governed capability.

Authority: n8n may fetch allowlisted sources and call restricted PostgreSQL intake functions.

Receipts: `nexus.v_automation_intake_queue`, n8n execution history, controlled source registry.

Forbidden: autonomous crawling, evidence admission, thesis promotion, decisions, trades, or capital actions.

Promotion condition: source registry, dedupe, review queue, and human admission path must all read back clean.

### 2. Decision Engine

Purpose: turn admitted evidence and portfolio context into governed assessment state.

Current state: live formal engine.

Authority: PostgreSQL policy ledger, portfolio-context ledger, append-only assessments, read-only workbench and proposal queue.

Receipts: `nexus.v_decision_engine_workbench`, assessment/current views, proposal/review records.

Forbidden: direct trade execution, self-approval, capital movement, brokerage calls.

Promotion condition: zero bypass paths, reviewer-only approval functions, decision-grade valuation/cash/debt/reserve/overlap evidence.

### 3. Investing Engine

Purpose: orchestrate the investment workflow across intake, evidence, Decision Engine, capital controls, shadow observation, and Paper boundary.

Current state: live formal parent/orchestration engine.

Authority: aggregate views and component registry; does not duplicate Decision Engine.

Receipts: `nexus.v_investing_engine_status`, `nexus.v_investing_engine_workbench`, Command Tower census.

Forbidden: deciding its own mission, approving investments, enabling live trading, or submitting orders outside the Paper gate.

Promotion condition: verified component count, workbench readback, paper policy health, and no live-trading authority.

### 4. Capital Deployment Engine

Purpose: decide whether capital deployment is allowed after evidence, liquidity, reserve, debt, valuation, and overlap gates.

Current state: distributed governed capability; not a standalone object.

Authority: capital preservation posture, portfolio decision contexts, Decision Engine validation, and Paper policy gates.

Receipts: capital posture checks, Decision Engine assessments, policy health, Paper receipts.

Forbidden: treating available brokerage access as deployable cash, forcing deployment, live orders, transfers, margin, shorts, options, or crypto.

Promotion condition: explicit standalone authority surface or a documented distributed-control map with regression checks.

### 5. Research Radar Engine

Purpose: organize official-record signals, state lanes, research queues, and candidate review flow.

Current state: live review/radar capability; not thesis-promotion authority.

Authority: lane definitions, source definitions, pending signal queues, review status views.

Receipts: `nexus.v_research_radar_governance_health`, `nexus.v_research_radar_state_status`, review queues.

Forbidden: scraper deployment without authorization, thesis promotion, Decision Engine override, trade action.

Promotion condition: official-record-first source rules, lane validation, human review gates, and zero scraper/trade violations.

### 6. Consumer Intelligence / Consumer Review Engine

Purpose: manage consumer-sector/lender review packets, sufficiency checks, monitoring-only statuses, and review completion.

Current state: live review capability; monitoring-only capital boundary.

Authority: consumer review packet views, completion status, requirements, artifacts, and monitoring-only records.

Receipts: consumer review dashboards, completion status views, packet artifacts, backup packages.

Forbidden: turning review completion into investment approval, capital action, or trade authority.

Promotion condition: packet evidence, thesis-owner attestation, source sufficiency, human review, and explicit monitoring/action split.

### 7. Governance Engine

Purpose: enforce cross-system authority, scope, boundaries, compliance tests, and promotion gates.

Current state: candidate engine; governance framework exists, but engine promotion requires explicit authority mapping and tests.

Authority: broader Nexus Governance database, doctrines, authority records, tool-boundary records, audit/history tables.

Receipts: governance registrations, certifications, compliance tests, Command Tower pass/fail gates.

Forbidden: claiming formal Nexus governance from local safeguards alone, bypassing human authority, or treating documentation as enforcement.

Promotion condition: Capital Map registration, authority mapping, boundary tests, compliance readback, and cross-system receipts.

### 8. Infrastructure Context Engine

Purpose: map raw signals, infrastructure context, environment/constraint relationships, and contextual routing for downstream engines.

Current state: historical/candidate capability; not current capital authority.

Authority: raw signal context, routing metadata, infrastructure-context records if reactivated.

Receipts: raw signal intake, linked context records, validation artifacts.

Forbidden: replacing evidence admission, inventing source authority, or pushing signals into decisions without review.

Promotion condition: refreshed schema location, source provenance, replay-safe validation, Command Tower visibility.

## Operating chain

Foundation governs purpose.

Intake gathers.

Research Radar organizes.

Consumer Review specializes.

Decision assesses.

Investing orchestrates.

Capital Deployment gates.

Execution/Paper submits only with human-approved policy.

Command Tower observes.

Governance binds all of it.

## Status labels

- `formal_live`: implemented with PostgreSQL authority surface and current readback.
- `governed_capability`: implemented, bounded, but not a standalone engine.
- `distributed_control`: real control plane spread across several objects/views.
- `review_only`: review/monitoring authority only; no capital action.
- `candidate`: name and purpose exist, but promotion requirements remain open.
