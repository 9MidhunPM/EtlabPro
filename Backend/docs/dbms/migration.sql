-- ============================================================
-- EtlabPro — Supabase PostgreSQL Migration  (v2)
-- Run in Supabase: Dashboard → SQL Editor → New query → Run
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- 1. STUDENTS
-- ============================================================
CREATE TABLE IF NOT EXISTS students (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    roll_number      TEXT NOT NULL UNIQUE,
    admission_number TEXT,
    etlab_user_id    TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_students_roll ON students(roll_number);

-- ============================================================
-- 2. SUBJECTS  (master reference — auto-populated by triggers)
--    Canonical record for every subject seen in any scrape.
--    Sources: internal_marks, timetable, university_results.
-- ============================================================
CREATE TABLE IF NOT EXISTS subjects (
    subject_code TEXT PRIMARY KEY,
    subject_name TEXT,
    credit       NUMERIC(4,2),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 3. STUDENT PROFILE
-- ============================================================
CREATE TABLE IF NOT EXISTS student_profile (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id       UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    -- Core identity
    full_name        TEXT,
    gender           TEXT,
    date_of_birth    TEXT,
    place_of_birth   TEXT,
    blood_group      TEXT,
    nationality      TEXT,
    nativity         TEXT,
    religion         TEXT,
    community        TEXT,
    caste            TEXT,
    mother_tongue    TEXT,
    -- Academic identifiers
    admission_number TEXT,
    sr_no            TEXT,
    regno            TEXT,
    academic_year    TEXT,
    date_of_admission TEXT,
    admission_quota  TEXT,
    admission_type   TEXT,
    reservation_category           TEXT,
    reservation_category_eligible  TEXT,
    lateral_entry_roll_no          TEXT,
    abc_id           TEXT,
    aadhaar_no       TEXT,
    department       TEXT,
    programme        TEXT,
    semester         TEXT,
    is_hosteler      TEXT,
    -- Contact
    email            TEXT,
    phone            TEXT,
    phone_office     TEXT,
    -- Address
    address          TEXT,           -- house name / flat number
    street           TEXT,
    address_line_2   TEXT,
    district         TEXT,
    state            TEXT,
    pin_code         TEXT,
    boarding_point   TEXT,
    -- Father / guardian
    guardian_name    TEXT,           -- father's name
    guardian_phone   TEXT,           -- father's mobile
    father_occupation TEXT,
    father_education TEXT,
    -- Mother
    mother_name      TEXT,
    mother_phone     TEXT,
    mother_occupation TEXT,
    mother_education TEXT,
    annual_income    TEXT,
    -- Bank / finance
    bank_name        TEXT,
    bank_account_no  TEXT,
    bank_ifsc        TEXT,
    fee_concession   TEXT,
    -- Entrance / qualifications
    entrance_rank    TEXT,
    entrance_roll_no TEXT,
    entrance_exam_score TEXT,
    nata_score       TEXT,
    plus_two_board   TEXT,
    last_school      TEXT,
    hss_year         TEXT,
    sslc_pct         TEXT,
    sslc_year        TEXT,
    plus_two_overall_pct TEXT,
    maths_mark       TEXT,
    maths_pct        TEXT,
    physics_mark     TEXT,
    physics_pct      TEXT,
    chemistry_mark   TEXT,
    chemistry_pct    TEXT,
    pcm_pct          TEXT,
    plus_two_total_mark TEXT,
    -- Physical identification
    identification_mark_1 TEXT,
    identification_mark_2 TEXT,
    tc_date          TEXT,
    tc_no            TEXT,
    -- Any fields not matched by the above (future-proofing)
    extra_fields     JSONB,
    scraped_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(student_id)
);

CREATE INDEX IF NOT EXISTS idx_profile_student ON student_profile(student_id);

-- ============================================================
-- 4. INTERNAL MARKS
-- ============================================================
CREATE TABLE IF NOT EXISTS internal_marks (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id      UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    subject_code    TEXT NOT NULL REFERENCES subjects(subject_code) ON UPDATE CASCADE,
    subject_name    TEXT NOT NULL,
    semester        TEXT NOT NULL,
    exam_number     TEXT NOT NULL,
    exam_type       TEXT NOT NULL DEFAULT 'series_exam',
    -- exam_type: series_exam | module_test | class_project | assignment | tutorial
    max_marks       NUMERIC(6,2) NOT NULL DEFAULT 0,
    marks_obtained  NUMERIC(6,2),               -- NULL = not published / not submitted
    scraped_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(student_id, subject_code, semester, exam_number, exam_type)
);

CREATE INDEX IF NOT EXISTS idx_imarks_student  ON internal_marks(student_id);
CREATE INDEX IF NOT EXISTS idx_imarks_subject  ON internal_marks(subject_code);
CREATE INDEX IF NOT EXISTS idx_imarks_semester ON internal_marks(student_id, semester);

-- ============================================================
-- 5. ATTENDANCE
--    subject_name auto-filled by trigger from subjects table.
-- ============================================================
CREATE TABLE IF NOT EXISTS attendance (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id       UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    subject_code     TEXT NOT NULL REFERENCES subjects(subject_code) ON UPDATE CASCADE,
    subject_name     TEXT,
    classes_attended INTEGER NOT NULL DEFAULT 0,
    classes_total    INTEGER NOT NULL DEFAULT 0,
    percentage       NUMERIC(5,2) NOT NULL DEFAULT 0,
    scraped_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(student_id, subject_code)
);

CREATE INDEX IF NOT EXISTS idx_attendance_student ON attendance(student_id);

-- ============================================================
-- 6. TIMETABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS timetable (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id   UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    day          TEXT NOT NULL,
    period       INTEGER NOT NULL,
    period_time  TEXT NOT NULL,
    subject_code TEXT REFERENCES subjects(subject_code) ON UPDATE CASCADE,
    subject_name TEXT,
    class_type   TEXT,
    teacher      TEXT,
    scraped_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(student_id, day, period)
);

CREATE INDEX IF NOT EXISTS idx_timetable_student ON timetable(student_id);
CREATE INDEX IF NOT EXISTS idx_timetable_day     ON timetable(student_id, day);

-- ============================================================
-- 7. UNIVERSITY EXAM RESULTS
-- ============================================================
CREATE TABLE IF NOT EXISTS university_results (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id      UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    exam_id         TEXT NOT NULL,
    exam_name       TEXT,
    semester_label  TEXT,
    academic_year   TEXT,
    exam_month      TEXT,
    exam_year       TEXT,
    slot            TEXT,
    subject_code    TEXT NOT NULL REFERENCES subjects(subject_code) ON UPDATE CASCADE,
    subject_name    TEXT,
    grade           TEXT,
    credit          NUMERIC(4,2),
    result_status   TEXT,
    sgpa            NUMERIC(4,2),
    cgpa            NUMERIC(4,2),
    earned_credit   NUMERIC(5,2),
    scraped_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(student_id, subject_code, exam_id)
);

CREATE INDEX IF NOT EXISTS idx_uresults_student  ON university_results(student_id);
CREATE INDEX IF NOT EXISTS idx_uresults_exam_id  ON university_results(student_id, exam_id);
CREATE INDEX IF NOT EXISTS idx_uresults_semester ON university_results(student_id, semester_label);

-- ============================================================
-- 8. SYNC META
-- ============================================================
CREATE TABLE IF NOT EXISTS sync_meta (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id   UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    category     TEXT NOT NULL,
    last_synced  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    rows_written INTEGER NOT NULL DEFAULT 0,
    status       TEXT NOT NULL DEFAULT 'ok',
    error_msg    TEXT,
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(student_id, category)
);

CREATE INDEX IF NOT EXISTS idx_syncmeta_student ON sync_meta(student_id);

-- ============================================================
-- 9. TRIGGERS
-- ============================================================

-- 9a. auto-update updated_at on every table --------------------------------
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

DO $$
DECLARE tbl TEXT;
BEGIN
    FOREACH tbl IN ARRAY ARRAY[
        'students','student_profile','internal_marks',
        'attendance','timetable','university_results','sync_meta'
    ] LOOP
        EXECUTE format($f$
            DROP TRIGGER IF EXISTS trg_set_updated_at ON %I;
            CREATE TRIGGER trg_set_updated_at
            BEFORE UPDATE ON %I
            FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
        $f$, tbl, tbl);
    END LOOP;
END;
$$;

-- 9b. auto-upsert into subjects from internal_marks -----------------------
CREATE OR REPLACE FUNCTION fn_upsert_subject_from_marks()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO subjects(subject_code, subject_name, last_seen_at)
    VALUES (NEW.subject_code, NEW.subject_name, NOW())
    ON CONFLICT (subject_code) DO UPDATE
      SET subject_name = COALESCE(EXCLUDED.subject_name, subjects.subject_name),
          last_seen_at = NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_subjects_from_marks ON internal_marks;
CREATE TRIGGER trg_subjects_from_marks
AFTER INSERT OR UPDATE ON internal_marks
FOR EACH ROW EXECUTE FUNCTION fn_upsert_subject_from_marks();

-- 9c. auto-upsert into subjects from timetable ----------------------------
CREATE OR REPLACE FUNCTION fn_upsert_subject_from_timetable()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.subject_code IS NOT NULL THEN
        INSERT INTO subjects(subject_code, subject_name, last_seen_at)
        VALUES (NEW.subject_code, NEW.subject_name, NOW())
        ON CONFLICT (subject_code) DO UPDATE
          SET subject_name = COALESCE(EXCLUDED.subject_name, subjects.subject_name),
              last_seen_at = NOW();
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_subjects_from_timetable ON timetable;
CREATE TRIGGER trg_subjects_from_timetable
AFTER INSERT OR UPDATE ON timetable
FOR EACH ROW EXECUTE FUNCTION fn_upsert_subject_from_timetable();

-- 9d. auto-upsert into subjects from university_results (also syncs credit)
CREATE OR REPLACE FUNCTION fn_upsert_subject_from_uresults()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO subjects(subject_code, subject_name, credit, last_seen_at)
    VALUES (NEW.subject_code, NEW.subject_name, NEW.credit, NOW())
    ON CONFLICT (subject_code) DO UPDATE
      SET subject_name = COALESCE(EXCLUDED.subject_name, subjects.subject_name),
          credit       = COALESCE(EXCLUDED.credit,       subjects.credit),
          last_seen_at = NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_subjects_from_uresults ON university_results;
CREATE TRIGGER trg_subjects_from_uresults
AFTER INSERT OR UPDATE ON university_results
FOR EACH ROW EXECUTE FUNCTION fn_upsert_subject_from_uresults();

-- 9e. auto-fill attendance.subject_name from subjects ---------------------
CREATE OR REPLACE FUNCTION fn_fill_attendance_subject_name()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.subject_name IS NULL OR NEW.subject_name = '' THEN
        SELECT subject_name INTO NEW.subject_name
        FROM subjects WHERE subject_code = NEW.subject_code;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_fill_attendance_name ON attendance;
CREATE TRIGGER trg_fill_attendance_name
BEFORE INSERT OR UPDATE ON attendance
FOR EACH ROW EXECUTE FUNCTION fn_fill_attendance_subject_name();

-- 9f. propagate subject_name changes subjects → attendance ----------------
CREATE OR REPLACE FUNCTION fn_propagate_subject_name()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.subject_name IS DISTINCT FROM OLD.subject_name THEN
        UPDATE attendance
           SET subject_name = NEW.subject_name
         WHERE subject_code  = NEW.subject_code
           AND (subject_name IS NULL
                OR subject_name = ''
                OR subject_name = OLD.subject_name);
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_propagate_subject_name ON subjects;
CREATE TRIGGER trg_propagate_subject_name
AFTER UPDATE ON subjects
FOR EACH ROW EXECUTE FUNCTION fn_propagate_subject_name();

-- ============================================================
-- 10. VIEWS
-- ============================================================

-- Student-level summary: CGPA, attendance, contact info
CREATE OR REPLACE VIEW v_student_summary AS
SELECT
    s.id                                        AS student_id,
    s.roll_number,
    s.admission_number,
    sp.full_name,
    sp.department,
    sp.programme,
    sp.semester,
    sp.email,
    sp.phone,
    (
        SELECT ur.cgpa
        FROM university_results ur
        WHERE ur.student_id = s.id AND ur.cgpa IS NOT NULL
        ORDER BY ur.exam_id::INTEGER DESC
        LIMIT 1
    )                                           AS latest_cgpa,
    (
        SELECT ur.sgpa
        FROM university_results ur
        WHERE ur.student_id = s.id AND ur.sgpa IS NOT NULL
        ORDER BY ur.exam_id::INTEGER DESC
        LIMIT 1
    )                                           AS latest_sgpa,
    ROUND(AVG(a.percentage)::NUMERIC, 2)        AS avg_attendance_pct,
    COUNT(*) FILTER (WHERE a.percentage < 75)   AS subjects_below_75,
    sp.updated_at                               AS profile_last_updated
FROM students s
LEFT JOIN student_profile sp ON sp.student_id = s.id
LEFT JOIN attendance       a  ON a.student_id  = s.id
GROUP BY s.id, s.roll_number, s.admission_number,
         sp.full_name, sp.department, sp.programme, sp.semester,
         sp.email, sp.phone, sp.updated_at;

-- GPA progression across exam sessions
CREATE OR REPLACE VIEW v_gpa_progression AS
SELECT DISTINCT ON (student_id, exam_id)
    student_id,
    exam_id,
    exam_name,
    semester_label,
    academic_year,
    exam_month,
    exam_year,
    sgpa,
    cgpa,
    earned_credit
FROM university_results
WHERE sgpa IS NOT NULL
ORDER BY student_id, exam_id;

-- ============================================================
-- RELATIONSHIP SUMMARY
-- ============================================================
-- students         (1) --< student_profile    (1:1,  CASCADE)
-- students         (1) --< internal_marks     (1:N,  CASCADE)
-- students         (1) --< attendance         (1:N,  CASCADE)
-- students         (1) --< timetable          (1:N,  CASCADE)
-- students         (1) --< university_results (1:N,  CASCADE)
-- students         (1) --< sync_meta          (1:N,  CASCADE)
-- subjects.code    (1) --< internal_marks     (1:N,  ON UPDATE CASCADE)
-- subjects.code    (1) --< attendance         (1:N,  ON UPDATE CASCADE)
-- subjects.code    (1) --< timetable          (1:N,  ON UPDATE CASCADE)
-- subjects.code    (1) --< university_results (1:N,  ON UPDATE CASCADE)
--
-- TRIGGER FLOW:
--   INSERT internal_marks     -> upsert subjects (name)
--   INSERT timetable          -> upsert subjects (name)
--   INSERT university_results -> upsert subjects (name, credit)
--   UPDATE subjects           -> propagate subject_name -> attendance
--   INSERT/UPDATE attendance  -> auto-fill subject_name from subjects
--   UPDATE any row            -> auto-set updated_at
-- ============================================================
