BEGIN;
SET LOCAL lock_timeout = '5s';

CREATE TABLE nexus.broker_connections (
    broker_connection_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    connection_code text NOT NULL UNIQUE CHECK (btrim(connection_code) <> ''),
    broker_name text NOT NULL CHECK (broker_name = 'Alpaca'),
    broker_environment text NOT NULL CHECK (broker_environment = 'alpaca_paper'),
    api_base_url text NOT NULL CHECK (api_base_url = 'https://paper-api.alpaca.markets/v2'),
    credential_storage_model text NOT NULL CHECK (credential_storage_model = 'windows_current_user_dpapi_outside_project'),
    linked_shadow_experiment_id uuid NOT NULL REFERENCES nexus.shadow_experiments ON DELETE RESTRICT,
    read_account_enabled boolean NOT NULL DEFAULT true CHECK (read_account_enabled),
    read_positions_enabled boolean NOT NULL DEFAULT false CHECK (NOT read_positions_enabled),
    read_orders_enabled boolean NOT NULL DEFAULT false CHECK (NOT read_orders_enabled),
    order_submission_enabled boolean NOT NULL DEFAULT false CHECK (NOT order_submission_enabled),
    live_trading_enabled boolean NOT NULL DEFAULT false CHECK (NOT live_trading_enabled),
    requires_human_order_confirmation boolean NOT NULL DEFAULT true CHECK (requires_human_order_confirmation),
    connection_notes text NOT NULL CHECK (length(btrim(connection_notes)) >= 40),
    created_by text NOT NULL DEFAULT session_user,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER prevent_broker_connection_mutation
BEFORE UPDATE OR DELETE OR TRUNCATE ON nexus.broker_connections
FOR EACH STATEMENT EXECUTE FUNCTION nexus.prevent_mutation();

CREATE TABLE nexus.broker_connection_checks (
    broker_connection_check_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    broker_connection_id uuid NOT NULL REFERENCES nexus.broker_connections ON DELETE RESTRICT,
    checked_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    check_source text NOT NULL CHECK (btrim(check_source) <> ''),
    result_status text NOT NULL CHECK (result_status IN ('succeeded','failed')),
    http_status integer CHECK (http_status BETWEEN 0 AND 599),
    endpoint_path text NOT NULL CHECK (endpoint_path = '/account'),
    request_method text NOT NULL CHECK (request_method = 'GET'),
    external_request_count integer NOT NULL DEFAULT 1 CHECK (external_request_count = 1),
    account_status text,
    currency text,
    trading_blocked boolean,
    transfers_blocked boolean,
    account_blocked boolean,
    paper_cash numeric(24,8),
    paper_buying_power numeric(24,8),
    paper_portfolio_value numeric(24,8),
    response_fingerprint_sha256 text CHECK (
        response_fingerprint_sha256 IS NULL OR response_fingerprint_sha256 ~ '^[0-9a-f]{64}$'
    ),
    safe_summary text NOT NULL CHECK (length(btrim(safe_summary)) >= 40),
    created_by text NOT NULL DEFAULT session_user,
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (
        (result_status='succeeded' AND http_status BETWEEN 200 AND 299
            AND account_status IS NOT NULL AND currency IS NOT NULL
            AND response_fingerprint_sha256 IS NOT NULL)
        OR
        (result_status='failed')
    )
);
CREATE INDEX idx_broker_connection_checks_latest
    ON nexus.broker_connection_checks(broker_connection_id, checked_at DESC);
CREATE TRIGGER prevent_broker_connection_check_mutation
BEFORE UPDATE OR DELETE OR TRUNCATE ON nexus.broker_connection_checks
FOR EACH STATEMENT EXECUTE FUNCTION nexus.prevent_mutation();

CREATE VIEW nexus.v_broker_connection_health AS
SELECT connection.connection_code,
       connection.broker_name,
       connection.broker_environment,
       connection.api_base_url,
       connection.credential_storage_model,
       experiment.experiment_code AS linked_shadow_experiment_code,
       connection.read_account_enabled,
       connection.read_positions_enabled,
       connection.read_orders_enabled,
       connection.order_submission_enabled,
       connection.live_trading_enabled,
       connection.requires_human_order_confirmation,
       latest.checked_at AS latest_checked_at,
       latest.result_status AS latest_result_status,
       latest.http_status AS latest_http_status,
       latest.account_status AS latest_account_status,
       latest.currency AS latest_currency,
       latest.trading_blocked AS latest_trading_blocked,
       latest.transfers_blocked AS latest_transfers_blocked,
       latest.account_blocked AS latest_account_blocked,
       latest.paper_cash,
       latest.paper_buying_power,
       latest.paper_portfolio_value,
       latest.safe_summary AS latest_safe_summary
FROM nexus.broker_connections connection
JOIN nexus.shadow_experiments experiment
  ON experiment.shadow_experiment_id=connection.linked_shadow_experiment_id
LEFT JOIN LATERAL (
    SELECT *
    FROM nexus.broker_connection_checks check_row
    WHERE check_row.broker_connection_id=connection.broker_connection_id
    ORDER BY check_row.checked_at DESC
    LIMIT 1
) latest ON true;

CREATE FUNCTION nexus.record_broker_connection_check(
    target_connection_code text,
    target_result_status text,
    target_http_status integer,
    target_account_status text,
    target_currency text,
    target_trading_blocked boolean,
    target_transfers_blocked boolean,
    target_account_blocked boolean,
    target_paper_cash numeric,
    target_paper_buying_power numeric,
    target_paper_portfolio_value numeric,
    target_response_fingerprint_sha256 text,
    target_safe_summary text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE
    target_connection nexus.broker_connections%ROWTYPE;
    check_id uuid := gen_random_uuid();
BEGIN
    IF target_result_status NOT IN ('succeeded','failed') THEN
        RAISE EXCEPTION 'Broker check result must be succeeded or failed';
    END IF;
    IF length(btrim(target_safe_summary)) < 40 THEN
        RAISE EXCEPTION 'Broker check summary must contain at least 40 characters';
    END IF;
    SELECT * INTO STRICT target_connection
    FROM nexus.broker_connections
    WHERE connection_code=target_connection_code;
    IF target_connection.order_submission_enabled OR target_connection.live_trading_enabled THEN
        RAISE EXCEPTION 'Read-only broker connection cannot be used when order or live trading flags are enabled';
    END IF;

    INSERT INTO nexus.broker_connection_checks(
        broker_connection_check_id,broker_connection_id,check_source,result_status,
        http_status,endpoint_path,request_method,external_request_count,
        account_status,currency,trading_blocked,transfers_blocked,account_blocked,
        paper_cash,paper_buying_power,paper_portfolio_value,response_fingerprint_sha256,
        safe_summary,created_by
    ) VALUES (
        check_id,target_connection.broker_connection_id,'scripts/Test-AlpacaPaperConnection.ps1',
        target_result_status,target_http_status,'/account','GET',1,
        target_account_status,target_currency,target_trading_blocked,target_transfers_blocked,
        target_account_blocked,target_paper_cash,target_paper_buying_power,target_paper_portfolio_value,
        target_response_fingerprint_sha256,target_safe_summary,session_user
    );
    RETURN check_id;
END $$;

REVOKE ALL ON nexus.broker_connections,nexus.broker_connection_checks FROM PUBLIC;
REVOKE ALL ON FUNCTION nexus.record_broker_connection_check(text,text,integer,text,text,boolean,boolean,boolean,numeric,numeric,numeric,text,text) FROM PUBLIC;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='nexus_broker_monitor') THEN
        CREATE ROLE nexus_broker_monitor NOLOGIN;
    END IF;
END $$;

GRANT USAGE ON SCHEMA nexus TO nexus_broker_monitor;
GRANT SELECT ON nexus.v_broker_connection_health TO nexus_broker_monitor,nexus_automation_reader,nexus_shadow_runner,nexus_human_reviewer;
GRANT EXECUTE ON FUNCTION nexus.record_broker_connection_check(text,text,integer,text,text,boolean,boolean,boolean,numeric,numeric,numeric,text,text)
    TO nexus_broker_monitor;

INSERT INTO nexus.broker_connections(
    broker_connection_id,connection_code,broker_name,broker_environment,api_base_url,
    credential_storage_model,linked_shadow_experiment_id,read_account_enabled,
    read_positions_enabled,read_orders_enabled,order_submission_enabled,live_trading_enabled,
    requires_human_order_confirmation,connection_notes,created_by
)
SELECT '11700000-0000-4000-8000-000000000001','alpaca_paper_readonly_v1',
       'Alpaca','alpaca_paper','https://paper-api.alpaca.markets/v2',
       'windows_current_user_dpapi_outside_project',shadow_experiment_id,true,
       false,false,false,false,true,
       'Read-only Alpaca Paper account connection for health verification. Credentials are stored outside the project with Windows current-user protection, and this connection cannot submit orders.',
       'nexus_migration_117'
FROM nexus.shadow_experiments
WHERE experiment_code='alpaca_paper_shadow_v1';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM nexus.broker_connections connection
        JOIN nexus.shadow_experiments experiment
          ON experiment.shadow_experiment_id=connection.linked_shadow_experiment_id
        WHERE connection.connection_code='alpaca_paper_readonly_v1'
          AND experiment.experiment_code='alpaca_paper_shadow_v1'
          AND connection.read_account_enabled
          AND NOT connection.order_submission_enabled
          AND NOT connection.live_trading_enabled
          AND connection.requires_human_order_confirmation
    ) THEN
        RAISE EXCEPTION 'Alpaca Paper read-only connection was not installed with safe boundaries';
    END IF;
END $$;

COMMENT ON TABLE nexus.broker_connections IS 'Read-only external broker connection metadata. No API keys, secrets or OAuth tokens are stored in PostgreSQL.';
COMMENT ON TABLE nexus.broker_connection_checks IS 'Append-only read-only broker health checks. Rows record sanitized account health and never represent orders.';
COMMENT ON FUNCTION nexus.record_broker_connection_check(text,text,integer,text,text,boolean,boolean,boolean,numeric,numeric,numeric,text,text) IS 'Records a sanitized Alpaca Paper /account health check. It cannot submit orders and stores no credentials.';

COMMIT;
