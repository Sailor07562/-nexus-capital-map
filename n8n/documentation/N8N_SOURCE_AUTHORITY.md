# Nexus n8n Source Authority

Live n8n remains the operational workflow authority. The files preserved
under `n8n/workflows/local-candidates/` are exact local evidence and recovery
sources only. Their `LOCAL-CANONICAL-CANDIDATE` classification means strongest
local evidence; it does not establish current live state.

Live status for all four preserved candidates is `UNVERIFIED`. The active or
inactive value recorded in the source JSON is artifact state, not proof of the
current live n8n state. A later controlled read-only verification may promote a
candidate to `LIVE-VERIFIED-CANONICAL`, but GitHub preservation alone cannot do
so.

GitHub preservation does not authorize workflow activation, execution, import,
or modification. Historical raw JSON must remain byte-for-byte unchanged.
Credential-reference metadata may be preserved as metadata, but credential
values, secrets, private keys, credential-bearing connection strings, runtime
execution data, and private production records are prohibited.

Promotion sequence:

```text
LOCAL EVIDENCE
→ HASH/FINGERPRINT VERIFIED
→ SECURITY REVIEWED
→ GITHUB PRESERVED
→ LIVE VERIFIED
→ CANONICAL
```

The encrypted n8n credential backups remain permanently excluded from GitHub.
