"""
db.marks
────────
CRUD for the `internal_marks_events` table (canonical v3 schema).

Uses delete-then-insert (not upsert) because semester_id is NULL and
Postgres unique constraints treat NULL != NULL, so ON CONFLICT won't
fire — causing duplicate rows on every sync.
"""
import logging
from datetime import datetime, timezone

from supabase import Client

log = logging.getLogger(__name__)

# Canonical exam_type_enum values
_EXAM_TYPE_ENUM = frozenset([
    "series_exam", "module_test", "class_project", "assignment", "tutorial"
])


def _normalize_exam_type(raw: str | None) -> str:
    """Map a raw exam_type to a valid exam_type_enum value, defaulting to series_exam."""
    if raw and raw.lower() in _EXAM_TYPE_ENUM:
        return raw.lower()
    return "series_exam"


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
        {
            "subject_code": code,
            "subject_name": name if name else code,
        }
        for code, name in seen.items()
    ]
    (
        client.table("subjects")
        .upsert(payload, on_conflict="subject_code")
        .execute()
    )


def upsert_marks(client: Client, student_id: str, rows: list[dict]) -> int:
    """
    Replace all internal mark rows for the student.
    Deletes existing rows first (safe full-refresh) because semester_id is NULL
    and ON CONFLICT can't match NULLs.
    `rows` is the list returned by scraper.marks.scrape_marks().

    Returns the number of rows written.
    """
    if not rows:
        return 0

    _upsert_subjects(client, rows)

    # Delete all existing marks for this student before re-inserting
    client.table("internal_marks_events").delete().eq("student_id", student_id).execute()

    payload = [
        {
            "student_id":       student_id,
            "semester_id":      r.get("semester_id") or None,
            "subject_code":     r["subject_code"],
            "raw_subject_name": r.get("subject_name") or None,
            "exam_number":      str(r["exam_number"]),
            "exam_type":        _normalize_exam_type(r.get("exam_type")),
            "max_marks":        r["max_marks"],
            "marks_obtained":   r.get("marks_obtained"),
            "scraped_at":       r.get("scraped_at") or _now(),
        }
        for r in rows
    ]

    client.table("internal_marks_events").insert(payload).execute()
    log.info(
        "Replaced %d internal_marks_events rows for student_id=%s…",
        len(payload), student_id[:8],
    )
    return len(payload)


def get_marks(client: Client, student_id: str) -> list[dict]:
    resp = (
        client.table("internal_marks_events")
        .select("*")
        .eq("student_id", student_id)
        .order("subject_code")
        .order("exam_type")
        .order("exam_number")
        .execute()
    )
    return resp.data or []


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()
