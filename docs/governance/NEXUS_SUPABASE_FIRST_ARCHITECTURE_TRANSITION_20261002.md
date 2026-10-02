# Nexus Supabase First Architecture Transition

Update ID: `NDU-20261002-001`  
Date: 2026-10-02  
Decision status: `APPROVED_TARGET`  
Implementation status: `CUTOVER_PENDING`

The owner approved a Supabase-first architecture for portable Nexus operations and authorized remote transition preparation. Laptop-dependent work is deferred. This decision selects the destination; it does not represent a completed semantic-authority transfer.

## Approved target

| Surface | Target role |
|---|---|
| Supabase | Primary operating database |
| GitHub | Versioned code, SQL, governance and change history |
| Google Drive | Evidence, working documents, backups and recovery packages |
| Local PostgreSQL | Future testing and recovery environment, subject to verification |
| n8n | Governed workflow executor |
| Command Tower | Coordination and status display |
| Airtable and Sheets | Explicitly bounded registries and projections |

Supabase is itself a PostgreSQL environment. The authority transition concerns which database deployment owns which records; it is not a replacement of PostgreSQL as the database technology.

## Verified remote preparation

On October 2, the authenticated management connection read database `postgres` in Supabase project `husnmxgsxasoinhklpfx` (`nexus_supabase_canonical`). It confirmed 206 base tables and 269 views in schema `nexus`. Project status was `ACTIVE_HEALTHY`.

The deployed `nexus-cloud-gateway` was ACTIVE at version 6 with JWT verification enabled. Its inspected source still sets `local_postgresql_authority_preserved=true` in both read and request-intake contracts. This source inspection was not a fresh HTTP execution test of its endpoints.

A single append-only transition record was inserted into `nexus.governance_framework_bindings` and successfully read back:

- Framework code: `nexus_remote_primary_transition_20261002`
- Binding ID: `dd93d242-ea37-4eeb-ba02-fcc87a164df3`
- Applicability: `verification_required`
- Prior binding superseded: none

The record means approved target with implementation pending. It does not grant verified applicability to the transition or supersede existing governance bindings.

## Current boundary during transition

Previously authorized remote Supabase work may continue within its existing scope. Existing deployed authority and gateway contracts remain in force until a verified, reviewed cutover updates them. The dated Command Tower inventory and adapter registry describe that existing deployment and should not be relabeled as proof of an implemented remote cutover.

The September 30 evidence record identifies local-only mission/MOS governance objects alongside cloud-only controls. Those local-only records must be reconciled before claiming a complete authority transfer. Historical local counts are not current laptop verification.

No architecture promotion implies a new broker, order, trade, transfer, payment, capital-allocation, workflow-execution or automatic-promotion permission. Existing controls remain applicable.

## Completion requirements

1. Identify authoritative, replicated, experimental and intake-only remote objects and their write routes.
2. Reconcile local-only records and local executor/display dependencies when the laptop is available.
3. Preserve independent database backups and separately preserve functions, configuration and any stored files.
4. Verify isolated restoration and document rollback.
5. Align the gateway, versioned governance, adapter registry and projection contracts with the accepted ownership map.
6. Record cutover evidence and review before promotion.

Folder organization remains on hold. No existing Drive folder or file is moved, renamed, relabeled or deleted by this decision.

## Evidence

- [October 2 remote transition receipt](https://drive.google.com/file/d/1-xQWdJy8Sz6dJndH1gRNzG0e65Apno5A/view?usp=drivesdk)
- [September 30 access and authority record](https://drive.google.com/file/d/178xsQDETwd5lk3R0_qReDSVV_zaR0Ly7/view)
- [Repository governance](REPOSITORY_GOVERNANCE.md)
- [September 24 adapter inventory](../../command-tower/CommandTower-Adapter-Inventory.md)
- [September 24 adapter registry](../../command-tower/command-tower-adapter-registry.json)
