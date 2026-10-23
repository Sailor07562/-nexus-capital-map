-- SANDBOX ONLY: NEXUS-CT-RECONCILER-ADJUDICATION-20261023-001.
-- Generated from baseline_catalog.json; no production rows or credentials.
-- Run once in a fresh disposable PostgreSQL database whose administrator is
-- distinct from the NOLOGIN postgres role created below.
-- Exact: reconciler_run_events columns, defaults, constraints, RLS, owner,
-- append-only trigger/function; record_reconciler_run_event; health view/function;
-- runtime_snapshot function body. Baseline function text is captured for byte equality.
-- Reduced synthetic dependencies: authority/policy tables and current views,
-- valid_symbol_set, dispatch/alert/claim/receipt tables have ONLY fields consumed
-- by the exact copied health/runtime functions. They have no broker/network code.
-- This fixture does not claim complete Supabase/auth/schema/runtime equivalence.
-- anon/authenticated are NOLOGIN; service_role is BYPASSRLS specifically to prove
-- that an ACL denial still holds even when RLS can be bypassed.
\set ON_ERROR_STOP on
DO $roles$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='postgres') THEN CREATE ROLE postgres NOLOGIN NOSUPERUSER; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon NOLOGIN NOSUPERUSER; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated NOLOGIN NOSUPERUSER; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role NOLOGIN NOSUPERUSER BYPASSRLS; END IF;
 IF EXISTS(SELECT 1 FROM pg_roles WHERE rolname IN ('postgres','anon','authenticated','service_role') AND (rolcanlogin OR rolsuper))
 OR NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='service_role' AND rolbypassrls) THEN
   RAISE EXCEPTION 'Disposable fixture roles are not the required NOLOGIN/NOSUPERUSER identities';
 END IF;
END
$roles$;
CREATE SCHEMA nexus_live_trading AUTHORIZATION postgres;
CREATE SCHEMA nexus_ct_live_command AUTHORIZATION postgres;
SET ROLE postgres;
CREATE TABLE nexus_live_trading.reconciler_dispatch_events(dispatched_at timestamptz NOT NULL);
CREATE TABLE nexus_live_trading.reconciler_alert_events(observed_at timestamptz NOT NULL);
CREATE TABLE nexus_live_trading.trade_authorizations(operation_id text PRIMARY KEY, authorization_kind text NOT NULL);
CREATE TABLE nexus_live_trading.trade_events(operation_id text NOT NULL, event_type text NOT NULL);
CREATE TABLE nexus_live_trading.reconciliation_receipts(operation_id text PRIMARY KEY);
CREATE TABLE nexus_live_trading.authority_events(
  authority_state text, execution_enabled boolean, kill_switch_engaged boolean,
  exact_action_time_ticket_required boolean, automatic_trading_enabled boolean,
  operating_mode text
);
CREATE VIEW nexus_live_trading.v_current_authority AS SELECT * FROM nexus_live_trading.authority_events;
CREATE TABLE nexus_ct_live_command.risk_policy_events(policy_state text, allowed_symbols text[]);
CREATE FUNCTION nexus_ct_live_command.current_policy()
RETURNS nexus_ct_live_command.risk_policy_events LANGUAGE sql STABLE
SET search_path=pg_catalog AS $$
  SELECT p FROM nexus_ct_live_command.risk_policy_events p LIMIT 1
$$;
CREATE FUNCTION nexus_ct_live_command.valid_symbol_set(target_symbols text[])
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path=pg_catalog AS $$
  SELECT cardinality(target_symbols)>0 AND NOT EXISTS(
    SELECT 1 FROM unnest(target_symbols) AS symbol WHERE symbol IS NULL OR btrim(symbol)=''
  )
$$;
INSERT INTO nexus_live_trading.authority_events VALUES('active',true,false,true,false,'sandbox_fixture_only');
INSERT INTO nexus_ct_live_command.risk_policy_events VALUES('active',ARRAY['SANDBOX']);

CREATE TABLE nexus_live_trading.reconciler_run_events (
  reconciler_run_event_id uuid DEFAULT gen_random_uuid() NOT NULL,
  run_id uuid NOT NULL,
  event_type text NOT NULL,
  run_state text NOT NULL,
  selected_count integer NOT NULL,
  succeeded_count integer NOT NULL,
  failed_count integer NOT NULL,
  broker_post_count integer DEFAULT 0 NOT NULL,
  outcomes jsonb DEFAULT '[]'::jsonb NOT NULL,
  executor_request_id text NOT NULL,
  occurred_at timestamp with time zone NOT NULL,
  recorded_at timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
  CONSTRAINT reconciler_run_events_broker_post_count_check CHECK (broker_post_count = 0),
  CONSTRAINT reconciler_run_events_check CHECK (event_type = 'started'::text AND run_state = 'running'::text AND selected_count = 0 AND succeeded_count = 0 AND failed_count = 0 AND jsonb_array_length(outcomes) = 0 OR event_type = 'finished'::text AND (run_state = ANY (ARRAY['completed'::text, 'completed_with_failures'::text])) AND selected_count = (succeeded_count + failed_count) AND jsonb_array_length(outcomes) = selected_count OR event_type = 'finished'::text AND run_state = 'batch_failed'::text AND selected_count = 0 AND succeeded_count = 0 AND failed_count = 1 AND jsonb_array_length(outcomes) = 1),
  CONSTRAINT reconciler_run_events_event_type_check CHECK (event_type = ANY (ARRAY['started'::text, 'finished'::text])),
  CONSTRAINT reconciler_run_events_executor_request_id_check CHECK (length(btrim(executor_request_id)) >= 8 AND length(btrim(executor_request_id)) <= 128),
  CONSTRAINT reconciler_run_events_failed_count_check CHECK (failed_count >= 0 AND failed_count <= 20),
  CONSTRAINT reconciler_run_events_outcomes_check CHECK (jsonb_typeof(outcomes) = 'array'::text AND jsonb_array_length(outcomes) <= 20),
  CONSTRAINT reconciler_run_events_pkey PRIMARY KEY (reconciler_run_event_id),
  CONSTRAINT reconciler_run_events_run_id_event_type_key UNIQUE (run_id, event_type),
  CONSTRAINT reconciler_run_events_run_state_check CHECK (run_state = ANY (ARRAY['running'::text, 'completed'::text, 'completed_with_failures'::text, 'batch_failed'::text])),
  CONSTRAINT reconciler_run_events_selected_count_check CHECK (selected_count >= 0 AND selected_count <= 20),
  CONSTRAINT reconciler_run_events_succeeded_count_check CHECK (succeeded_count >= 0 AND succeeded_count <= 20)
);

ALTER TABLE nexus_live_trading.reconciler_run_events ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION nexus_live_trading.reject_append_only_mutation()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog'
AS $function$
begin
  raise exception using errcode = '55000', message = format('%s is append-only', tg_table_name);
end;
$function$;

CREATE TRIGGER reconciler_run_events_append_only BEFORE DELETE OR UPDATE OR TRUNCATE ON nexus_live_trading.reconciler_run_events FOR EACH STATEMENT EXECUTE FUNCTION nexus_live_trading.reject_append_only_mutation();

CREATE OR REPLACE FUNCTION nexus_live_trading.record_reconciler_run_event(target_run_id uuid, target_event_type text, target_run_state text, target_selected_count integer, target_succeeded_count integer, target_failed_count integer, target_outcomes jsonb, target_executor_request_id text, target_occurred_at timestamp with time zone)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
declare
  new_event_id uuid;
  existing nexus_live_trading.reconciler_run_events%rowtype;
begin
  if target_run_id is null
     or target_event_type not in ('started','finished')
     or target_run_state not in ('running','completed','completed_with_failures','batch_failed')
     or target_occurred_at is null
     or target_occurred_at > clock_timestamp()+interval '1 minute'
     or target_occurred_at < clock_timestamp()-interval '10 minutes'
     or jsonb_typeof(target_outcomes) is distinct from 'array'
     or octet_length(target_outcomes::text) > 65536 then
    raise exception using errcode='22023', message='reconciler_run_event_invalid';
  end if;

  insert into nexus_live_trading.reconciler_run_events (
    run_id,event_type,run_state,selected_count,succeeded_count,failed_count,
    broker_post_count,outcomes,executor_request_id,occurred_at
  ) values (
    target_run_id,target_event_type,target_run_state,target_selected_count,
    target_succeeded_count,target_failed_count,0,target_outcomes,
    target_executor_request_id,target_occurred_at
  ) on conflict (run_id,event_type) do nothing
  returning reconciler_run_event_id into new_event_id;
  if new_event_id is not null then return new_event_id; end if;

  select * into existing from nexus_live_trading.reconciler_run_events
  where run_id=target_run_id and event_type=target_event_type;
  if existing.run_state is distinct from target_run_state
     or existing.selected_count is distinct from target_selected_count
     or existing.succeeded_count is distinct from target_succeeded_count
     or existing.failed_count is distinct from target_failed_count
     or existing.outcomes is distinct from target_outcomes
     or existing.executor_request_id is distinct from target_executor_request_id
     or existing.occurred_at is distinct from target_occurred_at then
    raise exception using errcode='23505', message='reconciler_run_event_replay_mismatch';
  end if;
  return existing.reconciler_run_event_id;
end;
$function$;

CREATE VIEW nexus_live_trading.v_reconciler_health WITH (security_invoker=true) AS  SELECT ( SELECT max(d.dispatched_at) AS max
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
          WHERE a.observed_at >= (statement_timestamp() - '24:00:00'::interval)) AS critical_alert_count_24h;

CREATE OR REPLACE FUNCTION nexus_live_trading.reconciler_health()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
  select coalesce((select to_jsonb(h) from nexus_live_trading.v_reconciler_health h),'{}'::jsonb)
$function$;

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
$function$;

REVOKE ALL ON SCHEMA nexus_live_trading,nexus_ct_live_command FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON ALL TABLES IN SCHEMA nexus_live_trading,nexus_ct_live_command FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA nexus_live_trading,nexus_ct_live_command FROM PUBLIC,anon,authenticated,service_role;
RESET ROLE;
CREATE SCHEMA sandbox_test;
CREATE TABLE sandbox_test.baseline_definitions(name text PRIMARY KEY, definition text NOT NULL);
INSERT INTO sandbox_test.baseline_definitions VALUES
 ('runtime_snapshot',pg_get_functiondef('nexus_ct_live_command.runtime_snapshot()'::regprocedure)),
 ('record_reconciler_run_event',pg_get_functiondef('nexus_live_trading.record_reconciler_run_event(uuid,text,text,integer,integer,integer,jsonb,text,timestamptz)'::regprocedure)),
 ('reject_append_only_mutation',pg_get_functiondef('nexus_live_trading.reject_append_only_mutation()'::regprocedure));
CREATE FUNCTION sandbox_test.event_contract() RETURNS jsonb LANGUAGE sql STABLE AS $$
 SELECT jsonb_build_object(
   'columns',(SELECT jsonb_agg(jsonb_build_object('name',a.attname,'type',format_type(a.atttypid,a.atttypmod),'notnull',a.attnotnull,'default',pg_get_expr(d.adbin,d.adrelid)) ORDER BY a.attnum)
      FROM pg_attribute a LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE a.attrelid='nexus_live_trading.reconciler_run_events'::regclass AND a.attnum>0 AND NOT a.attisdropped),
   'constraints',(SELECT jsonb_agg(jsonb_build_object('name',c.conname,'definition',pg_get_constraintdef(c.oid)) ORDER BY c.conname) FROM pg_constraint c WHERE c.conrelid='nexus_live_trading.reconciler_run_events'::regclass),
   'triggers',(SELECT jsonb_agg(pg_get_triggerdef(t.oid) ORDER BY t.tgname) FROM pg_trigger t WHERE t.tgrelid='nexus_live_trading.reconciler_run_events'::regclass AND NOT t.tgisinternal),
   'owner',(SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid='nexus_live_trading.reconciler_run_events'::regclass),
   'rls',(SELECT relrowsecurity FROM pg_class WHERE oid='nexus_live_trading.reconciler_run_events'::regclass),
   'acl',(SELECT relacl::text FROM pg_class WHERE oid='nexus_live_trading.reconciler_run_events'::regclass)
 )
$$;
INSERT INTO sandbox_test.baseline_definitions VALUES ('event_contract',sandbox_test.event_contract()::text);
CREATE TABLE sandbox_test.results(test_id integer PRIMARY KEY,name text NOT NULL,status text NOT NULL,sqlstate text,detail text,recorded_at timestamptz DEFAULT clock_timestamp());
CREATE FUNCTION sandbox_test.assert_true(condition boolean,detail text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF condition IS DISTINCT FROM true THEN RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE=detail; END IF; END
$$;
CREATE FUNCTION sandbox_test.ledger_digest() RETURNS text LANGUAGE sql STABLE AS $$
 SELECT md5(coalesce(jsonb_agg(to_jsonb(e) ORDER BY reconciler_run_event_id)::text,'[]')) FROM nexus_live_trading.reconciler_run_events e
$$;
CREATE FUNCTION sandbox_test.started(run uuid, age interval DEFAULT interval '5 minutes') RETURNS uuid LANGUAGE plpgsql AS $$
BEGIN
 INSERT INTO nexus_live_trading.reconciler_run_events(run_id,event_type,run_state,selected_count,succeeded_count,failed_count,outcomes,executor_request_id,occurred_at)
 VALUES(run,'started','running',0,0,0,'[]','sandbox-start-request',statement_timestamp()-age);
 RETURN run;
END
$$;
CREATE FUNCTION sandbox_test.finished(run uuid DEFAULT gen_random_uuid(),age interval DEFAULT interval '30 seconds',state text DEFAULT 'completed') RETURNS uuid LANGUAGE plpgsql AS $$
BEGIN
 INSERT INTO nexus_live_trading.reconciler_run_events(run_id,event_type,run_state,selected_count,succeeded_count,failed_count,outcomes,executor_request_id,occurred_at)
 VALUES(run,'finished',state,CASE WHEN state='completed' THEN 0 ELSE 1 END,0,CASE WHEN state='completed' THEN 0 ELSE 1 END,CASE WHEN state='completed' THEN '[]'::jsonb ELSE '[{}]'::jsonb END,'sandbox-finish-request',statement_timestamp()-age);
 RETURN run;
END
$$;
CREATE FUNCTION sandbox_test.expect_error(statement text,expected text[]) RETURNS text LANGUAGE plpgsql AS $$
DECLARE actual text;
BEGIN
 BEGIN EXECUTE statement; EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS actual=RETURNED_SQLSTATE; END;
 IF actual IS NULL OR NOT(actual=ANY(expected)) THEN
   RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE=format('Expected SQLSTATE %s; observed %s',expected,coalesce(actual,'SUCCESS'));
 END IF;
 RETURN actual;
END
$$;
CREATE FUNCTION sandbox_test.expect_denied_as(target_role text,statement text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE prior_role text:=current_user; actual text;
BEGIN
 PERFORM set_config('role',target_role,true);
 BEGIN EXECUTE statement; EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS actual=RETURNED_SQLSTATE; END;
 PERFORM set_config('role',prior_role,true);
 IF actual IS DISTINCT FROM '42501' THEN
   RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE=format('Role %s expected ACL SQLSTATE 42501; observed %s',target_role,coalesce(actual,'SUCCESS'));
 END IF;
 RETURN actual;
END
$$;
CREATE FUNCTION sandbox_test.run_case(id integer,title text,body text) RETURNS void LANGUAGE plpgsql AS $$
DECLARE verdict text; code text; detail text;
BEGIN
 BEGIN
   EXECUTE body;
   RAISE EXCEPTION USING ERRCODE='ZX001',MESSAGE='case passed; scenario rolled back';
 EXCEPTION
   WHEN SQLSTATE 'ZX001' THEN verdict:='PASS';code:='00000';detail:='All assertions passed; scenario rolled back';
   WHEN SQLSTATE 'ZX002' THEN GET STACKED DIAGNOSTICS detail=MESSAGE_TEXT;verdict:='BASELINE_GAP';code:='ZX002';
   WHEN OTHERS THEN GET STACKED DIAGNOSTICS code=RETURNED_SQLSTATE,detail=MESSAGE_TEXT;verdict:='FAIL';
 END;
 INSERT INTO sandbox_test.results(test_id,name,status,sqlstate,detail) VALUES(id,title,verdict,code,detail);
END
$$;
REVOKE ALL ON SCHEMA sandbox_test FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA sandbox_test FROM PUBLIC,anon,authenticated,service_role;
SELECT jsonb_build_object('fixture','ready','production_rows_copied',0,'runtime_definition_md5',md5(definition)) FROM sandbox_test.baseline_definitions WHERE name='runtime_snapshot';
