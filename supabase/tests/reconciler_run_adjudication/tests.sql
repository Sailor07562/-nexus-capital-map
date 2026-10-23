-- SANDBOX ONLY. Apply baseline.sql and the migration before running this file.
-- Execute as the disposable container administrator, NOT an external DB user.
-- Every scenario is rolled back by sandbox_test.run_case; only result rows persist.
-- Case 11 intentionally records BASELINE_GAP if the unchanged real runtime body
-- ignores a preserved critical alert. The harness never adds a fake runtime gate.
-- Restricted-role cases temporarily grant schema USAGE inside their rolled-back
-- scenario so they test actual table/function ACLs, rather than only schema denial.
\set ON_ERROR_STOP on
\pset format unaligned
\pset tuples_only on

CREATE FUNCTION sandbox_test.adjudicate(run uuid) RETURNS uuid LANGUAGE sql VOLATILE AS $$
 SELECT nexus_live_trading.adjudicate_reconciler_run(run,'abandoned','Synthetic sandbox investigation confirms the orphaned run.',
   '{"reference":"sandbox-evidence-001"}'::jsonb,'Captain')
$$;
CREATE FUNCTION sandbox_test.healthy_run() RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE run uuid:=gen_random_uuid();
BEGIN
 PERFORM sandbox_test.started(run,interval '1 minute');
 PERFORM sandbox_test.finished(run,interval '30 seconds');
 RETURN run;
END
$$;
REVOKE ALL ON FUNCTION sandbox_test.adjudicate(uuid),sandbox_test.healthy_run() FROM PUBLIC,anon,authenticated,service_role;

SELECT sandbox_test.run_case(1,'Stale orphan adjudication restores freshness only with otherwise healthy runtime',$case$
DO $body$
DECLARE run uuid:=gen_random_uuid(); before_hash text; receipt uuid; snapshot jsonb;
BEGIN
 PERFORM sandbox_test.started(run); PERFORM sandbox_test.healthy_run();
 before_hash:=sandbox_test.ledger_digest();
 PERFORM sandbox_test.assert_true((SELECT stale_started_run_count=1 FROM nexus_live_trading.v_reconciler_health),'Expected one original stale orphan');
 PERFORM sandbox_test.assert_true((nexus_ct_live_command.runtime_snapshot()->>'ready')::boolean IS FALSE,'Original orphan must hold readiness');
 receipt:=sandbox_test.adjudicate(run);
 snapshot:=nexus_ct_live_command.runtime_snapshot();
 PERFORM sandbox_test.assert_true(receipt IS NOT NULL AND (snapshot->>'stale_started_run_count')::integer=0,'Adjudication must exclude exactly the stale orphan');
 PERFORM sandbox_test.assert_true((snapshot->>'reconciler_fresh')::boolean AND (snapshot->>'ready')::boolean,'Otherwise healthy synthetic runtime should become fresh and ready');
 PERFORM sandbox_test.assert_true(before_hash=sandbox_test.ledger_digest(),'Full event ledger changed during adjudication');
 PERFORM sandbox_test.assert_true((SELECT count(*)=1 FROM nexus_live_trading.reconciler_run_adjudications WHERE adjudication_id=receipt AND run_id=run AND disposition='abandoned'),'Expected one administrative disposition');
END $body$;
$case$);

SELECT sandbox_test.run_case(2,'Recent unfinished run is rejected with 22023',$case$
DO $body$ DECLARE run uuid:=gen_random_uuid(); digest text;
BEGIN
 PERFORM sandbox_test.started(run,interval '1 minute'); digest:=sandbox_test.ledger_digest();
 PERFORM sandbox_test.assert_true((SELECT stale_started_run_count=0 FROM nexus_live_trading.v_reconciler_health),'Recent unfinished run must not be counted stale');
 PERFORM sandbox_test.expect_error(format('SELECT sandbox_test.adjudicate(%L::uuid)',run),ARRAY['22023']);
 PERFORM sandbox_test.assert_true(digest=sandbox_test.ledger_digest() AND (SELECT count(*)=0 FROM nexus_live_trading.reconciler_run_adjudications),'Recent rejection changed historical evidence');
END $body$;
$case$);

SELECT sandbox_test.run_case(3,'Already finished run is rejected with 22023',$case$
DO $body$ DECLARE run uuid:=gen_random_uuid(); digest text;
BEGIN
 PERFORM sandbox_test.started(run); PERFORM sandbox_test.finished(run); digest:=sandbox_test.ledger_digest();
 PERFORM sandbox_test.expect_error(format('SELECT sandbox_test.adjudicate(%L::uuid)',run),ARRAY['22023']);
 PERFORM sandbox_test.assert_true(digest=sandbox_test.ledger_digest(),'Completed rejection changed event ledger');
END $body$;
$case$);

SELECT sandbox_test.run_case(4,'Unknown run is rejected with 22023',$case$
DO $body$
BEGIN
 PERFORM sandbox_test.expect_error(format('SELECT sandbox_test.adjudicate(%L::uuid)',gen_random_uuid()),ARRAY['22023']);
 PERFORM sandbox_test.assert_true((SELECT count(*)=0 FROM nexus_live_trading.reconciler_run_adjudications),'Unknown run created an adjudication');
END $body$;
$case$);

SELECT sandbox_test.run_case(5,'Duplicate adjudication rejects with 23505 and preserves original record',$case$
DO $body$ DECLARE run uuid:=gen_random_uuid(); receipt uuid; original jsonb; digest text;
BEGIN
 PERFORM sandbox_test.started(run); digest:=sandbox_test.ledger_digest(); receipt:=sandbox_test.adjudicate(run);
 SELECT to_jsonb(j) INTO original FROM nexus_live_trading.reconciler_run_adjudications j WHERE run_id=run;
 PERFORM sandbox_test.expect_error(format('SELECT sandbox_test.adjudicate(%L::uuid)',run),ARRAY['23505']);
 PERFORM sandbox_test.assert_true((SELECT count(*)=1 FROM nexus_live_trading.reconciler_run_adjudications),'Duplicate created another disposition');
 PERFORM sandbox_test.assert_true((SELECT to_jsonb(j)=original FROM nexus_live_trading.reconciler_run_adjudications j WHERE run_id=run),'Duplicate changed original disposition');
 PERFORM sandbox_test.assert_true(digest=sandbox_test.ledger_digest(),'Duplicate changed event ledger');
END $body$;
$case$);

SELECT sandbox_test.run_case(6,'Only abandoned disposition is accepted',$case$
DO $body$ DECLARE run uuid:=gen_random_uuid(); bad text;
BEGIN
 PERFORM sandbox_test.started(run);
 FOREACH bad IN ARRAY ARRAY['completed','cancelled','',' abandoned','ABANDONED',NULL] LOOP
   PERFORM sandbox_test.expect_error(format('SELECT nexus_live_trading.adjudicate_reconciler_run(%L::uuid,%L,%L,%L::jsonb,%L)',run,bad,'Synthetic valid reason for this test.','{"reference":"sandbox-evidence-001"}','Captain'),ARRAY['23514','23502','22023']);
 END LOOP;
 PERFORM sandbox_test.assert_true((SELECT count(*)=0 FROM nexus_live_trading.reconciler_run_adjudications),'Invalid disposition was stored');
END $body$;
$case$);

SELECT sandbox_test.run_case(7,'Reason rejects null short padded and oversized inputs',$case$
DO $body$ DECLARE run uuid:=gen_random_uuid(); bad text;
BEGIN
 PERFORM sandbox_test.started(run);
 FOREACH bad IN ARRAY ARRAY[NULL,'','too short',repeat('a',15),repeat('a',2049),'  Synthetic reason has forbidden padding.  '] LOOP
  PERFORM sandbox_test.expect_error(format('SELECT nexus_live_trading.adjudicate_reconciler_run(%L::uuid,%L,%L,%L::jsonb,%L)',run,'abandoned',bad,'{"reference":"sandbox-evidence-001"}','Captain'),ARRAY['23514','23502','22023']);
 END LOOP;
 PERFORM sandbox_test.assert_true((SELECT count(*)=0 FROM nexus_live_trading.reconciler_run_adjudications),'Invalid reason was stored');
END $body$;
$case$);

SELECT sandbox_test.run_case(8,'Evidence rejects missing malformed short long and oversized references',$case$
DO $body$ DECLARE run uuid:=gen_random_uuid(); bad jsonb;
BEGIN
 PERFORM sandbox_test.started(run);
 FOREACH bad IN ARRAY ARRAY[NULL::jsonb,'null'::jsonb,'[]'::jsonb,'"text"'::jsonb,'{}'::jsonb,'{"reference":null}'::jsonb,'{"reference":42}'::jsonb,'{"reference":"short"}'::jsonb,'{"reference":"        "}'::jsonb,jsonb_build_object('reference',repeat('r',513)),jsonb_build_object('reference','sandbox-evidence-001','payload',repeat('x',17000))] LOOP
  PERFORM sandbox_test.expect_error(format('SELECT nexus_live_trading.adjudicate_reconciler_run(%L::uuid,%L,%L,%L::jsonb,%L)',run,'abandoned','Synthetic valid reason for this test.',bad,'Captain'),ARRAY['23514','23502','22023']);
 END LOOP;
 PERFORM sandbox_test.assert_true((SELECT count(*)=0 FROM nexus_live_trading.reconciler_run_adjudications),'Invalid evidence was stored');
END $body$;
$case$);

SELECT sandbox_test.run_case(9,'Actor rejects null malformed too-short and oversized identity',$case$
DO $body$ DECLARE run uuid:=gen_random_uuid(); bad text;
BEGIN
 PERFORM sandbox_test.started(run);
 FOREACH bad IN ARRAY ARRAY[NULL,'','ab',' Captain','Captain ','#Captain','Captain name',repeat('a',129)] LOOP
  PERFORM sandbox_test.expect_error(format('SELECT nexus_live_trading.adjudicate_reconciler_run(%L::uuid,%L,%L,%L::jsonb,%L)',run,'abandoned','Synthetic valid reason for this test.','{"reference":"sandbox-evidence-001"}',bad),ARRAY['23514','23502','22023']);
 END LOOP;
 PERFORM sandbox_test.assert_true((SELECT count(*)=0 FROM nexus_live_trading.reconciler_run_adjudications),'Invalid actor was stored');
END $body$;
$case$);

SELECT sandbox_test.run_case(10,'Unrelated stale orphan remains visible and keeps HOLD',$case$
DO $body$ DECLARE first_run uuid:=gen_random_uuid(); other_run uuid:=gen_random_uuid(); digest text; snapshot jsonb;
BEGIN
 PERFORM sandbox_test.started(first_run); PERFORM sandbox_test.started(other_run,interval '8 minutes'); PERFORM sandbox_test.healthy_run();
 digest:=sandbox_test.ledger_digest(); PERFORM sandbox_test.adjudicate(first_run); snapshot:=nexus_ct_live_command.runtime_snapshot();
 PERFORM sandbox_test.assert_true((snapshot->>'stale_started_run_count')::integer=1 AND (snapshot->>'ready')::boolean IS FALSE,'Adjudicating one run must not hide another orphan');
 PERFORM sandbox_test.assert_true(digest=sandbox_test.ledger_digest(),'Other orphan test changed event ledger');
END $body$;
$case$);

SELECT sandbox_test.run_case(11,'Critical alert remains counted; unchanged runtime must expose baseline gate gap',$case$
DO $body$ DECLARE run uuid:=gen_random_uuid(); snapshot jsonb; digest text;
BEGIN
 PERFORM sandbox_test.started(run); PERFORM sandbox_test.healthy_run();
 INSERT INTO nexus_live_trading.reconciler_alert_events VALUES(statement_timestamp());
 digest:=sandbox_test.ledger_digest(); PERFORM sandbox_test.adjudicate(run); snapshot:=nexus_ct_live_command.runtime_snapshot();
 PERFORM sandbox_test.assert_true((SELECT critical_alert_count_24h=1 FROM nexus_live_trading.v_reconciler_health),'Migration erased or suppressed critical alert count');
 PERFORM sandbox_test.assert_true(pg_get_functiondef('nexus_ct_live_command.runtime_snapshot()'::regprocedure)=(SELECT definition FROM sandbox_test.baseline_definitions WHERE name='runtime_snapshot'),'Runtime function changed rather than exposing its true baseline behavior');
 PERFORM sandbox_test.assert_true(digest=sandbox_test.ledger_digest(),'Critical-alert scenario changed historical events');
 PERFORM sandbox_test.assert_true((snapshot->>'reconciler_fresh')::boolean IS TRUE,'Baseline-gap scenario must isolate critical alert with otherwise fresh reconciler');
 IF (snapshot->>'ready')::boolean IS TRUE THEN
  RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='BASELINE_GAP: unchanged production runtime_snapshot reports ready=true with critical_alert_count_24h=1; alert preserved; no alert gate was fabricated';
 END IF;
 PERFORM sandbox_test.assert_true((snapshot->>'ready')::boolean IS FALSE,'Critical-alert readiness was neither true nor false');
END $body$;
$case$);

SELECT sandbox_test.run_case(12,'Unreconciled claim remains counted and keeps HOLD',$case$
DO $body$ DECLARE run uuid:=gen_random_uuid(); snapshot jsonb; digest text;
BEGIN
 PERFORM sandbox_test.started(run); PERFORM sandbox_test.healthy_run();
 INSERT INTO nexus_live_trading.trade_authorizations VALUES('sandbox-operation-001','exact_action_time_ticket');
 INSERT INTO nexus_live_trading.trade_events VALUES('sandbox-operation-001','submission_claimed');
 digest:=sandbox_test.ledger_digest(); PERFORM sandbox_test.adjudicate(run); snapshot:=nexus_ct_live_command.runtime_snapshot();
 PERFORM sandbox_test.assert_true((snapshot->>'unreconciled_claim_count')::integer=1 AND (snapshot->>'ready')::boolean IS FALSE,'Unreconciled claim must preserve HOLD');
 PERFORM sandbox_test.assert_true(digest=sandbox_test.ledger_digest(),'Unreconciled-claim scenario changed events');
END $body$;
$case$);

SELECT sandbox_test.run_case(13,'Latest failed completion still keeps HOLD',$case$
DO $body$ DECLARE run uuid:=gen_random_uuid(); finish_run uuid:=gen_random_uuid(); snapshot jsonb;
BEGIN
 PERFORM sandbox_test.started(run); PERFORM sandbox_test.started(finish_run,interval '1 minute');
 PERFORM sandbox_test.finished(finish_run,interval '30 seconds','completed_with_failures'); PERFORM sandbox_test.adjudicate(run);
 snapshot:=nexus_ct_live_command.runtime_snapshot();
 PERFORM sandbox_test.assert_true(snapshot->>'last_reconciler_state'='completed_with_failures' AND (snapshot->>'ready')::boolean IS FALSE,'Failed completion must not be converted into success');
END $body$;
$case$);

SELECT sandbox_test.run_case(14,'Old last completion still keeps HOLD',$case$
DO $body$ DECLARE run uuid:=gen_random_uuid(); finished_run uuid:=gen_random_uuid(); snapshot jsonb;
BEGIN
 PERFORM sandbox_test.started(run,interval '8 minutes'); PERFORM sandbox_test.started(finished_run,interval '7 minutes');
 PERFORM sandbox_test.finished(finished_run,interval '6 minutes'); PERFORM sandbox_test.adjudicate(run); snapshot:=nexus_ct_live_command.runtime_snapshot();
 PERFORM sandbox_test.assert_true((snapshot->>'stale_started_run_count')::integer=0 AND (snapshot->>'ready')::boolean IS FALSE,'Adjudication must not manufacture fresh completion');
END $body$;
$case$);

SELECT sandbox_test.run_case(15,'Adjudications reject UPDATE with append-only 55000',$case$
DO $body$ DECLARE run uuid:=gen_random_uuid(); prior jsonb;
BEGIN
 PERFORM sandbox_test.started(run); PERFORM sandbox_test.adjudicate(run);
 SELECT to_jsonb(j) INTO prior FROM nexus_live_trading.reconciler_run_adjudications j WHERE run_id=run;
 PERFORM sandbox_test.expect_error('UPDATE nexus_live_trading.reconciler_run_adjudications SET reason=''Replacement reason must be rejected.''',ARRAY['55000']);
 PERFORM sandbox_test.assert_true((SELECT to_jsonb(j)=prior FROM nexus_live_trading.reconciler_run_adjudications j WHERE run_id=run),'Rejected UPDATE changed adjudication');
END $body$;
$case$);

SELECT sandbox_test.run_case(16,'Adjudications reject DELETE with append-only 55000',$case$
DO $body$ DECLARE run uuid:=gen_random_uuid();
BEGIN
 PERFORM sandbox_test.started(run); PERFORM sandbox_test.adjudicate(run);
 PERFORM sandbox_test.expect_error('DELETE FROM nexus_live_trading.reconciler_run_adjudications',ARRAY['55000']);
 PERFORM sandbox_test.assert_true((SELECT count(*)=1 FROM nexus_live_trading.reconciler_run_adjudications),'Rejected DELETE removed adjudication');
END $body$;
$case$);

SELECT sandbox_test.run_case(17,'Adjudications reject TRUNCATE with append-only 55000',$case$
DO $body$ DECLARE run uuid:=gen_random_uuid();
BEGIN
 PERFORM sandbox_test.started(run); PERFORM sandbox_test.adjudicate(run);
 PERFORM sandbox_test.expect_error('TRUNCATE nexus_live_trading.reconciler_run_adjudications',ARRAY['55000']);
 PERFORM sandbox_test.assert_true((SELECT count(*)=1 FROM nexus_live_trading.reconciler_run_adjudications),'Rejected TRUNCATE removed adjudication');
END $body$;
$case$);

SELECT sandbox_test.run_case(18,'Late genuine finish still appends through unchanged writer',$case$
DO $body$ DECLARE run uuid:=gen_random_uuid(); original_start jsonb; original_adjudication jsonb; event_id uuid;
BEGIN
 PERFORM sandbox_test.started(run); PERFORM sandbox_test.adjudicate(run);
 SELECT to_jsonb(e) INTO original_start FROM nexus_live_trading.reconciler_run_events e WHERE run_id=run;
 SELECT to_jsonb(j) INTO original_adjudication FROM nexus_live_trading.reconciler_run_adjudications j WHERE run_id=run;
 event_id:=nexus_live_trading.record_reconciler_run_event(run,'finished','completed',0,0,0,'[]','sandbox-late-finish',clock_timestamp());
 PERFORM sandbox_test.assert_true(event_id IS NOT NULL AND (SELECT count(*)=2 FROM nexus_live_trading.reconciler_run_events WHERE run_id=run),'Late finish did not append normally');
 PERFORM sandbox_test.assert_true((SELECT to_jsonb(e)=original_start FROM nexus_live_trading.reconciler_run_events e WHERE run_id=run AND event_type='started'),'Late finish rewrote historical start');
 PERFORM sandbox_test.assert_true((SELECT to_jsonb(j)=original_adjudication FROM nexus_live_trading.reconciler_run_adjudications j WHERE run_id=run),'Late finish rewrote administrative disposition');
 PERFORM sandbox_test.assert_true((SELECT stale_started_run_count=0 FROM nexus_live_trading.v_reconciler_health),'Late finished run was double counted');
END $body$;
$case$);

SELECT sandbox_test.run_case(19,'Anon authenticated and BYPASSRLS service_role direct inserts are denied',$case$
DO $body$ DECLARE run uuid:=gen_random_uuid(); role_name text;
BEGIN
 PERFORM sandbox_test.started(run);
 GRANT USAGE ON SCHEMA nexus_live_trading TO anon,authenticated,service_role;
 PERFORM sandbox_test.assert_true((SELECT rolbypassrls FROM pg_roles WHERE rolname='service_role'),'service_role must bypass RLS to prove independent ACL enforcement');
 FOREACH role_name IN ARRAY ARRAY['anon','authenticated','service_role'] LOOP
  PERFORM sandbox_test.expect_denied_as(role_name,format('INSERT INTO nexus_live_trading.reconciler_run_adjudications(run_id,disposition,reason,evidence,adjudicated_by) VALUES(%L::uuid,%L,%L,%L::jsonb,%L)',run,'abandoned','Synthetic valid reason for ACL test.','{"reference":"sandbox-evidence-001"}','Captain'));
 END LOOP;
 PERFORM sandbox_test.assert_true((SELECT count(*)=0 FROM nexus_live_trading.reconciler_run_adjudications),'Restricted direct insert succeeded');
END $body$;
$case$);

SELECT sandbox_test.run_case(20,'Anon authenticated and service_role actual function calls are denied',$case$
DO $body$ DECLARE run uuid:=gen_random_uuid(); role_name text;
BEGIN
 PERFORM sandbox_test.started(run); GRANT USAGE ON SCHEMA nexus_live_trading TO anon,authenticated,service_role;
 FOREACH role_name IN ARRAY ARRAY['anon','authenticated','service_role'] LOOP
  PERFORM sandbox_test.expect_denied_as(role_name,format('SELECT nexus_live_trading.adjudicate_reconciler_run(%L::uuid,%L,%L,%L::jsonb,%L)',run,'abandoned','Synthetic valid reason for ACL test.','{"reference":"sandbox-evidence-001"}','Captain'));
 END LOOP;
 PERFORM sandbox_test.assert_true((SELECT count(*)=0 FROM nexus_live_trading.reconciler_run_adjudications),'Restricted function invocation succeeded');
END $body$;
$case$);

SELECT sandbox_test.run_case(21,'Adjudication table functions and health view remain owner-only',$case$
DO $body$
BEGIN
 PERFORM sandbox_test.assert_true(NOT EXISTS(
  SELECT 1 FROM pg_class c,LATERAL aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) a
  WHERE c.oid IN ('nexus_live_trading.reconciler_run_adjudications'::regclass,'nexus_live_trading.v_reconciler_health'::regclass)
    AND (c.relowner<>'postgres'::regrole OR a.grantee<>c.relowner)),'Table/view owner or ACL expanded');
 PERFORM sandbox_test.assert_true(NOT EXISTS(
  SELECT 1 FROM pg_proc p,LATERAL aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
  WHERE p.oid IN ('nexus_live_trading.adjudicate_reconciler_run(uuid,text,text,jsonb,text)'::regprocedure,'nexus_live_trading.validate_reconciler_run_adjudication()'::regprocedure)
    AND (p.proowner<>'postgres'::regrole OR a.grantee<>p.proowner)),'Function owner or ACL expanded');
 PERFORM sandbox_test.assert_true((SELECT relrowsecurity FROM pg_class WHERE oid='nexus_live_trading.reconciler_run_adjudications'::regclass),'Adjudications RLS not enabled');
END $body$;
$case$);

SELECT sandbox_test.run_case(22,'Existing event schema trigger ACL and writer functions are unchanged',$case$
DO $body$
BEGIN
 PERFORM sandbox_test.assert_true(sandbox_test.event_contract()::text=(SELECT definition FROM sandbox_test.baseline_definitions WHERE name='event_contract'),'Existing event contract changed');
 PERFORM sandbox_test.assert_true(pg_get_functiondef('nexus_live_trading.record_reconciler_run_event(uuid,text,text,integer,integer,integer,jsonb,text,timestamptz)'::regprocedure)=(SELECT definition FROM sandbox_test.baseline_definitions WHERE name='record_reconciler_run_event'),'Event writer function changed');
 PERFORM sandbox_test.assert_true(pg_get_functiondef('nexus_live_trading.reject_append_only_mutation()'::regprocedure)=(SELECT definition FROM sandbox_test.baseline_definitions WHERE name='reject_append_only_mutation'),'Existing immutability function changed');
 PERFORM sandbox_test.assert_true(pg_get_functiondef('nexus_ct_live_command.runtime_snapshot()'::regprocedure)=(SELECT definition FROM sandbox_test.baseline_definitions WHERE name='runtime_snapshot'),'Runtime function is not byte-identical');
END $body$;
$case$);

SELECT sandbox_test.run_case(23,'Caller cannot forge adjudication identifiers timestamps or recorded_by',$case$
DO $body$ DECLARE run uuid:=gen_random_uuid(); fake_id uuid:=gen_random_uuid(); row_value nexus_live_trading.reconciler_run_adjudications%rowtype; start_time timestamptz;
BEGIN
 PERFORM sandbox_test.started(run); SELECT occurred_at INTO start_time FROM nexus_live_trading.reconciler_run_events WHERE run_id=run;
 INSERT INTO nexus_live_trading.reconciler_run_adjudications(adjudication_id,run_id,disposition,reason,evidence,adjudicated_by,started_at,adjudicated_at,recorded_at,recorded_by)
 VALUES(fake_id,run,'abandoned','Synthetic direct insert tests server-owned audit fields.','{"reference":"sandbox-evidence-001"}','Captain','2000-01-01','2000-01-02','2000-01-03','forged_operator') RETURNING * INTO row_value;
 PERFORM sandbox_test.assert_true(row_value.adjudication_id<>fake_id AND row_value.started_at=start_time,'Caller forged ID or original start timestamp');
 PERFORM sandbox_test.assert_true(row_value.adjudicated_at=statement_timestamp() AND row_value.recorded_at>=row_value.adjudicated_at AND row_value.recorded_by=session_user,'Caller forged server audit metadata');
END $body$;
$case$);

SELECT sandbox_test.run_case(24,'Exact two-minute cutoff is still too recent',$case$
DO $body$ DECLARE run uuid:=gen_random_uuid();
BEGIN
 PERFORM sandbox_test.started(run,interval '2 minutes');
 PERFORM sandbox_test.expect_error(format('SELECT sandbox_test.adjudicate(%L::uuid)',run),ARRAY['22023']);
 PERFORM sandbox_test.assert_true((SELECT stale_started_run_count=0 FROM nexus_live_trading.v_reconciler_health),'Exact boundary disagrees with existing strict stale cutoff');
END $body$;
$case$);

SELECT sandbox_test.run_case(25,'Null run identity is rejected without records',$case$
DO $body$
BEGIN
 PERFORM sandbox_test.expect_error('SELECT sandbox_test.adjudicate(NULL::uuid)',ARRAY['22023','23502']);
 PERFORM sandbox_test.assert_true((SELECT count(*)=0 FROM nexus_live_trading.reconciler_run_adjudications),'Null run was stored');
END $body$;
$case$);

SELECT sandbox_test.run_case(26,'Valid minimum and maximum evidence and reason lengths accepted',$case$
DO $body$ DECLARE run uuid; reason_length integer; ref_length integer;
BEGIN
 FOREACH reason_length IN ARRAY ARRAY[16,2048] LOOP
  FOREACH ref_length IN ARRAY ARRAY[8,512] LOOP
   run:=gen_random_uuid(); PERFORM sandbox_test.started(run);
   PERFORM nexus_live_trading.adjudicate_reconciler_run(run,'abandoned',repeat('r',reason_length),jsonb_build_object('reference',repeat('e',ref_length)),'Captain');
  END LOOP;
 END LOOP;
 PERFORM sandbox_test.assert_true((SELECT count(*)=4 FROM nexus_live_trading.reconciler_run_adjudications),'Valid field boundaries rejected');
END $body$;
$case$);

SELECT sandbox_test.run_case(27,'Existing event append-only UPDATE DELETE and TRUNCATE still reject',$case$
DO $body$ DECLARE run uuid:=gen_random_uuid(); digest text;
BEGIN
 PERFORM sandbox_test.started(run); digest:=sandbox_test.ledger_digest();
 PERFORM sandbox_test.expect_error('UPDATE nexus_live_trading.reconciler_run_events SET executor_request_id=''replacement-request''',ARRAY['55000']);
 PERFORM sandbox_test.expect_error('DELETE FROM nexus_live_trading.reconciler_run_events',ARRAY['55000']);
 -- CASCADE includes the new dependent table; both are append-only statement triggers.
 PERFORM sandbox_test.expect_error('TRUNCATE nexus_live_trading.reconciler_run_events CASCADE',ARRAY['55000']);
 PERFORM sandbox_test.assert_true(digest=sandbox_test.ledger_digest(),'Existing ledger immutability weakened');
END $body$;
$case$);

SELECT sandbox_test.run_case(28,'Inactive authority retains HOLD after orphan exclusion',$case$
DO $body$ DECLARE run uuid:=gen_random_uuid(); snapshot jsonb;
BEGIN
 PERFORM sandbox_test.started(run); PERFORM sandbox_test.healthy_run();
 UPDATE nexus_live_trading.authority_events SET authority_state='hold',execution_enabled=false;
 PERFORM sandbox_test.adjudicate(run); snapshot:=nexus_ct_live_command.runtime_snapshot();
 PERFORM sandbox_test.assert_true((snapshot->>'reconciler_fresh')::boolean AND (snapshot->>'ready')::boolean IS FALSE,'Adjudication changed independent authority gate');
END $body$;
$case$);

SELECT sandbox_test.run_case(29,'Normal started-to-finished lifecycle stays nonstale without adjudication',$case$
DO $body$ DECLARE run uuid:=gen_random_uuid(); started_at timestamptz:=clock_timestamp()-interval '1 minute'; original_start jsonb; start_id uuid; finish_id uuid;
BEGIN
 start_id:=nexus_live_trading.record_reconciler_run_event(run,'started','running',0,0,0,'[]','sandbox-normal-start',started_at);
 SELECT to_jsonb(e) INTO original_start FROM nexus_live_trading.reconciler_run_events e WHERE reconciler_run_event_id=start_id;
 PERFORM sandbox_test.assert_true((SELECT stale_started_run_count=0 FROM nexus_live_trading.v_reconciler_health),'Normal recent started event was counted stale');
 finish_id:=nexus_live_trading.record_reconciler_run_event(run,'finished','completed',0,0,0,'[]','sandbox-normal-finish',clock_timestamp());
 PERFORM sandbox_test.assert_true(start_id IS NOT NULL AND finish_id IS NOT NULL AND start_id<>finish_id,'Normal writer did not create distinct append-only lifecycle events');
 PERFORM sandbox_test.assert_true((SELECT count(*)=2 FROM nexus_live_trading.reconciler_run_events WHERE run_id=run),'Normal lifecycle must contain exactly started and finished');
 PERFORM sandbox_test.assert_true((SELECT to_jsonb(e)=original_start FROM nexus_live_trading.reconciler_run_events e WHERE reconciler_run_event_id=start_id),'Normal finish rewrote original start');
 PERFORM sandbox_test.assert_true((SELECT stale_started_run_count=0 AND last_finished_state='completed' FROM nexus_live_trading.v_reconciler_health),'Normal finished run has incorrect health');
 PERFORM sandbox_test.assert_true((SELECT count(*)=0 FROM nexus_live_trading.reconciler_run_adjudications),'Normal run must require no administrative adjudication');
END $body$;
$case$);

SELECT sandbox_test.run_case(30,'All other health observations remain identical after orphan exclusion',$case$
DO $body$ DECLARE run uuid:=gen_random_uuid(); before_health jsonb; after_health jsonb; digest text;
BEGIN
 PERFORM sandbox_test.started(run); PERFORM sandbox_test.healthy_run();
 INSERT INTO nexus_live_trading.reconciler_dispatch_events VALUES(statement_timestamp()-interval '20 seconds');
 INSERT INTO nexus_live_trading.reconciler_alert_events VALUES(statement_timestamp());
 INSERT INTO nexus_live_trading.trade_authorizations VALUES('sandbox-health-invariant-001','exact_action_time_ticket');
 INSERT INTO nexus_live_trading.trade_events VALUES('sandbox-health-invariant-001','submission_claimed');
 SELECT to_jsonb(h) INTO before_health FROM nexus_live_trading.v_reconciler_health h;
 digest:=sandbox_test.ledger_digest(); PERFORM sandbox_test.adjudicate(run);
 SELECT to_jsonb(h) INTO after_health FROM nexus_live_trading.v_reconciler_health h;
 PERFORM sandbox_test.assert_true((before_health->>'stale_started_run_count')::integer=1 AND (after_health->>'stale_started_run_count')::integer=0,'Expected only targeted stale count to decrease');
 PERFORM sandbox_test.assert_true((before_health-'stale_started_run_count')=(after_health-'stale_started_run_count'),'Latest dispatch/start/finish/state or independent health counts changed');
 PERFORM sandbox_test.assert_true((after_health->>'unreconciled_claim_count')::integer=1 AND (after_health->>'critical_alert_count_24h')::integer=1,'Independent claim and alert counts were not preserved');
 PERFORM sandbox_test.assert_true(digest=sandbox_test.ledger_digest(),'Health-invariance scenario changed historical event evidence');
END $body$;
$case$);

SELECT jsonb_build_object(
 'mission','NEXUS-CT-RECONCILER-ADJUDICATION-20261023-001',
 'total',(SELECT count(*) FROM sandbox_test.results),
 'pass',(SELECT count(*) FROM sandbox_test.results WHERE status='PASS'),
 'fail',(SELECT count(*) FROM sandbox_test.results WHERE status='FAIL'),
 'baseline_gap',(SELECT count(*) FROM sandbox_test.results WHERE status='BASELINE_GAP'),
 'runtime_function_byte_identical',pg_get_functiondef('nexus_ct_live_command.runtime_snapshot()'::regprocedure)=(SELECT definition FROM sandbox_test.baseline_definitions WHERE name='runtime_snapshot'),
 'scenario_events_remaining',(SELECT count(*) FROM nexus_live_trading.reconciler_run_events),
 'scenario_adjudications_remaining',(SELECT count(*) FROM nexus_live_trading.reconciler_run_adjudications),
 'results',(SELECT jsonb_agg(to_jsonb(r) ORDER BY test_id) FROM sandbox_test.results r)
);
