# PostgreSQL Migration Lineage

## Verified authority

- **PostgreSQL version:** 18
- **Operational database:** `postgres`
- **Operational schema:** `nexus`
- **Migration authority:** `nexus.schema_migrations`
- **Gate verification:** Governance Gate 008, verified 2026-09-17
- **Verified maximum:** migration `124`
- **Verified count:** 124 migrations
- **Verified sequence:** continuous `1–124`

The runtime migration table is the authoritative record of applied migration
state. Gate 008 inspected only migration metadata in
`nexus.schema_migrations` inside a read-only transaction.

## Migrations 113–124

| Version | Identifier | Applied at | SHA-256 |
|---:|---|---|---|
| 113 | `113_nexus_decision_engine_v1.sql` | 2026-09-15 16:33:30.327172 -07 | `26bfc23e5bbeb94c43abf6d757c666683bda3fae36c3f31053442664abda6408` |
| 114 | `114_nexus_capital_preservation_posture.sql` | 2026-09-15 17:13:59.869013 -07 | `2a1b1420113db38be0bd9249ddd082c74e5e0bb6d28ae9d24ab57897c5aa899f` |
| 115 | `115_nexus_alpaca_shadow_mode.sql` | 2026-09-15 17:48:48.179525 -07 | `f3531e124ce2cd93c275117c7a050e67fcd0ed0dee3d99d981fabb30e752a42e` |
| 116 | `116_nexus_shadow_instrument_allowlist.sql` | 2026-09-15 18:11:02.684708 -07 | `e8cfcc8e2c0347fc1105a55083d61dedfb390bda87b8478f952cb917318cbda8` |
| 117 | `117_nexus_alpaca_paper_readonly_connection.sql` | 2026-09-15 19:53:32.974215 -07 | `e1b9e82e58b74b15de11c981e10cba818cf026b0357df383ff9e0348c2236480` |
| 118 | `118_nexus_alpaca_paper_approval_gated_orders.sql` | 2026-09-15 19:53:33.066340 -07 | `b5344c8ebf347868ab85a39773e1cbeea46ad1e4c59c6cfecbb7a578ad8dad39` |
| 119 | `119_nexus_paper_order_policy_health_view.sql` | 2026-09-15 19:58:43.535405 -07 | `9d10b7f7c1890369571a04425d78ebd9d4f5334dab8f36d2bf55bef89d1746a3` |
| 120 | `120_nexus_investing_engine_v1.sql` | 2026-09-15 21:09:57.947482 -07 | `f691dd7bf0bfdc29e6fd9801c2ed7d5c3e689c58612d09f32e9d0e900d2520c9` |
| 121 | `121_nexus_investing_engine_e5_verification.sql` | 2026-09-15 21:11:33.096588 -07 | `a515057223336e5f40039f9e5dc1d36aa7630a5be4aad704ec1567e142d223a7` |
| 122 | `122_nexus_limit_only_paper_orders.sql` | 2026-09-16 15:51:54.917569 -07 | `fdba2005ca3694f86da7bc4e315d352ccaa52354586cccabbd6c9adf76fbba1f` |
| 123 | `123_nexus_quote_gated_autonomous_previews.sql` | 2026-09-16 16:01:41.525984 -07 | `b09eeb7490880605c72072f93df38e17750caff11c41f89de8ac2421e0fd8896` |
| 124 | `124_nexus_research_radar_state_lanes.sql` | 2026-09-16 17:01:22.689627 -07 | `5fe1cd869674ab7d2b0c9e31d19d689ef21e765836ff509de57fcac66413f639` |

Migration 119 was a valid earlier checkpoint, not a conflicting state.
Migration 121 was applied before the September 15 backup described in the
local backup manifest. Migration 124 is the verified canonical maximum and
adds the Research Radar state-lane migration.

## Source recovery boundary

This document preserves migration metadata and provenance only. The actual SQL
bodies for migrations 1–124 have not been recovered into GitHub. They must not
be reconstructed from filenames, checksums, documentation, or assumptions.

The preserved PostgreSQL backup artifacts remain outside GitHub. They are not
source code and must not be committed as database dumps or raw data exports.
