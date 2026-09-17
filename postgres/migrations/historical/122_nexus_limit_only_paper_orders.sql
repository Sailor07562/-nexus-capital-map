BEGIN;
SET LOCAL lock_timeout = '5s';

ALTER TABLE nexus.paper_order_policies
    DROP CONSTRAINT paper_order_policies_allowed_order_type_check;
ALTER TABLE nexus.paper_order_policies
    ADD CONSTRAINT paper_order_policies_allowed_order_type_check
    CHECK (allowed_order_type IN ('market','limit'));

ALTER TABLE nexus.paper_order_proposals
    DROP CONSTRAINT paper_order_proposals_order_type_check;
ALTER TABLE nexus.paper_order_proposals
    ADD CONSTRAINT paper_order_proposals_order_type_check
    CHECK (order_type IN ('market','limit'));
ALTER TABLE nexus.paper_order_proposals
    ADD COLUMN quantity numeric(24,8),
    ADD COLUMN limit_price numeric(24,8);
ALTER TABLE nexus.paper_order_proposals
    ADD CONSTRAINT paper_order_proposals_limit_shape_check CHECK (
        (order_type='market' AND quantity IS NULL AND limit_price IS NULL)
        OR
        (order_type='limit' AND quantity > 0 AND limit_price > 0)
    );
ALTER TABLE nexus.paper_order_proposals
    ADD CONSTRAINT paper_order_proposals_limit_notional_cap_check CHECK (
        order_type <> 'limit' OR (quantity * limit_price) <= 25.00000000
    );

CREATE OR REPLACE VIEW nexus.v_paper_order_proposals AS
SELECT policy.policy_code,policy.policy_status,policy.broker_environment,
       policy.order_submission_mode,policy.max_order_notional,policy.max_daily_submitted_orders,
       proposal.paper_order_proposal_id,proposal.proposal_date,proposal.created_at AS proposed_at,
       instrument.ticker,instrument.name AS security_name,proposal.side,proposal.order_type,
       proposal.time_in_force,proposal.extended_hours,proposal.notional,
       proposal.client_order_id,proposal.proposal_status,proposal.rationale,
       submission.paper_order_submission_id,submission.submitted_at,
       submission.result_status AS submission_result_status,
       submission.http_status AS submission_http_status,
       submission.broker_order_status,submission.safe_summary AS submission_safe_summary,
       proposal.quantity,proposal.limit_price
FROM nexus.paper_order_proposals proposal
JOIN nexus.paper_order_policies policy USING(paper_order_policy_id)
JOIN nexus.instruments instrument USING(instrument_id)
LEFT JOIN nexus.paper_order_submissions submission USING(paper_order_proposal_id);

CREATE OR REPLACE VIEW nexus.v_paper_order_policy_health AS
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
       max(submission.submitted_at) AS latest_submitted_at,
       policy.endpoint_path,policy.request_method
FROM nexus.paper_order_policies policy
JOIN nexus.broker_connections connection USING(broker_connection_id)
JOIN nexus.shadow_experiments experiment USING(shadow_experiment_id)
LEFT JOIN nexus.paper_order_proposals proposal USING(paper_order_policy_id)
LEFT JOIN nexus.paper_order_submissions submission USING(paper_order_proposal_id)
GROUP BY policy.paper_order_policy_id,connection.connection_code,experiment.experiment_code;

CREATE OR REPLACE FUNCTION nexus.record_paper_order_proposal(
    target_policy_code text,
    target_ticker text,
    target_side text,
    target_notional numeric,
    target_client_order_id text,
    target_approval_fingerprint_sha256 text,
    target_rationale text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
    RAISE EXCEPTION 'Market paper-order proposals are retired. Use nexus.record_limit_paper_order_proposal.';
END $$;

CREATE FUNCTION nexus.record_limit_paper_order_proposal(
    target_policy_code text,
    target_ticker text,
    target_side text,
    target_notional numeric,
    target_quantity numeric,
    target_limit_price numeric,
    target_client_order_id text,
    target_approval_fingerprint_sha256 text,
    target_rationale text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
    policy nexus.paper_order_policies%ROWTYPE;
    instrument_row nexus.instruments%ROWTYPE;
    proposal_id uuid := gen_random_uuid();
    estimated_notional numeric;
BEGIN
    SELECT * INTO STRICT policy
    FROM nexus.paper_order_policies
    WHERE policy_code=target_policy_code;
    IF policy.policy_status<>'active' THEN
        RAISE EXCEPTION 'Paper order policy must be active';
    END IF;
    IF policy.live_trading_enabled OR policy.allowed_side<>'buy' OR policy.allowed_order_type<>'limit' THEN
        RAISE EXCEPTION 'Paper order policy is not in buy-only limit-paper mode';
    END IF;
    IF target_side<>'buy' THEN
        RAISE EXCEPTION 'This policy allows paper buy orders only';
    END IF;
    IF target_notional IS NULL OR target_notional<=0 OR target_notional>policy.max_order_notional THEN
        RAISE EXCEPTION 'Paper order notional exceeds the active policy limit';
    END IF;
    IF target_quantity IS NULL OR target_quantity<=0 OR target_limit_price IS NULL OR target_limit_price<=0 THEN
        RAISE EXCEPTION 'Limit paper orders require positive quantity and limit price';
    END IF;
    estimated_notional := target_quantity * target_limit_price;
    IF estimated_notional > policy.max_order_notional THEN
        RAISE EXCEPTION 'Limit paper order estimated exposure exceeds the active policy limit';
    END IF;
    IF estimated_notional > target_notional + 0.01 THEN
        RAISE EXCEPTION 'Limit paper order estimated exposure exceeds the stated notional cap';
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
        side,order_type,time_in_force,extended_hours,notional,quantity,limit_price,
        client_order_id,approval_fingerprint_sha256,proposal_status,rationale,created_by
    ) VALUES (
        proposal_id,policy.paper_order_policy_id,instrument_row.instrument_id,
        'buy','limit','day',false,target_notional,target_quantity,target_limit_price,
        target_client_order_id,target_approval_fingerprint_sha256,'previewed',
        target_rationale,session_user
    );
    RETURN proposal_id;
END $$;

CREATE OR REPLACE FUNCTION nexus.record_paper_order_submission(
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
    IF policy.allowed_order_type<>'limit' THEN
        RAISE EXCEPTION 'Only limit Paper order submissions are allowed';
    END IF;
    SELECT * INTO STRICT proposal
    FROM nexus.paper_order_proposals
    WHERE paper_order_policy_id=policy.paper_order_policy_id
      AND client_order_id=target_client_order_id;
    IF proposal.order_type<>'limit' OR proposal.limit_price IS NULL OR proposal.quantity IS NULL THEN
        RAISE EXCEPTION 'Paper order submission requires a limit-order proposal';
    END IF;
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

REVOKE ALL ON FUNCTION nexus.record_limit_paper_order_proposal(text,text,text,numeric,numeric,numeric,text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION nexus.record_limit_paper_order_proposal(text,text,text,numeric,numeric,numeric,text,text,text)
    TO nexus_broker_monitor;

INSERT INTO nexus.paper_order_policies(
    paper_order_policy_id,policy_code,broker_connection_id,shadow_experiment_id,
    policy_status,broker_environment,endpoint_path,request_method,order_submission_mode,
    allowed_side,allowed_order_type,allowed_time_in_force,extended_hours_allowed,
    max_order_notional,max_daily_submitted_orders,requires_current_allowlist,
    requires_human_confirmation,live_trading_enabled,permits_margin,permits_short_sales,
    permits_options,permits_crypto,policy_notes,created_by
)
SELECT '12200000-0000-4000-8000-000000000001','alpaca_paper_approval_gated_limit_buy_v1',
       connection.broker_connection_id,experiment.shadow_experiment_id,
       'active','alpaca_paper','/orders','POST','human_approval_gated',
       'buy','limit','day',false,25,1,true,true,false,false,false,false,false,
       'Paper-only approval-gated limit-buy policy for the five-security shadow allowlist. It caps estimated exposure at twenty-five dollars, requires explicit human confirmation and never enables live trading.',
       'nexus_migration_122'
FROM nexus.broker_connections connection
JOIN nexus.shadow_experiments experiment ON experiment.experiment_code='alpaca_paper_shadow_v1'
WHERE connection.connection_code='alpaca_paper_readonly_v1';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM nexus.v_paper_order_policy_health
        WHERE policy_code='alpaca_paper_approval_gated_limit_buy_v1'
          AND endpoint_path='/orders'
          AND request_method='POST'
          AND order_submission_mode='human_approval_gated'
          AND allowed_side='buy'
          AND allowed_order_type='limit'
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
        RAISE EXCEPTION 'Approval-gated Alpaca Paper limit-buy policy was not installed with safe boundaries';
    END IF;
END $$;

COMMENT ON FUNCTION nexus.record_paper_order_proposal(text,text,text,numeric,text,text,text) IS
    'Retired compatibility function. Market Paper order previews are disabled; use record_limit_paper_order_proposal.';
COMMENT ON FUNCTION nexus.record_limit_paper_order_proposal(text,text,text,numeric,numeric,numeric,text,text,text) IS
    'Records a limit Paper-order preview for an allowlisted security. It does not call Alpaca.';
COMMENT ON FUNCTION nexus.record_paper_order_submission(text,text,text,integer,text,text,text,text) IS
    'Records the result of an explicitly approved Alpaca Paper limit-order submission. It stores no credentials.';

COMMIT;
