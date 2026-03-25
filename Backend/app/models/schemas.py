"""
models.schemas
──────────────
Pydantic v2 models for request/response validation.
"""
from __future__ import annotations

from typing import Any
from pydantic import BaseModel, Field, field_validator


# ── Request bodies ───────────────────────────────────────────────────

class SyncRequest(BaseModel):
    """Passed to POST /sync-all"""
    username: str = Field(..., min_length=1, description="Etlab portal username")
    password: str = Field(..., min_length=1, description="Etlab portal password")
    force:    bool = Field(False, description="Force re-scrape even if data is fresh")

    class Config:
        # Prevent credentials from appearing in repr / logs
        json_schema_extra = {"example": {"username": "SAHCS23CS001", "password": "***", "force": False}}


class AttendanceSyncRequest(BaseModel):
    """Passed to POST /update-attendance"""
    username: str = Field(..., min_length=1)
    password: str = Field(..., min_length=1)


# ── Shared base ──────────────────────────────────────────────────────

class OKResponse(BaseModel):
    ok:      bool = True
    message: str  = "success"


# ── Profile ──────────────────────────────────────────────────────────

class ProfileResponse(BaseModel):
    # Core identity
    full_name:                      str | None = None
    gender:                         str | None = None
    date_of_birth:                  str | None = None
    place_of_birth:                 str | None = None
    blood_group:                    str | None = None
    nationality:                    str | None = None
    nativity:                       str | None = None
    religion:                       str | None = None
    community:                      str | None = None
    caste:                          str | None = None
    mother_tongue:                  str | None = None
    # Academic identifiers
    roll_number:                    str | None = None
    admission_number:               str | None = None
    sr_no:                          str | None = None
    regno:                          str | None = None
    academic_year:                  str | None = None
    date_of_admission:              str | None = None
    admission_quota:                str | None = None
    admission_type:                 str | None = None
    reservation_category:           str | None = None
    reservation_category_eligible:  str | None = None
    lateral_entry_roll_no:          str | None = None
    abc_id:                         str | None = None
    aadhaar_no:                     str | None = None
    department:                     str | None = None
    programme:                      str | None = None
    semester:                       str | None = None
    is_hosteler:                    str | None = None
    # Contact
    email:                          str | None = None
    phone:                          str | None = None
    phone_office:                   str | None = None
    # Address
    address:                        str | None = None
    street:                         str | None = None
    address_line_2:                 str | None = None
    district:                       str | None = None
    state:                          str | None = None
    pin_code:                       str | None = None
    boarding_point:                 str | None = None
    # Father / guardian
    guardian_name:                  str | None = None
    guardian_phone:                 str | None = None
    father_occupation:              str | None = None
    father_education:               str | None = None
    # Mother
    mother_name:                    str | None = None
    mother_phone:                   str | None = None
    mother_occupation:              str | None = None
    mother_education:               str | None = None
    annual_income:                  str | None = None
    # Bank / finance
    bank_name:                      str | None = None
    bank_account_no:                str | None = None
    bank_ifsc:                      str | None = None
    fee_concession:                 str | None = None
    # Entrance / qualifications
    entrance_rank:                  str | None = None
    entrance_roll_no:               str | None = None
    entrance_exam_score:            str | None = None
    nata_score:                     str | None = None
    plus_two_board:                 str | None = None
    last_school:                    str | None = None
    hss_year:                       str | None = None
    sslc_pct:                       str | None = None
    sslc_year:                      str | None = None
    plus_two_overall_pct:           str | None = None
    maths_mark:                     str | None = None
    maths_pct:                      str | None = None
    physics_mark:                   str | None = None
    physics_pct:                    str | None = None
    chemistry_mark:                 str | None = None
    chemistry_pct:                  str | None = None
    pcm_pct:                        str | None = None
    plus_two_total_mark:            str | None = None
    # Physical identification
    identification_mark_1:          str | None = None
    identification_mark_2:          str | None = None
    tc_date:                        str | None = None
    tc_no:                          str | None = None
    # Catch-all for any future unmapped fields
    extra_fields:                   dict[str, Any] = {}
    scraped_at:                     str | None = None
    updated_at:                     str | None = None


# ── Internal Marks ───────────────────────────────────────────────────

class InternalMarkRow(BaseModel):
    subject_code:    str
    subject_name:    str
    semester:        str
    exam_number:     str | int
    exam_type:       str = "series_exam"
    max_marks:       float
    marks_obtained:  float | None
    scraped_at:      str | None


class InternalMarksResponse(BaseModel):
    roll_number: str
    marks:       list[InternalMarkRow]


# ── Attendance ────────────────────────────────────────────────────────

class AttendanceRow(BaseModel):
    subject_code:     str
    subject_name:     str | None
    classes_attended: int
    classes_total:    int
    percentage:       float
    scraped_at:       str | None


class AttendanceResponse(BaseModel):
    roll_number: str
    attendance:  list[AttendanceRow]


# ── Timetable ────────────────────────────────────────────────────────

class TimetableSlot(BaseModel):
    day:          str
    period:       int
    period_time:  str
    subject_code: str | None
    subject_name: str | None
    class_type:   str | None
    teacher:      str | None


class TimetableResponse(BaseModel):
    roll_number: str
    slots:       list[TimetableSlot]


# ── University Results ────────────────────────────────────────────────

class UniversityResultRow(BaseModel):
    exam_id:        str
    exam_name:      str | None
    semester_label: str | None
    academic_year:  str | None
    exam_month:     str | None
    exam_year:      str | None
    slot:           str | None
    subject_code:   str
    subject_name:   str | None
    grade:          str | None
    credit:         float | None
    result_status:  str | None
    sgpa:           float | None
    cgpa:           float | None
    earned_credit:  float | None
    scraped_at:     str | None


class UniversityResultsResponse(BaseModel):
    roll_number: str
    results:     list[UniversityResultRow]


# ── Sync result summary ───────────────────────────────────────────────

class SyncSummary(BaseModel):
    roll_number:      str
    marks_written:    int
    attendance_written: int
    timetable_written:  int
    profile_updated:  bool
    university_results_written: int
    skipped:          list[str] = Field(default_factory=list, description="Categories skipped (data fresh)")


# ── Subjects ─────────────────────────────────────────────────────────

class SubjectRow(BaseModel):
    subject_code: str
    subject_name: str | None
    credit:       float | None
    last_seen_at: str | None


class SubjectsResponse(BaseModel):
    subjects: list[SubjectRow]


# ── Student summary (from v_student_summary view) ────────────────────

class StudentSummary(BaseModel):
    roll_number:          str
    admission_number:     str | None
    full_name:            str | None
    department:           str | None
    programme:            str | None
    semester:             str | None
    email:                str | None
    phone:                str | None
    latest_cgpa:          float | None
    latest_sgpa:          float | None
    avg_attendance_pct:   float | None
    subjects_below_75:    int | None
    profile_last_updated: str | None
