"""
etlab_sync_scraper.py
─────────────────────
Thin runner script — logs into ETlab, scrapes everything, and uploads
to Supabase by calling the existing app.* modules directly.

Required env vars in Backend/.env:
  SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, API_KEY,
  ETLAB_USERNAME, ETLAB_PASSWORD

Run:
  cd Backend
  python -m app.etlab_sync_scraper
"""

import logging
import os
import sys
from pathlib import Path

from dotenv import load_dotenv

# Load .env before any app.* import (Settings reads env at import time)
_ENV = Path(__file__).resolve().parent.parent / ".env"
load_dotenv(_ENV)

from app.db.client import get_supabase
from app.services.sync import sync_all

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(name)s — %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger(__name__)


def _require(name: str) -> str:
    v = os.getenv(name, "").strip()
    if not v:
        log.error("Missing env var: %s  — add it to Backend/.env", name)
        sys.exit(1)
    return v


def main() -> None:
    username = _require("ETLAB_USERNAME")
    password = _require("ETLAB_PASSWORD")

    sb = get_supabase()
    log.info("Starting full sync (force=True) …")

    try:
        summary = sync_all(
            client=sb,
            username=username,
            password=password,
            force=True,          # always scrape everything
        )
    except RuntimeError as exc:
        log.error("Login failed: %s", exc)
        sys.exit(1)
    except Exception as exc:
        log.exception("Sync failed: %s", exc)
        sys.exit(1)

    log.info("─" * 50)
    log.info("Done  — %s", summary.get("roll_number"))
    log.info("  Profile   : %s", "✓" if summary.get("profile_updated") else "skipped")
    log.info("  Marks     : %d rows", summary.get("marks_written", 0))
    log.info("  Attendance: %d rows", summary.get("attendance_written", 0))
    log.info("  Timetable : %d rows", summary.get("timetable_written", 0))
    log.info("  Uni results: %d rows", summary.get("university_results_written", 0))
    if summary.get("skipped"):
        log.info("  Skipped   : %s", ", ".join(summary["skipped"]))
    log.info("─" * 50)


if __name__ == "__main__":
    main()