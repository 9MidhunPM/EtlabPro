-- Fix v_student_summary: ORDER BY exam_id as INTEGER (not text)
-- exam_id values like "7", "16", "25", "33" sort incorrectly as text:
--   text: "7" > "33" > "25" > "16"  ← WRONG
--   int:  33 > 25 > 16 > 7          ← CORRECT (latest semester last)
--
-- Run this in Supabase SQL Editor.

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
        ORDER BY (g.exam_id::BIGINT) DESC
        LIMIT 1
    ) AS latest_cgpa,
    (
        SELECT g.sgpa
        FROM v_semester_gpa g
        WHERE g.student_id = s.id AND g.sgpa IS NOT NULL
        ORDER BY (g.exam_id::BIGINT) DESC
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
