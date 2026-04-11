-- ============================================================
-- EtlabPro — Profile Table Expansion (run this if tables already exist)
-- Adds all individual profile columns to student_profile.
-- Safe to run multiple times (IF NOT EXISTS on each column).
-- ============================================================

DO $$
DECLARE col TEXT; typ TEXT;
BEGIN
    FOR col, typ IN VALUES
        -- Identity
        ('place_of_birth',              'TEXT'),
        ('blood_group',                 'TEXT'),
        ('nationality',                 'TEXT'),
        ('nativity',                    'TEXT'),
        ('religion',                    'TEXT'),
        ('community',                   'TEXT'),
        ('caste',                       'TEXT'),
        ('mother_tongue',               'TEXT'),
        -- Academic IDs
        ('sr_no',                       'TEXT'),
        ('regno',                       'TEXT'),
        ('academic_year',               'TEXT'),
        ('date_of_admission',           'TEXT'),
        ('admission_quota',             'TEXT'),
        ('admission_type',              'TEXT'),
        ('reservation_category',        'TEXT'),
        ('reservation_category_eligible', 'TEXT'),
        ('lateral_entry_roll_no',       'TEXT'),
        ('abc_id',                      'TEXT'),
        ('aadhaar_no',                  'TEXT'),
        -- Contact extras
        ('phone_office',                'TEXT'),
        -- Address extras
        ('street',                      'TEXT'),
        ('address_line_2',              'TEXT'),
        ('district',                    'TEXT'),
        ('state',                       'TEXT'),
        ('pin_code',                    'TEXT'),
        ('boarding_point',              'TEXT'),
        -- Hosteler
        ('is_hosteler',                 'TEXT'),
        -- Parent / Guardian extras
        ('father_occupation',           'TEXT'),
        ('father_education',            'TEXT'),
        ('mother_name',                 'TEXT'),
        ('mother_phone',                'TEXT'),
        ('mother_occupation',           'TEXT'),
        ('mother_education',            'TEXT'),
        ('annual_income',               'TEXT'),
        -- Finance / Bank
        ('bank_name',                   'TEXT'),
        ('bank_account_no',             'TEXT'),
        ('bank_ifsc',                   'TEXT'),
        ('fee_concession',              'TEXT'),
        -- Entrance / Qualifications
        ('entrance_rank',               'TEXT'),
        ('entrance_roll_no',            'TEXT'),
        ('entrance_exam_score',         'TEXT'),
        ('nata_score',                  'TEXT'),
        ('plus_two_board',              'TEXT'),
        ('last_school',                 'TEXT'),
        ('hss_year',                    'TEXT'),
        ('sslc_pct',                    'TEXT'),
        ('sslc_year',                   'TEXT'),
        ('plus_two_overall_pct',        'TEXT'),
        ('maths_mark',                  'TEXT'),
        ('maths_pct',                   'TEXT'),
        ('physics_mark',                'TEXT'),
        ('physics_pct',                 'TEXT'),
        ('chemistry_mark',              'TEXT'),
        ('chemistry_pct',               'TEXT'),
        ('pcm_pct',                     'TEXT'),
        ('plus_two_total_mark',         'TEXT'),
        -- Misc
        ('identification_mark_1',       'TEXT'),
        ('identification_mark_2',       'TEXT'),
        ('tc_date',                     'TEXT'),
        ('tc_no',                       'TEXT')
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name = 'student_profile' AND column_name = col
        ) THEN
            EXECUTE format('ALTER TABLE student_profile ADD COLUMN %I %s', col, typ);
        END IF;
    END LOOP;
END;
$$;
