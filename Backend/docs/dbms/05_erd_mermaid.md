# ER Diagram (Mermaid)

```mermaid
erDiagram
    STUDENTS ||--o| STUDENT_PROFILE : has
    STUDENTS ||--o{ STUDENT_GUARDIANS : has
    STUDENTS ||--o| BANK_ACCOUNTS : has

    DEPARTMENTS ||--o{ PROGRAMMES : contains
    DEPARTMENTS ||--o{ SUBJECTS : owns
    PROGRAMMES ||--o{ SEMESTERS : has

    PROGRAMMES ||--o{ STUDENT_PROFILE : classifies
    SEMESTERS ||--o{ STUDENT_PROFILE : current

    STUDENTS ||--o{ INTERNAL_MARKS_EVENTS : gets
    SUBJECTS ||--o{ INTERNAL_MARKS_EVENTS : maps
    SEMESTERS ||--o{ INTERNAL_MARKS_EVENTS : scoped

    STUDENTS ||--o{ ATTENDANCE_SUMMARY : has
    SUBJECTS ||--o{ ATTENDANCE_SUMMARY : maps
    SEMESTERS ||--o{ ATTENDANCE_SUMMARY : scoped

    STUDENTS ||--o{ TIMETABLE_SLOTS : has
    SUBJECTS ||--o{ TIMETABLE_SLOTS : maps
    TEACHERS ||--o{ TIMETABLE_SLOTS : teaches
    SEMESTERS ||--o{ TIMETABLE_SLOTS : scoped

    ACADEMIC_YEARS ||--o{ SEMESTERS : organizes
    ACADEMIC_YEARS ||--o{ EXAM_SESSIONS : organizes
    SEMESTERS ||--o{ EXAM_SESSIONS : has

    EXAM_SESSIONS ||--o{ UNIVERSITY_EXAM_RESULTS : includes
    STUDENTS ||--o{ UNIVERSITY_EXAM_RESULTS : receives
    SUBJECTS ||--o{ UNIVERSITY_EXAM_RESULTS : maps

    STUDENTS ||--o{ SYNC_RUNS : executes
    STUDENTS ||--o{ SYNC_META : tracks

    STUDENTS {
      uuid id PK
      text roll_number UK
      text admission_number
      text etlab_user_id
      timestamptz created_at
      timestamptz updated_at
    }

    STUDENT_PROFILE {
      uuid id PK
      uuid student_id FK UK
      text full_name
      text email
      uuid department_id FK
      uuid programme_id FK
      uuid current_semester_id FK
      jsonb extra_fields
      timestamptz scraped_at
      timestamptz updated_at
    }

    SUBJECTS {
      text subject_code PK
      text subject_name
      numeric credit
      timestamptz last_seen_at
    }

    INTERNAL_MARKS_EVENTS {
      uuid id PK
      uuid student_id FK
      uuid semester_id FK
      text subject_code FK
      text exam_number
      text exam_type
      numeric max_marks
      numeric marks_obtained
      timestamptz scraped_at
    }

    ATTENDANCE_SUMMARY {
      uuid id PK
      uuid student_id FK
      uuid semester_id FK
      text subject_code FK
      int classes_attended
      int classes_total
      numeric percentage
      timestamptz scraped_at
    }

    TIMETABLE_SLOTS {
      uuid id PK
      uuid student_id FK
      uuid semester_id FK
      text day_of_week
      int period_number
      text subject_code FK
      uuid teacher_id FK
      timestamptz scraped_at
    }

    EXAM_SESSIONS {
      uuid id PK
      text exam_id UK
      text exam_name
      uuid semester_id FK
      uuid academic_year_id FK
      int exam_year
    }

    UNIVERSITY_EXAM_RESULTS {
      uuid id PK
      uuid student_id FK
      uuid exam_session_id FK
      text subject_code FK
      text grade
      text result_status
      numeric sgpa
      numeric cgpa
      numeric earned_credit
    }

    SYNC_RUNS {
      uuid id PK
      uuid student_id FK
      text category
      text status
      int rows_written
      timestamptz started_at
      timestamptz finished_at
    }

    SYNC_META {
      uuid id PK
      uuid student_id FK
      text category
      timestamptz last_synced
      int rows_written
      text status
    }
```
