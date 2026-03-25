"""
db.marks
────────
CRUD for the `internal_marks` table.
"""
import logging
from datetime import datetime, timezone

from supabase import Client

log = logging.getLogger(__name__)


def _upsert_subjects(client: Client, rows: list[dict]) -> None:
    """
    Ensure all subject codes referenced by `rows` exist in the subjects table.
    Must be called BEFORE inserting rows that FK → subjects.
    """
    seen: dict[str, str | None] = {}
    for r in rows:
        code = r.get("subject_code") or ""
        if code and code not in seen:
            seen[code] = r.get("subject_name") or None
    if not seen:
        return
    payload = [
        {"subject_code": code, "subject_name": name}
        for code, name in seen.items()
    ]
    (
        client.table("subjects")
        .upsert(payload, on_conflict="subject_code")
        .execute()
    )


def upsert_marks(client: Client, student_id: str, rows: list[dict]) -> int:
    """
    Upsert a batch of mark rows.
    `rows` is the list returned by scraper.marks.scrape_marks().

    Returns the number of rows written.
    """
    if not rows:
        return 0

    _upsert_subjects(client, rows)

    payload = [
        {
            "student_id":     student_id,
            "subject_code":   r["subject_code"],
            "subject_name":   r["subject_name"],
            "semester":       r["semester"],
            "exam_number":    str(r["exam_number"]),  # store as text (handles "Assignment 1")
            "exam_type":      r.get("exam_type", "series_exam"),
            "max_marks":      r["max_marks"],
            "marks_obtained": r["marks_obtained"],
            "scraped_at":     r.get("scraped_at") or _now(),
        }
        for r in rows
    ]

    (
        client.table("internal_marks")
        .upsert(payload, on_conflict="student_id,subject_code,semester,exam_number,exam_type")
        .execute()
    )
    log.info("Upserted %d internal mark rows for student_id=%s…", len(payload), student_id[:8])
    return len(payload)


def get_marks(client: Client, student_id: str) -> list[dict]:
    resp = (
        client.table("internal_marks")
        .select("*")
        .eq("student_id", student_id)
        .order("semester")
        .order("subject_code")
        .execute()
    )
    return resp.data or []


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()
