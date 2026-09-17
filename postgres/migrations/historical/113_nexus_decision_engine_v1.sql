BEGIN;
SET LOCAL lock_timeout = '5s';

CREATE TABLE nexus.decision_engine_policies (
    decision_engine_policy_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_code text NOT NULL,
    policy_version integer NOT NULL CHECK (policy_version > 0),
    policy_status text NOT NULL CHECK (policy_status IN ('draft','active','retired')),
    effective_on date NOT NULL,
    requires_current_valuation boolean NOT NULL DEFAULT true,
    requires_portfolio_context boolean NOT NULL DEFAULT true,
    requires_overlap_review boolean NOT NULL DEFAULT true,
    requires_human_approval boolean NOT NULL DEFAULT true,
    permits_trade_execution boolean NOT NULL DEFAULT false CHECK (permits_trade_execution = false),
    elevated_weight_threshold numeric(9,6) NOT NULL CHECK (elevated_weight_threshold BETWEEN 0 AND 1),
    high_weight_threshold numeric(9,6) NOT NULL CHECK (high_weight_threshold BETWEEN 0 AND 1),
    policy_summary text NOT NULL CHECK (btrim(policy_summary) <> ''),
    created_by text NOT NULL DEFAULT current_user,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (policy_code, policy_version),
    CHECK (high_weight_threshold > elevated_weight_threshold)
);
CREATE UNIQUE INDEX idx_decision_engine_one_active_policy
    ON nexus.decision_engine_policies(policy_code) WHERE policy_status='active';
CREATE TRIGGER prevent_decision_engine_policy_mutation
BEFORE UPDATE OR DELETE OR TRUNCATE ON nexus.decision_engine_policies
FOR EACH STATEMENT EXECUTE FUNCTION nexus.prevent_mutation();

CREATE TABLE nexus.portfolio_decision_contexts (
    portfolio_decision_context_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    context_as_of timestamptz NOT NULL,
    portfolio_value_basis text NOT NULL CHECK (btrim(portfolio_value_basis) <> ''),
    captured_securities_value numeric(24,8) NOT NULL CHECK (captured_securities_value >= 0),
    deployable_cash numeric(24,8) CHECK (deployable_cash >= 0),
    settled_cash numeric(24,8) CHECK (settled_cash >= 0),
    debt_priority_state text NOT NULL CHECK (debt_priority_state IN ('unverified','clear','binding')),
    emergency_reserve_state text NOT NULL CHECK (emergency_reserve_state IN ('unverified','adequate','shortfall')),
    deployment_authorized boolean NOT NULL DEFAULT false,
    source_note text NOT NULL CHECK (btrim(source_note) <> ''),
    created_by text NOT NULL DEFAULT current_user,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_portfolio_decision_context_as_of
    ON nexus.portfolio_decision_contexts(context_as_of DESC);
CREATE TRIGGER prevent_portfolio_decision_context_mutation
BEFORE UPDATE OR DELETE OR TRUNCATE ON nexus.portfolio_decision_contexts
FOR EACH STATEMENT EXECUTE FUNCTION nexus.prevent_mutation();

CREATE TABLE nexus.decision_engine_assessments (
    decision_engine_assessment_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    decision_engine_policy_id uuid NOT NULL REFERENCES nexus.decision_engine_policies ON DELETE RESTRICT,
    portfolio_decision_context_id uuid NOT NULL REFERENCES nexus.portfolio_decision_contexts ON DELETE RESTRICT,
    portfolio_lane_id uuid NOT NULL REFERENCES nexus.portfolio_lanes ON DELETE RESTRICT,
    instrument_id uuid NOT NULL REFERENCES nexus.instruments ON DELETE RESTRICT,
    lane_review_id uuid NOT NULL REFERENCES nexus.portfolio_lane_reviews ON DELETE RESTRICT,
    primary_review_evidence_id uuid NOT NULL REFERENCES nexus.map_review_evidence ON DELETE RESTRICT,
    recommendation nexus.decision_type NOT NULL,
    readiness text NOT NULL CHECK (readiness IN ('blocked','conditional','decision_ready')),
    conviction_level smallint CHECK (conviction_level BETWEEN 1 AND 7),
    thesis_state text NOT NULL CHECK (thesis_state IN ('research','supported','impaired','broken')),
    valuation_state text NOT NULL CHECK (valuation_state IN ('not_assessed','insufficient','supported','stretched','attractive')),
    concentration_state text NOT NULL CHECK (concentration_state IN ('normal','elevated','high')),
    overlap_state text NOT NULL CHECK (overlap_state IN ('unverified','measured_partial','measured_complete','not_applicable')),
    liquidity_state text NOT NULL CHECK (liquidity_state IN ('unverified','adequate','constrained')),
    debt_priority_state text NOT NULL CHECK (debt_priority_state IN ('unverified','clear','binding')),
    emergency_reserve_state text NOT NULL CHECK (emergency_reserve_state IN ('unverified','adequate','shortfall')),
    captured_market_value numeric(24,8) NOT NULL CHECK (captured_market_value >= 0),
    captured_portfolio_weight numeric(9,6) NOT NULL CHECK (captured_portfolio_weight BETWEEN 0 AND 1),
    known_indirect_overlap_value numeric(24,8) CHECK (known_indirect_overlap_value >= 0),
    blockers text[] NOT NULL DEFAULT ARRAY[]::text[],
    rationale text NOT NULL CHECK (btrim(rationale) <> ''),
    next_required_evidence text NOT NULL CHECK (btrim(next_required_evidence) <> ''),
    review_due_on date NOT NULL,
    supersedes_assessment_id uuid UNIQUE REFERENCES nexus.decision_engine_assessments ON DELETE RESTRICT,
    assessed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    created_by text NOT NULL DEFAULT current_user,
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (supersedes_assessment_id IS DISTINCT FROM decision_engine_assessment_id),
    CHECK (review_due_on >= (assessed_at AT TIME ZONE 'UTC')::date),
    CHECK ((readiness='decision_ready' AND conviction_level IS NOT NULL) OR readiness<>'decision_ready'),
    UNIQUE (decision_engine_assessment_id, portfolio_lane_id, instrument_id)
);
CREATE UNIQUE INDEX idx_decision_engine_assessment_one_root
    ON nexus.decision_engine_assessments(portfolio_lane_id,instrument_id)
    WHERE supersedes_assessment_id IS NULL;
CREATE INDEX idx_decision_engine_assessment_queue
    ON nexus.decision_engine_assessments(readiness,review_due_on);
CREATE INDEX idx_decision_engine_assessment_instrument
    ON nexus.decision_engine_assessments(instrument_id,assessed_at DESC);

CREATE FUNCTION nexus.validate_decision_engine_assessment()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE
    prior nexus.decision_engine_assessments%ROWTYPE;
    lane_review nexus.portfolio_lane_reviews%ROWTYPE;
    context_row nexus.portfolio_decision_contexts%ROWTYPE;
BEGIN
    SELECT * INTO STRICT lane_review FROM nexus.portfolio_lane_reviews
    WHERE lane_review_id=NEW.lane_review_id;
    IF lane_review.portfolio_lane_id<>NEW.portfolio_lane_id OR lane_review.instrument_id<>NEW.instrument_id THEN
        RAISE EXCEPTION 'Decision assessment lane review must match lane and instrument';
    END IF;
    IF EXISTS (SELECT 1 FROM nexus.portfolio_lane_reviews newer
               WHERE newer.supersedes_review_id=NEW.lane_review_id) THEN
        RAISE EXCEPTION 'Decision assessment requires the current lane review';
    END IF;
    IF NEW.supersedes_assessment_id IS NOT NULL THEN
        SELECT * INTO STRICT prior FROM nexus.decision_engine_assessments
        WHERE decision_engine_assessment_id=NEW.supersedes_assessment_id;
        IF prior.portfolio_lane_id<>NEW.portfolio_lane_id OR prior.instrument_id<>NEW.instrument_id
           OR NEW.assessed_at<prior.assessed_at THEN
            RAISE EXCEPTION 'Decision assessment successor must preserve lane, instrument, and chronology';
        END IF;
    END IF;
    SELECT * INTO STRICT context_row FROM nexus.portfolio_decision_contexts
    WHERE portfolio_decision_context_id=NEW.portfolio_decision_context_id;
    IF NEW.readiness='decision_ready' AND (
        cardinality(NEW.blockers)<>0 OR NEW.valuation_state IN ('not_assessed','insufficient')
        OR NEW.overlap_state='unverified' OR NEW.liquidity_state<>'adequate'
        OR NEW.debt_priority_state<>'clear' OR NEW.emergency_reserve_state<>'adequate'
    ) THEN
        RAISE EXCEPTION 'Decision-ready assessment must clear valuation, overlap, liquidity, debt, reserve, and blocker gates';
    END IF;
    IF NEW.recommendation IN ('starter_position','build_position') AND NOT context_row.deployment_authorized THEN
        RAISE EXCEPTION 'Deployment recommendation requires an explicitly authorized portfolio context';
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER validate_decision_engine_assessment
BEFORE INSERT ON nexus.decision_engine_assessments
FOR EACH ROW EXECUTE FUNCTION nexus.validate_decision_engine_assessment();
CREATE TRIGGER prevent_decision_engine_assessment_mutation
BEFORE UPDATE OR DELETE OR TRUNCATE ON nexus.decision_engine_assessments
FOR EACH STATEMENT EXECUTE FUNCTION nexus.prevent_mutation();

CREATE VIEW nexus.v_decision_engine_assessment_current AS
SELECT a.* FROM nexus.decision_engine_assessments a
WHERE NOT EXISTS (
    SELECT 1 FROM nexus.decision_engine_assessments successor
    WHERE successor.supersedes_assessment_id=a.decision_engine_assessment_id
);

ALTER TABLE nexus.decision_evidence
    ADD COLUMN map_review_evidence_id uuid REFERENCES nexus.map_review_evidence ON DELETE RESTRICT,
    ADD COLUMN lane_review_id uuid REFERENCES nexus.portfolio_lane_reviews ON DELETE RESTRICT;
ALTER TABLE nexus.decision_evidence DROP CONSTRAINT decision_evidence_has_reference;
ALTER TABLE nexus.decision_evidence ADD CONSTRAINT decision_evidence_has_reference CHECK (
    signal_evidence_id IS NOT NULL OR signal_id IS NOT NULL OR company_evidence_id IS NOT NULL
    OR map_review_evidence_id IS NOT NULL OR lane_review_id IS NOT NULL
);
CREATE INDEX idx_decision_evidence_map_review ON nexus.decision_evidence(map_review_evidence_id);
CREATE INDEX idx_decision_evidence_lane_review ON nexus.decision_evidence(lane_review_id);

CREATE TABLE nexus.decision_engine_decision_links (
    decision_engine_decision_link_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    decision_engine_assessment_id uuid NOT NULL REFERENCES nexus.decision_engine_assessments ON DELETE RESTRICT,
    decision_memory_id uuid NOT NULL UNIQUE REFERENCES nexus.decision_memory ON DELETE RESTRICT,
    created_by text NOT NULL DEFAULT current_user,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_decision_engine_link_assessment
    ON nexus.decision_engine_decision_links(decision_engine_assessment_id);
CREATE TRIGGER prevent_decision_engine_link_mutation
BEFORE UPDATE OR DELETE OR TRUNCATE ON nexus.decision_engine_decision_links
FOR EACH STATEMENT EXECUTE FUNCTION nexus.prevent_mutation();

CREATE TABLE nexus.decision_engine_review_events (
    decision_engine_review_event_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    proposed_decision_id uuid NOT NULL REFERENCES nexus.decision_memory ON DELETE RESTRICT,
    reviewed_decision_id uuid NOT NULL UNIQUE REFERENCES nexus.decision_memory ON DELETE RESTRICT,
    review_state text NOT NULL CHECK (review_state IN ('approved','rejected')),
    review_basis text NOT NULL CHECK (length(btrim(review_basis)) >= 40),
    reviewed_by text NOT NULL DEFAULT session_user CHECK (btrim(reviewed_by) <> ''),
    reviewed_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TRIGGER prevent_decision_engine_review_event_mutation
BEFORE UPDATE OR DELETE OR TRUNCATE ON nexus.decision_engine_review_events
FOR EACH STATEMENT EXECUTE FUNCTION nexus.prevent_mutation();

CREATE VIEW nexus.v_decision_engine_workbench AS
SELECT a.decision_engine_assessment_id,p.policy_code,p.policy_version,
       l.code AS lane_code,i.instrument_id,i.ticker,i.name AS security_name,i.instrument_type,
       a.recommendation,a.readiness,a.conviction_level,a.thesis_state,a.valuation_state,
       a.concentration_state,a.overlap_state,a.liquidity_state,a.debt_priority_state,
       a.emergency_reserve_state,a.captured_market_value,a.captured_portfolio_weight,
       a.known_indirect_overlap_value,a.blockers,a.rationale,a.next_required_evidence,
       a.review_due_on,a.primary_review_evidence_id,e.source_uri,e.source_title,
       c.context_as_of,c.deployable_cash,c.settled_cash,c.deployment_authorized,
       lr.review_status AS lane_review_status,
       COALESCE((SELECT count(*) FROM nexus.decision_engine_decision_links dl
                 JOIN nexus.decision_memory dm USING(decision_memory_id)
                 WHERE dl.decision_engine_assessment_id=a.decision_engine_assessment_id
                   AND NOT EXISTS (SELECT 1 FROM nexus.decision_memory newer
                                   WHERE newer.supersedes_decision_id=dm.decision_memory_id)),0) AS current_decision_count
FROM nexus.v_decision_engine_assessment_current a
JOIN nexus.decision_engine_policies p USING(decision_engine_policy_id)
JOIN nexus.portfolio_decision_contexts c USING(portfolio_decision_context_id)
JOIN nexus.portfolio_lanes l USING(portfolio_lane_id)
JOIN nexus.instruments i USING(instrument_id)
JOIN nexus.portfolio_lane_reviews lr ON lr.lane_review_id=a.lane_review_id
JOIN nexus.map_review_evidence e ON e.review_evidence_id=a.primary_review_evidence_id;

CREATE VIEW nexus.v_decision_engine_proposal_queue AS
SELECT dm.decision_memory_id,dl.decision_engine_assessment_id,i.ticker,i.name AS security_name,
       dm.decision_type,dm.decision_status,dm.conviction_level,dm.decision_date,
       dm.hypothesis,dm.evidence_summary,dm.approved_by,dm.approved_at,dm.created_by,dm.created_at,
       NOT EXISTS (SELECT 1 FROM nexus.decision_memory newer
                   WHERE newer.supersedes_decision_id=dm.decision_memory_id) AS is_current,
       (SELECT count(*) FROM nexus.decision_evidence de
        WHERE de.decision_memory_id=dm.decision_memory_id) AS evidence_count,
       (SELECT count(*) FROM nexus.outcomes o
        WHERE o.decision_memory_id=dm.decision_memory_id) AS outcome_count
FROM nexus.decision_engine_decision_links dl
JOIN nexus.decision_memory dm USING(decision_memory_id)
JOIN nexus.instruments i USING(instrument_id);

CREATE FUNCTION nexus.propose_decision_from_assessment(
    target_assessment_id uuid,
    target_hypothesis text,
    target_evidence_summary text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
    assessment nexus.decision_engine_assessments%ROWTYPE;
    new_decision_id uuid := gen_random_uuid();
    target_company_id uuid;
BEGIN
    IF length(btrim(target_hypothesis))<40 OR length(btrim(target_evidence_summary))<40 THEN
        RAISE EXCEPTION 'Decision hypothesis and evidence summary must each contain at least 40 characters';
    END IF;
    SELECT * INTO STRICT assessment FROM nexus.v_decision_engine_assessment_current
    WHERE decision_engine_assessment_id=target_assessment_id FOR UPDATE;
    IF assessment.readiness<>'decision_ready' THEN
        RAISE EXCEPTION 'Only a decision-ready assessment can create a proposal';
    END IF;
    IF EXISTS (
        SELECT 1 FROM nexus.decision_engine_decision_links dl
        JOIN nexus.decision_memory dm USING(decision_memory_id)
        WHERE dl.decision_engine_assessment_id=target_assessment_id
          AND NOT EXISTS (SELECT 1 FROM nexus.decision_memory newer
                          WHERE newer.supersedes_decision_id=dm.decision_memory_id)
          AND dm.decision_status IN ('proposed','approved')
    ) THEN
        RAISE EXCEPTION 'Assessment already has a current proposal or approval';
    END IF;
    SELECT i.issuer_company_id INTO target_company_id FROM nexus.instruments i
    WHERE i.instrument_id=assessment.instrument_id;
    INSERT INTO nexus.decision_memory(
        decision_memory_id,capital_map_id,company_id,instrument_id,decision_type,decision_status,
        conviction_level,decision_date,hypothesis,evidence_summary,expected_capital_flow,
        approval_required,created_by
    ) VALUES (
        new_decision_id,NULL,target_company_id,assessment.instrument_id,assessment.recommendation,
        'proposed',assessment.conviction_level,CURRENT_DATE,target_hypothesis,target_evidence_summary,
        'Decision Engine portfolio-role proposal only; no order, transfer, or brokerage execution authority.',
        true,session_user
    );
    INSERT INTO nexus.decision_evidence(
        decision_memory_id,map_review_evidence_id,lane_review_id,evidence_note,created_by
    ) VALUES (
        new_decision_id,assessment.primary_review_evidence_id,assessment.lane_review_id,
        'Decision Engine proposal linked to the current source-backed lane review and its primary evidence.',session_user
    );
    INSERT INTO nexus.decision_engine_decision_links(
        decision_engine_assessment_id,decision_memory_id,created_by
    ) VALUES (target_assessment_id,new_decision_id,session_user);
    INSERT INTO nexus.outcomes(
        decision_memory_id,outcome_status,measured_at,measurement_window,outcome_summary,
        thesis_result,created_by,updated_by
    ) VALUES (
        new_decision_id,'pending',CURRENT_DATE,'From proposal until next governed review',
        'Awaiting authenticated human review and subsequent outcome evidence. No trade was created.',
        'Unmeasured',session_user,session_user
    );
    RETURN new_decision_id;
END $$;

CREATE FUNCTION nexus.review_decision_proposal(
    target_decision_id uuid,
    target_review_state text,
    target_review_basis text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
    prior nexus.decision_memory%ROWTYPE;
    new_decision_id uuid := gen_random_uuid();
    assessment_id uuid;
BEGIN
    IF target_review_state NOT IN ('approved','rejected') THEN
        RAISE EXCEPTION 'Review state must be approved or rejected';
    END IF;
    IF length(btrim(target_review_basis))<40 THEN
        RAISE EXCEPTION 'Review basis must contain at least 40 characters';
    END IF;
    SELECT * INTO STRICT prior FROM nexus.decision_memory
    WHERE decision_memory_id=target_decision_id FOR UPDATE;
    IF prior.decision_status<>'proposed' OR EXISTS (
        SELECT 1 FROM nexus.decision_memory newer WHERE newer.supersedes_decision_id=target_decision_id
    ) THEN
        RAISE EXCEPTION 'Only a current proposed decision can be reviewed';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM nexus.decision_evidence WHERE decision_memory_id=target_decision_id) THEN
        RAISE EXCEPTION 'Decision proposal has no attached evidence';
    END IF;
    SELECT decision_engine_assessment_id INTO STRICT assessment_id
    FROM nexus.decision_engine_decision_links WHERE decision_memory_id=target_decision_id;
    INSERT INTO nexus.decision_memory(
        decision_memory_id,portfolio_position_id,capital_map_id,company_id,instrument_id,
        decision_type,decision_status,conviction_level,decision_date,hypothesis,evidence_summary,
        expected_capital_flow,approval_required,approved_by,approved_at,supersedes_decision_id,created_by
    ) VALUES (
        new_decision_id,prior.portfolio_position_id,prior.capital_map_id,prior.company_id,prior.instrument_id,
        prior.decision_type,target_review_state::nexus.decision_status,prior.conviction_level,CURRENT_DATE,
        prior.hypothesis,prior.evidence_summary || ' Review basis: ' || target_review_basis,
        'Governed portfolio-role decision only; no order, transfer, or brokerage execution authority.',
        true,CASE WHEN target_review_state='approved' THEN session_user END,
        CASE WHEN target_review_state='approved' THEN clock_timestamp() END,
        target_decision_id,session_user
    );
    INSERT INTO nexus.decision_evidence(
        decision_memory_id,signal_evidence_id,signal_id,company_evidence_id,map_review_evidence_id,
        lane_review_id,evidence_note,created_by
    ) SELECT new_decision_id,signal_evidence_id,signal_id,company_evidence_id,map_review_evidence_id,
             lane_review_id,'Evidence carried forward from reviewed proposal: ' || evidence_note,session_user
      FROM nexus.decision_evidence WHERE decision_memory_id=target_decision_id;
    INSERT INTO nexus.decision_engine_decision_links(
        decision_engine_assessment_id,decision_memory_id,created_by
    ) VALUES (assessment_id,new_decision_id,session_user);
    INSERT INTO nexus.decision_engine_review_events(
        proposed_decision_id,reviewed_decision_id,review_state,review_basis,reviewed_by
    ) VALUES (target_decision_id,new_decision_id,target_review_state,target_review_basis,session_user);
    RETURN new_decision_id;
END $$;

REVOKE ALL ON FUNCTION nexus.propose_decision_from_assessment(uuid,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION nexus.review_decision_proposal(uuid,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION nexus.propose_decision_from_assessment(uuid,text,text) TO nexus_human_reviewer;
GRANT EXECUTE ON FUNCTION nexus.review_decision_proposal(uuid,text,text) TO nexus_human_reviewer;
GRANT SELECT ON nexus.v_decision_engine_workbench,nexus.v_decision_engine_proposal_queue
    TO nexus_automation_reader,nexus_human_reviewer;

INSERT INTO nexus.decision_engine_policies(
    decision_engine_policy_id,policy_code,policy_version,policy_status,effective_on,
    requires_current_valuation,requires_portfolio_context,requires_overlap_review,
    requires_human_approval,permits_trade_execution,elevated_weight_threshold,
    high_weight_threshold,policy_summary,created_by
) VALUES (
    '11300000-0000-4000-8000-000000000001','capital_equity_decision_engine',1,'active','2026-09-15',
    true,true,true,true,false,0.10,0.20,
    'Evidence-gated portfolio-role decisions. Current valuation, portfolio liquidity, debt priority, reserve sufficiency, overlap, concentration and human approval are required before a decision is decision-ready. No forced deployment and no trade execution authority.',
    'nexus_migration_113'
);

INSERT INTO nexus.portfolio_decision_contexts(
    portfolio_decision_context_id,context_as_of,portfolio_value_basis,captured_securities_value,
    deployable_cash,settled_cash,debt_priority_state,emergency_reserve_state,deployment_authorized,
    source_note,created_by
) SELECT
    '11300000-0000-4000-8000-000000000002','2026-09-15T22:20:00Z',
    'Authenticated Fidelity and Chase stock/ETF observations only',sum(market_value),
    NULL,NULL,'unverified','unverified',false,
    'Captured securities values reconcile, but available-to-trade cash, settled cash, household debt priority and emergency-reserve sufficiency were not established. Unknown values remain NULL and deployment is not authorized.',
    'nexus_migration_113'
FROM nexus.v_consolidated_portfolio_snapshot;

WITH owned AS (
    SELECT w.*,
           sum(w.observed_market_value) OVER () AS total_value,
           COALESCE((SELECT sum(o.estimated_lookthrough_value)
                     FROM nexus.v_portfolio_fund_overlap o
                     WHERE o.holding_ticker=w.ticker),0) AS indirect_overlap
    FROM nexus.v_portfolio_lane_workbench w
    WHERE w.lane_code='capital_equity' AND w.observed_account_count>0
)
INSERT INTO nexus.decision_engine_assessments(
    decision_engine_assessment_id,decision_engine_policy_id,portfolio_decision_context_id,
    portfolio_lane_id,instrument_id,lane_review_id,primary_review_evidence_id,recommendation,
    readiness,conviction_level,thesis_state,valuation_state,concentration_state,overlap_state,
    liquidity_state,debt_priority_state,emergency_reserve_state,captured_market_value,
    captured_portfolio_weight,known_indirect_overlap_value,blockers,rationale,
    next_required_evidence,review_due_on,created_by
)
SELECT
    ('11300000-0000-4000-8000-' || lpad((100+row_number() OVER (ORDER BY ticker))::text,12,'0'))::uuid,
    '11300000-0000-4000-8000-000000000001','11300000-0000-4000-8000-000000000002',
    portfolio_lane_id,instrument_id,lane_review_id,primary_review_evidence_id,
    'research','blocked',NULL,'research','not_assessed',
    CASE WHEN observed_market_value/NULLIF(total_value,0)>0.20 THEN 'high'
         WHEN observed_market_value/NULLIF(total_value,0)>0.10 THEN 'elevated'
         ELSE 'normal' END,
    'measured_partial','unverified','unverified','unverified',observed_market_value,
    observed_market_value/NULLIF(total_value,0),indirect_overlap,
    array_remove(ARRAY[
        'current_valuation_missing','deployable_liquidity_unverified','debt_priority_unverified',
        'emergency_reserve_unverified','portfolio_overlap_not_decision_grade','lane_role_not_proposed',
        CASE WHEN observed_market_value/NULLIF(total_value,0)>0.20 THEN 'high_captured_concentration' END
    ],NULL),
    'Source-backed business research exists, but the security decision is not decision-grade. The engine withholds hold, add, reduce, exit and rejection conclusions until valuation and portfolio-capital gates are resolved.',
    'Add a dated valuation basis and current market context; verify deployable and settled liquidity, high-priority debt, emergency-reserve sufficiency, complete direct-plus-fund overlap, and the intended portfolio role before proposal.',
    '2026-10-15','nexus_migration_113'
FROM owned;

COMMENT ON TABLE nexus.decision_engine_policies IS 'Immutable versioned guardrails for evidence-gated portfolio decisions. Policies cannot authorize trade execution.';
COMMENT ON TABLE nexus.portfolio_decision_contexts IS 'Immutable portfolio-capital context. Unknown cash, debt and reserve inputs remain NULL or unverified rather than inferred.';
COMMENT ON TABLE nexus.decision_engine_assessments IS 'Append-only security decision assessments. Readiness and blockers are separate from recommendations and human approval.';
COMMENT ON VIEW nexus.v_decision_engine_workbench IS 'Current Decision Engine assessment surface. Decision-ready does not mean approved, funded or executed.';
COMMENT ON VIEW nexus.v_decision_engine_proposal_queue IS 'Governed proposal and review history created from decision-ready assessments; no trade execution surface.';
COMMENT ON FUNCTION nexus.propose_decision_from_assessment(uuid,text,text) IS 'Reviewer-only creation of an append-only proposed portfolio-role decision from a decision-ready assessment.';
COMMENT ON FUNCTION nexus.review_decision_proposal(uuid,text,text) IS 'Reviewer-only approve/reject transition. Approval is a governed portfolio-role decision, never a trade instruction.';

COMMIT;
