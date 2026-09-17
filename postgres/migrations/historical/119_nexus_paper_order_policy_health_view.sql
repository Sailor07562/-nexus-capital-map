BEGIN;
SET LOCAL lock_timeout = '5s';

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

GRANT SELECT ON nexus.v_paper_order_policy_health
    TO nexus_broker_monitor,nexus_automation_reader,nexus_shadow_runner,nexus_human_reviewer;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM nexus.v_paper_order_policy_health
        WHERE policy_code='alpaca_paper_approval_gated_buy_v1'
          AND endpoint_path='/orders'
          AND request_method='POST'
          AND order_submission_mode='human_approval_gated'
          AND allowed_side='buy'
          AND allowed_order_type='market'
          AND max_order_notional=25
          AND max_daily_submitted_orders=1
          AND NOT live_trading_enabled
    ) THEN
        RAISE EXCEPTION 'Paper order policy health view does not expose the expected safe policy shape';
    END IF;
END $$;

COMMENT ON VIEW nexus.v_paper_order_policy_health IS
    'Read-only Paper order policy health view, including endpoint and method for regression verification.';

COMMIT;
