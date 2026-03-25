"""
db.reference_tables
────────────────────
Populates lookup / reference tables from scraped student data:
  - departments   (unique on: code)
  - programmes    (unique on: code)
  - academic_years (unique on: label)
  - semesters     (unique on: programme_id, academic_year_id, semester_label)
  - teachers      (no unique on full_name — use select-then-insert pattern)

Called once per sync_all after all primary data is written.
Everything is idempotent so re-running is always safe.
"""
import logging
import re

from supabase import Client

log = logging.getLogger(__name__)


def populate_from_db(client: Client, student_id: str, profile_data: dict) -> dict:
    """
    Populate reference tables using data already stored in Supabase canonical tables.
    Called when sync is skipped (data is fresh) so reference tables still fill.
    """
    # Read existing DB rows for each category
    att_rows = (
        client.table("attendance_summary")
        .select("subject_code")
        .eq("student_id", student_id)
        .execute()
    ).data or []

    marks_rows = (
        client.table("internal_marks_events")
        .select("subject_code")
        .eq("student_id", student_id)
        .execute()
    ).data or []

    tt_rows = (
        client.table("timetable_slots")
        .select("subject_code,teacher_name_raw")
        .eq("student_id", student_id)
        .execute()
    ).data or []

    uni_rows = (
        client.table("exam_sessions")
        .select("exam_id,exam_name,exam_year")
        .execute()
    ).data or []

    return populate_reference_tables(
        client,
        student_id=student_id,
        profile_data=profile_data,
        timetable_rows=tt_rows,
        university_result_rows=uni_rows,
        attendance_rows=att_rows,
        marks_rows=marks_rows,
    )

# ── Semester number extraction ────────────────────────────────────────────────
_ORDINAL_MAP = {
    "first": 1, "second": 2, "third": 3, "fourth": 4,
    "fifth": 5, "sixth": 6, "seventh": 7, "eighth": 8,
}
_SEM_PATTERN = re.compile(
    r"(first|second|third|fourth|fifth|sixth|seventh|eighth)\s+semester",
    re.IGNORECASE,
)


def _sem_number_from_name(exam_name: str) -> int | None:
    m = _SEM_PATTERN.search(exam_name)
    if m:
        return _ORDINAL_MAP.get(m.group(1).lower())
    return None


def _sem_label(n: int) -> str:
    labels = {
        1: "Semester 1", 2: "Semester 2", 3: "Semester 3",
        4: "Semester 4", 5: "Semester 5", 6: "Semester 6",
        7: "Semester 7", 8: "Semester 8",
    }
    return labels.get(n, f"Semester {n}")


# ── Dept / programme inference from subject codes ─────────────────────────────
_DEPT_PREFIX_MAP: dict[str, tuple[str, str, str, str]] = {
    # prefix → (dept_code, dept_name, prog_code, prog_name)
    "CS": ("CS",  "Computer Science and Engineering",            "BTCS", "B.Tech CSE"),
    "EC": ("EC",  "Electronics and Communication Engineering",   "BTEC", "B.Tech ECE"),
    "EE": ("EE",  "Electrical and Electronics Engineering",      "BTEE", "B.Tech EEE"),
    "ME": ("ME",  "Mechanical Engineering",                      "BTME", "B.Tech ME"),
    "CE": ("CE",  "Civil Engineering",                           "BTCE", "B.Tech CE"),
    "IT": ("IT",  "Information Technology",                      "BTIT", "B.Tech IT"),
    "AI": ("AI",  "Artificial Intelligence and Data Science",    "BTAI", "B.Tech AI&DS"),
}


def _infer_dept_programme(subject_codes: list[str]) -> tuple[str,str,str,str] | tuple[None,None,None,None]:
    scores: dict[str, int] = {}
    for code in subject_codes:
        m = re.match(r"^\d{2}([A-Z]{2,3})", code)
        if m:
            prefix = m.group(1)[:2]
            scores[prefix] = scores.get(prefix, 0) + 1
    if not scores:
        return None, None, None, None
    best = max(scores, key=lambda k: scores[k])
    row = _DEPT_PREFIX_MAP.get(best)
    if not row:
        return None, None, None, None
    return row  # (dept_code, dept_name, prog_code, prog_name)


def _fetch_id(client: Client, table: str, col: str, val: str) -> str | None:
    """Fetch UUID id from a table by a unique column value."""
    resp = client.table(table).select("id").eq(col, val).limit(1).execute()
    return resp.data[0]["id"] if resp.data else None


def _teacher_exists(client: Client, full_name: str) -> bool:
    resp = client.table("teachers").select("id").eq("full_name", full_name).limit(1).execute()
    return bool(resp.data)


# ── Main entry point ──────────────────────────────────────────────────────────

def populate_reference_tables(
    client: Client,
    student_id: str,
    profile_data: dict,
    timetable_rows: list[dict],
    university_result_rows: list[dict],
    attendance_rows: list[dict],
    marks_rows: list[dict],
) -> dict:
    """
    Upsert all reference tables from available scraped data.
    Returns a dict with counts of what was written.
    """
    stats: dict[str, int] = {
        "departments": 0, "programmes": 0,
        "academic_years": 0, "semesters": 0, "teachers": 0,
    }

    # Collect all subject codes
    all_codes = (
        [r.get("subject_code", "") for r in marks_rows]
        + [r.get("subject_code", "") for r in attendance_rows]
        + [r.get("subject_code", "") for r in timetable_rows if r.get("subject_code")]
    )
    all_codes = [c for c in all_codes if c]

    # ── Departments ──────────────────────────────────────────────────────
    dept_code, dept_name, prog_code, prog_name = _infer_dept_programme(all_codes)
    dept_id = None
    prog_id = None

    if dept_code and dept_name:
        # unique on: code
        resp = (
            client.table("departments")
            .upsert({"code": dept_code, "name": dept_name}, on_conflict="code")
            .execute()
        )
        dept_id = resp.data[0]["id"] if resp.data else _fetch_id(client, "departments", "code", dept_code)
        stats["departments"] = 1
        log.info("Upserted department: %s (id=%s)", dept_name, dept_id)

    # ── Programmes ───────────────────────────────────────────────────────
    if prog_code and prog_name:
        # unique on: code
        resp = (
            client.table("programmes")
            .upsert(
                {"code": prog_code, "name": prog_name, "department_id": dept_id},
                on_conflict="code",
            )
            .execute()
        )
        prog_id = resp.data[0]["id"] if resp.data else _fetch_id(client, "programmes", "code", prog_code)
        stats["programmes"] = 1
        log.info("Upserted programme: %s (id=%s)", prog_name, prog_id)

    # ── Academic Years ────────────────────────────────────────────────────
    # column name is `label` (not year_label), unique on label
    years_seen: set[int] = set()
    raw_ay = (profile_data.get("extra_fields") or {}).get("academic_year") or profile_data.get("academic_year")
    if raw_ay:
        try:
            years_seen.add(int(str(raw_ay).strip()))
        except (ValueError, TypeError):
            pass
    for r in university_result_rows:
        ey = r.get("exam_year")
        if ey:
            try:
                years_seen.add(int(ey))
            except (ValueError, TypeError):
                pass

    for year in years_seen:
        lbl = f"{year}-{str(year + 1)[-2:]}"   # e.g. "2024-25"
        client.table("academic_years").upsert(
            {"label": lbl, "start_year": year, "end_year": year + 1},
            on_conflict="label",
        ).execute()
    stats["academic_years"] = len(years_seen)
    log.info("Upserted %d academic_years", len(years_seen))

    # ── Semesters ─────────────────────────────────────────────────────────
    # unique on: (programme_id, academic_year_id, semester_label)
    # column is semester_label (not label)
    # We need an academic_year_id per semester; use the exam_year from results
    sem_map: dict[int, int] = {}   # sem_number → exam_year
    for r in university_result_rows:
        exam_name = r.get("exam_name") or ""
        n = _sem_number_from_name(exam_name)
        ey = r.get("exam_year")
        if n and ey and n not in sem_map:
            try:
                sem_map[n] = int(ey)
            except (ValueError, TypeError):
                pass

    current_sem_id = None
    for sem_n in sorted(sem_map.keys()):
        slabel = _sem_label(sem_n)
        exam_year = sem_map[sem_n]
        ay_label = f"{exam_year}-{str(exam_year + 1)[-2:]}"

        # Resolve academic_year_id
        ay_id = _fetch_id(client, "academic_years", "label", ay_label)

        client.table("semesters").upsert(
            {
                "semester_number": sem_n,
                "semester_label":  slabel,        # correct column name
                "programme_id":    prog_id,
                "academic_year_id": ay_id,
            },
            on_conflict="programme_id,academic_year_id,semester_label",
        ).execute()

        # Track the highest semester as current
        sem_id = _fetch_id(client, "semesters", "semester_label", slabel)
        if sem_id:
            current_sem_id = sem_id

    stats["semesters"] = len(sem_map)
    log.info("Upserted %d semesters", len(sem_map))

    # ── Teachers ──────────────────────────────────────────────────────────
    # unique only on employee_id (which we don't have) — use select-then-insert
    teacher_names: set[str] = set()
    for slot in timetable_rows:
        raw = slot.get("teacher") or slot.get("teacher_name_raw") or ""
        for name in raw.split(","):
            name = name.strip()
            if name:
                teacher_names.add(name)

    for name in teacher_names:
        if not _teacher_exists(client, name):
            client.table("teachers").insert(
                {"full_name": name}
            ).execute()
    stats["teachers"] = len(teacher_names)
    log.info("Processed %d teachers", len(teacher_names))

    # ── Back-fill student_profile FK cols ─────────────────────────────────
    update_payload: dict = {}
    if dept_id:
        update_payload["department_id"] = dept_id
    if prog_id:
        update_payload["programme_id"] = prog_id
    if current_sem_id:
        update_payload["current_semester_id"] = current_sem_id

    if update_payload:
        client.table("student_profile").update(update_payload).eq("student_id", student_id).execute()
        log.info("Back-filled student_profile FKs: %s", list(update_payload.keys()))

    return stats
