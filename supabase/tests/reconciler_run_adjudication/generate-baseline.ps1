$ErrorActionPreference = 'Stop'
$catalog = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'baseline_catalog.json') | ConvertFrom-Json
$parts = [System.Collections.Generic.List[string]]::new()
$parts.Add(@'
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
'@)
$columns = @($catalog.table_and_view.columns | ForEach-Object {
  $line='  '+$_.column_name+' '+$_.data_type
  if($_.column_default){$line+=' DEFAULT '+$_.column_default}
  if($_.is_nullable -eq 'NO'){$line+=' NOT NULL'}
  $line
})
$constraints=@($catalog.table_and_view.constraints | ForEach-Object {'  CONSTRAINT '+$_.conname+' '+$_.definition})
$parts.Add("CREATE TABLE nexus_live_trading.reconciler_run_events (`n"+(($columns+$constraints) -join ",`n")+"`n);")
$parts.Add('ALTER TABLE nexus_live_trading.reconciler_run_events ENABLE ROW LEVEL SECURITY;')
$parts.Add(($catalog.functions | Where-Object name -eq 'reject_append_only_mutation').definition.TrimEnd()+';')
foreach($trigger in $catalog.table_and_view.triggers){$parts.Add($trigger+';')}
$parts.Add(($catalog.functions | Where-Object name -eq 'record_reconciler_run_event').definition.TrimEnd()+';')
$parts.Add('CREATE VIEW nexus_live_trading.v_reconciler_health WITH (security_invoker=true) AS '+$catalog.table_and_view.health_view)
$parts.Add(($catalog.functions | Where-Object name -eq 'reconciler_health').definition.TrimEnd()+';')
$parts.Add($catalog.runtime.runtime_snapshot.TrimEnd()+';')
$parts.Add(@'
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
'@)
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'baseline.sql'),($parts -join "`n`n")+"`n",[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'runtime_snapshot.baseline.sql'),$catalog.runtime.runtime_snapshot,[Text.UTF8Encoding]::new($false))
Get-Item -LiteralPath (Join-Path $PSScriptRoot 'baseline.sql'),(Join-Path $PSScriptRoot 'runtime_snapshot.baseline.sql') | Select-Object Name,Length
