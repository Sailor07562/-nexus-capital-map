-- Nexus Command Tower — Operations Schema Draft 001
-- Anchor: #ANCHOR-NEXUS-COMMAND-TOWER-OPERATIONS-SCHEMA-001
-- Status: DRAFT ONLY — NOT EXECUTED — NOT NUMBERED FOR nexus.schema_migrations
--
-- This artifact is intentionally not approved for any target. Do not run it
-- until target identity, existing migration lineage, ownership, privileges,
-- Last Known Good, sandbox validation, and Captain authorization are verified.
-- It must not alter the protected Nexus core schemas, Tracker schema, Room
-- Registry, or nexus_constitution.

BEGIN;

CREATE SCHEMA IF NOT EXISTS operations;

CREATE TABLE IF NOT EXISTS operations.operational_cycle (
    cycle_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cycle_key text NOT NULL UNIQUE,
    cycle_name text NOT NULL,
    lifecycle_status text NOT NULL DEFAULT 'DRAFT'
        CHECK (lifecycle_status IN (
            'DRAFT', 'PENDING_VERIFICATION', 'VERIFIED', 'SUPERSEDED',
            'RETIRED', 'ARCHIVED'
        )),
    opened_at timestamptz NOT NULL DEFAULT now(),
    closed_at timestamptz,
    owner_reference text NOT NULL,
    evidence_reference text,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT operational_cycle_closed_after_opened
        CHECK (closed_at IS NULL OR closed_at >= opened_at)
);

CREATE TABLE IF NOT EXISTS operations.service_registry (
    service_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    service_key text NOT NULL UNIQUE,
    service_name text NOT NULL,
    system_domain text NOT NULL,
    environment_name text NOT NULL,
    authority_system text NOT NULL,
    lifecycle_status text NOT NULL DEFAULT 'DRAFT'
        CHECK (lifecycle_status IN (
            'DRAFT', 'PENDING_VERIFICATION', 'VERIFIED', 'SUPERSEDED',
            'RETIRED', 'ARCHIVED'
        )),
    source_reference text,
    created_at timestamptz NOT NULL DEFAULT now(),
    retired_at timestamptz
);

CREATE TABLE IF NOT EXISTS operations.service_health (
    service_health_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    service_id bigint NOT NULL REFERENCES operations.service_registry(service_id),
    verification_state text NOT NULL
        CHECK (verification_state IN (
            'verified', 'inferred', 'unknown', 'failed', 'blocked', 'frozen'
        )),
    health_state text NOT NULL
        CHECK (health_state IN ('healthy', 'degraded', 'failed', 'unknown', 'blocked')),
    observed_at timestamptz NOT NULL DEFAULT now(),
    evidence_reference text,
    observation_note text,
    recorded_by text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS operations.attention_queue (
    attention_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    attention_key text NOT NULL UNIQUE,
    cycle_id bigint REFERENCES operations.operational_cycle(cycle_id),
    source_system text NOT NULL,
    severity text NOT NULL CHECK (severity IN ('critical', 'high', 'medium', 'low', 'info')),
    verification_state text NOT NULL
        CHECK (verification_state IN (
            'verified', 'inferred', 'unknown', 'failed', 'blocked', 'frozen'
        )),
    queue_status text NOT NULL DEFAULT 'open'
        CHECK (queue_status IN ('open', 'acknowledged', 'blocked', 'resolved', 'archived')),
    summary text NOT NULL,
    evidence_reference text,
    human_review_required boolean NOT NULL DEFAULT true,
    opened_at timestamptz NOT NULL DEFAULT now(),
    resolved_at timestamptz
);

CREATE TABLE IF NOT EXISTS operations.promotion_queue (
    promotion_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    promotion_key text NOT NULL UNIQUE,
    cycle_id bigint REFERENCES operations.operational_cycle(cycle_id),
    source_reference text NOT NULL,
    target_reference text NOT NULL,
    proposed_action text NOT NULL,
    risk_summary text NOT NULL,
    gate_status text NOT NULL DEFAULT 'blocked'
        CHECK (gate_status IN ('draft', 'blocked', 'ready_for_review', 'approved', 'executed', 'verified', 'rejected')),
    authorization_reference text,
    rollback_reference text,
    evidence_reference text,
    created_at timestamptz NOT NULL DEFAULT now(),
    verified_at timestamptz,
    CONSTRAINT promotion_queue_no_execution_without_authorization
        CHECK (gate_status NOT IN ('executed', 'verified') OR authorization_reference IS NOT NULL)
);

CREATE TABLE IF NOT EXISTS operations.backup_registry (
    backup_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    backup_key text NOT NULL UNIQUE,
    source_system text NOT NULL,
    scope_description text NOT NULL,
    storage_reference text NOT NULL,
    validation_state text NOT NULL
        CHECK (validation_state IN ('verified', 'inferred', 'unknown', 'failed', 'blocked', 'frozen')),
    backup_created_at timestamptz NOT NULL,
    validation_at timestamptz,
    evidence_reference text,
    sanitized_for_repository boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- Event and operator-log storage are append-only by governance contract.
-- Mutation prevention, role grants, and replay controls require a separate,
-- target-specific ledger implementation after sandbox discovery and approval.
CREATE TABLE IF NOT EXISTS operations.operational_events (
    operational_event_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_key uuid NOT NULL UNIQUE,
    cycle_id bigint REFERENCES operations.operational_cycle(cycle_id),
    event_type text NOT NULL,
    event_state text NOT NULL,
    source_system text NOT NULL,
    actor_reference text NOT NULL,
    occurred_at timestamptz NOT NULL DEFAULT now(),
    evidence_reference text,
    event_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    recorded_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS operations.operator_log (
    operator_log_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    log_key uuid NOT NULL UNIQUE,
    operational_event_id bigint REFERENCES operations.operational_events(operational_event_id),
    action_type text NOT NULL,
    action_scope text NOT NULL,
    actor_reference text NOT NULL,
    outcome_state text NOT NULL
        CHECK (outcome_state IN ('verified', 'inferred', 'unknown', 'failed', 'blocked', 'frozen')),
    evidence_reference text,
    logged_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_service_health_service_observed
    ON operations.service_health (service_id, observed_at DESC);
CREATE INDEX IF NOT EXISTS ix_attention_queue_status_severity
    ON operations.attention_queue (queue_status, severity, opened_at DESC);
CREATE INDEX IF NOT EXISTS ix_promotion_queue_gate_status
    ON operations.promotion_queue (gate_status, created_at DESC);
CREATE INDEX IF NOT EXISTS ix_operational_events_cycle_occurred
    ON operations.operational_events (cycle_id, occurred_at DESC);

COMMIT;

