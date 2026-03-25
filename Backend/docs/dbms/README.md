# EtlabPro DBMS Blueprint (Normalized, Supabase-Compatible)

This folder contains the implementation-ready database architecture for the next major schema version.

## Files

- `01_canonical_schema.sql` — canonical DDL (tables, constraints, indexes, triggers, views)
- `02_migration_plan.md` — phased rollout + backfill + cutover strategy
- `03_relationships.md` — complete FK/cardinality/cascade matrix
- `04_triggers_catalog.md` — trigger/function behavior catalog
- `05_erd_mermaid.md` — full ER diagram in Mermaid
- `06_schema.dbml` — DBML source for dbdiagram.io
- `07_data_dictionary.md` — business meaning of major tables/columns

## Design Goals

- Preserve Supabase PostgreSQL compatibility.
- Normalize core entities and reduce duplication.
- Keep current API contracts stable via compatibility views during migration.
- Enforce data quality with explicit `CHECK`, `UNIQUE`, FK, and enum constraints.
- Add auditable sync lifecycle with `sync_runs` + `sync_meta`.

## Rollout

Apply in phases from `02_migration_plan.md`; avoid big-bang replacement.
