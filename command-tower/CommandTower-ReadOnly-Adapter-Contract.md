# Command Tower Read-only Adapter Contract

Status: bounded fixture, aggregate readback, and approved live refresh implemented; direct browser binding remains intentionally disabled.

## Purpose

Expose only the approved PostgreSQL view inventory to the Command Tower shell after the bounded role and view readback gates pass.

## Source and authority

- Canonical view evidence: `command-tower-view-readback.json`
- Canonical aggregate evidence: `command-tower-summary-readback.json`
- Adapter fixture: `command-tower-readonly-adapter.json`
- Database authority: PostgreSQL
- Role: `nexus_command_tower_ro`
- Database: `postgres` on `127.0.0.1:5432`

## Allowed payload

The fixture contains view identity, existence, row-presence status, column counts, and scalar aggregate summaries. It does not contain row values, credentials, connection strings, or write operations.

## Hard boundaries

- No browser-to-database connection.
- No INSERT, UPDATE, DELETE, DDL, migration, workflow, or trading control.
- No raw row export.
- No Airtable or Tracker writes.
- Human review and promotion gates remain unchanged.

## Verification

The fixture represents the successful readback of 8 of 8 approved views plus 8 aggregate-only summaries. The approved local refresh path has been executed successfully. It is suitable for rendering readiness, provenance, and scalar health summaries only. Any future direct browser adapter must preserve this payload boundary and re-run the bounded role/readback verification before replacing the fixture.


