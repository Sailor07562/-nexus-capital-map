# Nexus Startup Verification Protocol

Anchor: #ANCHOR-NEXUS-GITHUB-CONSOLIDATION-STRUCTURE-001

## Mode Check

Before action, declare one current mode:

- Architecture/design only
- Local engineering mode
- Live PostgreSQL mode
- GitHub/repo mode

## Access Check

Verify access before action:

- Shell commands
- Intended project folder
- Git availability
- GitHub reachability and authentication
- PostgreSQL access, only when database work is requested
- Docker/n8n availability, only when integration work is requested

## Execution Rule

Designed does not mean executed.

Execution may only be claimed after successful tool output, command output, or
database readback proves it happened.

## Blocked Access Rule

If access is blocked, state the exact missing link and the shortest practical
fix.

