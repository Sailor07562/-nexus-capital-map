# B-001 — Live-Status Verification

Status: AUTHORIZED IMPLEMENTATION

## Purpose

Provide the Command Tower's first operational read-only answer to: **what is
actually live, verified, blocked, or failed right now?**

## Boundary

- No SQL or database authentication. PostgreSQL is only probed by TCP when an
  explicit host is configured.
- No writes, automations, workflow execution, credential collection, or secret
  storage.
- No status is inferred from configuration alone. A configured but unreachable
  target is `failed`; an unconfigured target is `blocked`.
- GitHub verification in B-001 proves the local checkout and its declared
  origin. It does not prove remote GitHub reachability.

## Verification endpoint

`GET /api/live-status` returns a no-store JSON evidence packet. The Operations
Dashboard calls it only when opened or when the operator presses **Verify now**.

## Supported B-001 checks

| System | Proof | State when not configured |
| --- | --- | --- |
| Command Tower | The Node process serves the response | n/a |
| GitHub repository | Local Git metadata, branch, origin, and working-tree state | `failed` if unreadable |
| PostgreSQL | TCP connection only | `blocked` |
| n8n | Unauthenticated HTTP HEAD request | `blocked` |
| Nexus Capital Tracker | Unauthenticated HTTP HEAD request | `blocked` |
| Airtable / Google Drive | No adapter exists in B-001 | `blocked` |

## Configuration

Copy `.env.example` to `.env` only if local service endpoints are available.
Do not place credentials in the file.
