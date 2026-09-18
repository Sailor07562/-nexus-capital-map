# Command Tower Last Known Good Verification

Status: **VERIFIED AS CURRENT RESTORATION REFERENCE**

Verified: 2026-09-18

## Current checkpoint

- Local package: `C:\Users\GBT\Documents\Codex\2026-09-17\a\outputs\nexus-capital-map-backup-20260917-191532.zip`
- Size: `80,186,435` bytes
- SHA-256: `CFB3382523EB3C0A1045CDA2D9CE35C9B9661BDD6E0389D2FD9F650810369234`
- Backup receipt: `nexus-capital-map-backup-20260917-191532-receipt.md`
- Live lineage recorded by receipt: migration `262`
- Live action authority recorded by receipt: `blocked`

## Read-only verification performed

- Local ZIP exists and its size/hash match the backup receipt.
- Archive contains `postgres/postgres-full-20260917-191532.dump`.
- Archive contains `postgres/postgres-full-20260917-191532.restore-list.txt` with `2,227` lines.
- Archive contains migrations `256` through `262` and the SHA-256 manifest.
- No restore was executed.
- No live database, migration, workflow, credential, Airtable, Tracker, trading, or capital state was changed.

## Drive verification

- Destination: [Nexus Capital Map Backups](https://drive.google.com/drive/folders/1_kDKJEsUvkroK3y5zqzgSDTLdGuHbCN6)
- Uploaded package: [nexus-capital-map-backup-20260917-191532.zip](https://drive.google.com/file/d/1WgR-mrreEqSk_U3kEvyhm803aTQcVYX_/view)
- Drive metadata size: `80,186,435` bytes
- Drive parent: `Nexus Capital Map Backups`

## Restore boundary

This is a restoration reference, not an authorization to restore. Any rehearsal must target a new empty database and must be separately reviewed. The live database must not be overwritten as a rollback shortcut.

## Older checkpoint note

The 2026-09-17 emergency checkpoint at `C:\Users\GBT\Documents\NexusEmergencyBackups\NEXUS_EMERGENCY_BACKUP_20260917_071056` also passed local verification, but its PostgreSQL snapshot was migration `124`; the later migration-262 package above is the current reference for Command Tower work.


