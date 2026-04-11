#!/usr/bin/env python
"""
Generate comprehensive API reference documentation with:
- All endpoint paths
- Request/response formats
- Real example data 
- Frontend implementation guide
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

print("Creating comprehensive API reference...\n")

# Login
login = requests.post(
    f"{BASE_URL}/api/v1/auth/login",
    json={"username": USERNAME, "password": PASSWORD},
    timeout=30
)
token = login.json()['access_token']

def fetch_endpoint(path, payload=None, timeout=120):
    """Fetch an endpoint and return pretty JSON"""
    try:
        resp = requests.post(
            f"{BASE_URL}{path}",
            json=payload or {"username": USERNAME, "password": PASSWORD},
            headers={"Authorization": f"Bearer {token}"},
            timeout=timeout
        )
        if resp.ok:
            return resp.json()
    except:
        pass
    return None

# Fetch all data
print("Fetching attendance metadata...")
metadata = fetch_endpoint("/api/v1/live/attendance-metadata")

print("Fetching simple monthly attendance...")
simple = fetch_endpoint("/api/v1/live/monthly-attendance-simple")

print("Fetching advanced example (Sem 3, Month 7)...")
advanced = fetch_endpoint(
    "/api/v1/live/monthly-attendance-advanced",
    {"username": USERNAME, "password": PASSWORD, "semester": "3", "month": "7"},
    timeout=120
)

print("Fetching all historical months (this may take 3-5 minutes)...")
all_months = fetch_endpoint("/api/v1/live/monthly-attendance-all", timeout=600)

# Create comprehensive documentation
lines = []

lines.append("╔" + "═" * 118 + "╗")
lines.append("║" + " " * 118 + "║")
lines.append("║" + "ETLAB PRO - COMPLETE API REFERENCE FOR FRONTEND DEVELOPERS".center(118) + "║")
lines.append("║" + " " * 118 + "║")
lines.append("╚" + "═" * 118 + "╝")
lines.append("")
lines.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
lines.append(f"Student: {USERNAME}")
lines.append(f"Base URL: {BASE_URL}")
lines.append("")

# ============================================================================
# TABLE OF CONTENTS
# ============================================================================
lines.append("┌ TABLE OF CONTENTS ".ljust(120, "─") + "┐")
lines.append("│                                                                                                                        │")
lines.append("│  1. ATTENDANCE METADATA - Get available semesters and months                                                         │")
lines.append("│  2. SIMPLE ATTENDANCE - Get current month for each semester (RECOMMENDED)                                            │")
lines.append("│  3. ADVANCED ATTENDANCE - Test specific semester/month combinations                                                  │")
lines.append("│  4. ALL MONTHS ATTENDANCE - Get complete historical record                                                           │")
lines.append("│  5. QUICK COMPARISON TABLE - All endpoints at a glance                                                               │")
lines.append("│  6. FRONTEND IMPLEMENTATION EXAMPLES                                                                                  │")
lines.append("│                                                                                                                        │")
lines.append("└" + "─" * 118 + "┘")
lines.append("")

# ============================================================================
# 1. ATTENDANCE METADATA
# ============================================================================
lines.append("╔═" + "═" * 117 + "╗")
lines.append("║  1. ATTENDANCE METADATA ENDPOINT" + " " * 84 + "║")
lines.append("╚═" + "═" * 117 + "╝")
lines.append("")
lines.append("Purpose: Discover available semesters, months, and years")
lines.append("Endpoint: POST /api/v1/live/attendance-metadata")
lines.append("")
lines.append("─ REQUEST ─")
lines.append("""
POST /api/v1/live/attendance-metadata
Authorization: Bearer {JWT_TOKEN}
Content-Type: application/json

{
  "username": "224079",
  "password": "password"
}
""")

if metadata:
    lines.append("─ RESPONSE ─")
    lines.append(json.dumps(metadata, indent=2))
    lines.append("")
    lines.append("KEY INFO FROM RESPONSE:")
    lines.append(f"  • Current Semester: {metadata.get('current_semester')}")
    lines.append(f"  • Total Semesters Available: {len(metadata.get('available_semesters', []))}")
    lines.append(f"  • Months in Current Semester: {len(metadata.get('available_months', []))}")
    
    # Show actual months available
    months_for_current = [m['label'] for m in metadata.get('available_months', [])]
    lines.append(f"  • Month Values: {', '.join(months_for_current)}")

lines.append("")
lines.append("")

# ============================================================================
# 2. SIMPLE ATTENDANCE
# ============================================================================
lines.append("╔═" + "═" * 117 + "╗")
lines.append("║  2. SIMPLE MONTHLY ATTENDANCE (RECOMMENDED FOR MAIN UI)" + " " * 52 + "║")
lines.append("╚═" + "═" * 117 + "╝")
lines.append("")
lines.append("Purpose: Get CURRENT (latest) month attendance for each of 4 semesters")
lines.append("Endpoint: POST /api/v1/live/monthly-attendance-simple")
lines.append("Speed: ~30 seconds")
lines.append("Use Case: Main UI, semester selector, dashboard")
lines.append("")
lines.append("─ REQUEST ─")
lines.append("""
POST /api/v1/live/monthly-attendance-simple
Authorization: Bearer {JWT_TOKEN}
Content-Type: application/json

{
  "username": "224079",
  "password": "password"
}
""")

if simple:
    lines.append("─ RESPONSE ─")
    lines.append(json.dumps(simple, indent=2))
    lines.append("")
    lines.append("STRUCTURE EXPLANATION:")
    lines.append("  • roll_number: Student's register number")
    lines.append("  • etlab_user_id: Internal ETLAB ID for the student")
    lines.append("  • count: Number of months returned (always 4)")
    lines.append("  • months: Array of month objects")
    lines.append("")
    lines.append("Each month object contains:")
    lines.append("  • semester: Semester name (e.g., 'Ist Semester', 'IVth Semester')")
    lines.append("  • month: Month name (e.g., 'Dec', 'Apr')")
    lines.append("  • year: Year (e.g., '2024', '2025')")
    lines.append("  • days_present: Days marked present")
    lines.append("  • days_absent: Days marked absent")
    lines.append("  • days_duty_leave: Days marked as duty leave")
    lines.append("  • total_marked_days: Total days with attendance record")

lines.append("")
lines.append("")

# ============================================================================
# 3. ADVANCED ATTENDANCE
# ============================================================================
lines.append("╔═" + "═" * 117 + "╗")
lines.append("║  3. ADVANCED ATTENDANCE (TEST SPECIFIC MONTHS)" + " " * 69 + "║")
lines.append("╚═" + "═" * 117 + "╝")
lines.append("")
lines.append("Purpose: Fetch specific semester/month combination and see what ETLAB returns")
lines.append("Endpoint: POST /api/v1/live/monthly-attendance-advanced")
lines.append("Speed: ~30 seconds per request")
lines.append("Use Case: Month selector, debugging, testing")
lines.append("")
lines.append("─ REQUEST ─")
lines.append("""
POST /api/v1/live/monthly-attendance-advanced
Authorization: Bearer {JWT_TOKEN}
Content-Type: application/json

{
  "username": "224079",
  "password": "password",
  "semester": "3",
  "month": "7",
  "year": "2025"
}
""")

if advanced:
    lines.append("─ RESPONSE ─")
    lines.append(json.dumps(advanced, indent=2))

lines.append("")
lines.append("")

# ============================================================================
# 4. ALL MONTHS ATTENDANCE
# ============================================================================
lines.append("╔═" + "═" * 117 + "╗")
lines.append("║  4. ALL MONTHS ATTENDANCE (COMPLETE HISTORY)" + " " * 70 + "║")
lines.append("╚═" + "═" * 117 + "╝")
lines.append("")
lines.append("Purpose: Get ALL available months across ALL semesters (18 months total)")
lines.append("Endpoint: POST /api/v1/live/monthly-attendance-all")
lines.append("Speed: 3-5 minutes (fetches many months)")
lines.append("Use Case: Export complete history, analytics, reports")
lines.append("")
lines.append("─ REQUEST ─")
lines.append("""
POST /api/v1/live/monthly-attendance-all
Authorization: Bearer {JWT_TOKEN}
Content-Type: application/json

{
  "username": "224079",
  "password": "password"
}
""")

if all_months:
    lines.append("─ RESPONSE SUMMARY ─")
    lines.append(f"Total Months: {all_months.get('total_months')}")
    lines.append(f"Contains months from all 4 semesters")
    lines.append("")
    
    # Group by semester
    by_sem = {}
    for month in all_months.get('months', []):
        sem = month.get('semester')
        if sem not in by_sem:
            by_sem[sem] = []
        by_sem[sem].append(month)
    
    lines.append("─ DATA BY SEMESTER ─")
    for sem in sorted(by_sem.keys()):
        months = by_sem[sem]
        month_strs = [f"{m.get('month')} {m.get('year', '')}" for m in months]
        lines.append(f"  {sem}: {len(months)} months")
        lines.append(f"    → {', '.join(month_strs)}")
    
    lines.append("")
    lines.append("─ SAMPLE MONTH OBJECT ─")
    if all_months.get('months'):
        lines.append(json.dumps(all_months['months'][0], indent=2))

lines.append("")
lines.append("")

# ============================================================================
# 5. QUICK COMPARISON
# ============================================================================
lines.append("╔═" + "═" * 117 + "╗")
lines.append("║  5. ENDPOINT COMPARISON TABLE" + " " * 86 + "║")
lines.append("╚═" + "═" * 117 + "╝")
lines.append("")

comparison = """
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Endpoint                           │ Purpose              │ Speed      │ Data Points │ Use Case                            │
├─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│ /attendance-metadata               │ Discover options     │ ~5s        │ 1           │ Initialize UI, load dropdowns       │
│ /monthly-attendance-simple         │ Current months only  │ ~30s       │ 4           │ Main dashboard, semester selector   │
│ /monthly-attendance-advanced       │ Test specific month  │ ~30s       │ 1           │ Testing, debugging                  │
│ /monthly-attendance-all            │ Complete history     │ 3-5 min    │ 18          │ Export, reports, analytics          │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
"""
lines.append(comparison)
lines.append("")

# ============================================================================
# 6. FRONTEND EXAMPLES
# ============================================================================
lines.append("╔═" + "═" * 117 + "╗")
lines.append("║  6. FRONTEND IMPLEMENTATION EXAMPLES" + " " * 80 + "║")
lines.append("╚═" + "═" * 117 + "╝")
lines.append("")

lines.append("─ EXAMPLE 1: Initialize Dashboard (JavaScript/TypeScript) ─")
lines.append("""
async function initializeDashboard(token, username, password) {
  try {
    // Step 1: Get metadata to know what's available
    const metadataRes = await fetch('/api/v1/live/attendance-metadata', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ username, password })
    });
    const metadata = await metadataRes.json();
    
    // Step 2: Get simple attendance (current months only)
    const attendanceRes = await fetch('/api/v1/live/monthly-attendance-simple', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ username, password })
    });
    const attendance = await attendanceRes.json();
    
    // Step 3: Display in UI
    const currentSemester = metadata.current_semester;
    attendance.months.forEach(month => {
      console.log(`${month.semester}: ${month.days_present}P ${month.days_absent}A (${month.total_marked_days} days)`);
    });
    
    return { metadata, attendance };
  } catch (error) {
    console.error('Error initializing dashboard:', error);
  }
}
""")

lines.append("")
lines.append("─ EXAMPLE 2: Semester Selector with Specific Month ─")
lines.append("""
async function fetchSemesterMonth(token, username, password, semester, month) {
  const res = await fetch('/api/v1/live/monthly-attendance-advanced', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ 
      username, 
      password,
      semester,      // e.g., "3"
      month          // e.g., "7" (July)
    })
  });
  
  const data = await res.json();
  
  // Check if requested month was actually returned
  // (ETLAB may ignore the month parameter for past semesters)
  const actualMonth = data.months[0].month;
  const requestedMonth = month;
  
  if (actualMonth !== expectedMonth) {
    console.warn(`Requested month ${month} but got ${actualMonth}`);
    console.warn('This semester may only have one available month');
  }
  
  return data.months[0];
}
""")

lines.append("")
lines.append("─ EXAMPLE 3: Export Complete History ─")
lines.append("""
async function exportCompleteAttendance(token, username, password) {
  console.log('Fetching all months (this may take 3-5 minutes)...');
  
  const res = await fetch('/api/v1/live/monthly-attendance-all', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ username, password })
  });
  
  const data = await res.json();
  
  // Create CSV
  const csv = ['Semester,Month,Year,Present,Absent,DutyLeave,TotalDays'];
  data.months.forEach(month => {
    csv.push(`${month.semester},${month.month},${month.year},${month.days_present},${month.days_absent},${month.days_duty_leave},${month.total_marked_days}`);
  });
  
  // Download
  const blob = new Blob([csv.join('\\n')], { type: 'text/csv' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = `attendance_${new Date().toISOString()}.csv`;
  link.click();
}
""")

lines.append("")
lines.append("")

# ============================================================================
# KEY INSIGHTS
# ============================================================================
lines.append("╔═" + "═" * 117 + "╗")
lines.append("║  KEY INSIGHTS FOR FRONTEND DEVELOPERS" + " " * 79 + "║")
lines.append("╚═" + "═" * 117 + "╝")
lines.append("")

lines.append("✓ 4 SEMESTERS WITH DATA")
lines.append("  • Semester 1: September-December 2024")
lines.append("  • Semester 2: January-April 2025")
lines.append("  • Semester 3: July-November 2025")
lines.append("  • Semester 4: December 2025-April 2026 (CURRENT)")
lines.append("  • Semesters 5+ do not have real enrollment data")
lines.append("")

lines.append("✓ TOTAL 18 MONTHS HISTORICAL DATA")
lines.append("  • 4 months for Sem 1")
lines.append("  • 4 months for Sem 2")
lines.append("  • 5 months for Sem 3")
lines.append("  • 5 months for Sem 4")
lines.append("")

lines.append("✓ EACH MONTH IS INDEPENDENT")
lines.append("  • You can fetch September 2024 separately")
lines.append("  • You can fetch August 2025 separately")
lines.append("  • All data is accessible, not just current")
lines.append("")

lines.append("✓ 3 RECOMMENDED USAGE PATTERNS")
lines.append("  1. Dashboard: Use /simple endpoint (fast, 4 data points)")
lines.append("  2. Detail View: Use /advanced endpoint (test specific month)")
lines.append("  3. Export: Use /all endpoint (complete history, slow but complete)")
lines.append("")

lines.append("✓ ERROR HANDLING")
lines.append("  • 401 Unauthorized: Invalid credentials or expired JWT")
lines.append("  • 404 Not Found: Endpoint doesn't exist")
lines.append("  • 500 Internal Error: Backend issue (rare)")
lines.append("")

# Save files
output_txt = Path(__file__).parent / "API_COMPLETE_REFERENCE.txt"
with open(output_txt, 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))

print(f"\n✓ Complete reference saved to: {output_txt}")
print(f"  File size: {output_txt.stat().st_size:,} bytes")

# Also create structured JSON for programmatic use
api_reference = {
    "generated_at": datetime.now().isoformat(),
    "base_url": BASE_URL,
    "student": USERNAME,
    "endpoints": {
        "metadata": {
            "path": "/api/v1/live/attendance-metadata",
            "method": "POST",
            "speed": "~5 seconds",
            "response": metadata,
        },
        "simple": {
            "path": "/api/v1/live/monthly-attendance-simple",
            "method": "POST",
            "speed": "~30 seconds",
            "returns": "4 months (current for each semester)",
            "response": simple,
        },
        "advanced": {
            "path": "/api/v1/live/monthly-attendance-advanced",
            "method": "POST",
            "speed": "~30 seconds",
            "parameters": ["semester", "month", "year"],
            "response": advanced,
        },
        "all_months": {
            "path": "/api/v1/live/monthly-attendance-all",
            "method": "POST",
            "speed": "3-5 minutes",
            "returns": "18 months (complete history)",
            "response_summary": {
                "total_months": all_months.get('total_months') if all_months else None,
            }
        }
    }
}

json_output = Path(__file__).parent / "API_REFERENCE.json"
with open(json_output, 'w', encoding='utf-8') as f:
    json.dump(api_reference, f, indent=2)

print(f"✓ JSON reference saved to: {json_output}")
print(f"  File size: {json_output.stat().st_size:,} bytes")

print("\n" + "="*80)
print("✓ API REFERENCE GENERATION COMPLETE")
print("="*80)
print(f"\nFiles created for frontend team:")
print(f"  1. API_COMPLETE_REFERENCE.txt - Beautiful formatted reference")
print(f"  2. API_REFERENCE.json - Machine readable format")
print(f"\nShare these with your frontend team!")
