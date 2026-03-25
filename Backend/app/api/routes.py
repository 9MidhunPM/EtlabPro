"""
api.routes
──────────
All FastAPI endpoint definitions.

Public routes: POST /auth/login, POST /auth/refresh
Protected routes: require a valid Bearer JWT (enforced via Depends).
"""
import logging

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
from app.models.schemas import (
    SyncRequest,
    AttendanceSyncRequest,
    SyncSummary,
    ProfileResponse,
    InternalMarksResponse,
    AttendanceResponse,
    TimetableResponse,
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
    return ProfileResponse(roll_number=roll, **data)


# ── GET /internal-results/{roll} ─────────────────────────────────────

@router.get(
    "/internal-results/{roll}",
    response_model=InternalMarksResponse,
    summary="Get stored internal / sessional exam marks",
)
def get_internal_results(roll: str, user: dict = Depends(get_current_user)) -> InternalMarksResponse:
    student = _require_student(roll)
    rows    = marks_db.get_marks(get_supabase(), student["id"])
    return InternalMarksResponse(roll_number=roll, marks=rows)


# ── GET /university-results/{roll} ───────────────────────────────────

@router.get(
    "/university-results/{roll}",
    response_model=UniversityResultsResponse,
    summary="Get stored university / end-semester exam results",
)
def get_university_results(roll: str, user: dict = Depends(get_current_user)) -> UniversityResultsResponse:
    student = _require_student(roll)
    rows    = uni_db.get_university_results(get_supabase(), student["id"])
    return UniversityResultsResponse(roll_number=roll, results=rows)


# ── GET /timetable/{roll} ────────────────────────────────────────────

@router.get(
    "/timetable/{roll}",
    response_model=TimetableResponse,
    summary="Get stored weekly timetable",
)
def get_timetable(roll: str, day: str | None = None, user: dict = Depends(get_current_user)) -> TimetableResponse:
    student = _require_student(roll)
    slots   = tt_db.get_timetable(get_supabase(), student["id"], day=day)
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
    return AttendanceResponse(roll_number=roll, attendance=rows)


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
