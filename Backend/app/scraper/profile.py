"""
scraper.profile
───────────────
Scrapes student profile from:
  GET /student/profile

The profile page on etlab contains a detail table with key-value rows
(Full Name, Roll No, Admission No, Department, etc.) and possibly a
section with academic info.

This scraper also extracts the etlab_user_id that is embedded in
links on the page — required to build the attendance URL.

⚠️  TODO CHECKLIST — complete before using in production:
─────────────────────────────────────────────────────────────
[ ] Open https://sahrdaya.etlab.in/student/profile in browser
    while logged in, then View Source (Ctrl+U).

[ ] Locate the main profile table.  Typical structure:
      <table>
        <tr><th>Full Name</th>   <td>John Doe</td></tr>
        <tr><th>Roll Number</th> <td>SAHCS23CS001</td></tr>
        …
      </table>

[ ] Check what the row labels are (they may be in <th> or first <td>).
    Update FIELD_MAP below with the exact text found on the page.

[ ] Find where the etlab numeric user ID appears.  Options:
      a) In a hidden input: <input name="id" value="41356045266">
      b) In a link: href="/ktuacademics/student/viewattendancesubject/41356045266"
      c) In a JS variable: var userId = "41356045266";
    Update _extract_etlab_user_id() accordingly.
─────────────────────────────────────────────────────────────
"""
import re
import logging
from datetime import datetime

import requests
from bs4 import BeautifulSoup

from app.config import get_settings
from app.scraper.session import scrape_etlab_user_id

TIMEOUT  = get_settings().REQUEST_TIMEOUT
URL      = f"{get_settings().ETLAB_BASE_URL}/student/profile"

log = logging.getLogger(__name__)

# ── Verified against real sahrdaya.etlab.in/student/profile HTML ─────
# Maps lowercased+stripped row-label text → internal dict key.
# Every field gets a named key — nothing goes into extra_fields.
FIELD_MAP: dict[str, str] = {
    # ── Identity ──────────────────────────────────────────────────
    "name":                                   "full_name",
    "gender":                                 "gender",
    "date of birth":                          "date_of_birth",
    "place of birth":                         "place_of_birth",
    "blood group":                            "blood_group",
    "nationality":                            "nationality",
    "nativity":                               "nativity",
    "religion":                               "religion",
    "community":                              "community",
    "caste":                                  "caste",
    "mother tongue":                          "mother_tongue",
    # ── Academic IDs ──────────────────────────────────────────────
    "university reg no":                      "roll_number",
    "admission no":                           "admission_number",
    "sr no":                                  "sr_no",
    "regno":                                  "regno",
    "academic year":                          "academic_year",
    "date of admission":                      "date_of_admission",
    "admission quota":                        "admission_quota",
    "admission type":                         "admission_type",
    "admitted reservation category":         "reservation_category",
    "eligible reservation category":         "reservation_category_eligible",
    "let rollno":                             "lateral_entry_roll_no",
    "abc id":                                 "abc_id",
    "aadhaar no":                             "aadhaar_no",
    # ── Contact ───────────────────────────────────────────────────
    "phone number (home)":                    "phone",
    "student mobile no":                      "phone",
    "phone office":                           "phone_office",
    "college email id":                       "email",
    "email":                                  "email",
    # ── Address ───────────────────────────────────────────────────
    "house name":                             "address",
    "street":                                 "street",
    "post / street 2":                        "address_line_2",
    "district":                               "district",
    "state":                                  "state",
    "pin":                                    "pin_code",
    "boarding point":                         "boarding_point",
    # ── Academic info ─────────────────────────────────────────────
    "branch":                                 "department",
    "programme":                              "programme",
    "program":                                "programme",
    "semester":                               "semester",
    "is hosteler?":                           "is_hosteler",
    # ── Parent / Guardian ─────────────────────────────────────────
    "father's name":                          "guardian_name",
    "father's mobile no":                     "guardian_phone",
    "father's occupation":                    "father_occupation",
    "father education":                       "father_education",
    "mother name":                            "mother_name",
    "mother's mobile no":                     "mother_phone",
    "mother's occupation":                    "mother_occupation",
    "mother education":                       "mother_education",
    "annual income":                          "annual_income",
    # ── Finance / Bank ────────────────────────────────────────────
    "bank name":                              "bank_name",
    "account no":                             "bank_account_no",
    "ifsc code":                              "bank_ifsc",
    "fee concession eligibility":             "fee_concession",
    # ── Entrance / Qualification ──────────────────────────────────
    "entrance rank":                          "entrance_rank",
    "entrance roll no":                       "entrance_roll_no",
    "exam score":                             "entrance_exam_score",
    "nata score":                             "nata_score",
    "board":                                  "plus_two_board",
    "last school":                            "last_school",
    "hss year":                               "hss_year",
    "sslc percentage":                        "sslc_pct",
    "sslc year":                              "sslc_year",
    "overall (%)":                            "plus_two_overall_pct",
    "maths mark":                             "maths_mark",
    "maths (%)":                              "maths_pct",
    "physics mark":                           "physics_mark",
    "physics (%)":                            "physics_pct",
    "chemistry mark":                         "chemistry_mark",
    "chemistry (%)":                          "chemistry_pct",
    "maths & physics & che/cs/bt/bio (%)":    "pcm_pct",
    "total mark":                             "plus_two_total_mark",
    # ── Misc ──────────────────────────────────────────────────────
    "personal marks of identification 1":     "identification_mark_1",
    "personal marks of identification 2":     "identification_mark_2",
    "tc date":                                "tc_date",
    "tc no":                                  "tc_no",
}

_KNOWN_KEYS = set(FIELD_MAP.values())


def _decode_cf_email(cfemail: str) -> str:
    """
    Decode a Cloudflare email-protected string.
    The algorithm: first byte is the XOR key; remaining bytes XOR'd with it.
    """
    enc = bytes.fromhex(cfemail)
    key = enc[0]
    return "".join(chr(b ^ key) for b in enc[1:])


def scrape_profile(session: requests.Session) -> dict:
    """
    Returns:
        {
          "roll_number":      str | None,   # University Reg No e.g. SHR24CS191
          "admission_number": str | None,
          "full_name":        str | None,
          "department":       str | None,
          "programme":        str | None,
          "semester":         str | None,
          "email":            str | None,
          "phone":            str | None,
          "date_of_birth":    str | None,
          "gender":           str | None,
          "address":          str | None,
          "guardian_name":    str | None,
          "guardian_phone":   str | None,
          "extra_fields":     dict,
          "etlab_user_id":    str | None,
          "scraped_at":       str (ISO),
        }
    """
    log.info("Scraping profile: %s", URL)
    resp = session.get(URL, timeout=TIMEOUT)
    resp.raise_for_status()
    soup = BeautifulSoup(resp.text, "lxml")

    profile: dict = {k: None for k in _KNOWN_KEYS}
    profile["extra_fields"] = {}
    profile["scraped_at"] = datetime.utcnow().isoformat()

    # etlab_user_id is NOT on the profile page — fetch it from attendance nav
    profile["etlab_user_id"] = scrape_etlab_user_id(session)

    # ── Parse all tables (profile page has ~35 small tables) ─────────
    for table in soup.find_all("table"):
        for tr in table.find_all("tr"):
            th = tr.find("th")
            td = tr.find("td")
            if not (th and td):
                # Fallback: two-td rows (some tables use td/td, not th/td)
                tds = tr.find_all("td")
                if len(tds) >= 2:
                    th_tag = tds[0]
                    td_tag = tds[1]
                else:
                    continue
            else:
                th_tag = th
                td_tag = td

            # ── Decode Cloudflare email protection ──────────────────
            cf = td_tag.find("a", class_="__cf_email__")
            if cf and cf.get("data-cfemail"):
                td_text = _decode_cf_email(cf["data-cfemail"])
            else:
                td_text = td_tag.get_text(strip=True)

            th_text = th_tag.get_text(strip=True)
            key = FIELD_MAP.get(th_text.lower().rstrip(":").strip())
            if key:
                # Don't overwrite a value already set by an earlier table row
                if not profile.get(key):
                    profile[key] = td_text or None
            elif th_text:
                profile["extra_fields"][th_text] = td_text

    if not profile.get("roll_number"):
        log.warning(
            "roll_number not found — profile tables may have changed. "
            "Check FIELD_MAP in scraper/profile.py"
        )

    log.info("Profile scraped: %s  email=%s", profile.get("roll_number"), profile.get("email"))
    return profile
