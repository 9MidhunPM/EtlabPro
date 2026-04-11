"""
api.routes
──────────
All FastAPI endpoint definitions.

Public routes: POST /auth/login, POST /auth/refresh
Protected routes: require a valid Bearer JWT (enforced via Depends).
"""
import logging
from typing import Any

import jwt
from fastapi import APIRouter, Depends, HTTPException, status

from app.api.deps import (
    create_access_token,
    create_refresh_token,
    decode_token,
    get_current_user,
)
from app.db.client import get_supabase
from app.db import students as students_db
from app.db import marks as marks_db
from app.db import attendance as att_db
from app.db import timetable as tt_db
from app.db import profile as profile_db
from app.db import university_results as uni_db
from app.services import sync as sync_service
from app.scraper import session as session_scraper
from app.scraper import profile as profile_scraper
from app.scraper import attendance as attendance_scraper
from app.scraper import marks as marks_scraper
from app.scraper import university_results as uni_scraper
from app.models.schemas import (
    SyncRequest,
    AttendanceSyncRequest,
    SyncSummary,
    ProfileResponse,
    InternalMarkRow,
    InternalMarksResponse,
    AttendanceRow,
    AttendanceResponse,
    TimetableSlot,
    TimetableResponse,
    UniversityResultRow,
    UniversityResultsResponse,
    SubjectsResponse,
    StudentSummary,
    OKResponse,
)

router = APIRouter()
log    = logging.getLogger(__name__)


# ── Auth models (inline — small) ─────────────────────────────────────

from pydantic import BaseModel, Field

class LoginRequest(BaseModel):
    username: str = Field(..., min_length=1)
    password: str = Field(..., min_length=1)
    device_id: str | None = Field(None, description="Unique device identifier")

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    roll_number: str

class RefreshRequest(BaseModel):
    refresh_token: str

class RefreshResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class LiveScrapeRequest(BaseModel):
    username: str = Field(..., min_length=1)
    password: str = Field(..., min_length=1)
    include_university_results: bool = Field(
        True,
        description="Whether to compare live university results in /live/updates.",
    )


# ── Helpers ──────────────────────────────────────────────────────────

def _require_student(roll: str) -> dict:
    """Return student row or raise 404."""
    student = students_db.get_student_by_roll(get_supabase(), roll)
    if not student:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Student '{roll}' not found. Login first.",
        )
    return student


def _as_float(val: Any) -> float | None:
    try:
        return float(val)
    except (TypeError, ValueError):
        return None


def _attendance_changes(previous_rows: list[dict], live_rows: list[dict]) -> list[dict]:
    prev = {r.get("subject_code"): r for r in previous_rows if r.get("subject_code")}
    live = {r.get("subject_code"): r for r in live_rows if r.get("subject_code")}

    updates: list[dict] = []

    for subject_code, cur in live.items():
        old = prev.get(subject_code)
        if not old:
            updates.append({
                "category": "attendance",
                "subject_code": subject_code,
                "type": "new_subject",
                "message": f"Attendance now tracked for {subject_code}.",
                "current": cur,
            })
            continue

        old_attended = int(old.get("classes_attended") or 0)
        new_attended = int(cur.get("classes_attended") or 0)
        old_total = int(old.get("classes_total") or 0)
        new_total = int(cur.get("classes_total") or 0)
        old_pct = _as_float(old.get("percentage"))
        new_pct = _as_float(cur.get("percentage"))

        changed = (old_attended != new_attended) or (old_total != new_total) or (old_pct != new_pct)
        if changed:
            delta_attended = new_attended - old_attended
            delta_total = new_total - old_total

            if delta_total > 0 and delta_attended == delta_total:
                msg = f"Attendance improved in {subject_code}: attended {delta_attended} new class(es)."
            elif delta_total > 0 and delta_attended < delta_total:
                msg = f"Attendance dropped in {subject_code}: missed {delta_total - delta_attended} class(es)."
            else:
                msg = f"Attendance updated in {subject_code}."

            updates.append({
                "category": "attendance",
                "subject_code": subject_code,
                "type": "changed",
                "message": msg,
                "previous": {
                    "classes_attended": old_attended,
                    "classes_total": old_total,
                    "percentage": old_pct,
                },
                "current": {
                    "classes_attended": new_attended,
                    "classes_total": new_total,
                    "percentage": new_pct,
                    "duty_leave": cur.get("duty_leave"),
                },
                "delta": {
                    "classes_attended": delta_attended,
                    "classes_total": delta_total,
                    "percentage": None if old_pct is None or new_pct is None else round(new_pct - old_pct, 2),
                },
            })

    for subject_code in sorted(set(prev) - set(live)):
        updates.append({
            "category": "attendance",
            "subject_code": subject_code,
            "type": "removed_subject",
            "message": f"{subject_code} no longer appears in live attendance page.",
            "previous": prev[subject_code],
        })

    return updates


def _marks_changes(previous_rows: list[dict], live_rows: list[dict]) -> list[dict]:
    def _key(row: dict) -> tuple[str, str, str]:
        return (
            str(row.get("subject_code") or ""),
            str(row.get("exam_type") or ""),
            str(row.get("exam_number") or ""),
        )

    prev = {_key(r): r for r in previous_rows}
    live = {_key(r): r for r in live_rows}
    updates: list[dict] = []

    for key, cur in live.items():
        old = prev.get(key)
        subject_code, exam_type, exam_number = key
        cur_mark = _as_float(cur.get("marks_obtained"))
        old_mark = _as_float(old.get("marks_obtained")) if old else None

        if not old:
            updates.append({
                "category": "marks",
                "subject_code": subject_code,
                "exam_type": exam_type,
                "exam_number": exam_number,
                "type": "new_result_row",
                "message": f"New mark row found for {subject_code} ({exam_type} {exam_number}).",
                "current": cur,
            })
            continue

        if old_mark != cur_mark:
            msg = (
                f"New mark published for {subject_code} ({exam_type} {exam_number}): {cur_mark}."
                if old_mark is None and cur_mark is not None
                else f"Mark updated for {subject_code} ({exam_type} {exam_number})."
            )
            updates.append({
                "category": "marks",
                "subject_code": subject_code,
                "exam_type": exam_type,
                "exam_number": exam_number,
                "type": "changed",
                "message": msg,
                "previous": {"marks_obtained": old_mark, "max_marks": _as_float(old.get("max_marks"))},
                "current": {"marks_obtained": cur_mark, "max_marks": _as_float(cur.get("max_marks"))},
                "delta": None if old_mark is None or cur_mark is None else round(cur_mark - old_mark, 2),
            })

    return updates


def _university_result_changes(previous_rows: list[dict], live_rows: list[dict]) -> list[dict]:
    def _key(row: dict) -> tuple[str, str]:
        return (
            str(row.get("exam_id") or ""),
            str(row.get("subject_code") or ""),
        )

    prev = {_key(r): r for r in previous_rows}
    live = {_key(r): r for r in live_rows}
    updates: list[dict] = []

    for key, cur in live.items():
        old = prev.get(key)
        exam_id, subject_code = key
        if not old:
            updates.append({
                "category": "university_results",
                "exam_id": exam_id,
                "subject_code": subject_code,
                "type": "new_result",
                "message": f"New university result available for {subject_code} (exam {exam_id}).",
                "current": cur,
            })
            continue

        changed_fields = []
        for field in ("grade", "result_status", "sgpa", "cgpa"):
            if (old.get(field) or None) != (cur.get(field) or None):
                changed_fields.append(field)

        if changed_fields:
            updates.append({
                "category": "university_results",
                "exam_id": exam_id,
                "subject_code": subject_code,
                "type": "changed",
                "message": f"University result updated for {subject_code} ({', '.join(changed_fields)}).",
                "changed_fields": changed_fields,
                "previous": {f: old.get(f) for f in changed_fields},
                "current": {f: cur.get(f) for f in changed_fields},
            })

    return updates


# ── PUBLIC: POST /auth/login ─────────────────────────────────────────

@router.post(
    "/auth/login",
    response_model=TokenResponse,
    summary="Login with Etlab credentials, get JWT tokens",
)
def auth_login(body: LoginRequest) -> TokenResponse:
    """
    Authenticates via full sync (scrapes all data if stale).
    Returns access_token (6h) + refresh_token (30d).
    """
    try:
        result = sync_service.sync_all(
            client=get_supabase(),
            username=body.username,
            password=body.password,
            force=False,
        )
    except RuntimeError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED,
                            detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                            detail=str(exc)) from exc
    except Exception as exc:
        log.exception("Unexpected error during auth_login")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                            detail=str(exc)) from exc

    roll = result["roll_number"]
    access = create_access_token(roll, body.device_id)
    refresh = create_refresh_token(roll, body.device_id)

    return TokenResponse(
        access_token=access,
        refresh_token=refresh,
        roll_number=roll,
    )


# ── PUBLIC: POST /auth/refresh ───────────────────────────────────────

@router.post(
    "/auth/refresh",
    response_model=RefreshResponse,
    summary="Get a new access token using a refresh token",
)
def auth_refresh(body: RefreshRequest) -> RefreshResponse:
    """Exchange a valid refresh token for a new access token."""
    try:
        payload = decode_token(body.refresh_token)
        if payload.get("type") != "refresh":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token type. Send a refresh token.",
            )
        roll = payload["sub"]
        device_id = payload.get("device")
        new_access = create_access_token(roll, device_id)
        return RefreshResponse(access_token=new_access)
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token expired. Please login again.",
        )
    except jwt.InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token.",
        )


# ══════════════════════════════════════════════════════════════════════
# PROTECTED ROUTES — all require Bearer JWT
# ══════════════════════════════════════════════════════════════════════


# ── POST /sync-all ───────────────────────────────────────────────────

@router.post(
    "/sync-all",
    response_model=SyncSummary,
    summary="Full sync: scrape all data and store in Supabase",
)
def sync_all(body: SyncRequest, user: dict = Depends(get_current_user)) -> SyncSummary:
    try:
        result = sync_service.sync_all(
            client=get_supabase(),
            username=body.username,
            password=body.password,
            force=body.force,
        )
    except RuntimeError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc)) from exc
    except Exception as exc:
        log.exception("Unexpected error during sync_all")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(exc)) from exc

    return SyncSummary(**result)


# ── POST /update-attendance ──────────────────────────────────────────

@router.post(
    "/update-attendance",
    response_model=OKResponse,
    summary="Lightweight attendance-only refresh",
)
def update_attendance(body: AttendanceSyncRequest, user: dict = Depends(get_current_user)) -> OKResponse:
    try:
        result = sync_service.sync_attendance_only(
            client=get_supabase(),
            username=body.username,
            password=body.password,
        )
    except RuntimeError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc)) from exc
    except Exception as exc:
        log.exception("Unexpected error during update_attendance")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(exc)) from exc

    return OKResponse(message=f"Attendance updated: {result['attendance_written']} rows for {result['roll_number']}")


@router.post(
    "/live/attendance-duty-leave",
    response_model=dict,
    summary="Live scrape: attendance with duty leave (no DB write)",
)
def get_live_attendance_with_duty_leave(
    body: LiveScrapeRequest,
    user: dict = Depends(get_current_user),
) -> dict:
    try:
        etlab = session_scraper.create_session(body.username, body.password)
        profile = profile_scraper.scrape_profile(etlab)
        roll_number = profile.get("roll_number")
        etlab_user_id = profile.get("etlab_user_id")

        if not etlab_user_id:
            raise ValueError("etlab_user_id not found from profile/attendance navigation.")

        rows = attendance_scraper.scrape_attendance_with_duty_leave(etlab, etlab_user_id)
        return {
            "roll_number": roll_number,
            "etlab_user_id": etlab_user_id,
            "scraped_at": profile.get("scraped_at"),
            "attendance": rows,
            "count": len(rows),
        }
    except RuntimeError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc)) from exc
    except Exception as exc:
        log.exception("Unexpected error during live duty-leave attendance scrape")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(exc)) from exc


@router.post(
    "/live/monthly-attendance",
    response_model=dict,
    summary="Live scrape: month-wise attendance view (no DB write)",
)
def get_live_monthly_attendance(
    body: LiveScrapeRequest,
    user: dict = Depends(get_current_user),
) -> dict:
    try:
        etlab = session_scraper.create_session(body.username, body.password)
        profile = profile_scraper.scrape_profile(etlab)
        monthly = attendance_scraper.scrape_monthly_attendance(etlab)

        return {
            "roll_number": profile.get("roll_number"),
            "etlab_user_id": monthly.get("etlab_user_id") or profile.get("etlab_user_id"),
            "scraped_at": monthly.get("scraped_at"),
            "months": monthly.get("months", []),
            "count": len(monthly.get("months", [])),
        }
    except RuntimeError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except Exception as exc:
        log.exception("Unexpected error during monthly attendance scrape")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(exc)) from exc


@router.post(
    "/live/updates",
    response_model=dict,
    summary="Compare live ETLAB data vs last synced DB data (no DB write)",
)
def get_live_updates(
    body: LiveScrapeRequest,
    user: dict = Depends(get_current_user),
) -> dict:
    try:
        sb = get_supabase()
        etlab = session_scraper.create_session(body.username, body.password)
        profile = profile_scraper.scrape_profile(etlab)
        roll_number = profile.get("roll_number")
        etlab_user_id = profile.get("etlab_user_id")

        if not roll_number:
            raise ValueError("roll_number not found from profile page.")
        if not etlab_user_id:
            raise ValueError("etlab_user_id not found from profile/attendance navigation.")

        student = students_db.get_student_by_roll(sb, roll_number)
        if not student:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"No synced baseline found for {roll_number}. Run /sync-all first.",
            )

        student_id = student["id"]

        prev_attendance = att_db.get_attendance(sb, student_id)
        prev_marks = marks_db.get_marks(sb, student_id)
        prev_university = uni_db.get_university_results(sb, student_id)

        live_attendance = attendance_scraper.scrape_attendance_with_duty_leave(etlab, etlab_user_id)
        live_marks = marks_scraper.scrape_marks(etlab)
        live_university = uni_scraper.scrape_university_results(etlab) if body.include_university_results else []

        attendance_updates = _attendance_changes(prev_attendance, live_attendance)
        marks_updates = _marks_changes(prev_marks, live_marks)
        university_updates = (
            _university_result_changes(prev_university, live_university)
            if body.include_university_results
            else []
        )

        updates = attendance_updates + marks_updates + university_updates

        return {
            "roll_number": roll_number,
            "etlab_user_id": etlab_user_id,
            "total_changes": len(updates),
            "attendance_changes": attendance_updates,
            "marks_changes": marks_updates,
            "university_result_changes": university_updates,
            "updates": updates,
            "checked_against_last_sync": True,
        }
    except RuntimeError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc)) from exc
    except HTTPException:
        raise
    except Exception as exc:
        log.exception("Unexpected error during live updates comparison")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(exc)) from exc


# ── GET /profile/{roll} ──────────────────────────────────────────────

@router.get(
    "/profile/{roll}",
    response_model=ProfileResponse,
    summary="Get stored student profile",
)
def get_profile(roll: str, user: dict = Depends(get_current_user)) -> ProfileResponse:
    student = _require_student(roll)
    data    = profile_db.get_profile(get_supabase(), student["id"])
    if not data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND,
                            detail="Profile not found. Login first.")
    # Exclude internal DB columns not in ProfileResponse schema
    exclude = {"id", "student_id", "department_id", "programme_id", "current_semester_id", "created_at"}
    filtered = {k: v for k, v in data.items() if k not in exclude}
    return ProfileResponse(**filtered)


# ── GET /internal-results/{roll} ─────────────────────────────────────

@router.get(
    "/internal-results/{roll}",
    response_model=InternalMarksResponse,
    summary="Get stored internal / sessional exam marks",
)
def get_internal_results(roll: str, user: dict = Depends(get_current_user)) -> InternalMarksResponse:
    student = _require_student(roll)
    rows    = marks_db.get_marks(get_supabase(), student["id"])
    marks   = [InternalMarkRow(**{k: v for k, v in r.items()
                                  if k in InternalMarkRow.model_fields}) for r in rows]
    return InternalMarksResponse(roll_number=roll, marks=marks)


# ── GET /university-results/{roll} ───────────────────────────────────

@router.get(
    "/university-results/{roll}",
    response_model=UniversityResultsResponse,
    summary="Get stored university / end-semester exam results",
)
def get_university_results(roll: str, user: dict = Depends(get_current_user)) -> UniversityResultsResponse:
    student = _require_student(roll)
    rows    = uni_db.get_university_results(get_supabase(), student["id"])
    results = [UniversityResultRow(**{k: v for k, v in r.items()
                                      if k in UniversityResultRow.model_fields}) for r in rows]
    return UniversityResultsResponse(roll_number=roll, results=results)


# ── GET /timetable/{roll} ────────────────────────────────────────────

@router.get(
    "/timetable/{roll}",
    response_model=TimetableResponse,
    summary="Get stored weekly timetable",
)
def get_timetable(roll: str, day: str | None = None, user: dict = Depends(get_current_user)) -> TimetableResponse:
    student = _require_student(roll)
    raw     = tt_db.get_timetable(get_supabase(), student["id"], day=day)
    slots   = [TimetableSlot(**{k: v for k, v in r.items()
                                if k in TimetableSlot.model_fields}) for r in raw]
    return TimetableResponse(roll_number=roll, slots=slots)


# ── GET /attendance/{roll} ────────────────────────────────────────────

@router.get(
    "/attendance/{roll}",
    response_model=AttendanceResponse,
    summary="Get stored attendance per subject",
)
def get_attendance(roll: str, user: dict = Depends(get_current_user)) -> AttendanceResponse:
    student = _require_student(roll)
    rows    = att_db.get_attendance(get_supabase(), student["id"])
    attendance = [AttendanceRow(**{k: v for k, v in r.items()
                                   if k in AttendanceRow.model_fields}) for r in rows]
    return AttendanceResponse(roll_number=roll, attendance=attendance)


# ── GET /subjects ─────────────────────────────────────────────────────

@router.get(
    "/subjects",
    response_model=SubjectsResponse,
    summary="List all subjects seen across any scrape",
)
def get_subjects(q: str | None = None, user: dict = Depends(get_current_user)) -> SubjectsResponse:
    sb    = get_supabase()
    query = sb.table("subjects").select("*").order("subject_code")
    if q:
        query = query.ilike("subject_code", f"{q}%")
    rows = query.execute().data or []
    return SubjectsResponse(subjects=rows)


# ── GET /summary/{roll} ───────────────────────────────────────────────

@router.get(
    "/summary/{roll}",
    response_model=StudentSummary,
    summary="Student overview: CGPA, attendance %, GPA progression",
)
def get_summary(roll: str, user: dict = Depends(get_current_user)) -> StudentSummary:
    sb   = get_supabase()
    resp = (
        sb.table("v_student_summary")
        .select("*")
        .eq("roll_number", roll)
        .limit(1)
        .execute()
    )
    if not resp.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No data found for '{roll}'. Login first.",
        )
    return StudentSummary(**resp.data[0])


# ── GET /departments ───────────────────────────────────────────────────

@router.get(
    "/departments",
    summary="List all departments",
    response_model=list[dict],
)
def get_departments(user: dict = Depends(get_current_user)) -> list[dict]:
    resp = get_supabase().table("departments").select("*").order("name").execute()
    return resp.data or []


# ── GET /programmes ────────────────────────────────────────────────────

@router.get(
    "/programmes",
    summary="List all programmes",
    response_model=list[dict],
)
def get_programmes(user: dict = Depends(get_current_user)) -> list[dict]:
    resp = get_supabase().table("programmes").select("*").order("name").execute()
    return resp.data or []


# ── GET /academic-years ────────────────────────────────────────────────

@router.get(
    "/academic-years",
    summary="List all academic years",
    response_model=list[dict],
)
def get_academic_years(user: dict = Depends(get_current_user)) -> list[dict]:
    resp = (
        get_supabase()
        .table("academic_years")
        .select("*")
        .order("start_year")
        .execute()
    )
    return resp.data or []


# ── GET /semesters ─────────────────────────────────────────────────────

@router.get(
    "/semesters",
    summary="List all semesters",
    response_model=list[dict],
)
def get_semesters(user: dict = Depends(get_current_user)) -> list[dict]:
    resp = (
        get_supabase()
        .table("semesters")
        .select("*")
        .order("semester_number")
        .execute()
    )
    return resp.data or []


# ── GET /teachers ──────────────────────────────────────────────────────

@router.get(
    "/teachers",
    summary="List all teachers seen in timetable scrapes",
    response_model=list[dict],
)
def get_teachers(user: dict = Depends(get_current_user)) -> list[dict]:
    resp = (
        get_supabase()
        .table("teachers")
        .select("*")
        .order("full_name")
        .execute()
    )
    return resp.data or []
