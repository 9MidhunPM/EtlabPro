# Data Dictionary (Canonical v3)

## students

- `id`: internal immutable primary key.
- `roll_number`: business identifier used by API and sync workflows.
- `admission_number`: institute identifier.
- `etlab_user_id`: ETLAB identifier used for attendance scraping.

## departments / programmes

- Department and programme masters prevent free-text drift from profile data.
- Used to standardize reporting and filtering.

## academic_years / semesters

- Academic calendar model.
- `semesters` are linked to programme and optionally year.
- `student_profile.current_semester_id` models the student’s current enrollment context.

## subjects

- Canonical subject master by `subject_code`.
- `subject_name`/`credit` are consolidated here.
- Auto-maintained by subject upsert triggers from ingestion tables.

## teachers

- Optional teacher master for timetable normalization.
- `teacher_name_raw` in timetable keeps source fallback when teacher mapping is not resolved.

## student_profile

- Student one-to-one profile record.
- Normalized references to department/programme/semester.
- Long tail ETLAB-specific fields remain in `extra_fields` for forward compatibility.

## student_guardians

- Multi-row guardian details (`father`, `mother`, `guardian`, etc.) via `relation_type`.

## bank_accounts

- Isolated student finance/bank details.
- One row per student.

## exam_sessions

- Master for university exam events (`exam_id`, `exam_name`, month/year/slot).
- Shared by all subject-level university results for that exam.

## internal_marks_events

- Fine-grained internal assessment rows.
- Unique key: student + subject + semester + exam_number + exam_type.
- `raw_subject_name` preserves source text without breaking normalization.

## attendance_summary

- Subject-level attendance aggregate by student (and optional semester).
- `percentage` is derived by trigger from `classes_attended/classes_total`.

## timetable_slots

- Timetable facts by day/period and student.
- Optional subject and teacher mappings.
- Unique slot constraint prevents duplicate periods for same student/semester/day.

## university_exam_results

- Subject-level university exam results.
- Linked to `exam_sessions` and `subjects`.
- Stores `grade`, `result_status`, and metrics (`sgpa`, `cgpa`, `earned_credit`) captured from source.

## sync_runs

- Full run history for each category sync execution.
- Records lifecycle (`running|ok|error|skipped`), row count, and error metadata.

## sync_meta

- Latest sync state per student/category.
- Kept automatically up-to-date from `sync_runs` terminal states.

## audit_log

- Generic mutable-history table for traceability.
- Stores table name, operation, before/after JSON payload, actor, and timestamp.
