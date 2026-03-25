# Relationships Matrix

## Core

| Parent | Child | Cardinality | FK | On Delete | On Update |
|---|---|---|---|---|---|
| students | student_profile | 1 : 0..1 | `student_profile.student_id -> students.id` | CASCADE | CASCADE |
| students | student_guardians | 1 : 0..N | `student_guardians.student_id -> students.id` | CASCADE | CASCADE |
| students | bank_accounts | 1 : 0..1 | `bank_accounts.student_id -> students.id` | CASCADE | CASCADE |
| departments | programmes | 1 : 0..N | `programmes.department_id -> departments.id` | SET NULL | CASCADE |
| departments | subjects | 1 : 0..N | `subjects.department_id -> departments.id` | SET NULL | CASCADE |
| programmes | semesters | 1 : 0..N | `semesters.programme_id -> programmes.id` | SET NULL | CASCADE |
| programmes | student_profile | 1 : 0..N | `student_profile.programme_id -> programmes.id` | SET NULL | CASCADE |
| academic_years | semesters | 1 : 0..N | `semesters.academic_year_id -> academic_years.id` | SET NULL | CASCADE |
| semesters | student_profile | 1 : 0..N | `student_profile.current_semester_id -> semesters.id` | SET NULL | CASCADE |

## Academic Facts

| Parent | Child | Cardinality | FK | On Delete | On Update |
|---|---|---|---|---|---|
| students | internal_marks_events | 1 : 0..N | `internal_marks_events.student_id -> students.id` | CASCADE | CASCADE |
| students | attendance_summary | 1 : 0..N | `attendance_summary.student_id -> students.id` | CASCADE | CASCADE |
| students | timetable_slots | 1 : 0..N | `timetable_slots.student_id -> students.id` | CASCADE | CASCADE |
| students | university_exam_results | 1 : 0..N | `university_exam_results.student_id -> students.id` | CASCADE | CASCADE |
| subjects | internal_marks_events | 1 : 0..N | `internal_marks_events.subject_code -> subjects.subject_code` | RESTRICT | CASCADE |
| subjects | attendance_summary | 1 : 0..N | `attendance_summary.subject_code -> subjects.subject_code` | RESTRICT | CASCADE |
| subjects | timetable_slots | 1 : 0..N | `timetable_slots.subject_code -> subjects.subject_code` | RESTRICT | CASCADE |
| subjects | university_exam_results | 1 : 0..N | `university_exam_results.subject_code -> subjects.subject_code` | RESTRICT | CASCADE |
| semesters | internal_marks_events | 1 : 0..N | `internal_marks_events.semester_id -> semesters.id` | SET NULL | CASCADE |
| semesters | attendance_summary | 1 : 0..N | `attendance_summary.semester_id -> semesters.id` | SET NULL | CASCADE |
| semesters | timetable_slots | 1 : 0..N | `timetable_slots.semester_id -> semesters.id` | SET NULL | CASCADE |
| semesters | exam_sessions | 1 : 0..N | `exam_sessions.semester_id -> semesters.id` | SET NULL | CASCADE |
| exam_sessions | university_exam_results | 1 : 0..N | `university_exam_results.exam_session_id -> exam_sessions.id` | CASCADE | CASCADE |

## Timetable/Teacher

| Parent | Child | Cardinality | FK | On Delete | On Update |
|---|---|---|---|---|---|
| teachers | timetable_slots | 1 : 0..N | `timetable_slots.teacher_id -> teachers.id` | SET NULL | CASCADE |

## Sync & Audit

| Parent | Child | Cardinality | FK | On Delete | On Update |
|---|---|---|---|---|---|
| students | sync_runs | 1 : 0..N | `sync_runs.student_id -> students.id` | CASCADE | CASCADE |
| students | sync_meta | 1 : 0..N | `sync_meta.student_id -> students.id` | CASCADE | CASCADE |
| sync_runs | sync_meta | Derived via trigger | `fn_sync_meta_from_runs()` | N/A | N/A |

## Uniqueness Rules

- `students.roll_number` unique.
- `student_profile.student_id` unique (strict 1:1).
- `student_guardians(student_id, relation_type)` unique.
- `bank_accounts.student_id` unique.
- `subjects.subject_code` primary key.
- `internal_marks_events(student_id, subject_code, semester_id, exam_number, exam_type)` unique.
- `attendance_summary(student_id, semester_id, subject_code)` unique.
- `timetable_slots(student_id, semester_id, day_of_week, period_number)` unique.
- `exam_sessions.exam_id` unique.
- `university_exam_results(student_id, exam_session_id, subject_code)` unique.
- `sync_meta(student_id, category)` unique.
