-- NEXUS-CT-RECONCILER-ADJUDICATION-20261023-001
-- Forward-only timestamped Supabase lineage. BUILD / REVIEW artifact only.
-- No historical events are inserted, updated or removed by this migration.
-- Run as postgres in a short transaction. A replay or baseline drift fails closed.
BEGIN;
SET LOCAL lock_timeout = '2s';
SET LOCAL statement_timeout = '30s';

DO $guard$
BEGIN
  IF current_user <> 'postgres' THEN
    RAISE EXCEPTION USING ERRCODE = '42501',
      MESSAGE = 'ct_adjudication_requires_postgres_migration_owner';
  END IF;
  IF to_regclass('nexus_live_trading.reconciler_run_adjudications') IS NOT NULL THEN
    RAISE EXCEPTION USING ERRCODE = '42710',
      MESSAGE = 'ct_adjudication_already_installed_review_migration_ledger';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_class c,
      LATERAL aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) a
    WHERE c.oid = 'nexus_live_trading.v_reconciler_health'::regclass
      AND (c.relowner <> 'postgres'::regrole OR a.grantee <> c.relowner)
  ) THEN
    RAISE EXCEPTION USING ERRCODE = '55000',
      MESSAGE = 'ct_adjudication_health_reader_acl_requires_review';
  END IF;
  IF pg_get_viewdef('nexus_live_trading.v_reconciler_health'::regclass, true)
     IS DISTINCT FROM $baseline$ SELECT ( SELECT max(d.dispatched_at) AS max
           FROM nexus_live_trading.reconciler_dispatch_events d) AS last_dispatch_at,
    ( SELECT max(r.occurred_at) AS max
           FROM nexus_live_trading.reconciler_run_events r
          WHERE r.event_type = 'started'::text) AS last_started_at,
    ( SELECT max(r.occurred_at) AS max
           FROM nexus_live_trading.reconciler_run_events r
          WHERE r.event_type = 'finished'::text) AS last_finished_at,
    ( SELECT r.run_state
           FROM nexus_live_trading.reconciler_run_events r
          WHERE r.event_type = 'finished'::text
          ORDER BY r.occurred_at DESC, r.recorded_at DESC, r.reconciler_run_event_id DESC
         LIMIT 1) AS last_finished_state,
    ( SELECT count(*)::integer AS count
           FROM nexus_live_trading.reconciler_run_events s
          WHERE s.event_type = 'started'::text AND s.occurred_at < (statement_timestamp() - '00:02:00'::interval) AND NOT (EXISTS ( SELECT 1
                   FROM nexus_live_trading.reconciler_run_events f
                  WHERE f.run_id = s.run_id AND f.event_type = 'finished'::text))) AS stale_started_run_count,
    ( SELECT count(*)::integer AS count
           FROM nexus_live_trading.trade_authorizations a
          WHERE a.authorization_kind = 'exact_action_time_ticket'::text AND (EXISTS ( SELECT 1
                   FROM nexus_live_trading.trade_events c
                  WHERE c.operation_id = a.operation_id AND c.event_type = 'submission_claimed'::text)) AND NOT (EXISTS ( SELECT 1
                   FROM nexus_live_trading.reconciliation_receipts rr
                  WHERE rr.operation_id = a.operation_id))) AS unreconciled_claim_count,
    ( SELECT count(*)::integer AS count
           FROM nexus_live_trading.reconciler_alert_events a
          WHERE a.observed_at >= (statement_timestamp() - '24:00:00'::interval)) AS critical_alert_count_24h;$baseline$ THEN
    RAISE EXCEPTION USING ERRCODE = '55000',
      MESSAGE = 'ct_adjudication_health_view_baseline_mismatch';
  END IF;
END;
$guard$;

CREATE TABLE nexus_live_trading.reconciler_run_adjudications (
  adjudication_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  run_id uuid NOT NULL UNIQUE,
  started_event_type text GENERATED ALWAYS AS ('started'::text) STORED NOT NULL,
  disposition text NOT NULL CHECK (disposition = 'abandoned'),
  reason text NOT NULL CHECK (
    reason = btrim(reason) AND length(reason) BETWEEN 16 AND 2048
  ),
  evidence jsonb NOT NULL CHECK (
    (jsonb_typeof(evidence) = 'object'
      AND octet_length(evidence::text) <= 16384
      AND jsonb_typeof(evidence -> 'reference') = 'string'
      AND length(btrim(evidence ->> 'reference')) BETWEEN 8 AND 512) IS TRUE
  ),
  -- Claimed human/operator identity; recorded_by is the authenticated database identity.
  adjudicated_by text NOT NULL CHECK (
    adjudicated_by ~ '^[A-Za-z0-9][A-Za-z0-9_.:@/-]{2,127}$'
  ),
  started_at timestamptz NOT NULL,
  adjudicated_at timestamptz NOT NULL,
  recorded_at timestamptz NOT NULL,
  recorded_by name NOT NULL,
  CONSTRAINT reconciler_run_adjudications_started_fk
    FOREIGN KEY (run_id, started_event_type)
    REFERENCES nexus_live_trading.reconciler_run_events (run_id, event_type)
    ON UPDATE NO ACTION ON DELETE NO ACTION NOT DEFERRABLE,
  CONSTRAINT reconciler_run_adjudications_stale_check
    CHECK (started_at < adjudicated_at - interval '2 minutes'),
  CONSTRAINT reconciler_run_adjudications_recorded_check
    CHECK (recorded_at >= adjudicated_at)
);

ALTER TABLE nexus_live_trading.reconciler_run_adjudications ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE nexus_live_trading.reconciler_run_adjudications
  FROM PUBLIC, anon, authenticated, service_role;

CREATE FUNCTION nexus_live_trading.validate_reconciler_run_adjudication()
RETURNS trigger
LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path = pg_catalog
AS $function$
DECLARE
  start_time timestamptz;
BEGIN
  -- An old transaction snapshot must never miss an already committed finish.
  IF current_setting('transaction_isolation') <> 'read committed' THEN
    RAISE EXCEPTION USING ERRCODE = '25001',
      MESSAGE = 'reconciler_adjudication_requires_read_committed';
  END IF;

  -- Existing event writers take ROW EXCLUSIVE on INSERT. NOWAIT rejects an
  -- active writer; subsequent writers wait until this short transaction ends.
  -- Validation SELECTs are deliberately after this lock in a VOLATILE function.
  LOCK TABLE nexus_live_trading.reconciler_run_events
    IN SHARE ROW EXCLUSIVE MODE NOWAIT;

  SELECT occurred_at INTO start_time
  FROM nexus_live_trading.reconciler_run_events
  WHERE run_id = NEW.run_id AND event_type = 'started';
  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'reconciler_adjudication_started_event_required';
  END IF;
  IF EXISTS (
    SELECT 1 FROM nexus_live_trading.reconciler_run_events
    WHERE run_id = NEW.run_id AND event_type = 'finished'
  ) THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'reconciler_adjudication_finished_run_rejected';
  END IF;

  -- Use the statement boundary, matching the health view's governed cutoff.
  -- A long-running statement may reject conservatively; it cannot admit early.
  NEW.adjudicated_at := statement_timestamp();
  IF NOT (start_time < NEW.adjudicated_at - interval '2 minutes') THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'reconciler_adjudication_run_not_stale';
  END IF;
  IF EXISTS (
    SELECT 1 FROM nexus_live_trading.reconciler_run_adjudications
    WHERE run_id = NEW.run_id
  ) THEN
    RAISE EXCEPTION USING ERRCODE = '23505',
      MESSAGE = 'reconciler_adjudication_duplicate';
  END IF;

  NEW.adjudication_id := gen_random_uuid();
  NEW.started_at := start_time;
  NEW.recorded_at := clock_timestamp();
  NEW.recorded_by := session_user;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION nexus_live_trading.validate_reconciler_run_adjudication()
  FROM PUBLIC, anon, authenticated, service_role;

CREATE TRIGGER reconciler_run_adjudications_validate
BEFORE INSERT ON nexus_live_trading.reconciler_run_adjudications
FOR EACH ROW EXECUTE FUNCTION nexus_live_trading.validate_reconciler_run_adjudication();

CREATE TRIGGER reconciler_run_adjudications_append_only
BEFORE UPDATE OR DELETE OR TRUNCATE ON nexus_live_trading.reconciler_run_adjudications
FOR EACH STATEMENT EXECUTE FUNCTION nexus_live_trading.reject_append_only_mutation();

CREATE FUNCTION nexus_live_trading.adjudicate_reconciler_run(
  target_run_id uuid,
  target_disposition text,
  target_reason text,
  target_evidence jsonb,
  target_adjudicated_by text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path = pg_catalog
AS $function$
DECLARE
  result_id uuid;
BEGIN
  INSERT INTO nexus_live_trading.reconciler_run_adjudications
    (run_id, disposition, reason, evidence, adjudicated_by)
  VALUES
    (target_run_id, target_disposition, target_reason, target_evidence, target_adjudicated_by)
  RETURNING adjudication_id INTO result_id;
  RETURN result_id;
END;
$function$;

REVOKE ALL ON FUNCTION nexus_live_trading.adjudicate_reconciler_run(uuid, text, text, jsonb, text)
  FROM PUBLIC, anon, authenticated, service_role;

COMMENT ON TABLE nexus_live_trading.reconciler_run_adjudications IS
  'Append-only administrative disposition of a historical unfinished run. Does not establish runtime health, broker freshness, trading authority or order approval.';
COMMENT ON FUNCTION nexus_live_trading.adjudicate_reconciler_run(uuid, text, text, jsonb, text) IS
  'Postgres owner only. Use a short READ COMMITTED transaction. Duplicate runs reject with 23505; lock contention rejects with 55P03. Evidence must contain a non-secret reference. Human actor is claimed; recorded_by is session_user.';

CREATE OR REPLACE VIEW nexus_live_trading.v_reconciler_health
WITH (security_invoker = true)
AS
 SELECT ( SELECT max(d.dispatched_at) AS max
           FROM nexus_live_trading.reconciler_dispatch_events d) AS last_dispatch_at,
    ( SELECT max(r.occurred_at) AS max
           FROM nexus_live_trading.reconciler_run_events r
          WHERE r.event_type = 'started'::text) AS last_started_at,
    ( SELECT max(r.occurred_at) AS max
           FROM nexus_live_trading.reconciler_run_events r
          WHERE r.event_type = 'finished'::text) AS last_finished_at,
    ( SELECT r.run_state
           FROM nexus_live_trading.reconciler_run_events r
          WHERE r.event_type = 'finished'::text
          ORDER BY r.occurred_at DESC, r.recorded_at DESC, r.reconciler_run_event_id DESC
         LIMIT 1) AS last_finished_state,
    ( SELECT count(*)::integer AS count
           FROM nexus_live_trading.reconciler_run_events s
          WHERE s.event_type = 'started'::text AND s.occurred_at < (statement_timestamp() - '00:02:00'::interval) AND NOT (EXISTS ( SELECT 1
                   FROM nexus_live_trading.reconciler_run_events f
                  WHERE f.run_id = s.run_id AND f.event_type = 'finished'::text)) AND NOT (EXISTS ( SELECT 1
                   FROM nexus_live_trading.reconciler_run_adjudications j
                  WHERE j.run_id = s.run_id AND j.disposition = 'abandoned'::text))) AS stale_started_run_count,
    ( SELECT count(*)::integer AS count
           FROM nexus_live_trading.trade_authorizations a
          WHERE a.authorization_kind = 'exact_action_time_ticket'::text AND (EXISTS ( SELECT 1
                   FROM nexus_live_trading.trade_events c
                  WHERE c.operation_id = a.operation_id AND c.event_type = 'submission_claimed'::text)) AND NOT (EXISTS ( SELECT 1
                   FROM nexus_live_trading.reconciliation_receipts rr
                  WHERE rr.operation_id = a.operation_id))) AS unreconciled_claim_count,
    ( SELECT count(*)::integer AS count
           FROM nexus_live_trading.reconciler_alert_events a
          WHERE a.observed_at >= (statement_timestamp() - '24:00:00'::interval)) AS critical_alert_count_24h;

-- Unexpected custom default grants must fail the whole migration, not create
-- an additional privileged API. No grants or role memberships are introduced.
DO $acl_guard$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_class c,
      LATERAL aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) a
    WHERE c.oid = 'nexus_live_trading.reconciler_run_adjudications'::regclass
      AND (c.relowner <> 'postgres'::regrole OR a.grantee <> c.relowner)
  ) OR EXISTS (
    SELECT 1 FROM pg_proc p,
      LATERAL aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
    WHERE p.oid IN (
      'nexus_live_trading.validate_reconciler_run_adjudication()'::regprocedure,
      'nexus_live_trading.adjudicate_reconciler_run(uuid,text,text,jsonb,text)'::regprocedure
    ) AND (p.proowner <> 'postgres'::regrole OR a.grantee <> p.proowner)
  ) THEN
    RAISE EXCEPTION USING ERRCODE = '42501',
      MESSAGE = 'ct_adjudication_unexpected_default_acl';
  END IF;
END;
$acl_guard$;

COMMIT;
