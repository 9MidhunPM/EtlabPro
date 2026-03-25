-- ============================================================
-- EtlabPro Canonical Schema v3 (Normalized, Supabase-Compatible)
-- ============================================================
-- Notes:
-- - Safe patterns use IF NOT EXISTS where practical.
-- - Designed for phased migration; do not drop legacy tables here.
-- - Uses pgcrypto UUID generation.

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- 0) ENUMS
-- ============================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'exam_type_enum') THEN
        CREATE TYPE exam_type_enum AS ENUM (
            'series_exam', 'module_test', 'class_project', 'assignment', 'tutorial'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'result_status_enum') THEN
        CREATE TYPE result_status_enum AS ENUM (
            'pass', 'fail', 'pending', 'absent', 'withheld'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'day_of_week_enum') THEN
        CREATE TYPE day_of_week_enum AS ENUM (
            'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'class_type_enum') THEN
        CREATE TYPE class_type_enum AS ENUM (
            'Lecture', 'Tutorial', 'Lab', 'Practical', 'Seminar', 'Workshop'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'sync_category_enum') THEN
        CREATE TYPE sync_category_enum AS ENUM (
            'profile', 'marks', 'attendance', 'timetable', 'university_results'
        );
    END IF;
END$$;

-- ============================================================
-- 1) MIGRATION VERSION TRACKING
-- ============================================================
CREATE TABLE IF NOT EXISTS _migrations (
    id          BIGSERIAL PRIMARY KEY,
    name        TEXT NOT NULL UNIQUE,
    applied_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    checksum    TEXT,
    applied_by  TEXT
);

-- ============================================================
-- 2) CORE MASTER TABLES
-- ============================================================
CREATE TABLE IF NOT EXISTS students (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    roll_number       TEXT NOT NULL UNIQUE,
    admission_number  TEXT,
    etlab_user_id     TEXT,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_students_roll ON students(roll_number);

CREATE TABLE IF NOT EXISTS departments (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code        TEXT NOT NULL UNIQUE,
    name        TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS programmes (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    department_id UUID REFERENCES departments(id) ON UPDATE CASCADE ON DELETE SET NULL,
    code          TEXT NOT NULL UNIQUE,
    name          TEXT NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_programmes_department ON programmes(department_id);

CREATE TABLE IF NOT EXISTS academic_years (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    label       TEXT NOT NULL UNIQUE,
    start_year  INTEGER,
    end_year    INTEGER,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (
        (start_year IS NULL AND end_year IS NULL) OR
        (start_year IS NOT NULL AND end_year IS NOT NULL AND end_year >= start_year)
    )
);

CREATE TABLE IF NOT EXISTS semesters (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    programme_id      UUID REFERENCES programmes(id) ON UPDATE CASCADE ON DELETE SET NULL,
    academic_year_id  UUID REFERENCES academic_years(id) ON UPDATE CASCADE ON DELETE SET NULL,
    semester_number   INTEGER,
    semester_label    TEXT NOT NULL,
    is_current        BOOLEAN NOT NULL DEFAULT FALSE,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(programme_id, academic_year_id, semester_label),
    CHECK (semester_number IS NULL OR semester_number > 0)
);
CREATE INDEX IF NOT EXISTS idx_semesters_programme ON semesters(programme_id);

CREATE TABLE IF NOT EXISTS subjects (
    subject_code    TEXT PRIMARY KEY,
    subject_name    TEXT NOT NULL,
    credit          NUMERIC(4,2),
    department_id   UUID REFERENCES departments(id) ON UPDATE CASCADE ON DELETE SET NULL,
    programme_id    UUID REFERENCES programmes(id) ON UPDATE CASCADE ON DELETE SET NULL,
    last_seen_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (credit IS NULL OR credit >= 0)
);
CREATE INDEX IF NOT EXISTS idx_subjects_name ON subjects(subject_name);

CREATE TABLE IF NOT EXISTS teachers (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id  TEXT UNIQUE,
    full_name    TEXT NOT NULL,
    email        TEXT,
    phone        TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 3) STUDENT PROFILE + EXTENSIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS student_profile (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id            UUID NOT NULL UNIQUE REFERENCES students(id) ON DELETE CASCADE,
    full_name             TEXT,
    gender                TEXT,
    date_of_birth         DATE,
    blood_group           TEXT,
    nationality           TEXT,
    religion              TEXT,
    community             TEXT,
    caste                 TEXT,
    mother_tongue         TEXT,
    department_id         UUID REFERENCES departments(id) ON UPDATE CASCADE ON DELETE SET NULL,
    programme_id          UUID REFERENCES programmes(id) ON UPDATE CASCADE ON DELETE SET NULL,
    current_semester_id   UUID REFERENCES semesters(id) ON UPDATE CASCADE ON DELETE SET NULL,
    email                 TEXT,
    phone                 TEXT,
    address               TEXT,
    district              TEXT,
    state                 TEXT,
    pin_code              TEXT,
    extra_fields          JSONB,
    scraped_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_profile_student ON student_profile(student_id);

CREATE TABLE IF NOT EXISTS student_guardians (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id         UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    relation_type      TEXT NOT NULL,
    guardian_name      TEXT,
    guardian_phone     TEXT,
    occupation         TEXT,
    education          TEXT,
    annual_income      NUMERIC(12,2),
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(student_id, relation_type),
    CHECK (annual_income IS NULL OR annual_income >= 0)
);

CREATE TABLE IF NOT EXISTS bank_accounts (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id        UUID NOT NULL UNIQUE REFERENCES students(id) ON DELETE CASCADE,
    bank_name         TEXT,
    account_number    TEXT,
    ifsc_code         TEXT,
    fee_concession    TEXT,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 4) ACADEMIC FACT TABLES
-- ============================================================
CREATE TABLE IF NOT EXISTS exam_sessions (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    exam_id            TEXT NOT NULL UNIQUE,
    exam_name          TEXT,
    semester_id        UUID REFERENCES semesters(id) ON UPDATE CASCADE ON DELETE SET NULL,
    academic_year_id   UUID REFERENCES academic_years(id) ON UPDATE CASCADE ON DELETE SET NULL,
    exam_month         TEXT,
    exam_year          INTEGER,
    slot               TEXT,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (exam_year IS NULL OR exam_year >= 2000)
);
CREATE INDEX IF NOT EXISTS idx_exam_sessions_semester ON exam_sessions(semester_id);

CREATE TABLE IF NOT EXISTS internal_marks_events (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id        UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    semester_id       UUID REFERENCES semesters(id) ON UPDATE CASCADE ON DELETE SET NULL,
    subject_code      TEXT NOT NULL REFERENCES subjects(subject_code) ON UPDATE CASCADE,
    raw_subject_name  TEXT,
    exam_number       TEXT NOT NULL,
    exam_type         exam_type_enum NOT NULL DEFAULT 'series_exam',
    max_marks         NUMERIC(6,2) NOT NULL DEFAULT 0,
    marks_obtained    NUMERIC(6,2),
    scraped_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(student_id, subject_code, semester_id, exam_number, exam_type),
    CHECK (max_marks >= 0),
    CHECK (marks_obtained IS NULL OR marks_obtained >= 0),
    CHECK (marks_obtained IS NULL OR marks_obtained <= max_marks)
);
CREATE INDEX IF NOT EXISTS idx_marks_student ON internal_marks_events(student_id);
CREATE INDEX IF NOT EXISTS idx_marks_subject ON internal_marks_events(subject_code);

CREATE TABLE IF NOT EXISTS attendance_summary (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id         UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    semester_id        UUID REFERENCES semesters(id) ON UPDATE CASCADE ON DELETE SET NULL,
    subject_code       TEXT NOT NULL REFERENCES subjects(subject_code) ON UPDATE CASCADE,
    classes_attended   INTEGER NOT NULL DEFAULT 0,
    classes_total      INTEGER NOT NULL DEFAULT 0,
    percentage         NUMERIC(5,2) NOT NULL DEFAULT 0,
    scraped_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(student_id, semester_id, subject_code),
    CHECK (classes_attended >= 0),
    CHECK (classes_total >= 0),
    CHECK (percentage >= 0 AND percentage <= 100),
    CHECK (classes_total = 0 OR classes_attended <= classes_total)
);
CREATE INDEX IF NOT EXISTS idx_attendance_student ON attendance_summary(student_id);
CREATE INDEX IF NOT EXISTS idx_attendance_low ON attendance_summary(student_id, percentage) WHERE percentage < 75;

CREATE TABLE IF NOT EXISTS timetable_slots (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id         UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    semester_id        UUID REFERENCES semesters(id) ON UPDATE CASCADE ON DELETE SET NULL,
    day_of_week        day_of_week_enum NOT NULL,
    period_number      INTEGER NOT NULL,
    period_time        TEXT,
    subject_code       TEXT REFERENCES subjects(subject_code) ON UPDATE CASCADE,
    raw_subject_name   TEXT,
    class_type         class_type_enum,
    teacher_id         UUID REFERENCES teachers(id) ON UPDATE CASCADE ON DELETE SET NULL,
    teacher_name_raw   TEXT,
    scraped_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(student_id, semester_id, day_of_week, period_number),
    CHECK (period_number > 0)
);
CREATE INDEX IF NOT EXISTS idx_timetable_student_day ON timetable_slots(student_id, day_of_week);

CREATE TABLE IF NOT EXISTS university_exam_results (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id        UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    exam_session_id   UUID NOT NULL REFERENCES exam_sessions(id) ON UPDATE CASCADE ON DELETE CASCADE,
    subject_code      TEXT NOT NULL REFERENCES subjects(subject_code) ON UPDATE CASCADE,
    raw_subject_name  TEXT,
    grade             TEXT,
    result_status     result_status_enum,
    credit            NUMERIC(4,2),
    sgpa              NUMERIC(4,2),
    cgpa              NUMERIC(4,2),
    earned_credit     NUMERIC(5,2),
    scraped_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(student_id, exam_session_id, subject_code),
    CHECK (credit IS NULL OR credit >= 0),
    CHECK (earned_credit IS NULL OR earned_credit >= 0),
    CHECK (sgpa IS NULL OR (sgpa >= 0 AND sgpa <= 10)),
    CHECK (cgpa IS NULL OR (cgpa >= 0 AND cgpa <= 10))
);
CREATE INDEX IF NOT EXISTS idx_uresults_student ON university_exam_results(student_id);
CREATE INDEX IF NOT EXISTS idx_uresults_exam ON university_exam_results(exam_session_id);

-- ============================================================
-- 5) SYNC + AUDIT TABLES
-- ============================================================
CREATE TABLE IF NOT EXISTS sync_runs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id      UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    category        sync_category_enum NOT NULL,
    status          TEXT NOT NULL DEFAULT 'running',
    started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    finished_at     TIMESTAMPTZ,
    rows_written    INTEGER NOT NULL DEFAULT 0,
    error_msg       TEXT,
    metadata        JSONB,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (rows_written >= 0),
    CHECK (status IN ('running', 'ok', 'error', 'skipped'))
);
CREATE INDEX IF NOT EXISTS idx_sync_runs_student_category ON sync_runs(student_id, category, started_at DESC);

CREATE TABLE IF NOT EXISTS sync_meta (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id      UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    category        sync_category_enum NOT NULL,
    last_synced     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    rows_written    INTEGER NOT NULL DEFAULT 0,
    status          TEXT NOT NULL DEFAULT 'ok',
    error_msg       TEXT,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(student_id, category),
    CHECK (rows_written >= 0),
    CHECK (status IN ('ok', 'error', 'skipped'))
);

CREATE TABLE IF NOT EXISTS audit_log (
    id              BIGSERIAL PRIMARY KEY,
    table_name      TEXT NOT NULL,
    operation       TEXT NOT NULL,
    record_pk       TEXT,
    old_values      JSONB,
    new_values      JSONB,
    changed_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    changed_by      TEXT,
    CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE'))
);
CREATE INDEX IF NOT EXISTS idx_audit_table_time ON audit_log(table_name, changed_at DESC);

-- ============================================================
-- 6) GENERIC TRIGGER FUNCTIONS
-- ============================================================
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION fn_compute_attendance_percentage()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.classes_total <= 0 THEN
        NEW.percentage = 0;
    ELSE
        NEW.percentage = ROUND((NEW.classes_attended::NUMERIC / NEW.classes_total::NUMERIC) * 100, 2);
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION fn_upsert_subject_from_marks_event()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO subjects(subject_code, subject_name, last_seen_at)
    VALUES (NEW.subject_code, COALESCE(NEW.raw_subject_name, NEW.subject_code), NOW())
    ON CONFLICT (subject_code) DO UPDATE
      SET subject_name = COALESCE(EXCLUDED.subject_name, subjects.subject_name),
          last_seen_at = NOW();
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION fn_upsert_subject_from_timetable_slot()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.subject_code IS NOT NULL THEN
        INSERT INTO subjects(subject_code, subject_name, last_seen_at)
        VALUES (NEW.subject_code, COALESCE(NEW.raw_subject_name, NEW.subject_code), NOW())
        ON CONFLICT (subject_code) DO UPDATE
          SET subject_name = COALESCE(EXCLUDED.subject_name, subjects.subject_name),
              last_seen_at = NOW();
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION fn_upsert_subject_from_university_result()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO subjects(subject_code, subject_name, credit, last_seen_at)
    VALUES (
        NEW.subject_code,
        COALESCE(NEW.raw_subject_name, NEW.subject_code),
        NEW.credit,
        NOW()
    )
    ON CONFLICT (subject_code) DO UPDATE
      SET subject_name = COALESCE(EXCLUDED.subject_name, subjects.subject_name),
          credit       = COALESCE(EXCLUDED.credit, subjects.credit),
          last_seen_at = NOW();
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION fn_sync_meta_from_runs()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.status IN ('ok', 'error', 'skipped') THEN
        INSERT INTO sync_meta(student_id, category, last_synced, rows_written, status, error_msg, updated_at)
        VALUES (NEW.student_id, NEW.category, COALESCE(NEW.finished_at, NOW()), NEW.rows_written,
                CASE WHEN NEW.status = 'ok' THEN 'ok'
                     WHEN NEW.status = 'error' THEN 'error'
                     ELSE 'skipped' END,
                NEW.error_msg, NOW())
        ON CONFLICT (student_id, category) DO UPDATE
          SET last_synced  = EXCLUDED.last_synced,
              rows_written = EXCLUDED.rows_written,
              status       = EXCLUDED.status,
              error_msg    = EXCLUDED.error_msg,
              updated_at   = NOW();
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION fn_audit_generic()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    pk_text TEXT;
BEGIN
    IF TG_OP = 'DELETE' THEN
        pk_text := COALESCE(OLD.id::TEXT, OLD.student_id::TEXT, 'n/a');
        INSERT INTO audit_log(table_name, operation, record_pk, old_values, new_values, changed_by)
        VALUES (TG_TABLE_NAME, TG_OP, pk_text, to_jsonb(OLD), NULL, current_user);
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        pk_text := COALESCE(NEW.id::TEXT, NEW.student_id::TEXT, 'n/a');
        INSERT INTO audit_log(table_name, operation, record_pk, old_values, new_values, changed_by)
        VALUES (TG_TABLE_NAME, TG_OP, pk_text, to_jsonb(OLD), to_jsonb(NEW), current_user);
        RETURN NEW;
    ELSE
        pk_text := COALESCE(NEW.id::TEXT, NEW.student_id::TEXT, 'n/a');
        INSERT INTO audit_log(table_name, operation, record_pk, old_values, new_values, changed_by)
        VALUES (TG_TABLE_NAME, TG_OP, pk_text, NULL, to_jsonb(NEW), current_user);
        RETURN NEW;
    END IF;
END;
$$;

-- ============================================================
-- 7) TRIGGER ATTACHMENTS
-- ============================================================
DO $$
DECLARE tbl TEXT;
BEGIN
    FOREACH tbl IN ARRAY ARRAY[
        'students', 'departments', 'programmes', 'academic_years', 'semesters',
        'subjects', 'teachers', 'student_profile', 'student_guardians', 'bank_accounts',
        'exam_sessions', 'internal_marks_events', 'attendance_summary', 'timetable_slots',
        'university_exam_results', 'sync_runs', 'sync_meta'
    ] LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS trg_set_updated_at ON %I;', tbl);
        EXECUTE format(
            'CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();',
            tbl
        );
    END LOOP;
END$$;

DROP TRIGGER IF EXISTS trg_compute_attendance_percentage ON attendance_summary;
CREATE TRIGGER trg_compute_attendance_percentage
BEFORE INSERT OR UPDATE OF classes_attended, classes_total
ON attendance_summary
FOR EACH ROW EXECUTE FUNCTION fn_compute_attendance_percentage();

DROP TRIGGER IF EXISTS trg_subject_from_marks_event ON internal_marks_events;
CREATE TRIGGER trg_subject_from_marks_event
AFTER INSERT OR UPDATE ON internal_marks_events
FOR EACH ROW EXECUTE FUNCTION fn_upsert_subject_from_marks_event();

DROP TRIGGER IF EXISTS trg_subject_from_timetable_slot ON timetable_slots;
CREATE TRIGGER trg_subject_from_timetable_slot
AFTER INSERT OR UPDATE ON timetable_slots
FOR EACH ROW EXECUTE FUNCTION fn_upsert_subject_from_timetable_slot();

DROP TRIGGER IF EXISTS trg_subject_from_university_result ON university_exam_results;
CREATE TRIGGER trg_subject_from_university_result
AFTER INSERT OR UPDATE ON university_exam_results
FOR EACH ROW EXECUTE FUNCTION fn_upsert_subject_from_university_result();

DROP TRIGGER IF EXISTS trg_sync_meta_from_runs ON sync_runs;
CREATE TRIGGER trg_sync_meta_from_runs
AFTER INSERT OR UPDATE OF status, finished_at, rows_written, error_msg
ON sync_runs
FOR EACH ROW EXECUTE FUNCTION fn_sync_meta_from_runs();

-- Audit only high-value mutable tables.
DO $$
DECLARE tbl TEXT;
BEGIN
    FOREACH tbl IN ARRAY ARRAY[
        'internal_marks_events', 'attendance_summary', 'university_exam_results',
        'student_profile', 'sync_runs'
    ] LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS trg_audit_generic ON %I;', tbl);
        EXECUTE format(
            'CREATE TRIGGER trg_audit_generic AFTER INSERT OR UPDATE OR DELETE ON %I FOR EACH ROW EXECUTE FUNCTION fn_audit_generic();',
            tbl
        );
    END LOOP;
END$$;

-- ============================================================
-- 8) ANALYTICS / COMPATIBILITY VIEWS
-- ============================================================
CREATE OR REPLACE VIEW v_semester_gpa AS
SELECT
    r.student_id,
    es.id AS exam_session_id,
    es.exam_id,
    es.exam_name,
    es.semester_id,
    MAX(r.sgpa) AS sgpa,
    MAX(r.cgpa) AS cgpa,
    SUM(COALESCE(r.earned_credit, 0)) AS earned_credit
FROM university_exam_results r
JOIN exam_sessions es ON es.id = r.exam_session_id
GROUP BY r.student_id, es.id, es.exam_id, es.exam_name, es.semester_id;

CREATE OR REPLACE VIEW v_student_summary AS
SELECT
    s.id AS student_id,
    s.roll_number,
    s.admission_number,
    sp.full_name,
    d.name AS department,
    p.name AS programme,
    sem.semester_label AS semester,
    sp.email,
    sp.phone,
    (
        SELECT g.cgpa
        FROM v_semester_gpa g
        WHERE g.student_id = s.id AND g.cgpa IS NOT NULL
        ORDER BY g.exam_id DESC
        LIMIT 1
    ) AS latest_cgpa,
    (
        SELECT g.sgpa
        FROM v_semester_gpa g
        WHERE g.student_id = s.id AND g.sgpa IS NOT NULL
        ORDER BY g.exam_id DESC
        LIMIT 1
    ) AS latest_sgpa,
    ROUND(AVG(a.percentage)::NUMERIC, 2) AS avg_attendance_pct,
    COUNT(*) FILTER (WHERE a.percentage < 75) AS subjects_below_75,
    sp.updated_at AS profile_last_updated
FROM students s
LEFT JOIN student_profile sp ON sp.student_id = s.id
LEFT JOIN departments d ON d.id = sp.department_id
LEFT JOIN programmes p ON p.id = sp.programme_id
LEFT JOIN semesters sem ON sem.id = sp.current_semester_id
LEFT JOIN attendance_summary a ON a.student_id = s.id
GROUP BY s.id, s.roll_number, s.admission_number,
         sp.full_name, d.name, p.name, sem.semester_label,
         sp.email, sp.phone, sp.updated_at;

CREATE OR REPLACE VIEW v_gpa_progression AS
SELECT
    g.student_id,
    g.exam_id,
    g.exam_name,
    sem.semester_label,
    ay.label AS academic_year,
    es.exam_month,
    es.exam_year,
    g.sgpa,
    g.cgpa,
    g.earned_credit
FROM v_semester_gpa g
JOIN exam_sessions es ON es.id = g.exam_session_id
LEFT JOIN semesters sem ON sem.id = es.semester_id
LEFT JOIN academic_years ay ON ay.id = es.academic_year_id
ORDER BY g.student_id, g.exam_id;

-- ============================================================
-- END
-- ============================================================
