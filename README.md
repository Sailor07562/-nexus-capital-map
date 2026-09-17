# Nexus Capital Map

Nexus Capital Map is a governed repository for the versioned artifacts that
support the capital map: PostgreSQL schema and migrations, n8n workflows,
research radar lanes, tracker and Airtable mappings, and operating procedures.

## Architecture

- **PostgreSQL** is the operational data authority. Versioned migrations,
  schema definitions, views, functions, reference data, and validation
  artifacts live under `/postgres`.
- **n8n** is the orchestration and workflow execution layer. Workflow exports
  and supporting documentation live under `/n8n`.
- **Research Radar** organizes research sources, lane definitions, and
  state-lane artifacts under `/research-radar`.
- **Integrations** contains tracker and Airtable mappings used for operational
  visibility and controlled integration under `/integrations`.
- **Docs** contains architecture, governance, and SOP material under `/docs`.
- **Config**, **tests**, and **scripts** hold safe templates, validation
  coverage, and repeatable repository tooling.

GitHub provides version control, provenance, recovery, and change history. It
does not independently acquire authority to modify production PostgreSQL or
n8n. Secrets, credentials, production dumps, and raw sensitive exports are
never committed; safe examples and templates must contain no real values.

See [`docs/governance/REPOSITORY_GOVERNANCE.md`](docs/governance/REPOSITORY_GOVERNANCE.md)
for the governing principles and promotion rules.
