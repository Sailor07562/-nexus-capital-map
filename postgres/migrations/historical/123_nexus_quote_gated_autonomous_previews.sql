BEGIN;
SET LOCAL lock_timeout = '5s';

CREATE TABLE nexus.market_data_quote_receipts (
    market_data_quote_receipt_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    received_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    provider text NOT NULL CHECK (provider = 'alpaca'),
    broker_environment text NOT NULL CHECK (broker_environment = 'alpaca_paper'),
    api_base_url text NOT NULL CHECK (api_base_url = 'https://data.alpaca.markets/v2'),
    endpoint_path text NOT NULL CHECK (endpoint_path = '/stocks/{symbol}/quotes/latest'),
    request_method text NOT NULL CHECK (request_method = 'GET'),
    feed text NOT NULL CHECK (feed IN ('iex','sip','delayed_sip')),
    ticker text NOT NULL CHECK (ticker = upper(btrim(ticker)) AND ticker ~ '^[A-Z.]{1,10}$'),
    currency text NOT NULL DEFAULT 'USD' CHECK (currency = 'USD'),
    result_status text NOT NULL CHECK (result_status IN ('succeeded','failed')),
    http_status integer,
    quote_timestamp timestamptz,
    quote_age_seconds numeric(18,3),
    bid_price numeric(24,8),
    ask_price numeric(24,8),
    bid_size integer,
    ask_size integer,
    spread_percent numeric(18,8),
    response_fingerprint_sha256 text NOT NULL CHECK (response_fingerprint_sha256 ~ '^[0-9a-f]{64}$'),
    safe_summary text NOT NULL CHECK (length(btrim(safe_summary)) >= 40),
    created_by text NOT NULL DEFAULT current_user,
    CHECK (
        (result_status='succeeded'
         AND http_status BETWEEN 200 AND 299
         AND quote_timestamp IS NOT NULL
         AND quote_age_seconds IS NOT NULL AND quote_age_seconds >= 0
         AND bid_price IS NOT NULL AND bid_price > 0
         AND ask_price IS NOT NULL AND ask_price > 0
         AND ask_price >= bid_price
         AND spread_percent IS NOT NULL AND spread_percent >= 0)
        OR result_status='failed'
    )
);

CREATE INDEX idx_market_data_quote_receipts_symbol_time
    ON nexus.market_data_quote_receipts(ticker, received_at DESC);

CREATE TRIGGER prevent_market_data_quote_receipt_mutation
BEFORE UPDATE OR DELETE OR TRUNCATE ON nexus.market_data_quote_receipts
FOR EACH STATEMENT EXECUTE FUNCTION nexus.prevent_mutation();

ALTER TABLE nexus.paper_order_proposals
    ADD COLUMN market_data_quote_receipt_id uuid REFERENCES nexus.market_data_quote_receipts ON DELETE RESTRICT;

CREATE TABLE nexus.autonomous_paper_preview_decisions (
    autonomous_paper_preview_decision_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    decided_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    market_data_quote_receipt_id uuid REFERENCES nexus.market_data_quote_receipts ON DELETE RESTRICT,
    paper_order_proposal_id uuid REFERENCES nexus.paper_order_proposals ON DELETE RESTRICT,
    decision_status text NOT NULL CHECK (decision_status IN ('previewed','abstained')),
    ticker text NOT NULL CHECK (ticker = upper(btrim(ticker)) AND ticker ~ '^[A-Z.]{1,10}$'),
    requested_notional numeric(24,8) NOT NULL,
    computed_quantity numeric(24,8),
    computed_limit_price numeric(24,8),
    max_quote_age_seconds integer NOT NULL CHECK (max_quote_age_seconds BETWEEN 1 AND 900),
    max_spread_percent numeric(18,8) NOT NULL CHECK (max_spread_percent > 0 AND max_spread_percent <= 10),
    blockers text[] NOT NULL DEFAULT ARRAY[]::text[],
    client_order_id text,
    safe_summary text NOT NULL CHECK (length(btrim(safe_summary)) >= 40),
    created_by text NOT NULL DEFAULT current_user,
    CHECK (
        (decision_status='previewed'
         AND paper_order_proposal_id IS NOT NULL
         AND market_data_quote_receipt_id IS NOT NULL
         AND computed_quantity > 0
         AND computed_limit_price > 0
         AND coalesce(array_length(blockers,1),0)=0
         AND client_order_id IS NOT NULL)
        OR
        (decision_status='abstained'
         AND paper_order_proposal_id IS NULL
         AND coalesce(array_length(blockers,1),0)>0)
    )
);

CREATE INDEX idx_autonomous_paper_preview_decisions_time
    ON nexus.autonomous_paper_preview_decisions(decided_at DESC);

CREATE TRIGGER prevent_autonomous_paper_preview_decision_mutation
BEFORE UPDATE OR DELETE OR TRUNCATE ON nexus.autonomous_paper_preview_decisions
FOR EACH STATEMENT EXECUTE FUNCTION nexus.prevent_mutation();

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
       proposal.quantity,proposal.limit_price,proposal.market_data_quote_receipt_id
FROM nexus.paper_order_proposals proposal
JOIN nexus.paper_order_policies policy USING(paper_order_policy_id)
JOIN nexus.instruments instrument USING(instrument_id)
LEFT JOIN nexus.paper_order_submissions submission USING(paper_order_proposal_id);

CREATE VIEW nexus.v_latest_market_data_quote_receipts AS
SELECT DISTINCT ON (receipt.ticker)
       receipt.market_data_quote_receipt_id,receipt.received_at,receipt.provider,
       receipt.broker_environment,receipt.feed,receipt.ticker,receipt.currency,
       receipt.result_status,receipt.http_status,receipt.quote_timestamp,
       receipt.quote_age_seconds,receipt.bid_price,receipt.ask_price,
       receipt.bid_size,receipt.ask_size,receipt.spread_percent,receipt.safe_summary
FROM nexus.market_data_quote_receipts receipt
ORDER BY receipt.ticker, receipt.received_at DESC;

CREATE VIEW nexus.v_autonomous_paper_preview_decisions AS
SELECT decision.autonomous_paper_preview_decision_id,decision.decided_at,
       decision.decision_status,decision.ticker,decision.requested_notional,
       decision.computed_quantity,decision.computed_limit_price,
       decision.max_quote_age_seconds,decision.max_spread_percent,
       decision.blockers,decision.client_order_id,decision.safe_summary,
       quote.feed,quote.quote_timestamp,quote.quote_age_seconds,quote.bid_price,
       quote.ask_price,quote.spread_percent,
       proposal.proposal_status,proposal.paper_order_submission_id
FROM nexus.autonomous_paper_preview_decisions decision
LEFT JOIN nexus.v_latest_market_data_quote_receipts quote
    ON quote.market_data_quote_receipt_id=decision.market_data_quote_receipt_id
LEFT JOIN nexus.v_paper_order_proposals proposal
    ON proposal.paper_order_proposal_id=decision.paper_order_proposal_id;

CREATE FUNCTION nexus.record_alpaca_market_data_quote_receipt(
    target_ticker text,
    target_feed text,
    target_result_status text,
    target_http_status integer,
    target_quote_timestamp timestamptz,
    target_bid_price numeric,
    target_ask_price numeric,
    target_bid_size integer,
    target_ask_size integer,
    target_response_fingerprint_sha256 text,
    target_safe_summary text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
    receipt_id uuid := gen_random_uuid();
    ticker_normalized text := upper(btrim(target_ticker));
    age_seconds numeric;
    spread numeric;
BEGIN
    IF target_feed NOT IN ('iex','sip','delayed_sip') THEN
        RAISE EXCEPTION 'Unsupported Alpaca market data feed for Nexus quote gating';
    END IF;
    IF target_result_status NOT IN ('succeeded','failed') THEN
        RAISE EXCEPTION 'Market data quote result status must be succeeded or failed';
    END IF;
    IF ticker_normalized !~ '^[A-Z.]{1,10}$' THEN
        RAISE EXCEPTION 'Ticker is not in the allowed symbol shape';
    END IF;
    IF target_response_fingerprint_sha256 !~ '^[0-9a-f]{64}$' THEN
        RAISE EXCEPTION 'Response fingerprint must be a lowercase SHA-256 hex digest';
    END IF;
    IF length(btrim(target_safe_summary)) < 40 THEN
        RAISE EXCEPTION 'Market data quote summary must contain at least 40 characters';
    END IF;

    IF target_result_status='succeeded' THEN
        IF target_http_status < 200 OR target_http_status > 299 THEN
            RAISE EXCEPTION 'Successful market data quote must have a 2xx HTTP status';
        END IF;
        IF target_quote_timestamp IS NULL OR target_bid_price IS NULL OR target_ask_price IS NULL
           OR target_bid_price <= 0 OR target_ask_price <= 0 OR target_ask_price < target_bid_price THEN
            RAISE EXCEPTION 'Successful market data quote requires positive bid/ask prices';
        END IF;
        age_seconds := greatest(0, extract(epoch from (clock_timestamp() - target_quote_timestamp)));
        spread := ((target_ask_price - target_bid_price) / target_ask_price) * 100;
    END IF;

    INSERT INTO nexus.market_data_quote_receipts(
        market_data_quote_receipt_id,provider,broker_environment,api_base_url,
        endpoint_path,request_method,feed,ticker,currency,result_status,http_status,
        quote_timestamp,quote_age_seconds,bid_price,ask_price,bid_size,ask_size,
        spread_percent,response_fingerprint_sha256,safe_summary,created_by
    ) VALUES (
        receipt_id,'alpaca','alpaca_paper','https://data.alpaca.markets/v2',
        '/stocks/{symbol}/quotes/latest','GET',target_feed,ticker_normalized,'USD',
        target_result_status,target_http_status,target_quote_timestamp,age_seconds,
        target_bid_price,target_ask_price,target_bid_size,target_ask_size,spread,
        target_response_fingerprint_sha256,target_safe_summary,session_user
    );
    RETURN receipt_id;
END $$;

CREATE FUNCTION nexus.evaluate_quote_gated_limit_paper_preview(
    target_market_data_quote_receipt_id uuid,
    target_notional numeric,
    target_max_quote_age_seconds integer,
    target_max_spread_percent numeric,
    target_client_order_id text,
    target_approval_fingerprint_sha256 text,
    target_rationale text
) RETURNS TABLE(
    autonomous_paper_preview_decision_id uuid,
    decision_status text,
    blockers text[],
    paper_order_proposal_id uuid,
    client_order_id text,
    quantity numeric,
    limit_price numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
    policy nexus.paper_order_policies%ROWTYPE;
    quote nexus.market_data_quote_receipts%ROWTYPE;
    instrument_row nexus.instruments%ROWTYPE;
    blocker_list text[] := ARRAY[]::text[];
    decision_id uuid := gen_random_uuid();
    proposal_id uuid;
    qty numeric;
    limit_px numeric;
    summary text;
BEGIN
    SELECT * INTO STRICT quote
    FROM nexus.market_data_quote_receipts
    WHERE market_data_quote_receipt_id=target_market_data_quote_receipt_id;

    SELECT * INTO STRICT policy
    FROM nexus.paper_order_policies
    WHERE policy_code='alpaca_paper_approval_gated_limit_buy_v1';

    IF policy.policy_status<>'active' OR policy.live_trading_enabled
       OR policy.allowed_side<>'buy' OR policy.allowed_order_type<>'limit'
       OR policy.allowed_time_in_force<>'day' THEN
        blocker_list := array_append(blocker_list,'policy_not_limit_paper_buy_day');
    END IF;
    IF target_notional IS NULL OR target_notional <= 0 OR target_notional > policy.max_order_notional THEN
        blocker_list := array_append(blocker_list,'notional_outside_policy_limit');
    END IF;
    IF target_max_quote_age_seconds IS NULL OR target_max_quote_age_seconds < 1 OR target_max_quote_age_seconds > 900 THEN
        blocker_list := array_append(blocker_list,'invalid_quote_age_limit');
    END IF;
    IF target_max_spread_percent IS NULL OR target_max_spread_percent <= 0 OR target_max_spread_percent > 10 THEN
        blocker_list := array_append(blocker_list,'invalid_spread_limit');
    END IF;
    IF target_approval_fingerprint_sha256 !~ '^[0-9a-f]{64}$' THEN
        blocker_list := array_append(blocker_list,'invalid_approval_fingerprint');
    END IF;
    IF length(btrim(target_rationale)) < 40 THEN
        blocker_list := array_append(blocker_list,'rationale_too_short');
    END IF;
    IF quote.result_status<>'succeeded' THEN
        blocker_list := array_append(blocker_list,'quote_not_succeeded');
    END IF;
    IF quote.feed='delayed_sip' THEN
        blocker_list := array_append(blocker_list,'quote_feed_is_delayed');
    END IF;
    IF quote.quote_age_seconds IS NULL OR quote.quote_age_seconds > target_max_quote_age_seconds THEN
        blocker_list := array_append(blocker_list,'quote_too_stale');
    END IF;
    IF quote.spread_percent IS NULL OR quote.spread_percent > target_max_spread_percent THEN
        blocker_list := array_append(blocker_list,'quote_spread_too_wide');
    END IF;

    SELECT * INTO instrument_row
    FROM nexus.instruments
    WHERE ticker=quote.ticker;
    IF instrument_row.instrument_id IS NULL THEN
        blocker_list := array_append(blocker_list,'instrument_not_registered');
    ELSIF instrument_row.instrument_type NOT IN ('equity','etf') THEN
        blocker_list := array_append(blocker_list,'instrument_type_not_supported');
    ELSIF policy.requires_current_allowlist AND NOT EXISTS (
        SELECT 1
        FROM nexus.v_shadow_instrument_allowlist allowlist
        WHERE allowlist.experiment_code='alpaca_paper_shadow_v1'
          AND allowlist.instrument_id=instrument_row.instrument_id
          AND allowlist.authorization_state='allowed'
    ) THEN
        blocker_list := array_append(blocker_list,'instrument_not_allowlisted');
    END IF;

    IF coalesce(array_length(blocker_list,1),0)=0 THEN
        limit_px := quote.ask_price;
        qty := floor((target_notional / limit_px) * 1000000) / 1000000;
        IF qty IS NULL OR qty <= 0 THEN
            blocker_list := array_append(blocker_list,'computed_quantity_rounded_to_zero');
        ELSIF qty * limit_px > policy.max_order_notional THEN
            blocker_list := array_append(blocker_list,'computed_exposure_above_policy_limit');
        END IF;
    END IF;

    IF coalesce(array_length(blocker_list,1),0)=0 THEN
        proposal_id := gen_random_uuid();
        INSERT INTO nexus.paper_order_proposals(
            paper_order_proposal_id,paper_order_policy_id,instrument_id,
            side,order_type,time_in_force,extended_hours,notional,quantity,limit_price,
            client_order_id,approval_fingerprint_sha256,proposal_status,rationale,
            market_data_quote_receipt_id,created_by
        ) VALUES (
            proposal_id,policy.paper_order_policy_id,instrument_row.instrument_id,
            'buy','limit','day',false,target_notional,qty,limit_px,
            target_client_order_id,target_approval_fingerprint_sha256,'previewed',
            target_rationale,target_market_data_quote_receipt_id,session_user
        );
        summary := 'Autonomous quote-gated preview created; no Alpaca order endpoint was called and human approval is still required.';
        INSERT INTO nexus.autonomous_paper_preview_decisions(
            autonomous_paper_preview_decision_id,market_data_quote_receipt_id,
            paper_order_proposal_id,decision_status,ticker,requested_notional,
            computed_quantity,computed_limit_price,max_quote_age_seconds,
            max_spread_percent,blockers,client_order_id,safe_summary,created_by
        ) VALUES (
            decision_id,target_market_data_quote_receipt_id,proposal_id,'previewed',
            quote.ticker,target_notional,qty,limit_px,target_max_quote_age_seconds,
            target_max_spread_percent,ARRAY[]::text[],target_client_order_id,summary,session_user
        );
    ELSE
        summary := 'Autonomous quote-gated preview abstained; no Paper order preview or broker request was created.';
        INSERT INTO nexus.autonomous_paper_preview_decisions(
            autonomous_paper_preview_decision_id,market_data_quote_receipt_id,
            decision_status,ticker,requested_notional,computed_quantity,
            computed_limit_price,max_quote_age_seconds,max_spread_percent,
            blockers,client_order_id,safe_summary,created_by
        ) VALUES (
            decision_id,target_market_data_quote_receipt_id,'abstained',quote.ticker,
            target_notional,qty,limit_px,target_max_quote_age_seconds,
            target_max_spread_percent,blocker_list,target_client_order_id,summary,session_user
        );
    END IF;

    RETURN QUERY
    SELECT decision_id,
           CASE WHEN proposal_id IS NULL THEN 'abstained' ELSE 'previewed' END,
           blocker_list,proposal_id,target_client_order_id,qty,limit_px;
END $$;

REVOKE ALL ON nexus.market_data_quote_receipts,nexus.autonomous_paper_preview_decisions FROM PUBLIC;
REVOKE ALL ON FUNCTION nexus.record_alpaca_market_data_quote_receipt(text,text,text,integer,timestamptz,numeric,numeric,integer,integer,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION nexus.evaluate_quote_gated_limit_paper_preview(uuid,numeric,integer,numeric,text,text,text) FROM PUBLIC;

GRANT SELECT ON nexus.v_latest_market_data_quote_receipts,nexus.v_autonomous_paper_preview_decisions
    TO nexus_broker_monitor,nexus_shadow_runner;
GRANT EXECUTE ON FUNCTION nexus.record_alpaca_market_data_quote_receipt(text,text,text,integer,timestamptz,numeric,numeric,integer,integer,text,text),
    nexus.evaluate_quote_gated_limit_paper_preview(uuid,numeric,integer,numeric,text,text,text)
    TO nexus_broker_monitor;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema='nexus'
          AND table_name='autonomous_paper_preview_decisions'
    ) THEN
        RAISE EXCEPTION 'Autonomous quote-gated preview ledger was not installed';
    END IF;
END $$;

COMMENT ON TABLE nexus.market_data_quote_receipts IS
    'Append-only sanitized Alpaca market-data quote receipts used for quote-gated paper previews. No credentials or raw broker response bodies are stored.';
COMMENT ON TABLE nexus.autonomous_paper_preview_decisions IS
    'Append-only audit of autonomous paper-preview decisions. Abstentions are recorded as first-class safety outcomes.';
COMMENT ON FUNCTION nexus.record_alpaca_market_data_quote_receipt(text,text,text,integer,timestamptz,numeric,numeric,integer,integer,text,text) IS
    'Records a sanitized Alpaca latest-quote receipt for a ticker. It does not call Alpaca and stores no credentials.';
COMMENT ON FUNCTION nexus.evaluate_quote_gated_limit_paper_preview(uuid,numeric,integer,numeric,text,text,text) IS
    'Evaluates a sanitized quote against autonomy gates and records either an abstention or a limit Paper preview. It never submits an Alpaca order.';

COMMIT;
