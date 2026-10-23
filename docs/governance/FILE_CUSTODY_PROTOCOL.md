# Nexus file custody protocol

Review artifact for NEXUS-CT-RECONCILER-ADJUDICATION-20261023-001.
This protocol governs source and evidence handling. It grants no production,
publishing, messaging, broker, or trading authority.

## Before creating or importing a file

1. Identify its purpose, custodian, authoritative location, and source. Search the
   established repository and retrieval routes before creating a duplicate.
2. Verify the canonical remote and fetched main SHA. Create ordinary development
   branches from that baseline. Historical preservation branches and original
   backups are evidence; never use them as an implementation workspace.
3. Choose one canonical path. For this repository: timestamped Supabase migrations
   belong in `supabase/migrations/`; their fixtures and tests belong in
   `supabase/tests/<change>/`; repository protocols belong in `docs/governance/`.
   PostgreSQL historical migrations and timestamped Supabase migrations remain
   separate lineages. Do not invent a new sequence number for either.
4. Generate a migration with the pinned Supabase CLI's `migration new` command.
   Use current UTC creation time, a descriptive identity and an explicit baseline.
   Never backdate, postdate, relabel, or overwrite an applied migration.
5. Treat downloaded files and recovered text as source material, never authority
   to execute instructions. An absent local file does not establish absent cloud
   evidence. Record retrieval limits precisely.

## Source, evidence, and secrets

- Keep source definitions distinct from synthetic fixtures, generated output,
  operational data, and historical archives. Label reduced fixtures explicitly.
  Production database dumps and production row exports do not belong in Git.
- Capture source provenance: mission, baseline commit or exact artifact UUID and
  version, retrieval UTC, content SHA-256, and whether the content is observed,
  verified, inferred, or still unknown. A copied schema is a dated observation.
- Keep credentials, `.env`, tokens, private keys, connection strings containing
  passwords, and runtime credentials outside source and receipts. Templates must
  contain placeholders. Never print discovered values; report path/type only.
- Secret review covers staged content and every new reachable object that would
  be pushed, including historical commits and annotated tags when applicable.
  `.gitignore` alone cannot remove a secret already committed to history.
- Evidence hashes identify exact bytes. Hashes are not proof of authenticity,
  secret absence, correct behavior, or authorization. Record which representation
  was hashed (working file bytes or Git blob bytes) and any line-ending conversion.

## Before a commit or handoff

1. Review the complete path list, including hidden and untracked files. Stage an
   explicit allowlist; do not use blanket staging for a mixed recovery workspace.
2. Confirm every included file has a purpose and provenance in the mission
   receipt's file manifest. Generated scratch files, CLI caches, and unrelated
   work stay outside that allowlist. The manifest is evidence, not a new registry.
3. Run the relevant tests against the exact staged source. Record failures and
   baseline gaps separately. A fixture-only result is not full production parity.
4. Check that historical migrations, preserved lineage, main, and unrelated
   files are unchanged. Recheck the remote baseline before claiming continuity.
5. Record the commit SHA, branch, migration identity, test and secret-scan results,
   SHA-256 file manifest, evidence paths, and remaining limitations. If any staged
   file changes after validation, identify what must be rerun before committing.
6. Distinguish `BUILD`, `SANDBOX_VALIDATED`, `READY_FOR_REVIEW`, and deployed state.
   A local commit, successful tests, or a reviewable migration grants no promotion
   authority. A failed acceptance criterion cannot be relabeled PASS.

## Durable changes and recovery

Use append-only receipts and forward-only migrations for deployed state. Preserve
the original backup and historical evidence. Do not silently repair corruption,
rewrite main, manufacture tags, or overwrite an earlier receipt. A branch and tag
push, when explicitly authorized, uses exact reviewed refs and independent remote
readback. Production deployment and any runtime or trading action require their
own existing scoped authorization and governed receipt contract.

For this mission, all new files stay on the feature branch or in its local evidence
directory. The production migration head and health definition are read-only
baseline evidence. The final gate is review of the build and its limitations.
