# Nexus Command Tower

Anchor: #ANCHOR-NEXUS-GITHUB-CONSOLIDATION-STRUCTURE-001

Status: STRUCTURE FROZEN

## Mission

Nexus Command Tower is the GitHub consolidation layer for Nexus.

It preserves SQL migrations, governance documents, engine and lane files,
backup notes, handoff prompts, integration exports, and operating protocols in
one version-controlled home.

GitHub does not replace PostgreSQL, Drive, Tracker, Airtable, Docker, n8n, or
Work Mode. It is the traceability, rollback, consolidation, and collaboration
layer.

## B-002 Authenticated Live-Status Verification

The restored CT surface now has B-002 authenticated read-only PostgreSQL
verification. The Operations Dashboard shows evidence-bearing `verified`,
`blocked`, and `failed` status. PostgreSQL is marked verified only after CT
authenticates as `nexus_command_tower_ro` and executes the identity query
documented in [`B-002_AUTHENTICATED_POSTGRES_VERIFICATION.md`](docs/operating-protocols/B-002_AUTHENTICATED_POSTGRES_VERIFICATION.md).

```bash
npm start
```

Open http://localhost:8080. For full startup instructions, see
[`docs/operating-protocols/B-000_STARTUP.md`](docs/operating-protocols/B-000_STARTUP.md).

The B-002 check does not perform SQL writes, DDL, migrations, privilege
changes, workflow execution, broker calls, or automation controls. The earlier
B-001 TCP-only contract is retained as historical reference in
[`B-001_LIVE_STATUS_VERIFICATION.md`](docs/operating-protocols/B-001_LIVE_STATUS_VERIFICATION.md).

## Prior Local Interface Shell

`interface/index.html` remains the pre-existing mock/read-only shell and is
preserved as prior committed work.

## Operating Rule

Do not claim execution unless it was verified by tool output.

Before database or repo work, verify the current operating mode and access path.
