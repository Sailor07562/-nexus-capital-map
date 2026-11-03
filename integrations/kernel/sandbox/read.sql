BEGIN READ ONLY;
SET LOCAL statement_timeout = '5s';
SET LOCAL lock_timeout = '1s';
SET LOCAL ROLE nexus_kernel_sandbox_ro;
SELECT nexus_sandbox.kernel_readiness() AS readiness;
ROLLBACK;
