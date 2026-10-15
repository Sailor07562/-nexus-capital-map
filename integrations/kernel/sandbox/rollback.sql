-- Run only against the same verified sandbox. Caller owns the transaction.
-- Rehearse with BEGIN; <this file>; ROLLBACK. No CASCADE or data deletion.
SET LOCAL lock_timeout = '2s';
SET LOCAL statement_timeout = '15s';
DROP FUNCTION nexus_sandbox.kernel_readiness();
DROP POLICY kernel_reader_select ON nexus_sandbox.environment_control;
DROP POLICY kernel_reader_select ON nexus_sandbox.federated_control_status;
DROP POLICY kernel_reader_select ON nexus_sandbox.federated_sync_contract;
DROP POLICY kernel_reader_select ON nexus_sandbox.federated_lane_registry;
DROP POLICY kernel_reader_select ON nexus_sandbox.federated_lane_state;
DROP POLICY kernel_reader_select ON nexus_sandbox.federated_authority_matrix;
DROP POLICY kernel_reader_select ON nexus_sandbox.federated_resume_checkpoint;
REVOKE SELECT (environment_name, authority_class, canonical_status,
  trade_authority, automatic_promotion)
  ON nexus_sandbox.environment_control FROM nexus_kernel_sandbox_ro;
REVOKE SELECT (control_id, projection_state, expected_lane_count,
  populated_lane_count, checkpoint_count, remote_resume_safe,
  canonical_write_authority, trade_authority, automatic_promotion,
  human_authorization_required, observed_at)
  ON nexus_sandbox.federated_control_status FROM nexus_kernel_sandbox_ro;
REVOKE SELECT (contract_id, contract_version, contract_state, source_access_mode,
  verification_required, lineage_required, writeback_to_canonical,
  canonical_write_authority, trade_authority, automatic_promotion,
  human_authorization_required)
  ON nexus_sandbox.federated_sync_contract FROM nexus_kernel_sandbox_ro;
REVOKE SELECT (lane_id, canonical_write_authority, trade_authority, automatic_promotion)
  ON nexus_sandbox.federated_lane_registry FROM nexus_kernel_sandbox_ro;
REVOKE SELECT (lane_id, automatic_promotion)
  ON nexus_sandbox.federated_lane_state FROM nexus_kernel_sandbox_ro;
REVOKE SELECT (lane_id, canonical_write_authority, trade_authority,
  automatic_promotion, human_authorization_required)
  ON nexus_sandbox.federated_authority_matrix FROM nexus_kernel_sandbox_ro;
REVOKE SELECT (lane_id, sync_status, canonical_write_authority, trade_authority,
  automatic_promotion, human_authorization_required)
  ON nexus_sandbox.federated_resume_checkpoint FROM nexus_kernel_sandbox_ro;
REVOKE USAGE ON SCHEMA nexus_sandbox FROM nexus_kernel_sandbox_ro;
REVOKE nexus_kernel_sandbox_ro FROM postgres;
DROP ROLE nexus_kernel_sandbox_ro;
