"""
scraper.attendance
──────────────────
Scrapes subject-wise attendance from:
  GET /ktuacademics/student/viewattendancesubject/{etlab_user_id}

The etlab_user_id is the numeric ID assigned to a student on the portal.
It is scraped from the student profile and stored in the `students` table.

Returns a list of dicts — no DB calls.
"""
import re
import logging
from datetime import datetime

import requests
from bs4 import BeautifulSoup

from app.config import get_settings

TIMEOUT  = get_settings().REQUEST_TIMEOUT
BASE_URL = get_settings().ETLAB_BASE_URL

log = logging.getLogger(__name__)


def _attendance_url(etlab_user_id: str) -> str:
    return f"{BASE_URL}/ktuacademics/student/viewattendancesubject/{etlab_user_id}"


def scrape_attendance(session: requests.Session, etlab_user_id: str) -> list[dict]:
    """
    Args:
        session:        Authenticated requests.Session.
        etlab_user_id:  The numeric user ID from the etlab portal
                        (extracted from profile page or dashboard URL).

    Returns:
        [
          {
            "subject_code":      str,
            "classes_attended":  int,
            "classes_total":     int,
            "percentage":        float,
            "scraped_at":        str (ISO),
          },
          ...
        ]
    """
    url = _attendance_url(etlab_user_id)
    log.info("Scraping attendance: %s", url)
    resp = session.get(url, timeout=TIMEOUT)
    resp.raise_for_status()
    soup = BeautifulSoup(resp.text, "lxml")

    table = soup.find("table")
    if not table:
        log.warning("No attendance table found")
        return []

    # Header row: UNi Reg No | Roll No | Name | <subject code> … | Total | Percentage
    thead = table.find("thead")
    headers = [th.get_text(strip=True) for th in thead.find_all(["th", "td"])] if thead else []
    subject_codes = headers[3:-2]   # strip first 3 and last 2 fixed columns

    tbody = table.find("tbody") or table
    now   = datetime.utcnow().isoformat()
    results: list[dict] = []

    for tr in tbody.find_all("tr"):
        cells = [td.get_text(strip=True) for td in tr.find_all("td")]
        if len(cells) < len(headers):
            continue
        for i, code in enumerate(subject_codes):
            cell_val = cells[3 + i]
            # Format: '22/24 (92%)'
            m = re.match(r"(\d+)/(\d+)\s*\((\d+)%\)", cell_val)
            if not m:
                continue
            results.append({
                "subject_code":     code,
                "classes_attended": int(m.group(1)),
                "classes_total":    int(m.group(2)),
                "percentage":       float(m.group(3)),
                "scraped_at":       now,
            })

    log.info("Scraped %d attendance rows", len(results))
    return results
