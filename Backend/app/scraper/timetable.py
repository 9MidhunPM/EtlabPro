"""
scraper.timetable
─────────────────
Scrapes weekly timetable from:
  GET /student/timetable

Returns a list of dicts — no DB calls.
"""
import re
import logging
from datetime import datetime

import requests
from bs4 import BeautifulSoup

from app.config import get_settings

TIMEOUT  = get_settings().REQUEST_TIMEOUT
URL      = f"{get_settings().ETLAB_BASE_URL}/student/timetable"

log = logging.getLogger(__name__)

_PERIOD_RE = re.compile(
    r"Period\s+(\d+)\s*\[?\s*(\d{2}:\d{2}\s*[AP]M\s*-\s*\d{2}:\d{2}\s*[AP]M)\s*\]?"
)
_SUBJECT_RE = re.compile(
    r"^([\w\d]+)\s*-\s*(.+?)\[\s*(Theory|Lab|Practical|Tutorial)\s*\](.*)$",
    re.IGNORECASE,
)


def scrape_timetable(session: requests.Session) -> list[dict]:
    """
    Returns:
        [
          {
            "day":          str,
            "period":       int,
            "period_time":  str,
            "subject_code": str | None,
            "subject_name": str | None,
            "class_type":   str | None,
            "teacher":      str | None,
            "scraped_at":   str (ISO),
          },
          ...
        ]
    """
    log.info("Scraping timetable: %s", URL)
    resp = session.get(URL, timeout=TIMEOUT)
    resp.raise_for_status()
    soup = BeautifulSoup(resp.text, "lxml")

    tables = soup.find_all("table")
    if not tables:
        log.warning("No timetable tables found")
        return []

    table = tables[0]
    thead = table.find("thead")
    headers_raw = (
        [th.get_text(strip=True) for th in thead.find_all(["th", "td"])] if thead else []
    )

    # Parse period headers (skip first "Day" column)
    periods: list[tuple[int, str]] = []
    for h in headers_raw[1:]:
        m = _PERIOD_RE.search(h)
        if m:
            periods.append((int(m.group(1)), m.group(2).strip()))
        else:
            periods.append((len(periods) + 1, h))

    tbody = table.find("tbody") or table
    now   = datetime.utcnow().isoformat()
    results: list[dict] = []

    for tr in tbody.find_all("tr"):
        cells = tr.find_all("td")
        if not cells:
            continue
        day = cells[0].get_text(strip=True)
        if not day or day.lower() == "day":
            continue

        for i, (period_num, period_time) in enumerate(periods):
            if i + 1 >= len(cells):
                break
            cell_text = cells[i + 1].get_text(strip=True)

            if not cell_text or cell_text.lower() == "free period":
                results.append({
                    "day": day, "period": period_num, "period_time": period_time,
                    "subject_code": None, "subject_name": "Free Period",
                    "class_type": None, "teacher": None, "scraped_at": now,
                })
                continue

            m = _SUBJECT_RE.match(cell_text)
            if m:
                code    = m.group(1).strip()
                name    = m.group(2).strip()
                ctype   = m.group(3).strip()
                teacher = m.group(4).strip().rstrip(",") if m.group(4) else ""
            else:
                code    = ""
                name    = cell_text
                ctype   = "Lab" if "LAB" in cell_text.upper() else ""
                teacher = ""

            results.append({
                "day": day, "period": period_num, "period_time": period_time,
                "subject_code": code or None,
                "subject_name": name or None,
                "class_type":   ctype or None,
                "teacher":      teacher or None,
                "scraped_at":   now,
            })

    log.info("Scraped %d timetable slots", len(results))
    return results
