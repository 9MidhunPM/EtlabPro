"""
models.schemas
──────────────
Pydantic v2 models for request/response validation.
Aligned with canonical v3 schema table names and column names.
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
    # Core identity (canonical student_profile columns)
    full_name:       str | None = None
    gender:          str | None = None
    date_of_birth:   str | None = None
    blood_group:     str | None = None
    nationality:     str | None = None
    religion:        str | None = None
    community:       str | None = None
    caste:           str | None = None
    mother_tongue:   str | None = None
    # Contact
    email:           str | None = None
    phone:           str | None = None
    # Address
    address:         str | None = None
    district:        str | None = None
    state:           str | None = None
    pin_code:        str | None = None
    # Catch-all for any future / non-canonical fields
    extra_fields:    dict[str, Any] = {}
    scraped_at:      str | None = None
    updated_at:      str | None = None


# ── Internal Marks ───────────────────────────────────────────────────

class InternalMarkRow(BaseModel):
    """Maps to internal_marks_events table."""
    subject_code:    str
    raw_subject_name: str | None = None
    semester_id:     str | None = None          # UUID or None
    exam_number:     str                         # stored as text
    exam_type:       str = "series_exam"
    max_marks:       float
    marks_obtained:  float | None = None
    scraped_at:      str | None = None


class InternalMarksResponse(BaseModel):
    roll_number: str
    marks:       list[InternalMarkRow]


# ── Attendance ────────────────────────────────────────────────────────

class AttendanceRow(BaseModel):
    """Maps to attendance_summary table."""
    subject_code:     str
    semester_id:      str | None = None          # UUID or None
    classes_attended: int
    classes_total:    int
    percentage:       float
    scraped_at:       str | None = None


class AttendanceResponse(BaseModel):
    roll_number: str
    attendance:  list[AttendanceRow]


# ── Timetable ────────────────────────────────────────────────────────

class TimetableSlot(BaseModel):
    """Maps to timetable_slots table."""
    day_of_week:     str
    period_number:   int
    period_time:     str | None = None
    subject_code:    str | None = None
    raw_subject_name: str | None = None
    class_type:      str | None = None
    teacher_name_raw: str | None = None
    semester_id:     str | None = None


class TimetableResponse(BaseModel):
    roll_number: str
    slots:       list[TimetableSlot]


# ── University Results ────────────────────────────────────────────────

class UniversityResultRow(BaseModel):
    """Maps to university_exam_results joined with exam_sessions."""
    exam_session_id: str | None = None
    exam_id:         str | None = None          # from exam_sessions join
    exam_name:       str | None = None
    exam_month:      str | None = None          # already cleaned (e.g. "May")
    exam_year:       int | None = None
    slot:            str | None = None
    subject_code:    str
    raw_subject_name: str | None = None
    grade:           str | None = None
    result_status:   str | None = None
    credit:          float | None = None
    sgpa:            float | None = None
    cgpa:            float | None = None
    earned_credit:   float | None = None
    scraped_at:      str | None = None


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
    subject_name: str | None = None
    credit:       float | None = None
    last_seen_at: str | None = None


class SubjectsResponse(BaseModel):
    subjects: list[SubjectRow]


# ── Student summary (from v_student_summary view) ────────────────────

class StudentSummary(BaseModel):
    roll_number:          str
    admission_number:     str | None = None
    full_name:            str | None = None
    department:           str | None = None
    programme:            str | None = None
    semester:             str | None = None
    email:                str | None = None
    phone:                str | None = None
    latest_cgpa:          float | None = None
    latest_sgpa:          float | None = None
    avg_attendance_pct:   float | None = None
    subjects_below_75:    int | None = None
    profile_last_updated: str | None = None
