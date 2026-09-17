# Repository Governance

## Authority and system boundaries

1. Production PostgreSQL remains the operational data authority.
2. GitHub is the version-control, provenance, recovery, and change-history
   layer.
3. n8n remains the orchestration and workflow execution layer.
4. Tracker and Airtable remain operational visibility and integration layers.
5. GitHub does not independently acquire authority to modify production
   PostgreSQL or n8n.

## Controlled change

6. Changes are developed on branches or worktrees and reviewed before
   promotion to `main`.
7. Existing production artifacts must be inventoried and sanitized before
   import into this repository.
8. Secrets and credentials are prohibited from Git.
9. Production database dumps are prohibited from Git.

Sanitized, reviewed source artifacts may be versioned when they contain no
secrets, credentials, production dumps, or uncontrolled personal data. Safe
templates must use placeholders and must not contain live values.

## Governing priorities

The following priorities govern design and operation:

- Governance > Automation
- Relational > Blob
- Replay-safe > Fast
- Controlled writes > Direct writes

These priorities apply to migrations, workflow design, research-lane
processing, and tracker integrations. Validation, provenance, and review must
remain possible even when automation is unavailable.
