# EtlabPro

<p align="center">
  <img src="frontend/assets/images/splash-icon4.png" alt="EtlabPro banner" width="260" />
</p>

<p align="center">
  <img src="frontend/assets/images/icon.png" alt="EtlabPro app icon" width="96" />
</p>

EtlabPro is a full-stack student companion platform for Sahrdaya ETLAB users. It combines a production-oriented FastAPI backend, ETLAB scraping workflows, Supabase persistence, and a Flutter mobile app with rich analytics across attendance, internal marks, semester results, monthly calendar view, and timetable.

## What EtlabPro Does

- Authenticates with ETLAB and syncs academic data into normalized storage.
- Serves a secure API for mobile consumption.
- Provides mobile dashboards for:
  - Home insights (attendance + result summaries)
  - Attendance tracking and risk analysis
  - CAT result breakdown with projection analysis
  - University end-sem result history by semester
  - Day-wise timetable and monthly attendance calendar

## Architecture Overview

Backend responsibilities:

- FastAPI API surface for auth, sync, live comparison, and analytics reads.
- Scrapers for profile, attendance, marks, timetable, and university results.
- Service layer orchestration that controls refresh policies and sync lifecycle.
- Supabase persistence through dedicated DB modules.

Frontend responsibilities:

- Secure login/session handling.
- JWT-backed API calls to protected endpoints.
- Local cached state for resilience and faster UX.
- Light and dark themed UI for all major student workflows.

## Current Deployment (Self-Hosted)

EtlabPro is currently self-hosted in Bangalore on a Dokploy setup.

Current hosting posture:

- Containerized backend deployment (FastAPI/Uvicorn) managed via Dokploy.
- Environment-driven secret management for runtime configuration.
- Public API exposure through a controlled self-hosted infrastructure boundary.
- Security-oriented backend defaults (JWT auth, CORS allow-list, reduced logging, docs disabled in production mode).

This gives you direct infrastructure control while keeping the application safely self-hosted and maintainable.

## Security and Safety

EtlabPro is designed with a safe-by-default backend model when operated with correct deployment practices.

Implemented in code:

- JWT access/refresh token flow for authenticated access.
- Protected routes enforced via Bearer token dependency checks.
- CORS origin restrictions from environment configuration.
- Supabase service role key only used server-side.
- Mobile credentials/tokens stored with encrypted secure storage.
- Production docs disabled by default.
- Concise operational logging to reduce sensitive signal leakage.

Operational best practices to keep it safe over time:

- Keep all secrets in environment variables and rotate them periodically.
- Enforce HTTPS end-to-end in front of Dokploy-managed services.
- Restrict DB and admin access by network and role.
- Monitor auth failures, sync anomalies, and dependency updates.

## Repository Layout

```text
EtlabPro/
  Backend/
    app/
      api/        # FastAPI routes + auth deps
      scraper/    # ETLAB scraping modules
      db/         # Supabase read/write modules
      services/   # Sync orchestration
      models/     # Pydantic schemas
    docs/dbms/    # Canonical schema + migration plan
    requirements.txt
    Dockerfile
  frontend/
    lib/
      screens/
      services/
      core/
      widgets/
    assets/images/
    pubspec.yaml
```

## Setup

### Backend

```powershell
cd Backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env
uvicorn app.main:app --reload --port 8000
```

- Health endpoint: `GET /health`
- API base: `/api/v1`

### Frontend

Create `frontend/.env`:

```env
API_BASE_URL=http://10.0.2.2:8000
APP_VERSION=1.0.0
```

Run app:

```powershell
cd frontend
flutter pub get
flutter run
```

## Screenshot Gallery (Analyzed)

The following screenshots are included from `frontend/assets/images` and grouped by mode.

### Light Mode

1. Home dashboard with schedule, attendance summary, results overview, and profile card.

![Light Home](frontend/assets/images/WhatsApp%20Image%202026-04-12%20at%209.03.25%20AM.jpeg)

2. Attendance analysis snapshot with duty-leave inclusion and by-subject risk classification.

![Light Attendance Analysis](frontend/assets/images/WhatsApp%20Image%202026-04-12%20at%209.03.25%20AM%20(1).jpeg)

3. Results tab showing CAT 1 and CAT 2 subject-wise scores.

![Light CAT Results](frontend/assets/images/WhatsApp%20Image%202026-04-12%20at%209.03.26%20AM.jpeg)

4. End-semester results tab with SGPA/CGPA and grade cards for Semester 1.

![Light End Sem](frontend/assets/images/WhatsApp%20Image%202026-04-12%20at%209.03.26%20AM%20(1).jpeg)

5. Monthly attendance calendar view with day-level attendance status and period list.

![Light Monthly Calendar](frontend/assets/images/WhatsApp%20Image%202026-04-12%20at%209.03.26%20AM%20(2).jpeg)

6. Grade analysis with CAT scaling, minimum CAT-2 projection, assignment input, and target warning.

![Light Grade Analysis](frontend/assets/images/WhatsApp%20Image%202026-04-12%20at%209.03.27%20AM.jpeg)

7. Timetable view (Monday selected) with period-wise class details and timings.

![Light Timetable](frontend/assets/images/WhatsApp%20Image%202026-04-12%20at%209.03.27%20AM%20(1).jpeg)

### Dark Mode

1. Home dashboard in dark theme with live sync indicators.

![Dark Home](frontend/assets/images/WhatsApp%20Image%202026-04-12%20at%209.03.27%20AM%20(2).jpeg)

2. Attendance analysis in dark theme highlighting risky subjects and required recovery classes.

![Dark Attendance Analysis](frontend/assets/images/WhatsApp%20Image%202026-04-12%20at%209.03.28%20AM.jpeg)

3. Monthly attendance calendar in dark theme with date-state color coding.

![Dark Monthly Calendar](frontend/assets/images/WhatsApp%20Image%202026-04-12%20at%209.03.28%20AM%20(1).jpeg)

4. CAT result list in dark theme.

![Dark CAT Results](frontend/assets/images/WhatsApp%20Image%202026-04-12%20at%209.03.28%20AM%20(2).jpeg)

5. Grade analysis and target feasibility warning in dark theme.

![Dark Grade Analysis](frontend/assets/images/WhatsApp%20Image%202026-04-12%20at%209.03.29%20AM.jpeg)

6. End-semester results in dark theme.

![Dark End Sem](frontend/assets/images/WhatsApp%20Image%202026-04-12%20at%209.03.29%20AM%20(1).jpeg)

7. Timetable in dark theme.

![Dark Timetable](frontend/assets/images/WhatsApp%20Image%202026-04-12%20at%209.03.29%20AM%20(2).jpeg)

## API Coverage Summary

Public endpoints:

- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `GET /api/v1/meta/latest-version`
- `GET /health`

Protected endpoints include:

- full sync + attendance-only update
- live attendance/monthly/updates workflows
- profile, attendance, marks, timetable, university results, summary
- departments, programmes, years, semesters, teachers metadata

## Notes

- This repository is actively developed.
- Database normalization and migration strategy are documented in `Backend/docs/dbms`.
