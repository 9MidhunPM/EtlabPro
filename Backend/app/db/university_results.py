"""
db.university_results
─────────────────────
CRUD for the `university_results` table.
"""
import logging
from datetime import datetime, timezone

from supabase import Client

log = logging.getLogger(__name__)


def _upsert_subjects(client: Client, rows: list[dict]) -> None:
    """Ensure all subject codes exist in subjects before FK insert."""
    seen: dict[str, dict] = {}
    for r in rows:
        code = r.get("subject_code") or ""
        if code and code not in seen:
            seen[code] = {
                "subject_code": code,
                "subject_name": r.get("subject_name") or None,
                "credit":       r.get("credit"),
            }
    if not seen:
        return
    (
        client.table("subjects")
        .upsert(list(seen.values()), on_conflict="subject_code")
        .execute()
    )


def upsert_university_results(client: Client, student_id: str, rows: list[dict]) -> int:
    """
    Upsert university exam results.
    `rows` is the list returned by scraper.university_results.scrape_university_results().

    Returns the number of rows written.
    """
    if not rows:
        return 0

    _upsert_subjects(client, rows)

    payload = [
        {
            "student_id":     student_id,
            "exam_id":        r["exam_id"],
            "exam_name":      r.get("exam_name"),
            "semester_label": r.get("semester_label"),
            "academic_year":  r.get("academic_year"),
            "exam_month":     r.get("exam_month"),
            "exam_year":      r.get("exam_year"),
            "slot":           r.get("slot"),
            "subject_code":   r["subject_code"],
            "subject_name":   r.get("subject_name"),
            "grade":          r.get("grade"),
            "credit":         r.get("credit"),
            "result_status":  r.get("result_status"),
            "sgpa":           r.get("sgpa"),
            "cgpa":           r.get("cgpa"),
            "earned_credit":  r.get("earned_credit"),
            "scraped_at":     r.get("scraped_at") or _now(),
        }
        for r in rows
    ]

    (
        client.table("university_results")
        .upsert(payload, on_conflict="student_id,subject_code,exam_id")
        .execute()
    )
    log.info(
        "Upserted %d university result rows for student_id=%s…",
        len(payload), student_id[:8]
    )
    return len(payload)


def get_university_results(client: Client, student_id: str) -> list[dict]:
    resp = (
        client.table("university_results")
        .select("*")
        .eq("student_id", student_id)
        .order("exam_id")
        .order("subject_code")
        .execute()
    )
    return resp.data or []


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()
