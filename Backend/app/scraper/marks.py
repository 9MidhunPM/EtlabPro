"""
scraper.marks
─────────────
Scrapes all internal assessment tables from:
  GET /ktuacademics/student/results

The page has 6 tables (based on real page inspection):
  Table 0: Series / Sessional Exams
  Table 1: Module Tests
  Table 2: Class Projects
  Table 3: Assignments
  Table 4: Tutorial (part 1)
  Table 5: Tutorial (part 2)

All are stored with an `exam_type` field so they can be queried separately.
Returns a list of dicts — no DB calls.
"""
import logging
from datetime import datetime

import requests
from bs4 import BeautifulSoup

from app.config import get_settings

TIMEOUT = get_settings().REQUEST_TIMEOUT
URL     = f"{get_settings().ETLAB_BASE_URL}/ktuacademics/student/results"

log = logging.getLogger(__name__)

# Maps table index → exam_type label
# Based on real page: Table 0=series exam, 1=module test, 2=class project,
#                     3=assignment, 4-5=tutorial
TABLE_TYPE_MAP = {
    0: "series_exam",
    1: "module_test",
    2: "class_project",
    3: "assignment",
    4: "tutorial",
    5: "tutorial",
}

# Marker strings that mean "no data yet" — skip these rows
_EMPTY_MARKERS = frozenset([
    "no module test yet",
    "no class projects yet",
    "no tutorial added  yet",
    "no tutorial added yet",
])


def _parse_subject(raw: str) -> tuple[str, str]:
    """'24CST403 - DAA' → ('24CST403', 'DAA')"""
    parts = raw.split(" - ", 1)
    return (parts[0].strip(), parts[1].strip()) if len(parts) == 2 else ("", raw.strip())


def _safe_float(val: str) -> float | None:
    try:
        return float(val)
    except (ValueError, TypeError):
        return None


def scrape_marks(session: requests.Session) -> list[dict]:
    """
    Returns:
        [
          {
            "subject_code":   str,
            "subject_name":   str,
            "semester":       str,
            "exam_number":    int | str,  # int for exams, str for assignments
            "exam_type":      str,        # series_exam | module_test | etc.
            "max_marks":      float,
            "marks_obtained": float | None,
            "scraped_at":     str (ISO),
          },
          ...
        ]
    """
    log.info("Scraping internal marks: %s", URL)
    resp = session.get(URL, timeout=TIMEOUT)
    resp.raise_for_status()
    soup = BeautifulSoup(resp.text, "lxml")

    tables = soup.find_all("table")
    if not tables:
        log.warning("No tables found on marks page")
        return []

    now = datetime.utcnow().isoformat()
    results: list[dict] = []

    for table_idx, table in enumerate(tables):
        exam_type = TABLE_TYPE_MAP.get(table_idx, f"table_{table_idx}")
        tbody = table.find("tbody") or table

        for tr in tbody.find_all("tr"):
            cells = [td.get_text(strip=True) for td in tr.find_all("td")]
            if not cells or len(cells) < 4:
                continue

            # Skip "no data" marker rows
            if cells[0].lower().strip() in _EMPTY_MARKERS:
                continue
            # Skip header-like rows
            if cells[0].lower() in ("subject", "sl no", "#"):
                continue

            code, name = _parse_subject(cells[0])
            semester    = cells[1]

            # Column 2: exam number (series) or exam label (assignment = "Assignment 1")
            raw_exam = cells[2]
            try:
                exam_number: int | str = int(raw_exam)
            except ValueError:
                exam_number = raw_exam   # e.g. "Assignment 1"

            max_marks    = _safe_float(cells[3]) or 0.0
            raw_obtained = cells[4] if len(cells) > 4 else ""

            # Values like "Results not published", "NOT SUBMITTED", "N/A" → None
            marks_obtained = _safe_float(raw_obtained)

            results.append({
                "subject_code":   code,
                "subject_name":   name,
                "semester":       semester,
                "exam_number":    exam_number,
                "exam_type":      exam_type,
                "max_marks":      max_marks,
                "marks_obtained": marks_obtained,
                "scraped_at":     now,
            })

    log.info("Scraped %d mark rows across %d tables", len(results), len(tables))
    return results
