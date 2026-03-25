"""
db.timetable
────────────
CRUD for the `timetable` table.
Timetable is fully replaced on every sync (delete-then-insert).
"""
import logging
from datetime import datetime, timezone

from supabase import Client

log = logging.getLogger(__name__)


def _upsert_subjects(client: Client, rows: list[dict]) -> None:
    """
    Ensure all subject codes in timetable rows exist in subjects before FK insert.
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


def replace_timetable(client: Client, student_id: str, rows: list[dict]) -> int:
    """
    Delete all existing timetable rows for the student, then insert fresh data.
    `rows` is the list returned by scraper.timetable.scrape_timetable().

    Returns the number of rows written.
    """
    # Delete existing
    client.table("timetable").delete().eq("student_id", student_id).execute()

    if not rows:
        return 0

    _upsert_subjects(client, rows)

    payload = [
        {
            "student_id":   student_id,
            "day":          r["day"],
            "period":       r["period"],
            "period_time":  r["period_time"],
            "subject_code": r.get("subject_code"),
            "subject_name": r.get("subject_name"),
            "class_type":   r.get("class_type"),
            "teacher":      r.get("teacher"),
            "scraped_at":   r.get("scraped_at") or _now(),
        }
        for r in rows
    ]

    client.table("timetable").insert(payload).execute()
    log.info("Replaced timetable with %d slots for student_id=%s…", len(payload), student_id[:8])
    return len(payload)


def get_timetable(client: Client, student_id: str, day: str | None = None) -> list[dict]:
    query = (
        client.table("timetable")
        .select("*")
        .eq("student_id", student_id)
        .order("day")
        .order("period")
    )
    if day:
        query = query.ilike("day", day)
    resp = query.execute()
    return resp.data or []


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()
