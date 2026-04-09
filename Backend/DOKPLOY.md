# Dokploy setup for Backend

This backend is now fully containerized from this folder only.

## Dokploy settings

- Source repository: this repository
- Build context: `Backend`
- Dockerfile path: `Dockerfile`
- Container port: `8000` (or use `PORT` env variable)
- Health check path: `/health`

## Required environment variables

Set these in Dokploy project environment variables:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `API_KEY`
- `FRONTEND_ORIGINS`
- `ENV=production`
- `JWT_SECRET` (recommended for stable token validation across restarts)

Optional:

- `PORT` (defaults to `8000`)
- `JWT_ACCESS_HOURS`
- `JWT_REFRESH_DAYS`
- `ATTENDANCE_MAX_AGE_SECONDS`
- `MARKS_MAX_AGE_SECONDS`
- `TIMETABLE_MAX_AGE_SECONDS`
- `PROFILE_MAX_AGE_SECONDS`
- `UNI_RESULTS_MAX_AGE_SECONDS`
- `REQUEST_TIMEOUT`

## Notes

- Do not mount or copy `.env` into the image for production.
- If Dokploy is configured at repository root, build context must still be `Backend`.
