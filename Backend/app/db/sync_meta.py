"""
db.sync_meta
────────────
Tracks when each data category was last synced per student.
Used by the service layer to decide whether a re-scrape is needed.
"""
import logging
from datetime import datetime, timezone, timedelta

from supabase import Client

log = logging.getLogger(__name__)

CATEGORIES = frozenset([
    "marks",
    "attendance",
    "timetable",
    "profile",
    "university_results",
])


def needs_refresh(
    client: Client,
    student_id: str,
    category: str,
    max_age_seconds: int,
) -> bool:
    """Return True if the category has never been synced or is stale."""
    resp = (
        client.table("sync_meta")
        .select("last_synced")
        .eq("student_id", student_id)
        .eq("category", category)
        .limit(1)
        .execute()
    )
    if not resp.data:
        return True

    last = datetime.fromisoformat(resp.data[0]["last_synced"])
    # Ensure timezone-aware comparison
    if last.tzinfo is None:
        last = last.replace(tzinfo=timezone.utc)

    age = datetime.now(timezone.utc) - last
    stale = age > timedelta(seconds=max_age_seconds)
    log.info(
        "sync_meta[%s/%s] last=%s  stale=%s",
        category, student_id[:8], resp.data[0]["last_synced"], stale
    )
    return stale


def mark_synced(
    client: Client,
    student_id: str,
    category: str,
    rows_written: int = 0,
    status: str = "ok",
    error_msg: str | None = None,
) -> None:
    """Upsert the last_synced timestamp, row count, and status for the category."""
    client.table("sync_meta").upsert(
        {
            "student_id":   student_id,
            "category":     category,
            "last_synced":  datetime.now(timezone.utc).isoformat(),
            "rows_written": rows_written,
            "status":       status,
            "error_msg":    error_msg,
        },
        on_conflict="student_id,category",
    ).execute()
