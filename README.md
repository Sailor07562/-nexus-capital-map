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

## Local Interface Shell

Open `interface/index.html` locally for the Command Tower mock/read-only shell.
It contains no database connection, credentials, workflow execution, or live
system controls.

## Operating Rule

Do not claim execution unless it was verified by tool output.

Before database or repo work, verify the current operating mode and access path.
