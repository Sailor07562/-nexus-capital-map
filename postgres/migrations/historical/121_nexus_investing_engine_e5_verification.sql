BEGIN;
SET LOCAL lock_timeout = '5s';

INSERT INTO nexus.investing_engine_registrations(
    investing_engine_registration_id,engine_code,engine_name,semantic_version,
    registration_revision,registration_state,maturity_level,operating_mode,
    canonical_system,purpose,authority_capabilities,prohibited_capabilities,
    governance_binding_id,verification_basis,effective_at,
    supersedes_registration_id,created_by
) SELECT
    '12100000-0000-4000-8000-000000000001',engine_code,engine_name,
    semantic_version,2,'verified',5,operating_mode,canonical_system,purpose,
    authority_capabilities,prohibited_capabilities,governance_binding_id,
    'Eight rollback-only suites completed successfully against the live migration-120 database: 76 core, 30 lane, 13 capital-management, 27 controlled-intake, 14 shadow-mode, 7 broker-connection, 8 Paper-order, and 15 Investing Engine checks. All fixtures rolled back.',
    clock_timestamp(),investing_engine_registration_id,'nexus_migration_121'
FROM nexus.v_investing_engine_current
WHERE engine_code='nexus_investing_engine'
  AND registration_revision=1
  AND registration_state='verification_pending'
  AND maturity_level=4;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM nexus.investing_engine_registrations
        WHERE investing_engine_registration_id=
              '12100000-0000-4000-8000-000000000001'
    ) THEN
        RAISE EXCEPTION 'Migration 121 requires the E4 migration-120 registration';
    END IF;
END $$;

INSERT INTO nexus.investing_engine_components(
    investing_engine_component_id,investing_engine_registration_id,
    sequence_number,component_code,component_name,component_class,
    relationship_to_engine,implementation_object,operating_state,
    capability_summary,authority_boundary,created_by
)
SELECT
    ('12100000-0000-4000-8001-' || lpad(sequence_number::text,12,'0'))::uuid,
    '12100000-0000-4000-8000-000000000001',sequence_number,
    component_code,component_name,component_class,relationship_to_engine,
    implementation_object,operating_state,capability_summary,authority_boundary,
    'nexus_migration_121'
FROM nexus.investing_engine_components
WHERE investing_engine_registration_id=
      '12000000-0000-4000-8000-000000000001';

INSERT INTO nexus.investing_engine_verification_events(
    investing_engine_verification_event_id,investing_engine_registration_id,
    verification_status,verified_maturity_level,suite_count,check_count,
    verification_basis,verified_at,verified_by
) VALUES (
    '12100000-0000-4000-8002-000000000001',
    '12100000-0000-4000-8000-000000000001','passed',5,8,190,
    'All eight live regression suites passed after migration 120 with rollback-only fixtures. The verified boundary retains zero live-trading authority, zero shadow-order authority, human-only evidence admission, human-reviewed decisions, and exact-confirmation Alpaca Paper execution.',
    clock_timestamp(),'Captain-authorized Codex verification'
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM nexus.v_investing_engine_current
        WHERE engine_code='nexus_investing_engine'
          AND registration_revision=2
          AND registration_state='verified'
          AND maturity_level=5
    ) THEN
        RAISE EXCEPTION 'Nexus Investing Engine was not promoted to E5';
    END IF;
    IF (SELECT component_count FROM nexus.v_investing_engine_status
        WHERE engine_code='nexus_investing_engine') <> 8 THEN
        RAISE EXCEPTION 'E5 successor did not preserve all eight components';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM nexus.investing_engine_verification_events
        WHERE investing_engine_registration_id=
              '12100000-0000-4000-8000-000000000001'
          AND verification_status='passed'
          AND verified_maturity_level=5
          AND suite_count=8
          AND check_count=190
    ) THEN
        RAISE EXCEPTION 'E5 verification receipt is missing';
    END IF;
    IF EXISTS (
        SELECT 1 FROM nexus.v_investing_engine_status
        WHERE engine_code='nexus_investing_engine'
          AND (live_trading_enabled OR any_shadow_order_enabled)
    ) THEN
        RAISE EXCEPTION 'E5 promotion cannot enable live or shadow order submission';
    END IF;
END $$;

COMMIT;
