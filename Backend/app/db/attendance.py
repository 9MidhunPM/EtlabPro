"""
db.attendance
─────────────
CRUD for the `attendance_summary` table (canonical v3 schema).

Uses delete-then-insert (not upsert) because semester_id is NULL and
Postgres unique constraints treat NULL != NULL, so ON CONFLICT won't
fire — causing duplicate rows on every sync.
"""
import logging
from datetime import datetime, timezone

from supabase import Client

log = logging.getLogger(__name__)


def _ensure_subjects(client: Client, subject_codes: list[str]) -> None:
    """
    Ensure bare subject-code rows exist in subjects before attendance FK insert.
    """
    if not subject_codes:
        return
    payload = [{"subject_code": code, "subject_name": code}
               for code in dict.fromkeys(subject_codes)]
    (
        client.table("subjects")
        .upsert(payload, on_conflict="subject_code")
        .execute()
    )


def upsert_attendance(client: Client, student_id: str, rows: list[dict]) -> int:
    """
    Replace subject-wise attendance rows for the student.
    Deletes existing rows first (safe full-refresh) because semester_id is NULL
    and ON CONFLICT can't match NULLs.
    `rows` is the list returned by scraper.attendance.scrape_attendance().

    Returns the number of rows written.
    """
    if not rows:
        return 0

    _ensure_subjects(client, [r["subject_code"] for r in rows])

    # Delete all existing attendance for this student before re-inserting
    client.table("attendance_summary").delete().eq("student_id", student_id).execute()

    payload = [
        {
            "student_id":       student_id,
            "semester_id":      r.get("semester_id") or None,
            "subject_code":     r["subject_code"],
            "classes_attended": r["classes_attended"],
            "classes_total":    r["classes_total"],
            "percentage":       r["percentage"],
            "scraped_at":       r.get("scraped_at") or _now(),
        }
        for r in rows
    ]

    client.table("attendance_summary").insert(payload).execute()
    log.info(
        "Replaced %d attendance_summary rows for student_id=%s…",
        len(payload), student_id[:8],
    )
    return len(payload)


def get_attendance(client: Client, student_id: str) -> list[dict]:
    resp = (
        client.table("attendance_summary")
        .select("*")
        .eq("student_id", student_id)
        .order("subject_code")
        .execute()
    )
    return resp.data or []


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()
