BEGIN;
SET LOCAL lock_timeout = '5s';

CREATE TABLE nexus.shadow_experiments (
    shadow_experiment_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    experiment_code text NOT NULL UNIQUE CHECK (btrim(experiment_code) <> ''),
    experiment_name text NOT NULL CHECK (btrim(experiment_name) <> ''),
    experiment_status text NOT NULL CHECK (experiment_status IN ('draft','active','paused','completed')),
    broker_environment text NOT NULL CHECK (broker_environment = 'alpaca_paper'),
    broker_endpoint text NOT NULL CHECK (broker_endpoint = 'https://paper-api.alpaca.markets/v2'),
    simulated_capital_limit numeric(24,8) NOT NULL CHECK (simulated_capital_limit > 0),
    max_intent_notional numeric(24,8) NOT NULL CHECK (
        max_intent_notional > 0 AND max_intent_notional <= simulated_capital_limit
    ),
    max_daily_trade_intents integer NOT NULL CHECK (max_daily_trade_intents BETWEEN 1 AND 10),
    asset_scope text NOT NULL CHECK (btrim(asset_scope) <> ''),
    requires_instrument_allowlist boolean NOT NULL DEFAULT true CHECK (requires_instrument_allowlist),
    sends_orders boolean NOT NULL DEFAULT false CHECK (NOT sends_orders),
    permits_margin boolean NOT NULL DEFAULT false CHECK (NOT permits_margin),
    permits_short_sales boolean NOT NULL DEFAULT false CHECK (NOT permits_short_sales),
    permits_options boolean NOT NULL DEFAULT false CHECK (NOT permits_options),
    permits_crypto boolean NOT NULL DEFAULT false CHECK (NOT permits_crypto),
    human_promotion_required boolean NOT NULL DEFAULT true CHECK (human_promotion_required),
    created_by text NOT NULL DEFAULT current_user,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER prevent_shadow_experiment_mutation
BEFORE UPDATE OR DELETE OR TRUNCATE ON nexus.shadow_experiments
FOR EACH STATEMENT EXECUTE FUNCTION nexus.prevent_mutation();

CREATE TABLE nexus.shadow_experiment_instruments (
    shadow_experiment_instrument_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    shadow_experiment_id uuid NOT NULL REFERENCES nexus.shadow_experiments ON DELETE RESTRICT,
    instrument_id uuid NOT NULL REFERENCES nexus.instruments ON DELETE RESTRICT,
    authorization_state text NOT NULL CHECK (authorization_state IN ('allowed','blocked')),
    authorization_basis text NOT NULL CHECK (length(btrim(authorization_basis)) >= 40),
    authorized_by text NOT NULL DEFAULT session_user CHECK (btrim(authorized_by) <> ''),
    authorized_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    UNIQUE (shadow_experiment_id, instrument_id)
);
CREATE TRIGGER prevent_shadow_experiment_instrument_mutation
BEFORE UPDATE OR DELETE OR TRUNCATE ON nexus.shadow_experiment_instruments
FOR EACH STATEMENT EXECUTE FUNCTION nexus.prevent_mutation();

CREATE TABLE nexus.shadow_runs (
    shadow_run_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    shadow_experiment_id uuid NOT NULL REFERENCES nexus.shadow_experiments ON DELETE RESTRICT,
    portfolio_decision_context_id uuid REFERENCES nexus.portfolio_decision_contexts ON DELETE RESTRICT,
    run_as_of timestamptz NOT NULL,
    run_status text NOT NULL CHECK (run_status IN ('completed','blocked','failed')),
    market_data_source text NOT NULL CHECK (market_data_source = 'alpaca_paper'),
    engine_mode text NOT NULL CHECK (engine_mode = 'shadow'),
    external_request_count integer NOT NULL DEFAULT 0 CHECK (external_request_count = 0),
    broker_order_submission_attempted boolean NOT NULL DEFAULT false CHECK (NOT broker_order_submission_attempted),
    run_summary text NOT NULL CHECK (length(btrim(run_summary)) >= 40),
    created_by text NOT NULL DEFAULT session_user,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_shadow_runs_experiment_as_of
    ON nexus.shadow_runs(shadow_experiment_id, run_as_of DESC);
CREATE TRIGGER prevent_shadow_run_mutation
BEFORE UPDATE OR DELETE OR TRUNCATE ON nexus.shadow_runs
FOR EACH STATEMENT EXECUTE FUNCTION nexus.prevent_mutation();

CREATE TABLE nexus.shadow_trade_intents (
    shadow_trade_intent_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    shadow_experiment_id uuid NOT NULL REFERENCES nexus.shadow_experiments ON DELETE RESTRICT,
    shadow_run_id uuid NOT NULL UNIQUE REFERENCES nexus.shadow_runs ON DELETE RESTRICT,
    instrument_id uuid NOT NULL REFERENCES nexus.instruments ON DELETE RESTRICT,
    decision_engine_assessment_id uuid REFERENCES nexus.decision_engine_assessments ON DELETE RESTRICT,
    session_date date NOT NULL DEFAULT CURRENT_DATE,
    intent_action text NOT NULL CHECK (intent_action IN ('observe','watch','hold','buy','sell')),
    intent_state text NOT NULL CHECK (intent_state IN ('observed','eligible','blocked')),
    order_type text NOT NULL CHECK (order_type IN ('none','limit')),
    time_in_force text NOT NULL CHECK (time_in_force IN ('none','day')),
    reference_price numeric(24,8) CHECK (reference_price > 0),
    simulated_notional numeric(24,8) CHECK (simulated_notional > 0),
    simulated_quantity numeric(32,12) CHECK (simulated_quantity > 0),
    limit_price numeric(24,8) CHECK (limit_price > 0),
    blockers text[] NOT NULL DEFAULT ARRAY[]::text[],
    rationale text NOT NULL CHECK (length(btrim(rationale)) >= 40),
    would_submit_order boolean NOT NULL DEFAULT false CHECK (NOT would_submit_order),
    broker_order_id text CHECK (broker_order_id IS NULL),
    created_by text NOT NULL DEFAULT session_user,
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (
        (intent_action IN ('observe','watch','hold')
         AND intent_state='observed' AND order_type='none' AND time_in_force='none'
         AND reference_price IS NULL AND simulated_notional IS NULL
         AND simulated_quantity IS NULL AND limit_price IS NULL)
        OR
        (intent_action IN ('buy','sell')
         AND intent_state IN ('eligible','blocked') AND order_type='limit' AND time_in_force='day'
         AND reference_price IS NOT NULL AND simulated_notional IS NOT NULL
         AND simulated_quantity IS NOT NULL AND limit_price IS NOT NULL)
    ),
    CHECK ((intent_state='eligible' AND cardinality(blockers)=0) OR intent_state<>'eligible'),
    UNIQUE (shadow_experiment_id, decision_engine_assessment_id, session_date, intent_action)
);
CREATE INDEX idx_shadow_trade_intents_experiment_date
    ON nexus.shadow_trade_intents(shadow_experiment_id, session_date DESC, created_at DESC);
CREATE TRIGGER prevent_shadow_trade_intent_mutation
BEFORE UPDATE OR DELETE OR TRUNCATE ON nexus.shadow_trade_intents
FOR EACH STATEMENT EXECUTE FUNCTION nexus.prevent_mutation();

CREATE VIEW nexus.v_shadow_trade_intents AS
SELECT e.experiment_code,e.experiment_status,e.simulated_capital_limit,e.max_intent_notional,
       r.shadow_run_id,r.run_as_of,r.run_status,r.external_request_count,
       r.broker_order_submission_attempted,i.shadow_trade_intent_id,i.session_date,
       s.ticker,s.name AS security_name,i.intent_action,i.intent_state,i.order_type,
       i.reference_price,i.simulated_notional,i.simulated_quantity,i.limit_price,
       i.blockers,i.rationale,i.would_submit_order,i.broker_order_id,
       a.recommendation AS assessment_recommendation,a.readiness AS assessment_readiness
FROM nexus.shadow_trade_intents i
JOIN nexus.shadow_experiments e USING(shadow_experiment_id)
JOIN nexus.shadow_runs r USING(shadow_run_id)
JOIN nexus.instruments s USING(instrument_id)
LEFT JOIN nexus.decision_engine_assessments a USING(decision_engine_assessment_id);

CREATE VIEW nexus.v_shadow_mode_summary AS
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
LEFT JOIN nexus.shadow_experiment_instruments allowlist USING(shadow_experiment_id)
LEFT JOIN nexus.shadow_trade_intents intent USING(shadow_experiment_id)
LEFT JOIN nexus.shadow_runs run ON run.shadow_run_id=intent.shadow_run_id
GROUP BY e.shadow_experiment_id,e.experiment_code,e.experiment_name,e.experiment_status,
         e.broker_environment,e.broker_endpoint,e.simulated_capital_limit,e.max_intent_notional,
         e.max_daily_trade_intents,e.asset_scope,e.sends_orders,e.human_promotion_required;

CREATE FUNCTION nexus.record_shadow_intent(
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
            SELECT 1 FROM nexus.shadow_experiment_instruments allowed
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

CREATE FUNCTION nexus.run_shadow_observation_cycle(target_experiment_code text)
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
    assessment record;
    inserted_count integer := 0;
BEGIN
    FOR assessment IN
        SELECT w.decision_engine_assessment_id,w.instrument_id,w.recommendation,w.ticker,
               w.readiness,w.rationale
        FROM nexus.v_decision_engine_workbench w
        JOIN nexus.shadow_experiments e ON e.experiment_code=target_experiment_code
        WHERE w.recommendation IN ('hold','watch')
          AND NOT EXISTS (
              SELECT 1 FROM nexus.shadow_trade_intents prior
              WHERE prior.shadow_experiment_id=e.shadow_experiment_id
                AND prior.decision_engine_assessment_id=w.decision_engine_assessment_id
                AND prior.session_date=CURRENT_DATE
                AND prior.intent_action=w.recommendation::text
          )
        ORDER BY w.ticker
    LOOP
        PERFORM nexus.record_shadow_intent(
            target_experiment_code,assessment.instrument_id,assessment.decision_engine_assessment_id,
            assessment.recommendation::text,NULL,NULL,NULL,
            'Shadow observation mirrors the current Decision Engine posture without creating or transmitting a brokerage order.'
        );
        inserted_count := inserted_count+1;
    END LOOP;
    RETURN inserted_count;
END $$;

REVOKE ALL ON FUNCTION nexus.record_shadow_intent(text,uuid,uuid,text,numeric,numeric,numeric,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION nexus.run_shadow_observation_cycle(text) FROM PUBLIC;
REVOKE ALL ON nexus.shadow_experiments,nexus.shadow_experiment_instruments,
    nexus.shadow_runs,nexus.shadow_trade_intents FROM PUBLIC;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='nexus_shadow_runner') THEN
        CREATE ROLE nexus_shadow_runner NOLOGIN;
    END IF;
END $$;

GRANT USAGE ON SCHEMA nexus TO nexus_shadow_runner;
GRANT SELECT ON nexus.v_decision_engine_workbench,nexus.v_shadow_trade_intents,
    nexus.v_shadow_mode_summary TO nexus_shadow_runner,nexus_automation_reader,nexus_human_reviewer;
GRANT EXECUTE ON FUNCTION nexus.record_shadow_intent(text,uuid,uuid,text,numeric,numeric,numeric,text),
    nexus.run_shadow_observation_cycle(text) TO nexus_shadow_runner;

INSERT INTO nexus.shadow_experiments(
    shadow_experiment_id,experiment_code,experiment_name,experiment_status,
    broker_environment,broker_endpoint,simulated_capital_limit,max_intent_notional,
    max_daily_trade_intents,asset_scope,requires_instrument_allowlist,sends_orders,
    permits_margin,permits_short_sales,permits_options,permits_crypto,human_promotion_required,created_by
) VALUES (
    '11500000-0000-4000-8000-000000000001','alpaca_paper_shadow_v1',
    'Alpaca Paper Shadow Experiment v1','active','alpaca_paper',
    'https://paper-api.alpaca.markets/v2',100,25,1,
    'Explicitly allowlisted U.S. stock or ETF instruments only. The initial allowlist is empty; current Decision Engine hold and watch postures may be observed without simulated orders.',
    true,false,false,false,false,false,true,'nexus_migration_115'
);

COMMENT ON TABLE nexus.shadow_experiments IS 'Bounded simulation policies. Shadow mode is paper-only and database-enforced to prohibit brokerage order submission.';
COMMENT ON TABLE nexus.shadow_trade_intents IS 'Immutable hypothetical order intents and non-trade observations. Rows cannot represent submitted or filled broker orders.';
COMMENT ON FUNCTION nexus.record_shadow_intent(text,uuid,uuid,text,numeric,numeric,numeric,text) IS 'Records a local shadow observation or hypothetical limit-order intent. It performs no network request and cannot submit an Alpaca order.';
COMMENT ON FUNCTION nexus.run_shadow_observation_cycle(text) IS 'Mirrors current Decision Engine hold/watch postures into the shadow ledger without prices, API calls, or broker orders.';

COMMIT;
