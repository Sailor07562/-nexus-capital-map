BEGIN READ ONLY;
SET LOCAL statement_timeout = '5s';
SELECT jsonb_build_object(
  'role_is_bounded', (SELECT NOT (rolcanlogin OR rolsuper OR rolcreatedb OR
    rolcreaterole OR rolreplication OR rolbypassrls OR rolinherit)
    FROM pg_roles WHERE rolname = 'nexus_kernel_sandbox_ro'),
  'no_elevated_memberships', NOT EXISTS (
    SELECT 1 FROM pg_auth_members WHERE member = 'nexus_kernel_sandbox_ro'::regrole),
  'no_nonowner_reader_members', NOT EXISTS (
    SELECT 1 FROM pg_auth_members WHERE roleid = 'nexus_kernel_sandbox_ro'::regrole
      AND member <> 'postgres'::regrole),
  'function_is_invoker_stable', (SELECT NOT prosecdef AND provolatile = 's'
    AND proconfig @> ARRAY['search_path=""', 'row_security=on']
    FROM pg_proc WHERE oid = 'nexus_sandbox.kernel_readiness()'::regprocedure),
  'no_api_role_execution', NOT EXISTS (
    SELECT 1 FROM (VALUES ('anon'), ('authenticated'), ('service_role'), ('authenticator')) r(role_name)
    WHERE has_function_privilege(r.role_name, 'nexus_sandbox.kernel_readiness()', 'EXECUTE')
       OR pg_has_role(r.role_name, 'nexus_kernel_sandbox_ro', 'SET')),
  'no_schema_creation', NOT EXISTS (
    SELECT 1 FROM pg_namespace WHERE nspname NOT LIKE 'pg_temp_%'
      AND has_schema_privilege('nexus_kernel_sandbox_ro', oid, 'CREATE')),
  'no_database_create_privilege', NOT has_database_privilege(
    'nexus_kernel_sandbox_ro', current_database(), 'CREATE'),
  'no_api_schema_access', NOT EXISTS (
    SELECT 1 FROM (VALUES ('anon'), ('authenticated'), ('service_role'), ('authenticator')) r(role_name)
    WHERE has_schema_privilege(r.role_name, 'nexus_sandbox', 'USAGE')),
  'no_whole_table_select_grants', NOT EXISTS (
    SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname IN ('public', 'nexus_sandbox') AND c.relkind IN ('r', 'v', 'm', 'f', 'p')
      AND has_table_privilege('nexus_kernel_sandbox_ro', c.oid, 'SELECT')),
  'no_business_write_privileges', NOT EXISTS (
    SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname IN ('public', 'nexus_sandbox') AND c.relkind IN ('r', 'v', 'm', 'f', 'p')
      AND (has_table_privilege('nexus_kernel_sandbox_ro', c.oid, 'INSERT,UPDATE,DELETE,TRUNCATE,TRIGGER')
        OR has_any_column_privilege('nexus_kernel_sandbox_ro', c.oid, 'INSERT,UPDATE'))),
  'seven_select_only_policies', (SELECT count(*) = 7 AND bool_and(cmd = 'SELECT'
    AND roles = ARRAY['nexus_kernel_sandbox_ro']::name[] AND with_check IS NULL)
    FROM pg_policies WHERE schemaname = 'nexus_sandbox' AND policyname = 'kernel_reader_select'),
  'all_sandbox_tables_keep_rls', (SELECT bool_and(c.relrowsecurity)
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'nexus_sandbox' AND c.relkind = 'r'),
  'no_existing_mutator_execution', NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname IN ('public', 'nexus_sandbox')
      AND p.oid <> 'nexus_sandbox.kernel_readiness()'::regprocedure
      AND has_function_privilege('nexus_kernel_sandbox_ro', p.oid, 'EXECUTE'))
) AS security_checks;
ROLLBACK;
