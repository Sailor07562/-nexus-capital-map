BEGIN;
SET LOCAL lock_timeout = '5s';

CREATE TABLE nexus.paper_order_policies (
    paper_order_policy_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_code text NOT NULL UNIQUE CHECK (btrim(policy_code) <> ''),
    broker_connection_id uuid NOT NULL REFERENCES nexus.broker_connections ON DELETE RESTRICT,
    shadow_experiment_id uuid NOT NULL REFERENCES nexus.shadow_experiments ON DELETE RESTRICT,
    policy_status text NOT NULL CHECK (policy_status IN ('active','paused','retired')),
    broker_environment text NOT NULL CHECK (broker_environment = 'alpaca_paper'),
    endpoint_path text NOT NULL CHECK (endpoint_path = '/orders'),
    request_method text NOT NULL CHECK (request_method = 'POST'),
    order_submission_mode text NOT NULL CHECK (order_submission_mode = 'human_approval_gated'),
    allowed_side text NOT NULL CHECK (allowed_side = 'buy'),
    allowed_order_type text NOT NULL CHECK (allowed_order_type = 'market'),
    allowed_time_in_force text NOT NULL CHECK (allowed_time_in_force = 'day'),
    extended_hours_allowed boolean NOT NULL DEFAULT false CHECK (NOT extended_hours_allowed),
    max_order_notional numeric(24,8) NOT NULL CHECK (max_order_notional > 0 AND max_order_notional <= 25),
    max_daily_submitted_orders integer NOT NULL CHECK (max_daily_submitted_orders BETWEEN 1 AND 3),
    requires_current_allowlist boolean NOT NULL DEFAULT true CHECK (requires_current_allowlist),
    requires_human_confirmation boolean NOT NULL DEFAULT true CHECK (requires_human_confirmation),
    live_trading_enabled boolean NOT NULL DEFAULT false CHECK (NOT live_trading_enabled),
    permits_margin boolean NOT NULL DEFAULT false CHECK (NOT permits_margin),
    permits_short_sales boolean NOT NULL DEFAULT false CHECK (NOT permits_short_sales),
    permits_options boolean NOT NULL DEFAULT false CHECK (NOT permits_options),
    permits_crypto boolean NOT NULL DEFAULT false CHECK (NOT permits_crypto),
    policy_notes text NOT NULL CHECK (length(btrim(policy_notes)) >= 40),
    created_by text NOT NULL DEFAULT session_user,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER prevent_paper_order_policy_mutation
BEFORE UPDATE OR DELETE OR TRUNCATE ON nexus.paper_order_policies
FOR EACH STATEMENT EXECUTE FUNCTION nexus.prevent_mutation();

CREATE TABLE nexus.paper_order_proposals (
    paper_order_proposal_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    paper_order_policy_id uuid NOT NULL REFERENCES nexus.paper_order_policies ON DELETE RESTRICT,
    shadow_trade_intent_id uuid REFERENCES nexus.shadow_trade_intents ON DELETE RESTRICT,
    instrument_id uuid NOT NULL REFERENCES nexus.instruments ON DELETE RESTRICT,
    proposal_date date NOT NULL DEFAULT CURRENT_DATE,
    side text NOT NULL CHECK (side = 'buy'),
    order_type text NOT NULL CHECK (order_type = 'market'),
    time_in_force text NOT NULL CHECK (time_in_force = 'day'),
    extended_hours boolean NOT NULL DEFAULT false CHECK (NOT extended_hours),
    notional numeric(24,8) NOT NULL CHECK (notional > 0 AND notional <= 25),
    client_order_id text NOT NULL UNIQUE CHECK (length(client_order_id) BETWEEN 12 AND 128),
    approval_fingerprint_sha256 text NOT NULL CHECK (approval_fingerprint_sha256 ~ '^[0-9a-f]{64}$'),
    proposal_status text NOT NULL CHECK (proposal_status = 'previewed'),
    rationale text NOT NULL CHECK (length(btrim(rationale)) >= 40),
    created_by text NOT NULL DEFAULT session_user,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_paper_order_proposals_policy_date
    ON nexus.paper_order_proposals(paper_order_policy_id, proposal_date DESC, created_at DESC);
CREATE TRIGGER prevent_paper_order_proposal_mutation
BEFORE UPDATE OR DELETE OR TRUNCATE ON nexus.paper_order_proposals
FOR EACH STATEMENT EXECUTE FUNCTION nexus.prevent_mutation();

CREATE TABLE nexus.paper_order_submissions (
    paper_order_submission_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    paper_order_proposal_id uuid NOT NULL UNIQUE REFERENCES nexus.paper_order_proposals ON DELETE RESTRICT,
    submitted_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    result_status text NOT NULL CHECK (result_status IN ('submitted','failed')),
    http_status integer CHECK (http_status BETWEEN 0 AND 599),
    endpoint_path text NOT NULL CHECK (endpoint_path = '/orders'),
    request_method text NOT NULL CHECK (request_method = 'POST'),
    external_request_count integer NOT NULL DEFAULT 1 CHECK (external_request_count = 1),
    broker_order_id text,
    broker_order_status text,
    response_fingerprint_sha256 text CHECK (
        response_fingerprint_sha256 IS NULL OR response_fingerprint_sha256 ~ '^[0-9a-f]{64}$'
    ),
    safe_summary text NOT NULL CHECK (length(btrim(safe_summary)) >= 40),
    created_by text NOT NULL DEFAULT session_user,
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (
        (result_status='submitted' AND http_status BETWEEN 200 AND 299
            AND broker_order_id IS NOT NULL AND response_fingerprint_sha256 IS NOT NULL)
        OR
        (result_status='failed')
    )
);
CREATE INDEX idx_paper_order_submissions_submitted_at
    ON nexus.paper_order_submissions(submitted_at DESC);
CREATE TRIGGER prevent_paper_order_submission_mutation
BEFORE UPDATE OR DELETE OR TRUNCATE ON nexus.paper_order_submissions
FOR EACH STATEMENT EXECUTE FUNCTION nexus.prevent_mutation();

CREATE VIEW nexus.v_paper_order_proposals AS
SELECT policy.policy_code,policy.policy_status,policy.broker_environment,
       policy.order_submission_mode,policy.max_order_notional,policy.max_daily_submitted_orders,
       proposal.paper_order_proposal_id,proposal.proposal_date,proposal.created_at AS proposed_at,
       instrument.ticker,instrument.name AS security_name,proposal.side,proposal.order_type,
       proposal.time_in_force,proposal.extended_hours,proposal.notional,proposal.client_order_id,
       proposal.proposal_status,proposal.rationale,
       submission.paper_order_submission_id,submission.submitted_at,
       submission.result_status AS submission_result_status,
       submission.http_status AS submission_http_status,
       submission.broker_order_status,submission.safe_summary AS submission_safe_summary
FROM nexus.paper_order_proposals proposal
JOIN nexus.paper_order_policies policy USING(paper_order_policy_id)
JOIN nexus.instruments instrument USING(instrument_id)
LEFT JOIN nexus.paper_order_submissions submission USING(paper_order_proposal_id);

CREATE VIEW nexus.v_paper_order_policy_health AS
SELECT policy.policy_code,policy.policy_status,policy.broker_environment,
       connection.connection_code AS broker_connection_code,
       experiment.experiment_code AS shadow_experiment_code,
       policy.order_submission_mode,policy.allowed_side,policy.allowed_order_type,
       policy.allowed_time_in_force,policy.extended_hours_allowed,
       policy.max_order_notional,policy.max_daily_submitted_orders,
       policy.requires_current_allowlist,policy.requires_human_confirmation,
       policy.live_trading_enabled,policy.permits_margin,policy.permits_short_sales,
       policy.permits_options,policy.permits_crypto,
       count(DISTINCT proposal.paper_order_proposal_id) AS proposal_count,
       count(DISTINCT submission.paper_order_submission_id)
           FILTER (WHERE submission.result_status='submitted') AS submitted_order_count,
       max(submission.submitted_at) AS latest_submitted_at
FROM nexus.paper_order_policies policy
JOIN nexus.broker_connections connection USING(broker_connection_id)
JOIN nexus.shadow_experiments experiment USING(shadow_experiment_id)
LEFT JOIN nexus.paper_order_proposals proposal USING(paper_order_policy_id)
LEFT JOIN nexus.paper_order_submissions submission USING(paper_order_proposal_id)
GROUP BY policy.paper_order_policy_id,connection.connection_code,experiment.experiment_code;

CREATE FUNCTION nexus.record_paper_order_proposal(
    target_policy_code text,
    target_ticker text,
    target_side text,
    target_notional numeric,
    target_client_order_id text,
    target_approval_fingerprint_sha256 text,
    target_rationale text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
    policy nexus.paper_order_policies%ROWTYPE;
    instrument_row nexus.instruments%ROWTYPE;
    proposal_id uuid := gen_random_uuid();
BEGIN
    SELECT * INTO STRICT policy
    FROM nexus.paper_order_policies
    WHERE policy_code=target_policy_code;
    IF policy.policy_status<>'active' THEN
        RAISE EXCEPTION 'Paper order policy must be active';
    END IF;
    IF policy.live_trading_enabled OR policy.allowed_side<>'buy' OR policy.allowed_order_type<>'market' THEN
        RAISE EXCEPTION 'Paper order policy is not in buy-only market-paper mode';
    END IF;
    IF target_side<>'buy' THEN
        RAISE EXCEPTION 'This policy allows paper buy orders only';
    END IF;
    IF target_notional IS NULL OR target_notional<=0 OR target_notional>policy.max_order_notional THEN
        RAISE EXCEPTION 'Paper order notional exceeds the active policy limit';
    END IF;
    IF length(btrim(target_rationale)) < 40 THEN
        RAISE EXCEPTION 'Paper order proposal rationale must contain at least 40 characters';
    END IF;
    IF target_approval_fingerprint_sha256 !~ '^[0-9a-f]{64}$' THEN
        RAISE EXCEPTION 'Approval fingerprint must be a lowercase SHA-256 hex digest';
    END IF;

    SELECT * INTO STRICT instrument_row
    FROM nexus.instruments
    WHERE ticker=upper(btrim(target_ticker));
    IF instrument_row.instrument_type NOT IN ('equity','etf') THEN
        RAISE EXCEPTION 'Paper order policy is restricted to equities and ETFs';
    END IF;
    IF policy.requires_current_allowlist AND NOT EXISTS (
        SELECT 1
        FROM nexus.v_shadow_instrument_allowlist allowlist
        WHERE allowlist.experiment_code='alpaca_paper_shadow_v1'
          AND allowlist.instrument_id=instrument_row.instrument_id
          AND allowlist.authorization_state='allowed'
    ) THEN
        RAISE EXCEPTION 'Instrument is not currently allowlisted for paper order testing';
    END IF;

    INSERT INTO nexus.paper_order_proposals(
        paper_order_proposal_id,paper_order_policy_id,instrument_id,
        side,order_type,time_in_force,extended_hours,notional,client_order_id,
        approval_fingerprint_sha256,proposal_status,rationale,created_by
    ) VALUES (
        proposal_id,policy.paper_order_policy_id,instrument_row.instrument_id,
        'buy','market','day',false,target_notional,target_client_order_id,
        target_approval_fingerprint_sha256,'previewed',target_rationale,session_user
    );
    RETURN proposal_id;
END $$;

CREATE FUNCTION nexus.record_paper_order_submission(
    target_policy_code text,
    target_client_order_id text,
    target_result_status text,
    target_http_status integer,
    target_broker_order_id text,
    target_broker_order_status text,
    target_response_fingerprint_sha256 text,
    target_safe_summary text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
    policy nexus.paper_order_policies%ROWTYPE;
    proposal nexus.paper_order_proposals%ROWTYPE;
    submission_id uuid := gen_random_uuid();
    submitted_today integer;
BEGIN
    SELECT * INTO STRICT policy
    FROM nexus.paper_order_policies
    WHERE policy_code=target_policy_code;
    IF policy.policy_status<>'active' THEN
        RAISE EXCEPTION 'Paper order policy must be active';
    END IF;
    IF NOT policy.requires_human_confirmation OR policy.live_trading_enabled THEN
        RAISE EXCEPTION 'Paper order submission requires human confirmation and cannot be live trading';
    END IF;
    SELECT * INTO STRICT proposal
    FROM nexus.paper_order_proposals
    WHERE paper_order_policy_id=policy.paper_order_policy_id
      AND client_order_id=target_client_order_id;
    IF EXISTS (
        SELECT 1 FROM nexus.paper_order_submissions existing
        WHERE existing.paper_order_proposal_id=proposal.paper_order_proposal_id
    ) THEN
        RAISE EXCEPTION 'Paper order proposal has already been submitted or failed';
    END IF;
    SELECT count(*) INTO submitted_today
    FROM nexus.paper_order_submissions submission
    JOIN nexus.paper_order_proposals submitted_proposal USING(paper_order_proposal_id)
    WHERE submitted_proposal.paper_order_policy_id=policy.paper_order_policy_id
      AND submission.result_status='submitted'
      AND submission.submitted_at::date=CURRENT_DATE;
    IF target_result_status='submitted' AND submitted_today>=policy.max_daily_submitted_orders THEN
        RAISE EXCEPTION 'Daily paper order submission limit reached';
    END IF;
    IF target_result_status NOT IN ('submitted','failed') THEN
        RAISE EXCEPTION 'Paper order submission result must be submitted or failed';
    END IF;
    IF length(btrim(target_safe_summary)) < 40 THEN
        RAISE EXCEPTION 'Paper order submission summary must contain at least 40 characters';
    END IF;

    INSERT INTO nexus.paper_order_submissions(
        paper_order_submission_id,paper_order_proposal_id,result_status,http_status,
        endpoint_path,request_method,external_request_count,broker_order_id,
        broker_order_status,response_fingerprint_sha256,safe_summary,created_by
    ) VALUES (
        submission_id,proposal.paper_order_proposal_id,target_result_status,target_http_status,
        '/orders','POST',1,target_broker_order_id,target_broker_order_status,
        target_response_fingerprint_sha256,target_safe_summary,session_user
    );
    RETURN submission_id;
END $$;

REVOKE ALL ON nexus.paper_order_policies,nexus.paper_order_proposals,nexus.paper_order_submissions FROM PUBLIC;
REVOKE ALL ON FUNCTION nexus.record_paper_order_proposal(text,text,text,numeric,text,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION nexus.record_paper_order_submission(text,text,text,integer,text,text,text,text) FROM PUBLIC;

GRANT SELECT ON nexus.v_paper_order_policy_health,nexus.v_paper_order_proposals
    TO nexus_broker_monitor,nexus_automation_reader,nexus_shadow_runner,nexus_human_reviewer;
GRANT EXECUTE ON FUNCTION nexus.record_paper_order_proposal(text,text,text,numeric,text,text,text),
    nexus.record_paper_order_submission(text,text,text,integer,text,text,text,text)
    TO nexus_broker_monitor;

INSERT INTO nexus.paper_order_policies(
    paper_order_policy_id,policy_code,broker_connection_id,shadow_experiment_id,
    policy_status,broker_environment,endpoint_path,request_method,order_submission_mode,
    allowed_side,allowed_order_type,allowed_time_in_force,extended_hours_allowed,
    max_order_notional,max_daily_submitted_orders,requires_current_allowlist,
    requires_human_confirmation,live_trading_enabled,permits_margin,permits_short_sales,
    permits_options,permits_crypto,policy_notes,created_by
)
SELECT '11800000-0000-4000-8000-000000000001','alpaca_paper_approval_gated_buy_v1',
       connection.broker_connection_id,experiment.shadow_experiment_id,
       'active','alpaca_paper','/orders','POST','human_approval_gated',
       'buy','market','day',false,25,1,true,true,false,false,false,false,false,
       'Paper-only approval-gated buy policy for the five-security shadow allowlist. It supports market day notional buys up to twenty-five dollars and never enables live trading.',
       'nexus_migration_118'
FROM nexus.broker_connections connection
JOIN nexus.shadow_experiments experiment ON experiment.experiment_code='alpaca_paper_shadow_v1'
WHERE connection.connection_code='alpaca_paper_readonly_v1';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM nexus.v_paper_order_policy_health
        WHERE policy_code='alpaca_paper_approval_gated_buy_v1'
          AND shadow_experiment_code='alpaca_paper_shadow_v1'
          AND broker_connection_code='alpaca_paper_readonly_v1'
          AND order_submission_mode='human_approval_gated'
          AND allowed_side='buy'
          AND allowed_order_type='market'
          AND allowed_time_in_force='day'
          AND max_order_notional=25
          AND max_daily_submitted_orders=1
          AND requires_current_allowlist
          AND requires_human_confirmation
          AND NOT live_trading_enabled
          AND NOT permits_margin
          AND NOT permits_short_sales
          AND NOT permits_options
          AND NOT permits_crypto
    ) THEN
        RAISE EXCEPTION 'Approval-gated Alpaca Paper buy policy was not installed with safe boundaries';
    END IF;
END $$;

COMMENT ON TABLE nexus.paper_order_policies IS 'Paper-only order submission policies. The first policy is buy-only, market day, notional-capped, allowlist-bound, and human approval gated.';
COMMENT ON TABLE nexus.paper_order_proposals IS 'Append-only preview records for proposed Alpaca Paper orders. A proposal is not a broker request.';
COMMENT ON TABLE nexus.paper_order_submissions IS 'Append-only sanitized records of Alpaca Paper order submission attempts after explicit human approval.';
COMMENT ON FUNCTION nexus.record_paper_order_proposal(text,text,text,numeric,text,text,text) IS 'Records a paper-order preview for an allowlisted security. It does not call Alpaca.';
COMMENT ON FUNCTION nexus.record_paper_order_submission(text,text,text,integer,text,text,text,text) IS 'Records the result of an explicitly approved Alpaca Paper order submission. It stores no credentials.';

COMMIT;
