BEGIN;
SET LOCAL lock_timeout = '5s';

CREATE TABLE nexus.investing_engine_registrations (
    investing_engine_registration_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    engine_code text NOT NULL CHECK (engine_code ~ '^[a-z0-9][a-z0-9_]*$'),
    engine_name text NOT NULL CHECK (btrim(engine_name) <> ''),
    semantic_version text NOT NULL CHECK (semantic_version ~ '^[0-9]+\.[0-9]+\.[0-9]+$'),
    registration_revision integer NOT NULL CHECK (registration_revision > 0),
    registration_state text NOT NULL CHECK (registration_state IN (
        'verification_pending','verified','superseded','retired'
    )),
    maturity_level smallint NOT NULL CHECK (maturity_level BETWEEN 0 AND 6),
    operating_mode text NOT NULL CHECK (operating_mode IN (
        'analysis_and_proposal','shadow','paper_approval_gated','live'
    )),
    canonical_system text NOT NULL CHECK (canonical_system = 'Nexus Capital Map'),
    purpose text NOT NULL CHECK (length(btrim(purpose)) >= 40),
    authority_capabilities text[] NOT NULL CHECK (cardinality(authority_capabilities) > 0),
    prohibited_capabilities text[] NOT NULL CHECK (cardinality(prohibited_capabilities) > 0),
    governance_binding_id uuid NOT NULL
        REFERENCES nexus.governance_framework_bindings(governance_binding_id) ON DELETE RESTRICT,
    verification_basis text NOT NULL CHECK (length(btrim(verification_basis)) >= 40),
    effective_at timestamptz NOT NULL,
    supersedes_registration_id uuid UNIQUE
        REFERENCES nexus.investing_engine_registrations(investing_engine_registration_id)
        ON DELETE RESTRICT,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    created_by text NOT NULL DEFAULT session_user,
    UNIQUE (engine_code, registration_revision),
    CHECK (supersedes_registration_id IS DISTINCT FROM investing_engine_registration_id),
    CHECK (operating_mode <> 'live' OR registration_state = 'verified')
);

CREATE UNIQUE INDEX idx_investing_engine_one_root
    ON nexus.investing_engine_registrations(engine_code)
    WHERE supersedes_registration_id IS NULL;
CREATE INDEX idx_investing_engine_registration_time
    ON nexus.investing_engine_registrations(engine_code, effective_at DESC);

CREATE FUNCTION nexus.validate_investing_engine_registration()
RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog AS $$
DECLARE
    prior nexus.investing_engine_registrations%ROWTYPE;
BEGIN
    IF NEW.supersedes_registration_id IS NULL THEN
        IF NEW.registration_revision <> 1 THEN
            RAISE EXCEPTION 'A root Investing Engine registration must use revision 1';
        END IF;
        RETURN NEW;
    END IF;

    SELECT * INTO STRICT prior
    FROM nexus.investing_engine_registrations
    WHERE investing_engine_registration_id = NEW.supersedes_registration_id;

    IF prior.engine_code <> NEW.engine_code
       OR prior.engine_name <> NEW.engine_name
       OR prior.semantic_version <> NEW.semantic_version
       OR prior.canonical_system <> NEW.canonical_system THEN
        RAISE EXCEPTION 'An Investing Engine successor must preserve canonical identity';
    END IF;
    IF NEW.registration_revision <> prior.registration_revision + 1 THEN
        RAISE EXCEPTION 'An Investing Engine successor must increment the registration revision by one';
    END IF;
    IF NEW.effective_at < prior.effective_at THEN
        RAISE EXCEPTION 'An Investing Engine successor cannot precede its predecessor';
    END IF;
    IF prior.registration_state IN ('superseded','retired') THEN
        RAISE EXCEPTION 'A superseded or retired Investing Engine registration is terminal';
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER validate_investing_engine_registration
BEFORE INSERT ON nexus.investing_engine_registrations
FOR EACH ROW EXECUTE FUNCTION nexus.validate_investing_engine_registration();
CREATE TRIGGER prevent_investing_engine_registration_mutation
BEFORE UPDATE OR DELETE OR TRUNCATE ON nexus.investing_engine_registrations
FOR EACH STATEMENT EXECUTE FUNCTION nexus.prevent_mutation();

CREATE TABLE nexus.investing_engine_components (
    investing_engine_component_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    investing_engine_registration_id uuid NOT NULL
        REFERENCES nexus.investing_engine_registrations ON DELETE RESTRICT,
    sequence_number smallint NOT NULL CHECK (sequence_number > 0),
    component_code text NOT NULL CHECK (component_code ~ '^[a-z0-9][a-z0-9_]*$'),
    component_name text NOT NULL CHECK (btrim(component_name) <> ''),
    component_class text NOT NULL CHECK (component_class IN (
        'intake','evidence','portfolio','exposure','decision','capital_control',
        'shadow','paper_execution_boundary'
    )),
    relationship_to_engine text NOT NULL CHECK (relationship_to_engine IN (
        'feeds','supports','governs','implemented_by','depends_on'
    )),
    implementation_object text NOT NULL CHECK (implementation_object ~ '^nexus\.'),
    operating_state text NOT NULL CHECK (operating_state IN (
        'active','active_protected','manual_only','paper_only'
    )),
    capability_summary text NOT NULL CHECK (length(btrim(capability_summary)) >= 30),
    authority_boundary text NOT NULL CHECK (length(btrim(authority_boundary)) >= 30),
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    created_by text NOT NULL DEFAULT session_user,
    UNIQUE (investing_engine_registration_id, sequence_number),
    UNIQUE (investing_engine_registration_id, component_code)
);
CREATE TRIGGER prevent_investing_engine_component_mutation
BEFORE UPDATE OR DELETE OR TRUNCATE ON nexus.investing_engine_components
FOR EACH STATEMENT EXECUTE FUNCTION nexus.prevent_mutation();

CREATE TABLE nexus.investing_engine_verification_events (
    investing_engine_verification_event_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    investing_engine_registration_id uuid NOT NULL
        REFERENCES nexus.investing_engine_registrations ON DELETE RESTRICT,
    verification_status text NOT NULL CHECK (verification_status IN ('passed','failed')),
    verified_maturity_level smallint NOT NULL CHECK (verified_maturity_level BETWEEN 0 AND 6),
    suite_count integer NOT NULL CHECK (suite_count > 0),
    check_count integer NOT NULL CHECK (check_count > 0),
    verification_basis text NOT NULL CHECK (length(btrim(verification_basis)) >= 40),
    verified_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    verified_by text NOT NULL DEFAULT session_user
);
CREATE INDEX idx_investing_engine_verification_time
    ON nexus.investing_engine_verification_events(
        investing_engine_registration_id, verified_at DESC
    );
CREATE TRIGGER prevent_investing_engine_verification_mutation
BEFORE UPDATE OR DELETE OR TRUNCATE ON nexus.investing_engine_verification_events
FOR EACH STATEMENT EXECUTE FUNCTION nexus.prevent_mutation();

CREATE VIEW nexus.v_investing_engine_current AS
SELECT registration.*
FROM nexus.investing_engine_registrations registration
WHERE NOT EXISTS (
    SELECT 1
    FROM nexus.investing_engine_registrations successor
    WHERE successor.supersedes_registration_id =
          registration.investing_engine_registration_id
);

CREATE VIEW nexus.v_investing_engine_workbench AS
SELECT engine.engine_code,engine.engine_name,engine.semantic_version,
       engine.registration_state,engine.maturity_level,engine.operating_mode,
       decision.lane_code,decision.instrument_id,decision.ticker,
       decision.security_name,decision.instrument_type,
       portfolio.account_count,portfolio.account_names,portfolio.quantity,
       portfolio.cost_basis,portfolio.market_value,portfolio.total_gain_loss,
       portfolio.consolidated_weight,portfolio.latest_observed_at,
       decision.recommendation,decision.readiness,decision.conviction_level,
       decision.thesis_state,decision.valuation_state,
       decision.concentration_state,decision.overlap_state,
       decision.liquidity_state,decision.debt_priority_state,
       decision.emergency_reserve_state,decision.known_indirect_overlap_value,
       decision.blockers,decision.rationale,decision.next_required_evidence,
       decision.review_due_on,decision.source_uri,decision.source_title,
       decision.context_as_of,decision.deployable_cash,decision.settled_cash,
       decision.deployment_authorized,decision.lane_review_status,
       GREATEST(decision.context_as_of,portfolio.latest_observed_at,
                intake.latest_retrieved_at) AS evidence_freshness_at,
       COALESCE(intake.intake_item_count,0) AS intake_item_count,
       COALESCE(intake.queued_intake_count,0) AS queued_intake_count,
       COALESCE(intake.accepted_intake_count,0) AS accepted_intake_count,
       decision.current_decision_count,
       proposal.decision_status AS current_decision_status,
       proposal.approved_by,proposal.approved_at,
       shadow.intent_action AS latest_shadow_action,
       shadow.intent_state AS latest_shadow_state,
       shadow.run_status AS latest_shadow_run_status,
       COALESCE(shadow.would_submit_order,false) AS shadow_would_submit_order,
       paper.proposal_status AS latest_paper_proposal_status,
       paper.submission_result_status AS latest_paper_submission_status,
       paper.broker_order_status AS latest_paper_broker_status,
       COALESCE(policy.live_trading_enabled,false) AS live_trading_enabled,
       CASE
         WHEN paper.paper_order_submission_id IS NOT NULL
           THEN 'paper_submission_recorded'
         WHEN proposal.decision_status = 'approved'
           THEN 'human_approved_decision_no_order'
         ELSE 'no_execution_authority'
       END AS execution_boundary
FROM nexus.v_investing_engine_current engine
CROSS JOIN nexus.v_decision_engine_workbench decision
LEFT JOIN nexus.v_consolidated_portfolio_snapshot portfolio
       USING (ticker)
LEFT JOIN LATERAL (
    SELECT count(*) AS intake_item_count,
           count(*) FILTER (WHERE review_state IN ('queued','needs_more_evidence'))
               AS queued_intake_count,
           count(*) FILTER (WHERE review_state='accepted') AS accepted_intake_count,
           max(retrieved_at) AS latest_retrieved_at
    FROM nexus.v_automation_intake_queue queue
    WHERE queue.ticker=decision.ticker
) intake ON true
LEFT JOIN LATERAL (
    SELECT queue.decision_status,queue.approved_by,queue.approved_at
    FROM nexus.v_decision_engine_proposal_queue queue
    WHERE queue.decision_engine_assessment_id=decision.decision_engine_assessment_id
      AND queue.is_current
    ORDER BY queue.created_at DESC
    LIMIT 1
) proposal ON true
LEFT JOIN LATERAL (
    SELECT intent.intent_action,intent.intent_state,intent.run_status,
           intent.would_submit_order
    FROM nexus.v_shadow_trade_intents intent
    WHERE intent.ticker=decision.ticker
    ORDER BY intent.run_as_of DESC,intent.session_date DESC
    LIMIT 1
) shadow ON true
LEFT JOIN LATERAL (
    SELECT order_view.paper_order_submission_id,order_view.proposal_status,
           order_view.submission_result_status,order_view.broker_order_status
    FROM nexus.v_paper_order_proposals order_view
    WHERE order_view.ticker=decision.ticker
    ORDER BY order_view.proposed_at DESC
    LIMIT 1
) paper ON true
LEFT JOIN LATERAL (
    SELECT bool_or(health.live_trading_enabled) AS live_trading_enabled
    FROM nexus.v_paper_order_policy_health health
) policy ON true;

CREATE VIEW nexus.v_investing_engine_status AS
SELECT engine.engine_code,engine.engine_name,engine.semantic_version,
       engine.registration_revision,engine.registration_state,
       engine.maturity_level,engine.operating_mode,engine.effective_at,
       (SELECT count(*) FROM nexus.investing_engine_components component
         WHERE component.investing_engine_registration_id=
               engine.investing_engine_registration_id) AS component_count,
       (SELECT count(*) FROM nexus.automation_source_registry source
         WHERE source.intake_status='allowed_for_intake') AS allowed_source_count,
       (SELECT count(*) FROM nexus.v_automation_intake_queue queue
         WHERE queue.review_state IN ('queued','needs_more_evidence'))
           AS pending_intake_count,
       count(workbench.instrument_id) AS assessed_security_count,
       count(*) FILTER (WHERE workbench.readiness='ready') AS decision_ready_count,
       count(*) FILTER (WHERE cardinality(workbench.blockers)>0) AS blocked_security_count,
       count(*) FILTER (WHERE workbench.current_decision_status='approved')
           AS approved_decision_count,
       count(*) FILTER (WHERE workbench.latest_paper_submission_status='submitted')
           AS submitted_paper_order_count,
       bool_or(workbench.live_trading_enabled) AS live_trading_enabled,
       bool_or(workbench.shadow_would_submit_order) AS any_shadow_order_enabled,
       max(workbench.evidence_freshness_at) AS latest_evidence_at
FROM nexus.v_investing_engine_current engine
LEFT JOIN nexus.v_investing_engine_workbench workbench
       ON workbench.engine_code=engine.engine_code
GROUP BY engine.investing_engine_registration_id,engine.engine_code,
         engine.engine_name,engine.semantic_version,engine.registration_revision,
         engine.registration_state,engine.maturity_level,engine.operating_mode,
         engine.effective_at;

REVOKE ALL ON nexus.investing_engine_registrations,
    nexus.investing_engine_components,nexus.investing_engine_verification_events
    FROM PUBLIC;
GRANT SELECT ON nexus.v_investing_engine_current,
    nexus.v_investing_engine_workbench,nexus.v_investing_engine_status
    TO nexus_automation_reader,nexus_human_reviewer,nexus_shadow_runner,
       nexus_broker_monitor;

INSERT INTO nexus.investing_engine_registrations(
    investing_engine_registration_id,engine_code,engine_name,semantic_version,
    registration_revision,registration_state,maturity_level,operating_mode,
    canonical_system,purpose,authority_capabilities,prohibited_capabilities,
    governance_binding_id,verification_basis,effective_at,created_by
) SELECT
    '12000000-0000-4000-8000-000000000001',
    'nexus_investing_engine','Nexus Investing Engine','1.0.0',1,
    'verification_pending',4,'paper_approval_gated','Nexus Capital Map',
    'Canonical parent for governed public-security intake, evidence review, portfolio and exposure context, security assessment, capital constraints, shadow observation, and explicitly approved Alpaca Paper execution.',
    ARRAY['acquire_allowlisted_sources','preserve_evidence','map_portfolio_exposure',
          'assess_security_readiness','abstain_when_blocked','propose_human_review',
          'observe_shadow_postures','record_approved_paper_submissions'],
    ARRAY['define_governance','admit_evidence_without_review','approve_its_own_decisions',
          'move_cash','submit_live_orders','use_margin','sell_short','trade_options',
          'trade_crypto','alter_authentication'],
    binding.governance_binding_id,
    'Migration 120 establishes the canonical parent identity and read-only workbench. E5 verification remains pending until all rollback-only suites pass against the live migration-120 database.',
    clock_timestamp(),'nexus_migration_120'
FROM nexus.v_governance_framework_binding_current binding
WHERE binding.framework_code='nexus_governance'
  AND binding.applicability_status='verified_applicable';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM nexus.investing_engine_registrations
        WHERE investing_engine_registration_id=
              '12000000-0000-4000-8000-000000000001'
    ) THEN
        RAISE EXCEPTION 'Verified Nexus Governance binding is required for the Investing Engine';
    END IF;
END $$;

INSERT INTO nexus.investing_engine_components(
    investing_engine_component_id,investing_engine_registration_id,sequence_number,
    component_code,component_name,component_class,relationship_to_engine,
    implementation_object,operating_state,capability_summary,authority_boundary,
    created_by
) VALUES
('12000000-0000-4000-8001-000000000001','12000000-0000-4000-8000-000000000001',1,
 'governed_intake','Governed Source Intake','intake','feeds',
 'nexus.v_automation_intake_queue','active_protected',
 'Allowlisted POWL SEC and XLP source packets are hashed, deduplicated, and queued.',
 'Automation may enqueue candidates only; it cannot admit evidence or write decisions.',
 'nexus_migration_120'),
('12000000-0000-4000-8001-000000000002','12000000-0000-4000-8000-000000000001',2,
 'evidence_review','Evidence Review and Admission','evidence','feeds',
 'nexus.map_review_evidence','manual_only',
 'Authenticated human review converts accepted intake items into immutable evidence.',
 'Evidence acceptance does not approve a map, lane, position size, recommendation, or trade.',
 'nexus_migration_120'),
('12000000-0000-4000-8001-000000000003','12000000-0000-4000-8000-000000000001',3,
 'portfolio_snapshot','Consolidated Portfolio Snapshot','portfolio','supports',
 'nexus.v_consolidated_portfolio_snapshot','active_protected',
 'Latest authenticated broker observations are consolidated by held security.',
 'Captured securities value is not settled cash, buying power, or authorization to deploy.',
 'nexus_migration_120'),
('12000000-0000-4000-8001-000000000004','12000000-0000-4000-8000-000000000001',4,
 'exposure_mapping','Portfolio Exposure Mapping','exposure','supports',
 'nexus.v_portfolio_map_workbench','active_protected',
 'Direct holdings and dated fund look-through evidence support qualitative exposure analysis.',
 'Partial look-through and mapped values cannot be treated as complete or revenue-weighted exposure.',
 'nexus_migration_120'),
('12000000-0000-4000-8001-000000000005','12000000-0000-4000-8000-000000000001',5,
 'decision_engine','Nexus Decision Engine','decision','implemented_by',
 'nexus.v_decision_engine_workbench','active_protected',
 'Source-backed research and portfolio context produce governed recommendations or abstention.',
 'Decision-ready does not mean approved, funded, sized, submitted, or executed.',
 'nexus_migration_120'),
('12000000-0000-4000-8001-000000000006','12000000-0000-4000-8000-000000000001',6,
 'capital_controls','Capital Preservation Controls','capital_control','governs',
 'nexus.portfolio_decision_contexts','active_protected',
 'Debt priority, emergency reserves, deployable cash, and settlement knowledge gate proposals.',
 'Unknown cash remains unknown and policy-deployable cash cannot be inferred from account value.',
 'nexus_migration_120'),
('12000000-0000-4000-8001-000000000007','12000000-0000-4000-8000-000000000001',7,
 'shadow_mode','Alpaca Paper Shadow Mode','shadow','supports',
 'nexus.v_shadow_mode_summary','active_protected',
 'Current Decision Engine postures are mirrored into a no-network observation ledger.',
 'Shadow mode cannot create or submit a brokerage order and carries zero execution authority.',
 'nexus_migration_120'),
('12000000-0000-4000-8001-000000000008','12000000-0000-4000-8000-000000000001',8,
 'paper_execution_boundary','Approval-Gated Alpaca Paper Boundary',
 'paper_execution_boundary','depends_on','nexus.v_paper_order_policy_health','paper_only',
 'Allowlisted Paper buy previews and sanitized submission receipts require exact human approval.',
 'Live trading, margin, short sales, options, crypto, autonomous approval, and cash movement are prohibited.',
 'nexus_migration_120');

DO $$
BEGIN
    IF (SELECT count(*) FROM nexus.v_investing_engine_current
        WHERE engine_code='nexus_investing_engine') <> 1 THEN
        RAISE EXCEPTION 'Expected one current Nexus Investing Engine registration';
    END IF;
    IF (SELECT component_count FROM nexus.v_investing_engine_status
        WHERE engine_code='nexus_investing_engine') <> 8 THEN
        RAISE EXCEPTION 'Expected eight canonical Investing Engine components';
    END IF;
    IF EXISTS (
        SELECT 1 FROM nexus.v_investing_engine_status
        WHERE engine_code='nexus_investing_engine'
          AND (live_trading_enabled OR any_shadow_order_enabled)
    ) THEN
        RAISE EXCEPTION 'Investing Engine cannot enable live or shadow order submission';
    END IF;
END $$;

COMMENT ON TABLE nexus.investing_engine_registrations IS
    'Append-only canonical identity and maturity history for the Nexus Investing Engine parent.';
COMMENT ON TABLE nexus.investing_engine_components IS
    'Immutable component map for each Investing Engine registration revision.';
COMMENT ON TABLE nexus.investing_engine_verification_events IS
    'Append-only verification receipts. A registration is not E5 merely because it is named or documented.';
COMMENT ON VIEW nexus.v_investing_engine_workbench IS
    'Unified read-only Investing Engine surface. It does not grant approval, funding, or execution authority.';
COMMENT ON VIEW nexus.v_investing_engine_status IS
    'Current Investing Engine maturity, component, evidence, decision, shadow, and execution-boundary health.';

COMMIT;
