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

## B-001 Live-Status Verification

The B-000 scaffold now has its first authorized operational capability:
B-001 read-only live-status verification. The Operations Dashboard shows
evidence-bearing `verified`, `blocked`, and `failed` status. All other pages
remain placeholders.

```bash
npm start
```

Open http://localhost:8080. For full startup instructions, see
[`docs/operating-protocols/B-000_STARTUP.md`](docs/operating-protocols/B-000_STARTUP.md).

It contains no SQL, database authentication, credentials, writes, workflow
execution, telemetry controls, or automation controls. See
[`B-001_LIVE_STATUS_VERIFICATION.md`](docs/operating-protocols/B-001_LIVE_STATUS_VERIFICATION.md).

## Prior Local Interface Shell

`interface/index.html` remains the pre-existing mock/read-only shell and is
preserved as prior committed work.

## Operating Rule

Do not claim execution unless it was verified by tool output.

Before database or repo work, verify the current operating mode and access path.
