# PostgreSQL Source Authority

## Authority boundaries

The PostgreSQL runtime migration table, `postgres.nexus.schema_migrations`, is
authoritative for the state of migrations applied to the operational database.
The verified current maximum at Gate 008 is migration `124`.

GitHub will become authoritative for reviewed migration source code only after
source recovery, sanitization, provenance review, and approval are complete.
Until then, this repository records metadata and provenance without claiming to
contain the applied SQL bodies.

## Immutability and identity

Existing applied migrations are immutable historical artifacts. Applied
migration numbers must never be reused, renumbered, silently replaced, or
recreated with different contents. A recovered source file must be reconciled
against its runtime filename and checksum before it is considered for review.

Migration metadata does not authorize execution or promotion. PostgreSQL
remains the operational data authority, and any future source recovery must
preserve the distinction between runtime state and reviewed GitHub source.

## Data protection

Production data and database dumps remain prohibited from GitHub. Credentials,
connection strings, API keys, tokens, private keys, raw exports, and other
sensitive runtime material must remain outside the repository.
