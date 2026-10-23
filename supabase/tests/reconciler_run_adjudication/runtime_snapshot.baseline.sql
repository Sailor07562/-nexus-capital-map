CREATE OR REPLACE FUNCTION nexus_ct_live_command.runtime_snapshot()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'pg_temp'
AS $function$
declare
  authority nexus_live_trading.authority_events%rowtype;
  health nexus_live_trading.v_reconciler_health%rowtype;
  policy nexus_ct_live_command.risk_policy_events%rowtype;
  reconciler_fresh boolean;
  symbol_policy_ready boolean;
  ready boolean;
begin
  select * into authority from nexus_live_trading.v_current_authority limit 1;
  select * into health from nexus_live_trading.v_reconciler_health limit 1;
  policy := nexus_ct_live_command.current_policy();
  reconciler_fresh := health.last_finished_state = 'completed'
    and health.last_finished_at >= clock_timestamp() - interval '3 minutes'
    and coalesce(health.stale_started_run_count, 0) = 0
    and coalesce(health.unreconciled_claim_count, 0) = 0;
  symbol_policy_ready := nexus_ct_live_command.valid_symbol_set(policy.allowed_symbols);
  ready := authority.authority_state = 'active'
    and authority.execution_enabled is true
    and authority.kill_switch_engaged is false
    and authority.exact_action_time_ticket_required is true
    and authority.automatic_trading_enabled is false
    and policy.policy_state = 'active'
    and symbol_policy_ready
    and reconciler_fresh;
  return jsonb_build_object(
    'ready', ready,
    'authority_state', authority.authority_state,
    'execution_enabled', authority.execution_enabled,
    'kill_switch_engaged', authority.kill_switch_engaged,
    'automatic_trading_enabled', authority.automatic_trading_enabled,
    'operating_mode', authority.operating_mode,
    'last_reconciler_finished_at', health.last_finished_at,
    'last_reconciler_state', health.last_finished_state,
    'stale_started_run_count', coalesce(health.stale_started_run_count, 0),
    'unreconciled_claim_count', coalesce(health.unreconciled_claim_count, 0),
    'reconciler_fresh', reconciler_fresh,
    'policy_state', policy.policy_state,
    'allowed_symbols', coalesce(to_jsonb(policy.allowed_symbols), '[]'::jsonb),
    'symbol_policy_ready', symbol_policy_ready
  );
end;
$function$
