"""
scraper.university_results
â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
Scrapes all university / end-semester exam results.

Real page structure (verified against sahrdaya.etlab.in):

  Step 1 â€” GET /universityexam/student/examresult
    Lists all exam sessions with a "View Result" button per session.
    Button href:  /universityexam/student/viewresult/{exam_id}

  Step 2 â€” GET /universityexam/student/viewresult/{exam_id}   (one per session)
    Table #0: exam_name, programme, semester_label
    Table #1: academic_year, exam_month, exam_year
    Table #2: per-subject rows + tfoot with Earned Credit / SGPA / CGPA
      Columns: No | Slot | Course Code | Course Name | Grade | Credit | Pass Status

Returns a list of dicts â€” no DB calls.
"""
import re
import logging
from datetime import datetime

import requests
from bs4 import BeautifulSoup

from app.config import get_settings

TIMEOUT  = get_settings().REQUEST_TIMEOUT
BASE_URL = get_settings().ETLAB_BASE_URL
LIST_URL = f"{BASE_URL}/universityexam/student/examresult"

log = logging.getLogger(__name__)


def _safe_float(val: str) -> float | None:
    try:
        return float(val.strip())
    except (ValueError, TypeError, AttributeError):
        return None


def _scrape_detail(
    session: requests.Session,
    exam_id: str,
    exam_name: str,
) -> list[dict]:
    """
    Fetch one viewresult detail page and return a list of subject-result dicts.
    Returns empty list if results not yet published.
    """
    url = f"{BASE_URL}/universityexam/student/viewresult/{exam_id}"
    log.info("Fetching exam detail: %s", url)
    resp = session.get(url, timeout=TIMEOUT)
    resp.raise_for_status()
    soup = BeautifulSoup(resp.text, "lxml")

    tables = soup.find_all("table")
    if len(tables) < 3:
        log.info("Exam %s: results not published yet (%d tables)", exam_id, len(tables))
        return []

    # â”€â”€ Table #0: metadata â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    meta0_rows = []
    for tr in (tables[0].find("tbody") or tables[0]).find_all("tr"):
        text = tr.get_text(strip=True)
        if text:
            meta0_rows.append(text)
    # Row order: exam_name, programme, semester_label
    semester_label = meta0_rows[2] if len(meta0_rows) > 2 else ""

    # â”€â”€ Table #1: date metadata â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    meta1_rows = []
    for tr in (tables[1].find("tbody") or tables[1]).find_all("tr"):
        text = tr.get_text(strip=True)
        if text:
            meta1_rows.append(text)
    academic_year = meta1_rows[0] if meta1_rows else ""
    exam_month    = meta1_rows[1] if len(meta1_rows) > 1 else ""
    exam_year     = meta1_rows[2] if len(meta1_rows) > 2 else ""

    # â”€â”€ Table #2: results (thead + tbody + tfoot) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    results_table = tables[2]

    # Extract SGPA / CGPA from tfoot
    sgpa: float | None = None
    cgpa: float | None = None
    earned_credit: float | None = None
    tfoot = results_table.find("tfoot")
    if tfoot:
        for tr in tfoot.find_all("tr"):
            label = tr.get_text(strip=True).lower()
            val_td = tr.find_all("td")[-1] if tr.find_all("td") else None
            val = val_td.get_text(strip=True) if val_td else ""
            if "sgpa" in label:
                sgpa = _safe_float(val)
            elif "cgpa" in label:
                cgpa = _safe_float(val)
            elif "earned credit" in label:
                earned_credit = _safe_float(val)

    now = datetime.utcnow().isoformat()
    rows: list[dict] = []

    tbody = results_table.find("tbody") or results_table
    for tr in tbody.find_all("tr"):
        cells = [td.get_text(strip=True) for td in tr.find_all("td")]
        # Expected: [No, Slot, Course Code, Course Name, Grade, Credit, Pass Status]
        if len(cells) < 5:
            continue
        subject_code = cells[2]
        if not subject_code or subject_code.lower() in ("course code", "no"):
            continue  # skip header-like rows

        rows.append({
            "exam_id":        exam_id,
            "exam_name":      exam_name,
            "semester_label": semester_label,
            "academic_year":  academic_year,
            "exam_month":     exam_month,
            "exam_year":      exam_year,
            "slot":           cells[1] if len(cells) > 1 else None,
            "subject_code":   subject_code,
            "subject_name":   cells[3] if len(cells) > 3 else None,
            "grade":          cells[4] if len(cells) > 4 else None,
            "credit":         _safe_float(cells[5]) if len(cells) > 5 else None,
            "result_status":  cells[6] if len(cells) > 6 else None,
            "sgpa":           sgpa,
            "cgpa":           cgpa,
            "earned_credit":  earned_credit,
            "scraped_at":     now,
        })

    log.info(
        "Exam %s (%s): %d subjects  SGPA=%s  CGPA=%s",
        exam_id, semester_label, len(rows), sgpa, cgpa,
    )
    return rows


def scrape_university_results(session: requests.Session) -> list[dict]:
    """
    Scrape all university exam sessions.

    Returns:
        [
          {
            "exam_id":        str,   # e.g. "7"
            "exam_name":      str,   # e.g. "First Semester Regular B. Tech..."
            "semester_label": str,   # e.g. "Ist Semester"
            "academic_year":  str,
            "exam_month":     str,
            "exam_year":      str,
            "slot":           str | None,
            "subject_code":   str,
            "subject_name":   str | None,
            "grade":          str | None,
            "credit":         float | None,
            "result_status":  str | None,
            "sgpa":           float | None,   # same for all rows in an exam
            "cgpa":           float | None,
            "earned_credit":  float | None,
            "scraped_at":     str (ISO),
          },
          ...
        ]
    """
    log.info("Fetching university results list: %s", LIST_URL)
    resp = session.get(LIST_URL, timeout=TIMEOUT)
    resp.raise_for_status()
    soup = BeautifulSoup(resp.text, "lxml")

    # Find all "View Result" links and their exam names
    exam_links: list[tuple[str, str]] = []   # (exam_id, exam_name)
    for a in soup.find_all("a", href=True):
        m = re.search(r"/viewresult/(\d+)", a["href"])
        if not m:
            continue
        exam_id = m.group(1)
        # Exam name is in the blue sibling div
        parent = a.find_parent("div", class_="row")
        exam_name = ""
        if parent:
            blue = parent.find(
                "div",
                style=lambda s: s and "background-color:#0864a2" in s,
            )
            if blue:
                exam_name = blue.get_text(strip=True)
        exam_links.append((exam_id, exam_name))

    log.info("Found %d exam sessions", len(exam_links))

    all_results: list[dict] = []
    for exam_id, exam_name in exam_links:
        try:
            rows = _scrape_detail(session, exam_id, exam_name)
            all_results.extend(rows)
        except Exception as exc:
            log.warning("Failed to scrape exam %s: %s", exam_id, exc)

    log.info("Scraped %d university result rows total", len(all_results))
    return all_results

