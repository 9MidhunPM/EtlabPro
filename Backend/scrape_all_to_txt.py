#!/usr/bin/env python3
"""
scrape_all_to_txt.py
────────────────────
Standalone script that:
  1. Calls POST /sync-all  → scrapes everything from ETLAB and stores it in
     all the canonical v3 Supabase tables (marks, attendance, timetable, etc.)
  2. Calls every GET endpoint to read the stored data back
  3. Dumps all responses to scrape_output.txt

Usage (from the Backend/ directory):
    python scrape_all_to_txt.py

Reads ETLAB_USERNAME and ETLAB_PASSWORD from .env automatically.
The output file (scrape_output.txt) is excluded from git via .gitignore.

IMPORTANT: This script talks to the *local* API server.
           Start it first: uvicorn app.main:app --reload --port 8000
"""
import json
import os
import sys
from datetime import datetime
from pathlib import Path

import requests
from dotenv import load_dotenv

# ── Load .env from the same directory ──────────────────────────────────
_HERE = Path(__file__).resolve().parent
load_dotenv(_HERE / ".env")

BASE_URL = os.getenv("API_BASE_URL", "http://localhost:8000/api/v1")
USERNAME = os.getenv("ETLAB_USERNAME", "")
PASSWORD = os.getenv("ETLAB_PASSWORD", "")
OUTPUT   = _HERE / "scrape_output.txt"


def _pp(obj) -> str:
    """Pretty-print JSON."""
    return json.dumps(obj, indent=2, ensure_ascii=False, default=str)


def _section(title: str, data) -> str:
    border = "=" * 72
    return f"\n{border}\n{title}\n{border}\n{_pp(data)}\n"


def main() -> None:
    if not USERNAME or not PASSWORD:
        print("ERROR: ETLAB_USERNAME / ETLAB_PASSWORD not set in .env", file=sys.stderr)
        sys.exit(1)

    # ── Step 1: Login → get JWT + roll_number ────────────────────────────
    # /auth/login also does a sync internally (first-time scrape), but we'll
    # call /sync-all explicitly with force=True right after to be thorough.
    print(f"[→] Logging in as {USERNAME} …")
    login_resp = requests.post(
        f"{BASE_URL}/auth/login",
        json={"username": USERNAME, "password": PASSWORD},
        timeout=300,
    )
    if login_resp.status_code != 200:
        print(f"Login failed: {login_resp.status_code} {login_resp.text}", file=sys.stderr)
        sys.exit(1)

    login_data   = login_resp.json()
    access_token = login_data["access_token"]
    roll_number  = login_data["roll_number"]
    print(f"[✓] Logged in — roll={roll_number}")

    headers = {"Authorization": f"Bearer {access_token}"}

    # ── Step 2: SYNC ALL → scrape everything + store in Supabase ─────────
    print("\n[→] POST /sync-all (force=True) — scraping all data into DB …")
    print("    This may take 30-120 seconds depending on connection speed …")
    sync_resp = requests.post(
        f"{BASE_URL}/sync-all",
        json={"username": USERNAME, "password": PASSWORD, "force": True},
        headers=headers,
        timeout=300,
    )
    if sync_resp.status_code == 200:
        sync_data = sync_resp.json()
        print(f"    [✓] Sync complete:")
        print(f"        marks_written:              {sync_data.get('marks_written', 0)}")
        print(f"        attendance_written:          {sync_data.get('attendance_written', 0)}")
        print(f"        timetable_written:           {sync_data.get('timetable_written', 0)}")
        print(f"        university_results_written:  {sync_data.get('university_results_written', 0)}")
        print(f"        profile_updated:             {sync_data.get('profile_updated', False)}")
        skipped = sync_data.get("skipped", [])
        if skipped:
            print(f"        skipped:                     {skipped}")
    else:
        print(f"    [!] sync-all returned {sync_resp.status_code} — {sync_resp.text[:300]}")
        print("        Continuing to GET endpoints anyway …")
        sync_data = {"error": sync_resp.status_code, "detail": sync_resp.text}

    # ── Step 3: Read back all data via GET endpoints ──────────────────────
    print("\n[→] Reading all data from DB …")
    sections: list[tuple[str, dict]] = [
        ("SYNC-ALL RESULT", sync_data),
    ]

    endpoints = [
        ("PROFILE",              f"/profile/{roll_number}"),
        ("INTERNAL MARKS",       f"/internal-results/{roll_number}"),
        ("ATTENDANCE",           f"/attendance/{roll_number}"),
        ("TIMETABLE",            f"/timetable/{roll_number}"),
        ("UNIVERSITY RESULTS",   f"/university-results/{roll_number}"),
        ("SUBJECTS",             f"/subjects"),
        ("DEPARTMENTS",          f"/departments"),
        ("PROGRAMMES",           f"/programmes"),
        ("ACADEMIC YEARS",       f"/academic-years"),
        ("SEMESTERS",            f"/semesters"),
        ("TEACHERS",             f"/teachers"),
        ("STUDENT SUMMARY",      f"/summary/{roll_number}"),
    ]

    for label, path in endpoints:
        url = f"{BASE_URL}{path}"
        print(f"    [→] GET {path} …")
        try:
            r = requests.get(url, headers=headers, timeout=120)
            if r.status_code == 200:
                data = r.json()
                sections.append((label, data))
                # Show a quick count for list-type responses
                for key in ("marks", "attendance", "slots", "results", "subjects"):
                    if key in data and isinstance(data[key], list):
                        print(f"        [✓] {len(data[key])} {key} rows")
                        break
                else:
                    print(f"        [✓] {r.status_code} OK")
            else:
                sections.append((label, {"error": r.status_code, "detail": r.text}))
                print(f"        [!] {r.status_code} — see output file")
        except Exception as exc:
            sections.append((label, {"error": str(exc)}))
            print(f"        [!] Exception: {exc}")

    # ── Step 4: Write output file ─────────────────────────────────────────
    with open(OUTPUT, "w", encoding="utf-8") as fh:
        fh.write("EtlabPro Full Scrape Dump\n")
        fh.write(f"Generated : {datetime.now().isoformat()}\n")
        fh.write(f"Roll Number: {roll_number}\n")
        fh.write(f"Username  : {USERNAME}\n")

        for label, data in sections:
            fh.write(_section(label, data))

    print(f"\n[✓] Output written to: {OUTPUT}")
    print(f"    File size: {OUTPUT.stat().st_size:,} bytes")


if __name__ == "__main__":
    main()
