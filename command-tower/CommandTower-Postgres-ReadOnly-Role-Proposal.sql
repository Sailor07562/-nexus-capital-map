-- NEXUS COMMAND TOWER
-- PostgreSQL read-only binding role proposal
--
-- STATUS: REVIEW ONLY — NOT EXECUTED
-- Architecture remains frozen. This file contains no active database command.
-- Do not uncomment or run until the target, owner, password handoff, and rollback
-- procedure have been explicitly approved.

-- Proposed role identity
-- CREATE ROLE nexus_command_tower_ro
--     LOGIN
--     NOSUPERUSER
--     NOCREATEDB
--     NOCREATEROLE
--     NOINHERIT
--     NOREPLICATION
--     NOBYPASSRLS;

-- Set the session default to read-only. This is a safety default, not a substitute
-- for privilege minimization.
-- ALTER ROLE nexus_command_tower_ro SET default_transaction_read_only = on;

-- Password handoff must occur through the secure local prompt; never embed a secret.
-- In psql, after role creation and before use:
-- \password nexus_command_tower_ro

-- Proposed database/schema boundary
-- GRANT CONNECT ON DATABASE postgres TO nexus_command_tower_ro;
-- GRANT USAGE ON SCHEMA nexus TO nexus_command_tower_ro;
-- REVOKE CREATE ON SCHEMA nexus FROM nexus_command_tower_ro;

-- Proposed data boundary: existing Nexus objects only.
-- GRANT SELECT ON ALL TABLES IN SCHEMA nexus TO nexus_command_tower_ro;
-- GRANT SELECT ON ALL SEQUENCES IN SCHEMA nexus TO nexus_command_tower_ro;

-- Preserve future read access without granting write capability.
-- ALTER DEFAULT PRIVILEGES IN SCHEMA nexus
--     GRANT SELECT ON TABLES TO nexus_command_tower_ro;

-- Do not grant any of the following:
-- INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, CREATE,
-- ALTER, DROP, EXECUTE on mutation functions, role membership, or ownership.

-- Required post-approval read-only verification
-- SELECT rolname, rolsuper, rolcreaterole, rolcreatedb, rolcanlogin,
--        rolreplication, rolbypassrls
-- FROM pg_roles
-- WHERE rolname = 'nexus_command_tower_ro';

-- SELECT has_database_privilege('nexus_command_tower_ro', 'postgres', 'CONNECT');
-- SELECT has_schema_privilege('nexus_command_tower_ro', 'nexus', 'USAGE');
-- SELECT has_schema_privilege('nexus_command_tower_ro', 'nexus', 'CREATE');
-- SELECT has_table_privilege('nexus_command_tower_ro', 'nexus.schema_migrations', 'SELECT');
-- SELECT has_table_privilege('nexus_command_tower_ro', 'nexus.schema_migrations', 'INSERT');
-- SELECT has_table_privilege('nexus_command_tower_ro', 'nexus.schema_migrations', 'UPDATE');
-- SELECT has_table_privilege('nexus_command_tower_ro', 'nexus.schema_migrations', 'DELETE');

-- Required adapter-session verification after approved handoff
-- SELECT current_database(), current_user, session_user,
--        current_setting('transaction_read_only'),
--        current_setting('default_transaction_read_only');

-- Acceptance criteria:
-- 1. Current user is nexus_command_tower_ro, not postgres.
-- 2. rolsuper, rolcreaterole, rolcreatedb, rolreplication, and rolbypassrls are false.
-- 3. CONNECT and nexus USAGE are true; nexus CREATE is false.
-- 4. SELECT is true for required objects; INSERT/UPDATE/DELETE are false.
-- 5. Adapter session reports transaction_read_only = on.
-- 6. No Command Tower adapter is connected until all criteria are read back.


