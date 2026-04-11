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
MONTH_NAMES = (
    "january", "february", "march", "april", "may", "june",
    "july", "august", "september", "october", "november", "december",
)

log = logging.getLogger(__name__)


def _attendance_url(etlab_user_id: str) -> str:
    return f"{BASE_URL}/ktuacademics/student/viewattendancesubject/{etlab_user_id}"


def _attendance_duty_leave_url(etlab_user_id: str) -> str:
    return f"{BASE_URL}/ktuacademics/student/viewattendancesubjectdutyleave/{etlab_user_id}"


def _monthly_attendance_url() -> str:
    return f"{BASE_URL}/ktuacademics/student/attendance"


def _extract_attendance_metrics(cell_val: str) -> tuple[int, int, float, int | None]:
    """
    Parse attendance metrics from flexible cell formats.
    Supported examples:
      "22/24 (92%)"
      "22/24 (91.67%) DL: 2"
      "22 / 24"
    """
    frac = re.search(r"(\d+)\s*/\s*(\d+)", cell_val)
    if not frac:
        raise ValueError("cell does not contain an attended/total fraction")

    attended = int(frac.group(1))
    total = int(frac.group(2))

    pct_match = re.search(r"(\d+(?:\.\d+)?)\s*%", cell_val)
    percentage = float(pct_match.group(1)) if pct_match else round((attended / total) * 100, 2) if total else 0.0

    duty_leave: int | None = None
    dl_match = re.search(r"(?:duty\s*leave|\bdl\b)\s*[:=\-]?\s*(\d+)", cell_val, flags=re.I)
    if dl_match:
        duty_leave = int(dl_match.group(1))
    else:
        nums = [int(n) for n in re.findall(r"\d+", cell_val)]
        # Heuristic fallback for formats where the third number is duty-leave count.
        if len(nums) >= 3:
            candidate = nums[2]
            if candidate <= total:
                duty_leave = candidate

    return attended, total, percentage, duty_leave


def _extract_month_label(text: str) -> str | None:
    low = text.lower()
    for month in MONTH_NAMES:
        if month in low:
            return month.title()
    return None


def _extract_date(text: str) -> str | None:
    m = re.search(r"\b(\d{1,2}[\-/]\d{1,2}[\-/]\d{2,4})\b", text)
    return m.group(1) if m else None


def _status_from_text_and_classes(text: str, classes: str) -> str | None:
    low = text.lower()
    cls = classes.lower()
    if any(k in low for k in ("duty leave", "dl")) or any(k in cls for k in ("duty", "leave", "warning")):
        return "duty_leave"
    if any(k in low for k in ("absent", "missed")) or any(k in cls for k in ("danger", "absent", "miss")):
        return "absent"
    if any(k in low for k in ("present", "attended")) or any(k in cls for k in ("success", "present", "attended", "green")):
        return "present"
    return None


def _canonical_cell_status(td, text: str) -> str:
    classes = {c.lower().strip() for c in (td.get("class") or [])}
    low = text.lower().strip()

    if "present" in classes:
        return "present"
    if "absent" in classes:
        return "absent"
    if "late" in classes:
        return "late"
    if "duty-leave" in classes or "duty_leave" in classes or "duty" in classes:
        return "duty_leave"
    if "holiday" in classes or "h-day" in classes or "hday" in classes:
        return "holiday"
    if "n-a" in classes or "na" in classes:
        return "na"

    # Fallback heuristics for occasional markup variations.
    if "duty" in low and "leave" in low:
        return "duty_leave"
    if "absent" in low:
        return "absent"
    if "late" in low:
        return "late"
    if text.strip():
        return "present"
    return "na"


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
            try:
                attended, total, percentage, _ = _extract_attendance_metrics(cell_val)
            except ValueError:
                continue
            results.append({
                "subject_code":     code,
                "classes_attended": attended,
                "classes_total":    total,
                "percentage":       percentage,
                "scraped_at":       now,
            })

    log.info("Scraped %d attendance rows", len(results))
    return results


def scrape_attendance_with_duty_leave(session: requests.Session, etlab_user_id: str) -> list[dict]:
    """
    Scrape attendance from the duty-leave inclusive URL.
    Returns per-subject rows and keeps duty_leave if visible on the page.
    """
    url = _attendance_duty_leave_url(etlab_user_id)
    log.info("Scraping attendance with duty leave: %s", url)
    resp = session.get(url, timeout=TIMEOUT)
    resp.raise_for_status()
    soup = BeautifulSoup(resp.text, "lxml")

    table = soup.find("table")
    if not table:
        log.warning("No duty-leave attendance table found")
        return []

    thead = table.find("thead")
    headers = [th.get_text(strip=True) for th in thead.find_all(["th", "td"])] if thead else []
    subject_codes = headers[3:-2]

    tbody = table.find("tbody") or table
    now = datetime.utcnow().isoformat()
    results: list[dict] = []

    for tr in tbody.find_all("tr"):
        cells = [td.get_text(strip=True) for td in tr.find_all("td")]
        if len(cells) < len(headers):
            continue

        for i, code in enumerate(subject_codes):
            cell_val = cells[3 + i]
            try:
                attended, total, percentage, duty_leave = _extract_attendance_metrics(cell_val)
            except ValueError:
                continue

            row = {
                "subject_code": code,
                "classes_attended": attended,
                "classes_total": total,
                "percentage": percentage,
                "scraped_at": now,
            }
            if duty_leave is not None:
                row["duty_leave"] = duty_leave
            results.append(row)

    log.info("Scraped %d duty-leave attendance rows", len(results))
    return results


def _get_available_semesters_and_months(soup: BeautifulSoup) -> dict:
    """
    Extract available semesters and their available months from the page.
    
    Returns:
        {
            "current_semester": "4",
            "available_semesters": ["1", "2", "3", "4"],  # Only those with data
            "months_by_semester": {
                "1": ["9", "10", "11", "12"],  # Calendar month numbers
                "2": ["1", "2", "3", "4"],
                "3": ["7", "8", "9", "10", "11"],
                "4": ["12", "1", "2", "3", "4"]
            }
        }
    """
    sem_select = soup.find("select", id="semester")
    month_select = soup.find("select", id="month")
    
    # Get current semester
    current_sem = None
    if sem_select:
        selected = sem_select.find("option", selected=True)
        if selected:
            current_sem = selected.get("value")
    
    # For now, store current available months (these change per semester on the form)
    available_months = []
    if month_select:
        for opt in month_select.find_all("option"):
            available_months.append(opt.get("value"))
    
    return {
        "current_semester": current_sem,
        "available_months_now": available_months,  # Months for currently selected semester
    }


def scrape_monthly_attendance(
    session: requests.Session,
    semester: str | None = None,
    month: str | None = None,
    year: str | None = None,
) -> dict:
    """
    Scrape monthly attendance page and return month-wise day status aggregates.
    
    Args:
        session:   Authenticated requests.Session.
        semester:  Optional semester value (1-10) to fetch specific semester. If None, uses current/default.
        month:     Optional month value (calendar month number 1-12) to fetch. If None, uses current/default.
        year:      Optional year value (e.g., "2025", "2026") to fetch specific year. If None, uses current/default.
    
    Returns:
        Dictionary with month attendance data.
        
    Note:
        Each semester only has certain months available (typically 2-5 months per semester).
        If an invalid semester/month combination is requested, the ETLAB portal will
        return the default month for that semester.
    """
    url = _monthly_attendance_url()
    log.info("Scraping monthly attendance page: %s", url)
    resp = session.get(url, timeout=TIMEOUT)
    resp.raise_for_status()
    soup = BeautifulSoup(resp.text, "lxml")

    etlab_user_id = None
    m = re.search(r"/viewattendancesubject/(\d+)", resp.text)
    if m:
        etlab_user_id = m.group(1)

    # Get form details
    form = soup.find("form")
    form_action = form.get("action") if form else None
    form_url = form_action if form_action and form_action.startswith("http") else f"{BASE_URL}{form_action}"
    
    # If specific semester/month/year requested, POST to the form with those parameters
    if semester or month or year:
        post_data = {}
        if semester:
            post_data["semester"] = semester
            log.info("Requesting semester: %s", semester)
        if month:
            post_data["month"] = month
            log.info("Requesting month: %s", month)
        if year:
            post_data["year"] = year
            log.info("Requesting year: %s", year)
        
        if post_data:
            resp = session.post(form_url, data=post_data, timeout=TIMEOUT)
            resp.raise_for_status()
            soup = BeautifulSoup(resp.text, "lxml")

    month_select = soup.find("select", id="month")
    year_select = soup.find("select", id="year")
    semester_select = soup.find("select", id="semester")

    def _selected_or_last(select_tag) -> str | None:
        if not select_tag:
            return None
        selected = select_tag.find("option", selected=True)
        if selected:
            return selected.get_text(" ", strip=True)
        options = select_tag.find_all("option")
        return options[-1].get_text(" ", strip=True) if options else None

    month_label = _selected_or_last(month_select)
    year_label = _selected_or_last(year_select)
    semester_label = _selected_or_last(semester_select)

    if not month_label:
        till_match = re.search(r"%\s*till\s*([A-Za-z]+)", soup.get_text(" ", strip=True), flags=re.I)
        if till_match:
            month_label = till_match.group(1).title()
    if not month_label:
        month_label = "Unknown"

    bucket = {
        "month": month_label,
        "year": year_label,
        "semester": semester_label,
        "days_present": 0,
        "days_absent": 0,
        "days_duty_leave": 0,
        "days_late": 0,
        "days_holiday": 0,
        "days_na": 0,
        "total_marked_days": 0,
        "period_present": 0,
        "period_absent": 0,
        "period_duty_leave": 0,
        "period_late": 0,
        "period_holiday": 0,
        "period_na": 0,
        "period_total": 0,
        "entries": [],
    }

    table = soup.find("table")
    if not table:
        return {
            "etlab_user_id": etlab_user_id,
            "months": [bucket],
            "scraped_at": datetime.utcnow().isoformat(),
        }

    rows = table.find_all("tr")
    for tr in rows[1:]:
        day_th = tr.find("th")
        tds = tr.find_all("td")
        if not day_th or not tds:
            continue

        day_match = re.search(r"\d+", day_th.get_text(" ", strip=True))
        if not day_match:
            continue
        day = int(day_match.group(0))

        day_counts = {
            "present": 0,
            "absent": 0,
            "duty_leave": 0,
            "late": 0,
            "holiday": 0,
            "na": 0,
        }
        periods: list[dict] = []

        period_index = 1
        for td in tds:
            colspan = int(td.get("colspan", "1") or "1")
            text = td.get_text(" ", strip=True)
            status = _canonical_cell_status(td, text)

            for _ in range(max(colspan, 1)):
                periods.append({
                    "period": period_index,
                    "status": status,
                    "subject": text or None,
                })
                period_index += 1

            day_counts[status] = day_counts.get(status, 0) + max(colspan, 1)

        bucket["period_total"] += len(periods)
        bucket["period_present"] += day_counts.get("present", 0)
        bucket["period_absent"] += day_counts.get("absent", 0)
        bucket["period_duty_leave"] += day_counts.get("duty_leave", 0)
        bucket["period_late"] += day_counts.get("late", 0)
        bucket["period_holiday"] += day_counts.get("holiday", 0)
        bucket["period_na"] += day_counts.get("na", 0)

        dominant = max(day_counts, key=lambda k: day_counts.get(k, 0)) if day_counts else "na"
        if dominant == "present":
            bucket["days_present"] += 1
        elif dominant == "absent":
            bucket["days_absent"] += 1
        elif dominant == "duty_leave":
            bucket["days_duty_leave"] += 1
        elif dominant == "late":
            bucket["days_late"] += 1
        elif dominant == "holiday":
            bucket["days_holiday"] += 1
        else:
            bucket["days_na"] += 1

        bucket["total_marked_days"] += 1
        bucket["entries"].append({
            "day": day,
            "day_label": day_th.get_text(" ", strip=True),
            "summary": dominant,
            "counts": day_counts,
            "periods": periods,
        })

    bucket["entries"] = sorted(bucket["entries"], key=lambda r: r["day"])

    return {
        "etlab_user_id": etlab_user_id,
        "months": [bucket],
        "scraped_at": datetime.utcnow().isoformat(),
    }


def scrape_monthly_attendance_all_months(
    session: requests.Session,
    semesters: list[str] | None = None,
) -> dict:
    """
    Scrape monthly attendance for ALL available months in each semester.
    Returns historical attendance data for all semesters and their months.
    
    Args:
        session:    Authenticated requests.Session.
        semesters:  List of semester values (e.g., ["1", "2", "3", "4"]) to scrape.
                   If None, scrapes 1-4 (the valid semesters).
    
    Returns:
        {
            "total_months": N,
            "months": [
                {
                    "semester": "Ist Semester",
                    "semester_value": "1",
                    "month": "July",
                    "year": "2025",
                    "days_present": 25,
                    "days_absent": 2,
                    "days_duty_leave": 0,
                    "total_marked_days": 27,
                    "display": "Ist Semester - July 2025 (25P, 2A)"
                },
                # ... more months
            ],
            "scraped_at": "2026-04-11T15:30:45.123456",
        }
    """
    url = _monthly_attendance_url()
    log.info("Scraping monthly attendance for ALL months across all semesters")
    
    if semesters is None:
        semesters = ["1", "2", "3", "4"]  # Only valid semesters with real data
    
    all_months = []
    
    for semester in semesters:
        log.info(f"Fetching semester {semester}...")
        
        # First, select the semester to see what months are available
        resp = session.post(url, data={"semester": semester}, timeout=TIMEOUT)
        soup = BeautifulSoup(resp.text, "lxml")
        
        # Get available months for this semester
        month_select = soup.find("select", id="month")
        if not month_select:
            log.warning(f"No month dropdown found for semester {semester}")
            continue
        
        # Get all available month values for this semester
        month_options = month_select.find_all("option")
        available_months = []
        for opt in month_options:
            val = opt.get("value")
            if val:
                available_months.append({
                    "value": val,
                    "label": opt.get_text(strip=True),
                })
        
        log.info(f"Semester {semester}: {len(available_months)} months available")
        
        # Fetch data for each month
        for month_info in available_months:
            month_val = month_info["value"]
            month_label = month_info["label"]
            
            resp = session.post(
                url,
                data={
                    "semester": semester,
                    "month": month_val,
                },
                timeout=TIMEOUT
            )
            
            soup = BeautifulSoup(resp.text, "lxml")
            
            # Extract displayed semester/month/year
            sem_select = soup.find("select", id="semester")
            month_select = soup.find("select", id="month")
            year_select = soup.find("select", id="year")
            
            def _get_selected_text(select_elem):
                if not select_elem:
                    return None
                selected = select_elem.find("option", selected=True)
                if selected:
                    return selected.get_text(strip=True)
                # Fallback: get first non-empty option
                options = select_elem.find_all("option")
                if options:
                    return options[0].get_text(strip=True)
                return None
            
            semester_display = _get_selected_text(sem_select) or semester
            month_display = _get_selected_text(month_select) or month_label
            year_display = _get_selected_text(year_select) or "Unknown"
            
            # Initialize bucket
            bucket = {
                "semester": semester_display,
                "semester_value": semester,
                "month": month_display,
                "year": year_display,
                "days_present": 0,
                "days_absent": 0,
                "days_duty_leave": 0,
                "days_late": 0,
                "days_holiday": 0,
                "days_na": 0,
                "total_marked_days": 0,
            }
            
            # Parse attendance table
            table = soup.find("table")
            if table:
                rows = table.find_all("tr")[1:]
                for tr in rows:
                    day_th = tr.find("th")
                    tds = tr.find_all("td")
                    if not day_th or not tds:
                        continue
                    
                    day_counts = {"present": 0, "absent": 0, "duty_leave": 0, "late": 0, "holiday": 0, "na": 0}
                    
                    for td in tds:
                        text = td.get_text(" ", strip=True)
                        status = _canonical_cell_status(td, text)
                        colspan = int(td.get("colspan", "1") or "1")
                        day_counts[status] = day_counts.get(status, 0) + max(colspan, 1)
                    
                    dominant = max(day_counts, key=lambda k: day_counts.get(k, 0))
                    if dominant == "present":
                        bucket["days_present"] += 1
                    elif dominant == "absent":
                        bucket["days_absent"] += 1
                    elif dominant == "duty_leave":
                        bucket["days_duty_leave"] += 1
                    elif dominant == "late":
                        bucket["days_late"] += 1
                    elif dominant == "holiday":
                        bucket["days_holiday"] += 1
                    else:
                        bucket["days_na"] += 1
                    
                    bucket["total_marked_days"] += 1
            
            # Add display string
            bucket["display"] = (
                f"{semester_display} - {month_display} {year_display or ''} "
                f"({bucket['days_present']}P, {bucket['days_absent']}A)"
            ).strip()
            
            all_months.append(bucket)
            log.info(f"  ✓ {bucket['display']}")
    
    return {
        "total_months": len(all_months),
        "months": all_months,
        "scraped_at": datetime.utcnow().isoformat(),
    }
