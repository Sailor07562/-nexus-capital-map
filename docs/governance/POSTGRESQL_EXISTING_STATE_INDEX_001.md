# PostgreSQL Existing State Index 001

Anchor: #ANCHOR-NEXUS-COMMAND-TOWER-POSTGRESQL-STATE-001

Status: BASELINE TEMPLATE — NOT YET READ FROM LIVE POSTGRESQL

## Purpose

This index is the Command Tower's controlled record of the PostgreSQL state
that already exists. It does not define, alter, migrate, or infer the live
database. PostgreSQL remains the system of record.

## Current Readback Status

| Check | Status | Evidence |
| --- | --- | --- |
| Live PostgreSQL access verified | Not verified in this repository session | None |
| Database inventory captured | Not captured | None |
| Schema inventory captured | Not captured | None |
| Existing migrations reconciled | Not captured | None |
| Backup/checkpoint reference verified | Not captured | None |

## Required Read-Only Capture

When live PostgreSQL mode is explicitly authorized, record only readback from
the intended database target:

- server and database identity (sanitized)
- PostgreSQL version
- schema inventory
- tables, views, sequences, functions, and extensions
- ownership and role model (sanitized)
- migration-history location and current version, if present
- approved backup/checkpoint reference

## Governing Rules

- No SQL in this file is executable authority.
- No state may be marked verified without command output or database readback.
- No modification is permitted while this index is in baseline-template status.
- Sensitive names, URLs, identities, credentials, and raw financial data remain
  outside this repository unless sanitized under `security/redaction-rules.md`.

