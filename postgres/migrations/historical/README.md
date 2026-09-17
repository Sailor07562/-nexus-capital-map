# Historical Migration Preservation

The SQL files in this directory are exact historical migrations already
applied to Nexus PostgreSQL. They are preserved for provenance and recovery.

These files must not be edited, sanitized, reformatted, normalized, annotated,
redacted, or automatically executed. Any recovery or execution requires a
separately governed procedure.

Future corrections must use a new migration number. An applied migration
number must never be reused, renumbered, silently replaced, or recreated with
different contents.

Migrations 113–123 have verified exact duplicate provenance in the September
16 project backup. Migration 124 currently has one verified canonical working
source copy.

Migration 119 is classified `STANDARD-HISTORICAL`. Migrations 113, 114, 115,
116, 117, 118, 120, 121, 122, 123, and 124 are classified
`RESTRICTED-HISTORICAL`. Restricted classification indicates additional
review and control for operational architecture, references, endpoints, roles,
permissions, or topology; it does not imply that credentials are present.

The files must remain byte-for-byte identical to their verified runtime
provenance. See `PROVENANCE.md` for source paths, hashes, duplicate status,
and verification details.
