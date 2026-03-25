"""
db.university_results
─────────────────────
CRUD for `exam_sessions` + `university_exam_results` (canonical v3 schema).

Write order:
  1. upsert exam_sessions (one row per unique exam_id)
  2. upsert university_exam_results (FKs exam_session_id, subject_code)
"""
import logging
from datetime import datetime, timezone

from supabase import Client

log = logging.getLogger(__name__)

# Map scraped pass-status strings to result_status_enum values
_STATUS_MAP: dict[str, str] = {
    "pass":    "pass",
    "p":       "pass",
    "fail":    "fail",
    "f":       "fail",
    "fc":      "fail",
    "absent":  "absent",
    "ab":      "absent",
    "withheld":"withheld",
    "wh":      "withheld",
}


def _map_result_status(raw: str | None) -> str | None:
    if not raw:
        return None
    return _STATUS_MAP.get(raw.strip().lower(), "pending")


def _upsert_subjects(client: Client, rows: list[dict]) -> None:
    """Ensure all subject codes exist in subjects before FK insert."""
    seen: dict[str, dict] = {}
    for r in rows:
        code = r.get("subject_code") or ""
        if code and code not in seen:
            seen[code] = {
                "subject_code": code,
                "subject_name": r.get("subject_name") or code,
                "credit":       r.get("credit"),
            }
    if not seen:
        return
    (
        client.table("subjects")
        .upsert(list(seen.values()), on_conflict="subject_code")
        .execute()
    )


def _upsert_exam_sessions(client: Client, rows: list[dict]) -> dict[str, str]:
    """
    Upsert one exam_sessions row per unique exam_id.
    Returns mapping {exam_id: session_uuid}.
    """
    # De-duplicate by exam_id — take the first occurrence of each
    sessions: dict[str, dict] = {}
    for r in rows:
        eid = r["exam_id"]
        if eid not in sessions:
            sessions[eid] = {
                "exam_id":      eid,
                "exam_name":    r.get("exam_name") or None,
                "exam_month":   r.get("exam_month") or None,
                "exam_year":    _safe_int(r.get("exam_year")),
                "slot":         r.get("slot") or None,
                # semester_id and academic_year_id require resolution — NULL for now
                "semester_id":       None,
                "academic_year_id":  None,
            }

    if not sessions:
        return {}

    payload = list(sessions.values())
    resp = (
        client.table("exam_sessions")
        .upsert(payload, on_conflict="exam_id")
        .execute()
    )
    # Build lookup {exam_id → uuid}
    lookup: dict[str, str] = {}
    for row in (resp.data or []):
        lookup[row["exam_id"]] = row["id"]

    # Fallback: fetch IDs for any exam_ids not returned by upsert
    missing = [eid for eid in sessions if eid not in lookup]
    if missing:
        fb = (
            client.table("exam_sessions")
            .select("id, exam_id")
            .in_("exam_id", missing)
            .execute()
        )
        for row in (fb.data or []):
            lookup[row["exam_id"]] = row["id"]

    return lookup


def _safe_int(val) -> int | None:
    try:
        return int(str(val).strip())
    except (ValueError, TypeError):
        return None


def upsert_university_results(client: Client, student_id: str, rows: list[dict]) -> int:
    """
    Upsert university exam results into the canonical table pair.
    `rows` is the list returned by scraper.university_results.scrape_university_results().

    Returns the total number of university_exam_results rows written.
    """
    if not rows:
        return 0

    _upsert_subjects(client, rows)
    session_lookup = _upsert_exam_sessions(client, rows)

    payload = []
    for r in rows:
        session_id = session_lookup.get(r["exam_id"])
        if not session_id:
            log.warning("No exam_session_id for exam_id=%s — skipping row", r["exam_id"])
            continue
        payload.append({
            "student_id":      student_id,
            "exam_session_id": session_id,
            "subject_code":    r["subject_code"],
            "raw_subject_name": r.get("subject_name") or None,
            "grade":           r.get("grade") or None,
            "result_status":   _map_result_status(r.get("result_status")),
            "credit":          r.get("credit"),
            "sgpa":            r.get("sgpa"),
            "cgpa":            r.get("cgpa"),
            "earned_credit":   r.get("earned_credit"),
            "scraped_at":      r.get("scraped_at") or _now(),
        })

    if payload:
        (
            client.table("university_exam_results")
            .upsert(
                payload,
                on_conflict="student_id,exam_session_id,subject_code",
            )
            .execute()
        )

    log.info(
        "Upserted %d university_exam_results rows for student_id=%s…",
        len(payload), student_id[:8],
    )
    return len(payload)


def get_university_results(client: Client, student_id: str) -> list[dict]:
    """
    Returns university results joined with exam session metadata.
    """
    resp = (
        client.table("university_exam_results")
        .select("*, exam_sessions(exam_id, exam_name, exam_month, exam_year, slot)")
        .eq("student_id", student_id)
        .order("exam_session_id")
        .order("subject_code")
        .execute()
    )
    # Flatten exam_sessions nested object into the row for API compatibility
    results = []
    for row in (resp.data or []):
        session = row.pop("exam_sessions", {}) or {}
        results.append({**row, **session})
    return results


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()
