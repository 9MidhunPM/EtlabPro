# Trigger and Function Catalog

## 1) Timestamp Maintenance

### `fn_set_updated_at()`
- Type: `BEFORE UPDATE`
- Purpose: sets `NEW.updated_at = NOW()`
- Applied on:
  - `students`, `departments`, `programmes`, `academic_years`, `semesters`
  - `subjects`, `teachers`
  - `student_profile`, `student_guardians`, `bank_accounts`
  - `exam_sessions`, `internal_marks_events`, `attendance_summary`, `timetable_slots`, `university_exam_results`
  - `sync_runs`, `sync_meta`

## 2) Attendance Derivation

### `fn_compute_attendance_percentage()`
- Type: `BEFORE INSERT OR UPDATE OF classes_attended, classes_total` on `attendance_summary`
- Purpose:
  - Computes `percentage` deterministically from counts.
  - Guards divide-by-zero by returning `0` when total is `0`.

## 3) Subject Master Auto-Upsert

### `fn_upsert_subject_from_marks_event()`
- Type: `AFTER INSERT OR UPDATE` on `internal_marks_events`
- Purpose:
  - Ensures `subjects` row exists for `subject_code`.
  - Updates `subject_name` (from `raw_subject_name`) + `last_seen_at`.

### `fn_upsert_subject_from_timetable_slot()`
- Type: `AFTER INSERT OR UPDATE` on `timetable_slots`
- Purpose:
  - Ensures `subjects` row exists from timetable payload.
  - Updates `subject_name` + `last_seen_at`.

### `fn_upsert_subject_from_university_result()`
- Type: `AFTER INSERT OR UPDATE` on `university_exam_results`
- Purpose:
  - Ensures `subjects` row exists from exam payload.
  - Syncs canonical credit when available.
  - Updates `subject_name` + `last_seen_at`.

## 4) Sync State Derivation

### `fn_sync_meta_from_runs()`
- Type: `AFTER INSERT OR UPDATE OF status, finished_at, rows_written, error_msg` on `sync_runs`
- Purpose:
  - Auto-upserts `sync_meta` from terminal run states (`ok`, `error`, `skipped`).
  - Keeps freshness checks independent from run history.

## 5) Audit Logging

### `fn_audit_generic()`
- Type: `AFTER INSERT OR UPDATE OR DELETE` (selected high-value tables)
- Captured tables:
  - `internal_marks_events`
  - `attendance_summary`
  - `university_exam_results`
  - `student_profile`
  - `sync_runs`
- Purpose:
  - Writes row diffs to `audit_log` with operation, old/new JSON payload, table name, timestamp, actor.

## Trigger Flow Summary

1. Academic writes happen (`internal_marks_events` / `timetable_slots` / `university_exam_results`).
2. Subject upsert triggers maintain canonical `subjects` row.
3. Attendance trigger computes percentage pre-write.
4. Sync run completion updates `sync_meta` automatically.
5. Audit triggers capture critical changes for traceability.
