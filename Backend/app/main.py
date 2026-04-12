"""
app.main
────────
FastAPI application entry point.

Run locally:
    uvicorn app.main:app --reload --port 8000
"""
import logging
import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import router
from app.config import get_settings

logging.basicConfig(
    level=logging.WARNING,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
)

# Silence noisy loggers — keep only our app + uvicorn access logs
for _noisy in ("httpcore", "httpx", "hpack", "urllib3", "asyncio",
               "watchfiles", "multipart", "dotenv", "uvicorn.access", "uvicorn.error"):
    logging.getLogger(_noisy).setLevel(logging.WARNING)

_settings = get_settings()

# Docs are only accessible in development (set ENV=development in .env for local work).
# In production they are disabled entirely so the API surface is not discoverable.
_dev = os.getenv("ENV", "production").lower() == "development"

app = FastAPI(
    title="EtlabPro API",
    description=(
        "Backend service that scrapes sahrdaya.etlab.in and stores "
        "student data (marks, attendance, timetable, results) in Supabase. "
        "Public endpoints: /auth/login, /auth/refresh. "
        "All other endpoints require a valid Bearer JWT."
    ),
    version="1.0.0",
    docs_url="/docs" if _dev else None,
    redoc_url="/redoc" if _dev else None,
    openapi_url="/openapi.json" if _dev else None,
)

# ── CORS — only the configured frontend origins are allowed ──────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=_settings.FRONTEND_ORIGINS,
    allow_methods=["GET", "POST"],
    allow_headers=["Authorization", "Content-Type", "Accept"],
    allow_credentials=False,
)

# ── Register routes ───────────────────────────────────────────────────
app.include_router(router, prefix="/api/v1")


@app.get("/health", tags=["meta"])
def health() -> dict:
    """Public health-check — no API key required."""
    return {"status": "ok"}
