#!/usr/bin/env python
"""
Scrape all API endpoints and generate comprehensive documentation with real outputs.
This will create a reference file for frontend developers showing actual API responses.
"""

import requests
import os
from dotenv import load_dotenv
from pathlib import Path
import json
from datetime import datetime

_ENV_PATH = Path(__file__).resolve().parent / ".env"
load_dotenv(_ENV_PATH)

USERNAME = os.getenv("ETLAB_USERNAME", "")
PASSWORD = os.getenv("ETLAB_PASSWORD", "")

BASE_URL = "http://localhost:8000"

print("Scraping all API endpoints...")
print("This may take 5-10 minutes...\n")

# Login
login = requests.post(
    f"{BASE_URL}/api/v1/auth/login",
    json={"username": USERNAME, "password": PASSWORD},
    timeout=30
)
token = login.json()['access_token']

endpoints_data = {}

# Helper to call endpoint and store response
def fetch_endpoint(name, method, path, payload=None, timeout=120):
    try:
        if method == "POST":
            resp = requests.post(
                f"{BASE_URL}{path}",
                json=payload or {"username": USERNAME, "password": PASSWORD},
                headers={"Authorization": f"Bearer {token}"},
                timeout=timeout
            )
        else:
            resp = requests.get(
                f"{BASE_URL}{path}",
                headers={"Authorization": f"Bearer {token}"},
                timeout=timeout
            )
        
        if resp.ok:
            try:
                data = resp.json()
                endpoints_data[name] = {
                    "status": "✓ Success",
                    "response": data,
                    "note": None
                }
                print(f"✓ {name}")
            except:
                endpoints_data[name] = {
                    "status": "✗ Invalid JSON",
                    "response": resp.text[:500],
                    "note": None
                }
                print(f"✗ {name} (Invalid JSON)")
        else:
            endpoints_data[name] = {
                "status": f"✗ {resp.status_code}",
                "response": resp.text[:500],
                "note": None
            }
            print(f"✗ {name} ({resp.status_code})")
    except Exception as e:
        endpoints_data[name] = {
            "status": f"✗ Error",
            "response": str(e),
            "note": None
        }
        print(f"✗ {name} (Error: {e})")

# Fetch endpoints
print("Fetching data...")
print("-" * 80)

# 1. Profile
fetch_endpoint("Profile", "POST", "/api/v1/live/profile")

# 2. Attendance metadata
fetch_endpoint("Attendance Metadata", "POST", "/api/v1/live/attendance-metadata")

# 3. Monthly attendance simple
fetch_endpoint("Monthly Attendance (Simple)", "POST", "/api/v1/live/monthly-attendance-simple")

# 4. Monthly attendance advanced
fetch_endpoint(
    "Monthly Attendance (Advanced - Sem 1, Month 9)",
    "POST",
    "/api/v1/live/monthly-attendance-advanced",
    {"username": USERNAME, "password": PASSWORD, "semester": "1", "month": "9"},
    timeout=120
)

# 5. Monthly attendance all (SLOW - takes 2-5 minutes)
print("\n(Fetching all historical months - this may take 3-5 minutes...)")
fetch_endpoint("Monthly Attendance (All Months)", "POST", "/api/v1/live/monthly-attendance-all", timeout=600)

# 6. Attendance per subject
fetch_endpoint("Subject-wise Attendance", "POST", "/api/v1/live/attendance")

# 7. Marks
fetch_endpoint("Marks", "POST", "/api/v1/live/marks")

# 8. Timetable
fetch_endpoint("Timetable", "POST", "/api/v1/live/timetable")

# 9. University Results
fetch_endpoint("University Results", "POST", "/api/v1/live/university-results")

print("-" * 80)
print("\nGenerating comprehensive documentation...\n")

# Create organized text file
doc = []
doc.append("=" * 100)
doc.append("ETLAB PRO - API ENDPOINTS REFERENCE DOCUMENTATION")
doc.append("=" * 100)
doc.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
doc.append(f"Student: {USERNAME}")
doc.append("")
doc.append("This document contains LIVE response data from all API endpoints.")
doc.append("Use this for frontend development and testing.")
doc.append("")

for endpoint_name, data in endpoints_data.items():
    doc.append("\n" + "=" * 100)
    doc.append(f"ENDPOINT: {endpoint_name}")
    doc.append("=" * 100)
    doc.append(f"Status: {data['status']}")
    doc.append("")
    
    if isinstance(data['response'], dict):
        # Pretty print JSON
        json_str = json.dumps(data['response'], indent=2)
        doc.append("RESPONSE:")
        doc.append("-" * 100)
        doc.extend(json_str.split('\n'))
        doc.append("-" * 100)
    else:
        doc.append(f"Response: {data['response']}")
    
    doc.append("")

# Add summary tables
doc.append("\n" + "=" * 100)
doc.append("QUICK REFERENCE - ENDPOINT SUMMARY")
doc.append("=" * 100)
doc.append("")

for endpoint_name, data in endpoints_data.items():
    status = data['status']
    if isinstance(data['response'], dict):
        if 'count' in data['response']:
            count = data['response']['count']
            info = f" - {count} items"
        elif 'total_months' in data['response']:
            count = data['response']['total_months']
            info = f" - {count} months"
        else:
            info = ""
    else:
        info = " - ERROR"
    
    doc.append(f"• {endpoint_name:50} {status:20} {info}")

doc.append("")

# Save to file
output_path = Path(__file__).parent / "API_ENDPOINTS_REFERENCE.txt"
with open(output_path, 'w', encoding='utf-8') as f:
    f.write('\n'.join(doc))

print(f"\n✓ Documentation saved to: {output_path}")
print(f"  File size: {output_path.stat().st_size:,} bytes")

# Also create a JSON version for programmatic access
json_output = {
    "generated_at": datetime.now().isoformat(),
    "endpoints": endpoints_data
}

json_path = Path(__file__).parent / "API_ENDPOINTS_REFERENCE.json"
with open(json_path, 'w', encoding='utf-8') as f:
    json.dump(json_output, f, indent=2)

print(f"✓ JSON version saved to: {json_path}")
print(f"  File size: {json_path.stat().st_size:,} bytes")

print("\n" + "=" * 80)
print("SUMMARY")
print("=" * 80)
successful = sum(1 for d in endpoints_data.values() if "Success" in d['status'])
print(f"Total endpoints: {len(endpoints_data)}")
print(f"Successful: {successful}")
print(f"Failed: {len(endpoints_data) - successful}")
print("")
print("Files created:")
print(f"  1. {output_path.name} - Human readable text format")
print(f"  2. {json_path.name} - Machine readable JSON format")
print(f"\nShare these files with your frontend team!")
