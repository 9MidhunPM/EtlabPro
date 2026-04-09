"""
db.timetable
────────────
CRUD for the `timetable_slots` table (canonical v3 schema).
Timetable is fully replaced on every sync (delete-then-insert).
"""
import logging
from datetime import datetime, timezone

from supabase import Client

log = logging.getLogger(__name__)

# Maps scraper day strings to canonical day_of_week_enum values
_DAY_MAP: dict[str, str] = {
    "monday":    "Mon",
    "tuesday":   "Tue",
    "wednesday": "Wed",
    "thursday":  "Thu",
    "friday":    "Fri",
    "saturday":  "Sat",
    "sunday":    "Sun",
    "mon": "Mon",
    "tue": "Tue",
    "wed": "Wed",
    "thu": "Thu",
    "fri": "Fri",
    "sat": "Sat",
    "sun": "Sun",
}

# Maps scraper class-type strings → class_type_enum values
# Canonical enum: 'Lecture', 'Tutorial', 'Lab', 'Practical', 'Seminar', 'Workshop'
_CLASS_TYPE_MAP: dict[str, str] = {
    "theory":    "Lecture",
    "lecture":   "Lecture",
    "tutorial":  "Tutorial",
    "lab":       "Lab",
    "practical": "Practical",
    "seminar":   "Seminar",
    "workshop":  "Workshop",
}


def _normalize_day(raw: str) -> str:
    """Normalise a day string from the scraper to the DB enum value."""
    return _DAY_MAP.get(raw.strip().lower(), raw[:3].capitalize())


def _normalize_class_type(raw: str | None) -> str | None:
    """Map scraper class-type string to class_type_enum or None."""
    if not raw:
        return None
    mapped = _CLASS_TYPE_MAP.get(raw.strip().lower())
    if not mapped:
        log.warning("Unknown class_type %r — storing NULL", raw)
        return None
    return mapped


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


def replace_timetable(client: Client, student_id: str, rows: list[dict]) -> int:
    """
    Delete all existing timetable_slots for the student, then insert fresh data.
    `rows` is the list returned by scraper.timetable.scrape_timetable().

    Returns the number of rows written.
    """
    # Delete existing slots for student
    client.table("timetable_slots").delete().eq("student_id", student_id).execute()

    if not rows:
        return 0

    _upsert_subjects(client, rows)

    payload = [
        {
            "student_id":       student_id,
            "semester_id":      r.get("semester_id") or None,
            "day_of_week":      _normalize_day(r["day"]),
            "period_number":    int(r["period"]),
            "period_time":      r.get("period_time"),
            "subject_code":     r.get("subject_code") or None,
            "raw_subject_name": r.get("subject_name") or None,
            "class_type":       _normalize_class_type(r.get("class_type")),
            "teacher_name_raw": r.get("teacher") or None,
            "scraped_at":       r.get("scraped_at") or _now(),
        }
        for r in rows
    ]

    client.table("timetable_slots").insert(payload).execute()
    log.info(
        "Replaced timetable_slots with %d slots for student_id=%s…",
        len(payload), student_id[:8],
    )
    return len(payload)


def get_timetable(
    client: Client,
    student_id: str,
    day: str | None = None,
) -> list[dict]:
    query = (
        client.table("timetable_slots")
        .select("*")
        .eq("student_id", student_id)
        .order("day_of_week")
        .order("period_number")
    )
    if day:
        query = query.eq("day_of_week", _normalize_day(day))
    resp = query.execute()
    return resp.data or []


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()
