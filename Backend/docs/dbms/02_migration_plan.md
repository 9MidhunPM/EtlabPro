# Migration Plan: Current Schema → Canonical v3

## Strategy

Use an additive, reversible migration path with compatibility views. Avoid immediate destructive changes.

## Phase A — Foundation (No breaking changes)

1. Apply enum types and master/reference tables from `01_canonical_schema.sql`:
   - `departments`, `programmes`, `academic_years`, `semesters`, `teachers`
2. Add migration ledger table `_migrations` if not present.
3. Seed master data from observed profile/subject/result values.

Rollback: drop newly added reference tables only if no downstream dependencies created.

## Phase B — New normalized fact tables

1. Create:
   - `internal_marks_events`
   - `attendance_summary`
   - `timetable_slots`
   - `exam_sessions`
   - `university_exam_results`
   - `sync_runs`, enhanced `sync_meta`, `audit_log`
2. Create trigger functions + trigger attachments.
3. Create new views (`v_semester_gpa`, `v_student_summary`, `v_gpa_progression`).

Rollback: disable new write paths in app; preserve legacy tables untouched.

## Phase C — Backfill

Backfill in deterministic order:

1. `students` (already primary source)
2. `subjects` (merge legacy values)
3. `departments/programmes/academic_years/semesters` (distinct extraction)
4. `student_profile` (map legacy text fields; unresolved values remain in `extra_fields`)
5. `exam_sessions` from legacy `university_results.exam_id`
6. fact tables (`internal_marks_events`, `attendance_summary`, `timetable_slots`, `university_exam_results`)
7. sync tables (`sync_meta` + synthetic historic `sync_runs` if desired)

Validation after backfill:

- Row-count parity by student/category.
- FK integrity checks (no orphan rows).
- Random sample comparisons for summary metrics (attendance %, latest CGPA/SGPA).

## Phase D — App dual-read / dual-write window

1. Update `app/db/*.py` write modules to write **new tables**.
2. Keep API output shape unchanged using compatibility views (or projection mapping in DB modules).
3. Optionally dual-write legacy + new for one release cycle.

## Phase E — Cutover

1. Route all reads to canonical tables/views.
2. Freeze legacy table writes.
3. Archive legacy rows if needed.
4. Remove dual-write logic.

## Phase F — Deprecation (after stabilization)

1. Rename legacy tables to `_legacy_*` first.
2. Observe for one cycle.
3. Drop legacy tables and legacy triggers if no regressions.

## Operational Guardrails

- One migration file per phase and record in `_migrations`.
- Use transactions around each migration step (`BEGIN ... COMMIT`).
- Run dry-run on staging Supabase project before production.
- For high-risk migrations (backfill), batch by student and log checkpoints.
