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
import re

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


def _normalize_header(text: str) -> str:
    return re.sub(r"\s+", " ", text.strip().lower())


def _extract_series_rows_from_wide_table(
    table,
    now: str,
) -> list[dict]:
    """
    Handle table layouts where Series 1/2 are columns in the same row.
    Example header patterns: "Series 1", "Series 2", "Assignment 1".
    """
    thead = table.find("thead")
    if not thead:
        return []

    header_cells = [
        _normalize_header(th.get_text(strip=True))
        for th in thead.find_all(["th", "td"])
    ]
    if not header_cells:
        return []

    subject_idx = next((i for i, h in enumerate(header_cells) if "subject" in h or "course" in h), None)
    semester_idx = next((i for i, h in enumerate(header_cells) if "semester" in h), None)
    if subject_idx is None:
        return []

    metric_cols: list[tuple[int, str, int | str, float | None]] = []
    for idx, header in enumerate(header_cells):
        if idx in (subject_idx, semester_idx):
            continue

        m_series = re.search(r"series\s*(\d+)", header)
        if m_series:
            metric_cols.append((idx, "series_exam", int(m_series.group(1)), 30.0))
            continue

        m_assign = re.search(r"assignment\s*(\d+)", header)
        if m_assign:
            metric_cols.append((idx, "assignment", f"Assignment {m_assign.group(1)}", None))
            continue

        m_module = re.search(r"module\s*test\s*(\d+)", header)
        if m_module:
            metric_cols.append((idx, "module_test", int(m_module.group(1)), None))
            continue

    if not metric_cols:
        return []

    tbody = table.find("tbody") or table
    rows: list[dict] = []
    for tr in tbody.find_all("tr"):
        cells = [td.get_text(strip=True) for td in tr.find_all("td")]
        if not cells or len(cells) <= subject_idx:
            continue

        first = cells[0].lower().strip()
        if first in _EMPTY_MARKERS or first in ("subject", "sl no", "#"):
            continue

        subject_raw = cells[subject_idx]
        code, name = _parse_subject(subject_raw)
        if not code and not name:
            continue

        semester = cells[semester_idx] if semester_idx is not None and semester_idx < len(cells) else ""

        for col_idx, exam_type, exam_number, default_max in metric_cols:
            if col_idx >= len(cells):
                continue
            raw_obtained = cells[col_idx]
            marks_obtained = _safe_float(raw_obtained)
            if marks_obtained is None and raw_obtained.strip().lower() in _EMPTY_MARKERS:
                continue

            rows.append({
                "subject_code": code,
                "subject_name": name,
                "semester": semester,
                "exam_number": exam_number,
                "exam_type": exam_type,
                "max_marks": default_max or 0.0,
                "marks_obtained": marks_obtained,
                "scraped_at": now,
            })

    return rows


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

        # Prefer explicit wide-table parsing when series/assignment columns exist.
        wide_rows = _extract_series_rows_from_wide_table(table, now)
        if wide_rows:
            results.extend(wide_rows)
            continue

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
