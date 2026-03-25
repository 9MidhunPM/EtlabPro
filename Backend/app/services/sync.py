"""
services.sync
─────────────
Orchestrates scraping + DB writes.
This is the only layer that calls both the scraper and DB modules.

Rules enforced here:
  - Scraper functions are called; their raw output passed to DB functions.
  - Scraper modules never see the Supabase client.
  - DB modules never see the requests.Session.
  - Refresh intervals are respected unless force=True.
"""
import logging

from supabase import Client

from app.config import get_settings
from app.scraper import session as session_mod
from app.scraper import marks as marks_scraper
from app.scraper import attendance as att_scraper
from app.scraper import timetable as tt_scraper
from app.scraper import profile as profile_scraper
from app.scraper import university_results as uni_scraper

from app.db import students as students_db
from app.db import marks as marks_db
from app.db import attendance as att_db
from app.db import timetable as tt_db
from app.db import profile as profile_db
from app.db import university_results as uni_db
from app.db import sync_meta

cfg = get_settings()
log = logging.getLogger(__name__)


def sync_all(
    client: Client,
    username: str,
    password: str,
    force: bool = False,
) -> dict:
    """
    Full sync for a student.
    1. Login
    2. Scrape profile → determine roll_number + etlab_user_id
    3. Upsert student row
    4. Sync each category respecting refresh intervals

    Returns a SyncSummary-compatible dict.
    """
    # ── Login ──────────────────────────────────────────────────────────
    etlab = session_mod.create_session(username, password)

    # ── Profile (always scraped first — we need roll_number) ───────────
    profile_data = profile_scraper.scrape_profile(etlab)
    roll_number  = profile_data.get("roll_number")

    if not roll_number:
        raise ValueError(
            "Could not determine roll_number from profile page. "
            "Check scraper/profile.py FIELD_MAP and selectors."
        )

    etlab_user_id = profile_data.get("etlab_user_id")

    # ── Ensure student row exists ──────────────────────────────────────
    student = students_db.get_or_create_student(
        client,
        roll_number=roll_number,
        admission_number=profile_data.get("admission_number"),
        etlab_user_id=etlab_user_id,
    )
    student_id = student["id"]

    summary: dict = {
        "roll_number":                roll_number,
        "marks_written":              0,
        "attendance_written":         0,
        "timetable_written":          0,
        "profile_updated":            False,
        "university_results_written": 0,
        "skipped":                    [],
    }

    # ── Profile sync ───────────────────────────────────────────────────
    if force or sync_meta.needs_refresh(client, student_id, "profile", cfg.PROFILE_MAX_AGE_SECONDS):
        profile_db.upsert_profile(client, student_id, profile_data)
        sync_meta.mark_synced(client, student_id, "profile", rows_written=1)
        summary["profile_updated"] = True
    else:
        summary["skipped"].append("profile")

    # ── Internal Marks ─────────────────────────────────────────────────
    if force or sync_meta.needs_refresh(client, student_id, "marks", cfg.MARKS_MAX_AGE_SECONDS):
        rows = marks_scraper.scrape_marks(etlab)
        n = marks_db.upsert_marks(client, student_id, rows)
        summary["marks_written"] = n
        sync_meta.mark_synced(client, student_id, "marks", rows_written=n)
    else:
        summary["skipped"].append("marks")

    # ── Attendance ─────────────────────────────────────────────────────
    if force or sync_meta.needs_refresh(client, student_id, "attendance", cfg.ATTENDANCE_MAX_AGE_SECONDS):
        if not etlab_user_id:
            log.warning("etlab_user_id unknown — cannot scrape attendance for %s", roll_number)
            summary["skipped"].append("attendance (etlab_user_id missing)")
        else:
            rows = att_scraper.scrape_attendance(etlab, etlab_user_id)
            n = att_db.upsert_attendance(client, student_id, rows)
            summary["attendance_written"] = n
            sync_meta.mark_synced(client, student_id, "attendance", rows_written=n)
    else:
        summary["skipped"].append("attendance")

    # ── Timetable ──────────────────────────────────────────────────────
    if force or sync_meta.needs_refresh(client, student_id, "timetable", cfg.TIMETABLE_MAX_AGE_SECONDS):
        rows = tt_scraper.scrape_timetable(etlab)
        n = tt_db.replace_timetable(client, student_id, rows)
        summary["timetable_written"] = n
        sync_meta.mark_synced(client, student_id, "timetable", rows_written=n)
    else:
        summary["skipped"].append("timetable")

    # ── University Results ─────────────────────────────────────────────
    if force or sync_meta.needs_refresh(client, student_id, "university_results", cfg.UNI_RESULTS_MAX_AGE_SECONDS):
        rows = uni_scraper.scrape_university_results(etlab)
        n = uni_db.upsert_university_results(client, student_id, rows)
        summary["university_results_written"] = n
        sync_meta.mark_synced(client, student_id, "university_results", rows_written=n)
    else:
        summary["skipped"].append("university_results")

    log.info("Sync complete for %s: %s", roll_number, summary)
    return summary


def sync_attendance_only(
    client: Client,
    username: str,
    password: str,
) -> dict:
    """
    Lightweight attendance-only sync.  Skips all other categories.
    Always scrapes (ignores refresh interval) since the caller
    explicitly requested an attendance update.
    """
    etlab = session_mod.create_session(username, password)

    # Still need profile to get roll_number + etlab_user_id
    profile_data  = profile_scraper.scrape_profile(etlab)
    roll_number   = profile_data.get("roll_number")
    etlab_user_id = profile_data.get("etlab_user_id")

    if not roll_number:
        raise ValueError("Could not determine roll_number from profile page.")

    student = students_db.get_or_create_student(
        client,
        roll_number=roll_number,
        etlab_user_id=etlab_user_id,
    )
    student_id = student["id"]

    if not etlab_user_id:
        raise ValueError(
            f"etlab_user_id not found for student {roll_number}. "
            "Run POST /sync-all first so the profile is stored."
        )

    rows = att_scraper.scrape_attendance(etlab, etlab_user_id)
    written = att_db.upsert_attendance(client, student_id, rows)
    sync_meta.mark_synced(client, student_id, "attendance", rows_written=written)

    return {"roll_number": roll_number, "attendance_written": written}
