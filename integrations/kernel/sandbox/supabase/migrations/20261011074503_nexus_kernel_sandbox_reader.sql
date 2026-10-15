-- Sandbox-only, additive reader. No business data or existing authority changes.
-- Generated with Supabase CLI 2.120.0; apply through the scoped migration tool.
SET LOCAL lock_timeout = '2s';
SET LOCAL statement_timeout = '15s';

DO $guard$
BEGIN
  IF (SELECT count(*) FROM nexus_sandbox.environment_control) <> 1
     OR NOT EXISTS (
       SELECT 1 FROM nexus_sandbox.environment_control
       WHERE environment_name = 'nexus_supabase_sandbox'
         AND authority_class = 'SANDBOX' AND canonical_status = 'NON_CANONICAL'
         AND trade_authority IS FALSE AND automatic_promotion IS FALSE
     )
     OR to_regnamespace('nexus_live_trading') IS NOT NULL
     OR to_regnamespace('nexus_ct_live_command') IS NOT NULL THEN
    RAISE EXCEPTION 'sandbox reader installation requires the isolated non-canonical sandbox';
  END IF;
  IF to_regrole('nexus_kernel_sandbox_ro') IS NOT NULL
     OR to_regprocedure('nexus_sandbox.kernel_readiness()') IS NOT NULL THEN
    RAISE EXCEPTION 'reader already exists; inspect drift instead of replacing it';
  END IF;
  IF (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'nexus_sandbox' AND c.relkind = 'r' AND c.relrowsecurity
        AND c.relname IN ('environment_control', 'federated_control_status',
          'federated_sync_contract', 'federated_lane_registry',
          'federated_lane_state', 'federated_authority_matrix',
          'federated_resume_checkpoint')) <> 7 THEN
    RAISE EXCEPTION 'all seven existing reader tables must retain RLS';
  END IF;
END;
$guard$;

CREATE ROLE nexus_kernel_sandbox_ro NOLOGIN NOINHERIT NOSUPERUSER
  NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
GRANT nexus_kernel_sandbox_ro TO postgres WITH INHERIT FALSE, SET TRUE;
GRANT USAGE ON SCHEMA nexus_sandbox TO nexus_kernel_sandbox_ro;

GRANT SELECT (environment_name, authority_class, canonical_status,
  trade_authority, automatic_promotion)
  ON nexus_sandbox.environment_control TO nexus_kernel_sandbox_ro;
GRANT SELECT (control_id, projection_state, expected_lane_count,
  populated_lane_count, checkpoint_count, remote_resume_safe,
  canonical_write_authority, trade_authority, automatic_promotion,
  human_authorization_required, observed_at)
  ON nexus_sandbox.federated_control_status TO nexus_kernel_sandbox_ro;
GRANT SELECT (contract_id, contract_version, contract_state, source_access_mode,
  verification_required, lineage_required, writeback_to_canonical,
  canonical_write_authority, trade_authority, automatic_promotion,
  human_authorization_required)
  ON nexus_sandbox.federated_sync_contract TO nexus_kernel_sandbox_ro;
GRANT SELECT (lane_id, canonical_write_authority, trade_authority, automatic_promotion)
  ON nexus_sandbox.federated_lane_registry TO nexus_kernel_sandbox_ro;
GRANT SELECT (lane_id, automatic_promotion)
  ON nexus_sandbox.federated_lane_state TO nexus_kernel_sandbox_ro;
GRANT SELECT (lane_id, canonical_write_authority, trade_authority,
  automatic_promotion, human_authorization_required)
  ON nexus_sandbox.federated_authority_matrix TO nexus_kernel_sandbox_ro;
GRANT SELECT (lane_id, sync_status, canonical_write_authority, trade_authority,
  automatic_promotion, human_authorization_required)
  ON nexus_sandbox.federated_resume_checkpoint TO nexus_kernel_sandbox_ro;

CREATE POLICY kernel_reader_select ON nexus_sandbox.environment_control
  FOR SELECT TO nexus_kernel_sandbox_ro
  USING (environment_name = 'nexus_supabase_sandbox');
CREATE POLICY kernel_reader_select ON nexus_sandbox.federated_control_status
  FOR SELECT TO nexus_kernel_sandbox_ro USING (control_id = 'FED-CONTROL-001');
CREATE POLICY kernel_reader_select ON nexus_sandbox.federated_sync_contract
  FOR SELECT TO nexus_kernel_sandbox_ro USING (contract_id = 'FED-SYNC-CONTRACT-001');
CREATE POLICY kernel_reader_select ON nexus_sandbox.federated_lane_registry
  FOR SELECT TO nexus_kernel_sandbox_ro USING (true);
CREATE POLICY kernel_reader_select ON nexus_sandbox.federated_lane_state
  FOR SELECT TO nexus_kernel_sandbox_ro USING (true);
CREATE POLICY kernel_reader_select ON nexus_sandbox.federated_authority_matrix
  FOR SELECT TO nexus_kernel_sandbox_ro USING (true);
CREATE POLICY kernel_reader_select ON nexus_sandbox.federated_resume_checkpoint
  FOR SELECT TO nexus_kernel_sandbox_ro USING (true);

CREATE FUNCTION nexus_sandbox.kernel_readiness()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
SET row_security = on
AS $reader$
DECLARE
  env record;
  ctl record;
  contract record;
  v_lane_count bigint;
  v_state_count bigint;
  v_authority_count bigint;
  v_checkpoint_count bigint;
  v_unsafe_lanes bigint;
  v_unsafe_states bigint;
  v_unsafe_authorities bigint;
  v_unsafe_checkpoints bigint;
  v_blocked_checkpoints bigint;
  blockers text[] := ARRAY['KERNEL_BINDINGS_UNVERIFIED'];
BEGIN
  IF current_user <> 'nexus_kernel_sandbox_ro' THEN
    RAISE SQLSTATE '42501' USING MESSAGE = 'explicit sandbox reader role required';
  END IF;
  IF current_setting('transaction_read_only') <> 'on' THEN
    RAISE SQLSTATE '25006' USING MESSAGE = 'sandbox reader requires a read-only transaction';
  END IF;

  SELECT environment_name, authority_class, canonical_status,
         trade_authority, automatic_promotion
    INTO STRICT env FROM nexus_sandbox.environment_control
    WHERE environment_name = 'nexus_supabase_sandbox';
  SELECT control_id, projection_state, expected_lane_count, populated_lane_count,
         checkpoint_count, remote_resume_safe, canonical_write_authority,
         trade_authority, automatic_promotion, human_authorization_required, observed_at
    INTO STRICT ctl FROM nexus_sandbox.federated_control_status
    WHERE control_id = 'FED-CONTROL-001';
  SELECT contract_id, contract_version, contract_state, source_access_mode,
         verification_required, lineage_required, writeback_to_canonical,
         canonical_write_authority, trade_authority, automatic_promotion,
         human_authorization_required
    INTO STRICT contract FROM nexus_sandbox.federated_sync_contract
    WHERE contract_id = 'FED-SYNC-CONTRACT-001';

  IF env.authority_class IS DISTINCT FROM 'SANDBOX'
     OR env.canonical_status IS DISTINCT FROM 'NON_CANONICAL'
     OR env.trade_authority IS DISTINCT FROM false
     OR env.automatic_promotion IS DISTINCT FROM false THEN
    RAISE SQLSTATE '23514' USING MESSAGE = 'sandbox environment boundary changed';
  END IF;

  SELECT count(lane_id), count(lane_id) FILTER (WHERE
      canonical_write_authority IS DISTINCT FROM false
      OR trade_authority IS DISTINCT FROM false OR automatic_promotion IS DISTINCT FROM false)
    INTO v_lane_count, v_unsafe_lanes FROM nexus_sandbox.federated_lane_registry;
  SELECT count(lane_id), count(lane_id) FILTER (WHERE automatic_promotion IS DISTINCT FROM false)
    INTO v_state_count, v_unsafe_states FROM nexus_sandbox.federated_lane_state;
  SELECT count(lane_id), count(lane_id) FILTER (WHERE
      canonical_write_authority IS DISTINCT FROM false
      OR trade_authority IS DISTINCT FROM false OR automatic_promotion IS DISTINCT FROM false
      OR human_authorization_required IS DISTINCT FROM true)
    INTO v_authority_count, v_unsafe_authorities FROM nexus_sandbox.federated_authority_matrix;
  SELECT count(lane_id), count(lane_id) FILTER (WHERE
      canonical_write_authority IS DISTINCT FROM false
      OR trade_authority IS DISTINCT FROM false OR automatic_promotion IS DISTINCT FROM false
      OR human_authorization_required IS DISTINCT FROM true),
    count(lane_id) FILTER (WHERE sync_status IS DISTINCT FROM 'VERIFIED')
    INTO v_checkpoint_count, v_unsafe_checkpoints, v_blocked_checkpoints
    FROM nexus_sandbox.federated_resume_checkpoint;

  IF contract.contract_state = 'HOLD' THEN
    blockers := array_append(blockers, 'FEDERATION_CONTRACT_HOLD');
  END IF;
  IF ctl.remote_resume_safe IS DISTINCT FROM true THEN
    blockers := array_append(blockers, 'REMOTE_RESUME_BLOCKED');
  END IF;
  IF ctl.expected_lane_count IS NULL OR ctl.expected_lane_count <= 0
     OR v_lane_count <> ctl.expected_lane_count OR v_state_count <> ctl.expected_lane_count
     OR v_authority_count <> ctl.expected_lane_count OR v_checkpoint_count <> ctl.expected_lane_count THEN
    blockers := array_append(blockers, 'FEDERATION_POPULATION_INCOMPLETE');
  END IF;
  IF ctl.populated_lane_count IS DISTINCT FROM v_lane_count
     OR ctl.checkpoint_count IS DISTINCT FROM v_checkpoint_count THEN
    blockers := array_append(blockers, 'CONTROL_COUNT_MISMATCH');
  END IF;
  IF v_blocked_checkpoints > 0 THEN
    blockers := array_append(blockers, 'CHECKPOINTS_NOT_VERIFIED');
  END IF;
  IF v_unsafe_lanes + v_unsafe_states + v_unsafe_authorities + v_unsafe_checkpoints > 0
     OR ctl.canonical_write_authority IS DISTINCT FROM false
     OR ctl.trade_authority IS DISTINCT FROM false OR ctl.automatic_promotion IS DISTINCT FROM false
     OR ctl.human_authorization_required IS DISTINCT FROM true
     OR contract.writeback_to_canonical IS DISTINCT FROM false
     OR contract.canonical_write_authority IS DISTINCT FROM false
     OR contract.trade_authority IS DISTINCT FROM false OR contract.automatic_promotion IS DISTINCT FROM false
     OR contract.human_authorization_required IS DISTINCT FROM true
     OR contract.verification_required IS DISTINCT FROM true
     OR contract.lineage_required IS DISTINCT FROM true
     OR contract.source_access_mode IS DISTINCT FROM 'READ_ONLY' THEN
    blockers := array_append(blockers, 'SANDBOX_AUTHORITY_DRIFT');
  END IF;

  RETURN jsonb_build_object(
    'reader_version', 1, 'probe_status', 'READ_OK', 'reader_role', current_user,
    'captured_at', transaction_timestamp(), 'read_only', true,
    'kernel_integration_status', 'HOLD', 'kernel_bindings', 'UNVERIFIED',
    'execution_authorized', false, 'production_verified', false,
    'canonical_state_changed', false, 'blockers', to_jsonb(blockers),
    'environment', to_jsonb(env), 'control', to_jsonb(ctl), 'contract', to_jsonb(contract),
    'observed_counts', jsonb_build_object('lanes', v_lane_count, 'states', v_state_count,
      'authorities', v_authority_count, 'checkpoints', v_checkpoint_count),
    'unsafe_metadata_rows', v_unsafe_lanes + v_unsafe_states + v_unsafe_authorities + v_unsafe_checkpoints,
    'unverified_checkpoints', v_blocked_checkpoints
  );
END;
$reader$;

REVOKE ALL ON FUNCTION nexus_sandbox.kernel_readiness() FROM PUBLIC;
-- Supabase default privileges may grant these roles EXECUTE; remove explicitly.
REVOKE ALL ON FUNCTION nexus_sandbox.kernel_readiness()
  FROM anon, authenticated, service_role, authenticator;
GRANT EXECUTE ON FUNCTION nexus_sandbox.kernel_readiness() TO nexus_kernel_sandbox_ro;
