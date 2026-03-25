"""
db.attendance
─────────────
CRUD for the `attendance` table.
Fully overwrite-safe — designed for lightweight frequent updates.
"""
import logging
from datetime import datetime, timezone

from supabase import Client

log = logging.getLogger(__name__)


def _ensure_subjects(client: Client, subject_codes: list[str]) -> None:
    """
    Ensure bare subject-code rows exist in subjects before attendance FK insert.
    The attendance scraper only returns codes (no names); names are filled later
    by the fn_fill_attendance_subject_name DB trigger.
    """
    if not subject_codes:
        return
    payload = [{"subject_code": code} for code in dict.fromkeys(subject_codes)]
    (
        client.table("subjects")
        .upsert(payload, on_conflict="subject_code")
        .execute()
    )


def upsert_attendance(client: Client, student_id: str, rows: list[dict]) -> int:
    """
    Upsert subject-wise attendance rows.
    `rows` is the list returned by scraper.attendance.scrape_attendance().

    Returns the number of rows written.
    """
    if not rows:
        return 0

    _ensure_subjects(client, [r["subject_code"] for r in rows])

    payload = [
        {
            "student_id":        student_id,
            "subject_code":      r["subject_code"],
            "subject_name":      r.get("subject_name"),
            "classes_attended":  r["classes_attended"],
            "classes_total":     r["classes_total"],
            "percentage":        r["percentage"],
            "scraped_at":        r.get("scraped_at") or _now(),
        }
        for r in rows
    ]

    (
        client.table("attendance")
        .upsert(payload, on_conflict="student_id,subject_code")
        .execute()
    )
    log.info("Upserted %d attendance rows for student_id=%s…", len(payload), student_id[:8])
    return len(payload)


def get_attendance(client: Client, student_id: str) -> list[dict]:
    resp = (
        client.table("attendance")
        .select("*")
        .eq("student_id", student_id)
        .order("subject_code")
        .execute()
    )
    return resp.data or []


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()
