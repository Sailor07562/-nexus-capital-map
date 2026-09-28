# Command Tower Checkpoint — Tabbed Header Locked

Date: 2026-09-27

Checkpoint ID: `CT-RESTORE-V7-TABBED-HEADER-20260927`

Locked source commit: `10695749f673fa2b9181383d17265bb8d0a93204`

Parent restore anchor: `CT-B002-RESTORED-20260927`

## What is locked

- The Nexus Tree emblem remains in the persistent Command Tower header.
- The North Star remains in the persistent Command Tower header.
- The landscape backdrop and header identity treatment are preserved.
- The Command Tower lanes open as individual tabs.
- The locked tab set includes Overview, Nexus Watch, Capital Map Coverage,
  Future Trades, Intake Engine, Adapter Registry, Governance Engine,
  Infrastructure Context, Capital Deployment Boundary, Paper Receipt
  Reconciliation, Workflow Hygiene, Nexus Architecture, Investing Engine,
  Engine Canon, Maintenance Queue, Data, Tools, Live Status, n8n Sandbox,
  Foundation, and Boundaries.

## Verification

Endpoint: `http://127.0.0.1:8080/api/live-status`

```text
contract: B-002 authenticated read-only PostgreSQL verification
PostgreSQL state: verified
current_user: nexus_command_tower_ro
current_database: postgres
query: SELECT current_user, current_database();
```

The current browser surface was verified at:

`http://127.0.0.1:8080/#/paper-reconciliation`

The working tree was clean at lock time. JavaScript syntax and Git whitespace
checks passed.

## Restore instruction

For this exact CT surface, restore:

```powershell
git switch --detach CT-RESTORE-V7-TABBED-HEADER-20260927
node --env-file=.env app/server.js
```

Do not replace the header artwork, collapse the lanes into one page, or use
B-001 TCP-only evidence as a substitute for B-002 authenticated verification.
The surface remains read-only: no SQL writes, DDL, migrations, privilege
changes, n8n mutation, broker action, trade, or transfer.
