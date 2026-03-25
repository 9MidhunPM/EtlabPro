"""
db.profile
──────────
CRUD for the `student_profile` table.
"""
import logging
from datetime import datetime, timezone

from supabase import Client

log = logging.getLogger(__name__)


def upsert_profile(client: Client, student_id: str, profile: dict) -> dict:
    """
    Insert or fully overwrite the student's profile.
    `profile` is the dict returned by scraper.profile.scrape_profile().
    """
    def _g(key: str):
        return profile.get(key) or None

    payload = {
        "student_id":                   student_id,
        # Core identity
        "full_name":                    _g("full_name"),
        "gender":                       _g("gender"),
        "date_of_birth":                _g("date_of_birth"),
        "place_of_birth":               _g("place_of_birth"),
        "blood_group":                  _g("blood_group"),
        "nationality":                  _g("nationality"),
        "nativity":                     _g("nativity"),
        "religion":                     _g("religion"),
        "community":                    _g("community"),
        "caste":                        _g("caste"),
        "mother_tongue":                _g("mother_tongue"),
        # Academic identifiers
        "admission_number":             _g("admission_number"),
        "sr_no":                        _g("sr_no"),
        "regno":                        _g("regno"),
        "academic_year":                _g("academic_year"),
        "date_of_admission":            _g("date_of_admission"),
        "admission_quota":              _g("admission_quota"),
        "admission_type":               _g("admission_type"),
        "reservation_category":         _g("reservation_category"),
        "reservation_category_eligible":_g("reservation_category_eligible"),
        "lateral_entry_roll_no":        _g("lateral_entry_roll_no"),
        "abc_id":                       _g("abc_id"),
        "aadhaar_no":                   _g("aadhaar_no"),
        "department":                   _g("department"),
        "programme":                    _g("programme"),
        "semester":                     _g("semester"),
        "is_hosteler":                  _g("is_hosteler"),
        # Contact
        "email":                        _g("email"),
        "phone":                        _g("phone"),
        "phone_office":                 _g("phone_office"),
        # Address
        "address":                      _g("address"),
        "street":                       _g("street"),
        "address_line_2":               _g("address_line_2"),
        "district":                     _g("district"),
        "state":                        _g("state"),
        "pin_code":                     _g("pin_code"),
        "boarding_point":               _g("boarding_point"),
        # Father / guardian
        "guardian_name":                _g("guardian_name"),
        "guardian_phone":               _g("guardian_phone"),
        "father_occupation":            _g("father_occupation"),
        "father_education":             _g("father_education"),
        # Mother
        "mother_name":                  _g("mother_name"),
        "mother_phone":                 _g("mother_phone"),
        "mother_occupation":            _g("mother_occupation"),
        "mother_education":             _g("mother_education"),
        "annual_income":                _g("annual_income"),
        # Bank / finance
        "bank_name":                    _g("bank_name"),
        "bank_account_no":              _g("bank_account_no"),
        "bank_ifsc":                    _g("bank_ifsc"),
        "fee_concession":               _g("fee_concession"),
        # Entrance / qualifications
        "entrance_rank":                _g("entrance_rank"),
        "entrance_roll_no":             _g("entrance_roll_no"),
        "entrance_exam_score":          _g("entrance_exam_score"),
        "nata_score":                   _g("nata_score"),
        "plus_two_board":               _g("plus_two_board"),
        "last_school":                  _g("last_school"),
        "hss_year":                     _g("hss_year"),
        "sslc_pct":                     _g("sslc_pct"),
        "sslc_year":                    _g("sslc_year"),
        "plus_two_overall_pct":         _g("plus_two_overall_pct"),
        "maths_mark":                   _g("maths_mark"),
        "maths_pct":                    _g("maths_pct"),
        "physics_mark":                 _g("physics_mark"),
        "physics_pct":                  _g("physics_pct"),
        "chemistry_mark":               _g("chemistry_mark"),
        "chemistry_pct":                _g("chemistry_pct"),
        "pcm_pct":                      _g("pcm_pct"),
        "plus_two_total_mark":          _g("plus_two_total_mark"),
        # Physical identification
        "identification_mark_1":        _g("identification_mark_1"),
        "identification_mark_2":        _g("identification_mark_2"),
        "tc_date":                      _g("tc_date"),
        "tc_no":                        _g("tc_no"),
        # Catch-all for any unmapped fields
        "extra_fields":                 profile.get("extra_fields") or {},
        "scraped_at":                   profile.get("scraped_at") or _now(),
        "updated_at":                   _now(),
    }
    resp = (
        client.table("student_profile")
        .upsert(payload, on_conflict="student_id")
        .execute()
    )
    log.info("Upserted profile for student_id=%s…", student_id[:8])
    return resp.data[0] if resp.data else payload


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
