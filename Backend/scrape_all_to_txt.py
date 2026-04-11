#!/usr/bin/env python3
"""
scrape_all_to_txt.py

Runs a full API sweep using ETLAB credentials from Backend/.env and writes
timestamped artifacts under Backend/test/.

Coverage includes:
  - Public endpoints (/health, /auth/login, /auth/refresh)
  - Protected sync endpoints
  - All protected read endpoints
  - New live scrape endpoints
"""
import json
import os
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

import requests
from dotenv import load_dotenv

HERE = Path(__file__).resolve().parent
load_dotenv(HERE / ".env")

API_BASE_URL = os.getenv("API_BASE_URL", "http://localhost:8000/api/v1").rstrip("/")
ROOT_BASE_URL = API_BASE_URL.rsplit("/api/v1", 1)[0] if "/api/v1" in API_BASE_URL else API_BASE_URL
USERNAME = os.getenv("ETLAB_USERNAME", "")
PASSWORD = os.getenv("ETLAB_PASSWORD", "")
TEST_DIR = HERE / "test"


def _pp(obj: Any) -> str:
    return json.dumps(obj, indent=2, ensure_ascii=False, default=str)


def _safe_json(resp: requests.Response) -> Any:
    try:
        return resp.json()
    except Exception:
        return {"raw_text": resp.text}


def _call(
    session: requests.Session,
    method: str,
    url: str,
    *,
    headers: dict[str, str] | None = None,
    payload: dict | None = None,
    timeout: int = 240,
) -> dict:
    entry: dict[str, Any] = {
        "method": method,
        "url": url,
        "ok": False,
    }
    try:
        resp = session.request(method=method, url=url, headers=headers, json=payload, timeout=timeout)
        data = _safe_json(resp)
        entry.update(
            {
                "status_code": resp.status_code,
                "ok": 200 <= resp.status_code < 300,
                "response": data,
            }
        )
    except Exception as exc:
        entry.update({"error": str(exc)})
    return entry


def _write_outputs(snapshot: dict, output_json: Path, output_txt: Path) -> None:
    output_json.write_text(_pp(snapshot), encoding="utf-8")

    lines: list[str] = []
    lines.append("EtlabPro API Full Sweep")
    lines.append(f"Generated: {snapshot.get('generated_at')}")
    lines.append(f"API Base : {snapshot.get('api_base_url')}")
    lines.append(f"Roll No  : {snapshot.get('roll_number')}")
    lines.append(f"Success  : {snapshot.get('summary', {}).get('success_count', 0)}")
    lines.append(f"Failed   : {snapshot.get('summary', {}).get('failed_count', 0)}")
    lines.append("")

    for rec in snapshot.get("calls", []):
        title = f"{rec.get('label', 'CALL')} | {rec.get('method')} {rec.get('path')}"
        lines.append("=" * 72)
        lines.append(title)
        lines.append("=" * 72)
        lines.append(_pp(rec))
        lines.append("")

    output_txt.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    if not USERNAME or not PASSWORD:
        print("ERROR: ETLAB_USERNAME / ETLAB_PASSWORD not set in Backend/.env", file=sys.stderr)
        sys.exit(1)

    TEST_DIR.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_json = TEST_DIR / f"api_sweep_{stamp}.json"
    output_txt = TEST_DIR / f"api_sweep_{stamp}.txt"
    latest_json = TEST_DIR / "latest_api_sweep.json"
    latest_txt = TEST_DIR / "latest_api_sweep.txt"

    session = requests.Session()
    calls: list[dict] = []

    print("[1/6] Public checks...")
    health = _call(session, "GET", f"{ROOT_BASE_URL}/health", timeout=60)
    health.update({"label": "HEALTH", "path": "/health"})
    calls.append(health)

    login = _call(
        session,
        "POST",
        f"{API_BASE_URL}/auth/login",
        payload={"username": USERNAME, "password": PASSWORD},
        timeout=420,
    )
    login.update({"label": "AUTH LOGIN", "path": "/auth/login"})
    calls.append(login)
    if not login.get("ok"):
        snapshot = {
            "generated_at": datetime.now().isoformat(),
            "api_base_url": API_BASE_URL,
            "roll_number": None,
            "calls": calls,
            "summary": {
                "success_count": sum(1 for c in calls if c.get("ok")),
                "failed_count": sum(1 for c in calls if not c.get("ok")),
            },
        }
        _write_outputs(snapshot, output_json, output_txt)
        latest_json.write_text(output_json.read_text(encoding="utf-8"), encoding="utf-8")
        latest_txt.write_text(output_txt.read_text(encoding="utf-8"), encoding="utf-8")
        print("Login failed. Partial artifacts written.")
        sys.exit(1)

    login_body = login.get("response", {}) or {}
    access_token = login_body.get("access_token")
    refresh_token = login_body.get("refresh_token")
    roll_number = login_body.get("roll_number")
    auth_headers = {"Authorization": f"Bearer {access_token}"} if access_token else {}
    live_payload = {
        "username": USERNAME,
        "password": PASSWORD,
        "include_university_results": True,
    }

    print("[2/6] Token refresh check...")
    refresh = _call(
        session,
        "POST",
        f"{API_BASE_URL}/auth/refresh",
        payload={"refresh_token": refresh_token},
        timeout=120,
    )
    refresh.update({"label": "AUTH REFRESH", "path": "/auth/refresh"})
    calls.append(refresh)

    print("[3/6] Sync endpoints...")
    sync_all = _call(
        session,
        "POST",
        f"{API_BASE_URL}/sync-all",
        headers=auth_headers,
        payload={"username": USERNAME, "password": PASSWORD, "force": True},
        timeout=420,
    )
    sync_all.update({"label": "SYNC ALL", "path": "/sync-all"})
    calls.append(sync_all)

    update_att = _call(
        session,
        "POST",
        f"{API_BASE_URL}/update-attendance",
        headers=auth_headers,
        payload={"username": USERNAME, "password": PASSWORD},
        timeout=300,
    )
    update_att.update({"label": "UPDATE ATTENDANCE", "path": "/update-attendance"})
    calls.append(update_att)

    print("[4/6] Live scrape endpoints...")
    live_endpoints = [
        ("LIVE ATTENDANCE DUTY LEAVE", "/live/attendance-duty-leave", live_payload),
        ("LIVE MONTHLY ATTENDANCE", "/live/monthly-attendance", live_payload),
        ("LIVE UPDATES", "/live/updates", live_payload),
    ]
    for label, path, payload in live_endpoints:
        rec = _call(
            session,
            "POST",
            f"{API_BASE_URL}{path}",
            headers=auth_headers,
            payload=payload,
            timeout=420,
        )
        rec.update({"label": label, "path": path})
        calls.append(rec)

    print("[5/6] Protected GET endpoints...")
    get_endpoints = [
        ("PROFILE", f"/profile/{roll_number}"),
        ("INTERNAL RESULTS", f"/internal-results/{roll_number}"),
        ("UNIVERSITY RESULTS", f"/university-results/{roll_number}"),
        ("TIMETABLE", f"/timetable/{roll_number}"),
        ("ATTENDANCE", f"/attendance/{roll_number}"),
        ("SUBJECTS", "/subjects"),
        ("SUMMARY", f"/summary/{roll_number}"),
        ("DEPARTMENTS", "/departments"),
        ("PROGRAMMES", "/programmes"),
        ("ACADEMIC YEARS", "/academic-years"),
        ("SEMESTERS", "/semesters"),
        ("TEACHERS", "/teachers"),
    ]
    for label, path in get_endpoints:
        rec = _call(session, "GET", f"{API_BASE_URL}{path}", headers=auth_headers, timeout=240)
        rec.update({"label": label, "path": path})
        calls.append(rec)

    print("[6/6] Writing artifacts...")
    snapshot = {
        "generated_at": datetime.now().isoformat(),
        "api_base_url": API_BASE_URL,
        "roll_number": roll_number,
        "calls": calls,
        "summary": {
            "success_count": sum(1 for c in calls if c.get("ok")),
            "failed_count": sum(1 for c in calls if not c.get("ok")),
        },
    }
    _write_outputs(snapshot, output_json, output_txt)
    latest_json.write_text(output_json.read_text(encoding="utf-8"), encoding="utf-8")
    latest_txt.write_text(output_txt.read_text(encoding="utf-8"), encoding="utf-8")

    print(f"Artifacts written: {output_json}")
    print(f"Artifacts written: {output_txt}")
    print(f"Latest snapshot : {latest_json}")
    print(f"Latest text     : {latest_txt}")
    print(
        "Done. "
        f"success={snapshot['summary']['success_count']} "
        f"failed={snapshot['summary']['failed_count']}"
    )


if __name__ == "__main__":
    main()
