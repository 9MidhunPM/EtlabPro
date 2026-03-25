"""
db.profile
──────────
CRUD for the canonical `student_profile`, `student_guardians`,
and `bank_accounts` tables (v3 schema).

Only columns that exist in canonical student_profile are written there.
All unmapped ETLAB-specific fields are packed into `extra_fields` JSONB.
Guardian data is split into student_guardians (father + mother rows).
Bank data is split into bank_accounts.
"""
import logging
from datetime import datetime, timezone

from supabase import Client

log = logging.getLogger(__name__)


def _normalise_date(raw: str | None) -> str | None:
    """
    Convert various date formats to ISO YYYY-MM-DD for Postgres.
    Handles:
      DD/MM/YYYY   → YYYY-MM-DD
      DD-MM-YYYY   → YYYY-MM-DD
      YYYY-MM-DD   → unchanged
      Any unparseable value → None (avoids Postgres crashing)
    """
    if not raw:
        return None
    raw = raw.strip()
    # Already ISO
    if len(raw) == 10 and raw[4] == "-":
        return raw
    # DD/MM/YYYY or DD-MM-YYYY
    for sep in ("/", "-"):
        parts = raw.split(sep)
        if len(parts) == 3:
            d, m, y = parts
            if len(y) == 4:           # day/month/year order
                try:
                    return f"{int(y):04d}-{int(m):02d}-{int(d):02d}"
                except ValueError:
                    pass
            elif len(d) == 4:         # year/month/day order
                try:
                    return f"{int(d):04d}-{int(m):02d}-{int(y):02d}"
                except ValueError:
                    pass
    log.warning("Could not normalise date: %r — storing NULL", raw)
    return None

# Canonical columns of student_profile (excluding generated/FK columns)
_CANONICAL_PROFILE_COLS = frozenset([
    "student_id",
    "full_name", "gender", "date_of_birth", "blood_group",
    "nationality", "religion", "community", "caste", "mother_tongue",
    "department_id", "programme_id", "current_semester_id",
    "email", "phone",
    "address", "district", "state", "pin_code",
    "extra_fields", "scraped_at", "updated_at",
])

# Fields that get stored elsewhere (guardians / bank) — not in student_profile
_GUARDIAN_FIELDS = frozenset([
    "guardian_name", "guardian_phone", "father_occupation", "father_education",
    "mother_name", "mother_phone", "mother_occupation", "mother_education",
    "annual_income",
])
_BANK_FIELDS = frozenset([
    "bank_name", "bank_account_no", "bank_ifsc", "fee_concession",
])


def upsert_profile(client: Client, student_id: str, profile: dict) -> dict:
    """
    Insert or fully overwrite the student's profile across three tables:
      - student_profile (canonical columns only)
      - student_guardians (father + mother rows)
      - bank_accounts
    `profile` is the dict returned by scraper.profile.scrape_profile().
    """
    def _g(key: str):
        return profile.get(key) or None

    # ── Build extra_fields from all non-canonical, non-guardian, non-bank keys ──
    known_keys = _CANONICAL_PROFILE_COLS | _GUARDIAN_FIELDS | _BANK_FIELDS | {
        "roll_number", "admission_number", "etlab_user_id",
        "scraped_at", "extra_fields",
        # These are already extracted individually below
        "nativity", "address_line_2", "street", "boarding_point",
        "phone_office", "is_hosteler", "academic_year",
        "sr_no", "regno", "date_of_admission", "admission_quota",
        "admission_type", "reservation_category", "reservation_category_eligible",
        "lateral_entry_roll_no", "abc_id", "aadhaar_no",
        "entrance_rank", "entrance_roll_no", "entrance_exam_score", "nata_score",
        "plus_two_board", "last_school", "hss_year", "sslc_pct", "sslc_year",
        "plus_two_overall_pct", "maths_mark", "maths_pct", "physics_mark",
        "physics_pct", "chemistry_mark", "chemistry_pct", "pcm_pct",
        "plus_two_total_mark", "identification_mark_1", "identification_mark_2",
        "tc_date", "tc_no", "place_of_birth", "semester", "department", "programme",
    }

    # Start with any extra_fields the scraper already collected
    extra: dict = dict(profile.get("extra_fields") or {})

    # Move non-canonical profile fields into extra_fields
    for key, val in profile.items():
        if key not in known_keys and val is not None:
            extra[key] = val

    # Also pack the rich academic/entrance fields that don't fit canonical schema
    for field in [
        "nativity", "address_line_2", "street", "boarding_point",
        "phone_office", "is_hosteler", "academic_year",
        "sr_no", "regno", "date_of_admission", "admission_quota",
        "admission_type", "reservation_category", "reservation_category_eligible",
        "lateral_entry_roll_no", "abc_id", "aadhaar_no",
        "entrance_rank", "entrance_roll_no", "entrance_exam_score", "nata_score",
        "plus_two_board", "last_school", "hss_year", "sslc_pct", "sslc_year",
        "plus_two_overall_pct", "maths_mark", "maths_pct", "physics_mark",
        "physics_pct", "chemistry_mark", "chemistry_pct", "pcm_pct",
        "plus_two_total_mark", "identification_mark_1", "identification_mark_2",
        "tc_date", "tc_no", "place_of_birth",
    ]:
        v = _g(field)
        if v is not None:
            extra[field] = v

    # Pack academic context (department/programme/semester as raw text for reference)
    for field in ("department", "programme", "semester"):
        v = _g(field)
        if v is not None:
            extra[field] = v

    # ── student_profile upsert ────────────────────────────────────────────
    profile_payload = {
        "student_id":   student_id,
        "full_name":    _g("full_name"),
        "gender":       _g("gender"),
        "date_of_birth": _normalise_date(_g("date_of_birth")),
        "blood_group":  _g("blood_group"),
        "nationality":  _g("nationality"),
        "religion":     _g("religion"),
        "community":    _g("community"),
        "caste":        _g("caste"),
        "mother_tongue": _g("mother_tongue"),
        "email":        _g("email"),
        "phone":        _g("phone"),
        "address":      _g("address"),
        "district":     _g("district"),
        "state":        _g("state"),
        "pin_code":     _g("pin_code"),
        # FK refs set to NULL until a resolution layer is added
        "department_id":         None,
        "programme_id":          None,
        "current_semester_id":   None,
        "extra_fields":          extra,
        "scraped_at":            profile.get("scraped_at") or _now(),
        "updated_at":            _now(),
    }

    resp = (
        client.table("student_profile")
        .upsert(profile_payload, on_conflict="student_id")
        .execute()
    )
    log.info("Upserted student_profile for student_id=%s…", student_id[:8])

    # ── student_guardians: father ─────────────────────────────────────────
    _upsert_guardian(client, student_id, "father", {
        "guardian_name":  _g("guardian_name"),
        "guardian_phone": _g("guardian_phone"),
        "occupation":     _g("father_occupation"),
        "education":      _g("father_education"),
        "annual_income":  _parse_income(_g("annual_income")),
    })

    # ── student_guardians: mother ─────────────────────────────────────────
    _upsert_guardian(client, student_id, "mother", {
        "guardian_name":  _g("mother_name"),
        "guardian_phone": _g("mother_phone"),
        "occupation":     _g("mother_occupation"),
        "education":      _g("mother_education"),
        "annual_income":  None,  # income is per-family, stored on father row
    })

    # ── bank_accounts ─────────────────────────────────────────────────────
    bank_name    = _g("bank_name")
    account_no   = _g("bank_account_no")
    ifsc         = _g("bank_ifsc")
    fee_conc     = _g("fee_concession")
    if any([bank_name, account_no, ifsc, fee_conc]):
        (
            client.table("bank_accounts")
            .upsert(
                {
                    "student_id":     student_id,
                    "bank_name":      bank_name,
                    "account_number": account_no,
                    "ifsc_code":      ifsc,
                    "fee_concession": fee_conc,
                },
                on_conflict="student_id",
            )
            .execute()
        )
        log.info("Upserted bank_accounts for student_id=%s…", student_id[:8])

    return resp.data[0] if resp.data else profile_payload


def _upsert_guardian(
    client: Client,
    student_id: str,
    relation_type: str,
    data: dict,
) -> None:
    """Upsert one guardian row if any data is present."""
    if not any(v for v in data.values()):
        return
    payload = {
        "student_id":    student_id,
        "relation_type": relation_type,
        "guardian_name": data.get("guardian_name"),
        "guardian_phone": data.get("guardian_phone"),
        "occupation":    data.get("occupation"),
        "education":     data.get("education"),
        "annual_income": data.get("annual_income"),
    }
    (
        client.table("student_guardians")
        .upsert(payload, on_conflict="student_id,relation_type")
        .execute()
    )


def _parse_income(raw: str | None) -> float | None:
    if not raw:
        return None
    try:
        return float("".join(c for c in str(raw) if c.isdigit() or c == "."))
    except (ValueError, TypeError):
        return None


def get_profile(client: Client, student_id: str) -> dict | None:
    resp = (
        client.table("student_profile")
        .select("*")
        .eq("student_id", student_id)
        .limit(1)
        .execute()
    )
    return resp.data[0] if resp.data else None


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()
