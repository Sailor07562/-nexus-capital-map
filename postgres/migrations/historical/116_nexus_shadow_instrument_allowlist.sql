BEGIN;
SET LOCAL lock_timeout = '5s';

ALTER TABLE nexus.shadow_experiment_instruments
    ADD COLUMN supersedes_authorization_id uuid UNIQUE
        REFERENCES nexus.shadow_experiment_instruments(shadow_experiment_instrument_id) ON DELETE RESTRICT,
    ADD CONSTRAINT shadow_authorization_not_self
        CHECK (supersedes_authorization_id IS DISTINCT FROM shadow_experiment_instrument_id);

ALTER TABLE nexus.shadow_experiment_instruments
    DROP CONSTRAINT shadow_experiment_instruments_shadow_experiment_id_instrume_key;

CREATE UNIQUE INDEX idx_shadow_authorization_one_root
    ON nexus.shadow_experiment_instruments(shadow_experiment_id,instrument_id)
    WHERE supersedes_authorization_id IS NULL;
CREATE INDEX idx_shadow_authorization_current
    ON nexus.shadow_experiment_instruments(shadow_experiment_id,instrument_id,authorized_at DESC);

CREATE FUNCTION nexus.validate_shadow_instrument_authorization()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $$
DECLARE
    previous nexus.shadow_experiment_instruments%ROWTYPE;
BEGIN
    IF NEW.supersedes_authorization_id IS NOT NULL THEN
        SELECT * INTO previous
        FROM nexus.shadow_experiment_instruments
        WHERE shadow_experiment_instrument_id=NEW.supersedes_authorization_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Previous shadow instrument authorization does not exist';
        END IF;
        IF previous.shadow_experiment_id<>NEW.shadow_experiment_id
           OR previous.instrument_id<>NEW.instrument_id
           OR NEW.authorized_at<previous.authorized_at THEN
            RAISE EXCEPTION 'Shadow authorization successor must preserve experiment, instrument, and chronology';
        END IF;
        IF EXISTS (
            SELECT 1 FROM nexus.shadow_experiment_instruments successor
            WHERE successor.supersedes_authorization_id=previous.shadow_experiment_instrument_id
        ) THEN
            RAISE EXCEPTION 'Shadow instrument authorization already has a successor';
        END IF;
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER validate_shadow_instrument_authorization
BEFORE INSERT ON nexus.shadow_experiment_instruments
FOR EACH ROW EXECUTE FUNCTION nexus.validate_shadow_instrument_authorization();

CREATE VIEW nexus.v_shadow_experiment_instrument_current AS
SELECT auth.*
FROM nexus.shadow_experiment_instruments auth
WHERE NOT EXISTS (
    SELECT 1 FROM nexus.shadow_experiment_instruments successor
    WHERE successor.supersedes_authorization_id=auth.shadow_experiment_instrument_id
);

CREATE VIEW nexus.v_shadow_instrument_allowlist AS
SELECT experiment.experiment_code,experiment.experiment_status,
       auth.shadow_experiment_instrument_id,auth.shadow_experiment_id,
       instrument.instrument_id,instrument.ticker,instrument.exchange,
       instrument.name AS security_name,instrument.instrument_type,
       auth.authorization_state,auth.authorization_basis,
       auth.authorized_by,auth.authorized_at,
       auth.supersedes_authorization_id
FROM nexus.v_shadow_experiment_instrument_current auth
JOIN nexus.shadow_experiments experiment USING(shadow_experiment_id)
JOIN nexus.instruments instrument USING(instrument_id);

CREATE OR REPLACE VIEW nexus.v_shadow_mode_summary AS
SELECT e.shadow_experiment_id,e.experiment_code,e.experiment_name,e.experiment_status,
       e.broker_environment,e.broker_endpoint,e.simulated_capital_limit,e.max_intent_notional,
       e.max_daily_trade_intents,e.asset_scope,e.sends_orders,e.human_promotion_required,
       count(DISTINCT allowlist.instrument_id) FILTER (WHERE allowlist.authorization_state='allowed') AS allowed_instrument_count,
       count(DISTINCT intent.shadow_trade_intent_id) AS intent_count,
       count(DISTINCT intent.shadow_trade_intent_id) FILTER (WHERE intent.intent_state='observed') AS observed_intent_count,
       count(DISTINCT intent.shadow_trade_intent_id) FILTER (WHERE intent.intent_state='eligible') AS eligible_intent_count,
       count(DISTINCT intent.shadow_trade_intent_id) FILTER (WHERE intent.intent_state='blocked') AS blocked_intent_count,
       max(intent.created_at) AS latest_intent_at,
       bool_or(COALESCE(intent.would_submit_order,false)) AS any_order_submission_enabled,
       bool_or(COALESCE(run.broker_order_submission_attempted,false)) AS any_order_submission_attempted,
       COALESCE(sum(run.external_request_count),0) AS external_request_count
FROM nexus.shadow_experiments e
LEFT JOIN nexus.v_shadow_experiment_instrument_current allowlist USING(shadow_experiment_id)
LEFT JOIN nexus.shadow_trade_intents intent USING(shadow_experiment_id)
LEFT JOIN nexus.shadow_runs run ON run.shadow_run_id=intent.shadow_run_id
GROUP BY e.shadow_experiment_id,e.experiment_code,e.experiment_name,e.experiment_status,
         e.broker_environment,e.broker_endpoint,e.simulated_capital_limit,e.max_intent_notional,
         e.max_daily_trade_intents,e.asset_scope,e.sends_orders,e.human_promotion_required;

CREATE OR REPLACE FUNCTION nexus.record_shadow_intent(
    target_experiment_code text,
    target_instrument_id uuid,
    target_assessment_id uuid,
    target_action text,
    target_reference_price numeric,
    target_simulated_notional numeric,
    target_limit_price numeric,
    target_rationale text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
    experiment nexus.shadow_experiments%ROWTYPE;
    assessment nexus.decision_engine_assessments%ROWTYPE;
    context_row nexus.portfolio_decision_contexts%ROWTYPE;
    blocker_list text[] := ARRAY[]::text[];
    intent_id uuid := gen_random_uuid();
    run_id uuid := gen_random_uuid();
    target_state text;
    target_run_status text;
    current_trade_count integer;
    cumulative_eligible_buy_notional numeric(24,8);
BEGIN
    IF target_action NOT IN ('observe','watch','hold','buy','sell') THEN
        RAISE EXCEPTION 'Shadow intent action must be observe, watch, hold, buy, or sell';
    END IF;
    IF length(btrim(target_rationale)) < 40 THEN
        RAISE EXCEPTION 'Shadow intent rationale must contain at least 40 characters';
    END IF;

    SELECT * INTO STRICT experiment FROM nexus.shadow_experiments
    WHERE experiment_code=target_experiment_code;
    IF experiment.experiment_status<>'active' THEN
        RAISE EXCEPTION 'Shadow experiment must be active';
    END IF;
    IF experiment.sends_orders OR experiment.broker_environment<>'alpaca_paper' THEN
        RAISE EXCEPTION 'Shadow mode cannot send orders or use a live broker environment';
    END IF;
    PERFORM 1 FROM nexus.instruments WHERE instrument_id=target_instrument_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Unknown instrument'; END IF;

    IF target_assessment_id IS NOT NULL THEN
        SELECT * INTO assessment FROM nexus.decision_engine_assessments
        WHERE decision_engine_assessment_id=target_assessment_id
          AND instrument_id=target_instrument_id;
        IF NOT FOUND THEN
            blocker_list := array_append(blocker_list,'assessment_missing_or_instrument_mismatch');
        ELSIF EXISTS (
            SELECT 1 FROM nexus.decision_engine_assessments successor
            WHERE successor.supersedes_assessment_id=assessment.decision_engine_assessment_id
        ) THEN
            blocker_list := array_append(blocker_list,'assessment_not_current');
        ELSE
            SELECT * INTO STRICT context_row FROM nexus.portfolio_decision_contexts
            WHERE portfolio_decision_context_id=assessment.portfolio_decision_context_id;
        END IF;
    ELSIF target_action IN ('buy','sell') THEN
        blocker_list := array_append(blocker_list,'decision_assessment_required');
    END IF;

    IF target_action IN ('buy','sell') THEN
        IF target_reference_price IS NULL OR target_reference_price<=0
           OR target_simulated_notional IS NULL OR target_simulated_notional<=0
           OR target_limit_price IS NULL OR target_limit_price<=0 THEN
            RAISE EXCEPTION 'Shadow buy or sell intent requires positive reference price, notional, and limit price';
        END IF;
        IF NOT EXISTS (
            SELECT 1 FROM nexus.v_shadow_experiment_instrument_current allowed
            WHERE allowed.shadow_experiment_id=experiment.shadow_experiment_id
              AND allowed.instrument_id=target_instrument_id
              AND allowed.authorization_state='allowed'
        ) THEN
            blocker_list := array_append(blocker_list,'instrument_not_allowlisted');
        END IF;
        IF target_simulated_notional>experiment.max_intent_notional THEN
            blocker_list := array_append(blocker_list,'intent_notional_above_limit');
        END IF;
        SELECT count(*) INTO current_trade_count
        FROM nexus.shadow_trade_intents prior
        WHERE prior.shadow_experiment_id=experiment.shadow_experiment_id
          AND prior.session_date=CURRENT_DATE
          AND prior.intent_action IN ('buy','sell');
        IF current_trade_count>=experiment.max_daily_trade_intents THEN
            blocker_list := array_append(blocker_list,'daily_trade_intent_limit_reached');
        END IF;
        SELECT COALESCE(sum(prior.simulated_notional),0) INTO cumulative_eligible_buy_notional
        FROM nexus.shadow_trade_intents prior
        WHERE prior.shadow_experiment_id=experiment.shadow_experiment_id
          AND prior.intent_action='buy' AND prior.intent_state='eligible';
        IF target_action='buy'
           AND cumulative_eligible_buy_notional+target_simulated_notional>experiment.simulated_capital_limit THEN
            blocker_list := array_append(blocker_list,'simulated_capital_limit_exceeded');
        END IF;
        IF target_assessment_id IS NOT NULL AND assessment.decision_engine_assessment_id IS NOT NULL THEN
            IF assessment.readiness<>'decision_ready' THEN
                blocker_list := array_append(blocker_list,'assessment_not_decision_ready');
            END IF;
            IF target_action='buy' AND assessment.recommendation NOT IN ('starter_position','build_position') THEN
                blocker_list := array_append(blocker_list,'assessment_does_not_support_buy');
            END IF;
            IF target_action='sell' AND assessment.recommendation NOT IN ('reduce','exit') THEN
                blocker_list := array_append(blocker_list,'assessment_does_not_support_sell');
            END IF;
            IF target_action='buy' AND NOT context_row.deployment_authorized THEN
                blocker_list := array_append(blocker_list,'deployment_not_authorized');
            END IF;
        END IF;
        target_state := CASE WHEN cardinality(blocker_list)=0 THEN 'eligible' ELSE 'blocked' END;
        target_run_status := CASE WHEN target_state='eligible' THEN 'completed' ELSE 'blocked' END;
    ELSE
        IF target_reference_price IS NOT NULL OR target_simulated_notional IS NOT NULL OR target_limit_price IS NOT NULL THEN
            RAISE EXCEPTION 'Observe, watch, and hold intents cannot carry simulated order values';
        END IF;
        target_state := 'observed';
        target_run_status := 'completed';
        blocker_list := ARRAY[]::text[];
    END IF;

    INSERT INTO nexus.shadow_runs(
        shadow_run_id,shadow_experiment_id,portfolio_decision_context_id,run_as_of,
        run_status,market_data_source,engine_mode,external_request_count,
        broker_order_submission_attempted,run_summary,created_by
    ) VALUES (
        run_id,experiment.shadow_experiment_id,
        CASE WHEN assessment.decision_engine_assessment_id IS NULL THEN NULL
             ELSE assessment.portfolio_decision_context_id END,
        clock_timestamp(),target_run_status,'alpaca_paper','shadow',0,false,
        CASE WHEN target_state='blocked'
             THEN 'Shadow intent recorded as blocked. It was not transmitted to Alpaca and cannot become a broker order.'
             ELSE 'Shadow observation recorded locally. It was not transmitted to Alpaca and cannot become a broker order.' END,
        session_user
    );
    INSERT INTO nexus.shadow_trade_intents(
        shadow_trade_intent_id,shadow_experiment_id,shadow_run_id,instrument_id,
        decision_engine_assessment_id,session_date,intent_action,intent_state,
        order_type,time_in_force,reference_price,simulated_notional,simulated_quantity,
        limit_price,blockers,rationale,would_submit_order,broker_order_id,created_by
    ) VALUES (
        intent_id,experiment.shadow_experiment_id,run_id,target_instrument_id,target_assessment_id,
        CURRENT_DATE,target_action,target_state,
        CASE WHEN target_action IN ('buy','sell') THEN 'limit' ELSE 'none' END,
        CASE WHEN target_action IN ('buy','sell') THEN 'day' ELSE 'none' END,
        target_reference_price,target_simulated_notional,
        CASE WHEN target_action IN ('buy','sell') THEN target_simulated_notional/target_reference_price ELSE NULL END,
        target_limit_price,blocker_list,target_rationale,false,NULL,session_user
    );
    RETURN intent_id;
END $$;

INSERT INTO nexus.companies(
    company_id,ticker,exchange,name,legal_name,country_code,sector,industry,cik,created_by,updated_by
) VALUES (
    '11600000-0000-4000-8000-000000000001','WMT','NASDAQ','Walmart','Walmart Inc.','US',
    'Consumer Staples','Retail-Variety Stores','0000104169','nexus_migration_116','nexus_migration_116'
)
ON CONFLICT DO NOTHING;

DO $$
BEGIN
    IF (SELECT count(*) FROM nexus.companies
        WHERE cik='0000104169' OR (ticker='WMT' AND exchange='NASDAQ'))<>1 THEN
        RAISE EXCEPTION 'Walmart company identity is missing or ambiguous';
    END IF;
END $$;

INSERT INTO nexus.instruments(
    instrument_id,ticker,exchange,name,instrument_type,issuer_company_id,country_code,created_by
)
SELECT '11600000-0000-4000-8000-000000000002','WMT','NASDAQ','Walmart common stock',
       'equity',company_id,'US','nexus_migration_116'
FROM nexus.companies
WHERE cik='0000104169' OR (ticker='WMT' AND exchange='NASDAQ')
ON CONFLICT DO NOTHING;

DO $$
BEGIN
    IF (SELECT count(*) FROM nexus.instruments WHERE ticker IN ('POWL','XLI','WMT','NVDA','CCJ'))<>5 THEN
        RAISE EXCEPTION 'The five requested shadow instruments are missing or ambiguous';
    END IF;
    IF EXISTS (
        SELECT 1 FROM nexus.instruments
        WHERE ticker IN ('POWL','XLI','WMT','NVDA','CCJ')
          AND instrument_type NOT IN ('equity','etf')
    ) THEN
        RAISE EXCEPTION 'Shadow allowlist is restricted to equity and ETF instruments';
    END IF;
END $$;

INSERT INTO nexus.shadow_experiment_instruments(
    shadow_experiment_instrument_id,shadow_experiment_id,instrument_id,
    authorization_state,authorization_basis,authorized_by,authorized_at
)
SELECT requested.authorization_id,experiment.shadow_experiment_id,instrument.instrument_id,
       'allowed',
       'User explicitly selected this security for the small-capital Alpaca Paper shadow experiment. Authorization is simulation-only and does not permit an API request or order submission.',
       'user_explicit_shadow_selection_20260915',clock_timestamp()
FROM (VALUES
    ('POWL','11600000-0000-4000-8000-000000000011'::uuid),
    ('XLI', '11600000-0000-4000-8000-000000000012'::uuid),
    ('WMT', '11600000-0000-4000-8000-000000000013'::uuid),
    ('NVDA','11600000-0000-4000-8000-000000000014'::uuid),
    ('CCJ', '11600000-0000-4000-8000-000000000015'::uuid)
) requested(ticker,authorization_id)
JOIN nexus.instruments instrument USING(ticker)
JOIN nexus.shadow_experiments experiment ON experiment.experiment_code='alpaca_paper_shadow_v1';

DO $$
BEGIN
    IF (SELECT count(*) FROM nexus.v_shadow_instrument_allowlist
        WHERE experiment_code='alpaca_paper_shadow_v1'
          AND authorization_state='allowed'
          AND ticker IN ('POWL','XLI','WMT','NVDA','CCJ'))<>5 THEN
        RAISE EXCEPTION 'Requested Alpaca Paper shadow allowlist was not installed';
    END IF;
END $$;

REVOKE ALL ON FUNCTION nexus.validate_shadow_instrument_authorization() FROM PUBLIC;
GRANT SELECT ON nexus.v_shadow_experiment_instrument_current,nexus.v_shadow_instrument_allowlist
    TO nexus_shadow_runner,nexus_automation_reader,nexus_human_reviewer;

COMMENT ON COLUMN nexus.shadow_experiment_instruments.supersedes_authorization_id IS
    'Append-only pointer used to allow or revoke a shadow instrument while retaining authorization history.';
COMMENT ON VIEW nexus.v_shadow_instrument_allowlist IS
    'Current instrument-level authorization state for each shadow experiment.';
COMMENT ON FUNCTION nexus.record_shadow_intent(text,uuid,uuid,text,numeric,numeric,numeric,text) IS
    'Records a local shadow observation or hypothetical limit-order intent, checking only the current append-only allowlist. It performs no network request and cannot submit an Alpaca order.';

COMMIT;
