# Redaction Rules

Anchor: #ANCHOR-NEXUS-GITHUB-CONSOLIDATION-STRUCTURE-001

## Never Commit

- Passwords
- API keys
- Access tokens
- Private keys
- Bank account data
- Brokerage account data
- Raw personal financial exports
- Unfiltered PostgreSQL dumps
- `.env` files
- Browser session data

## Redact Before Commit

- Account numbers
- Routing numbers
- Login names
- Email confirmation identifiers
- Personal addresses not required for the artifact
- Internal URLs containing tokens or signatures

## Allowed When Sanitized

- SQL migration logic
- Schema definitions
- Read-only verification queries
- Governance doctrine
- Engine specs
- Backup manifests without secrets
- Workflow exports with credentials removed

