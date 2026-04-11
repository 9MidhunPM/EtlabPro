"""
Central configuration — reads from environment variables.
All other modules import from here; nothing imports os.getenv directly.
"""
import os
import secrets as _secrets
from functools import lru_cache
from dotenv import load_dotenv
from pathlib import Path

# .env lives one level above the app/ directory (i.e. Backend/.env)
_ENV_PATH = Path(__file__).resolve().parent.parent / ".env"
load_dotenv(_ENV_PATH)


class Settings:
    # ── Supabase ─────────────────────────────────────────────────────
    SUPABASE_URL: str = os.environ["SUPABASE_URL"]
    SUPABASE_SERVICE_ROLE_KEY: str = os.environ["SUPABASE_SERVICE_ROLE_KEY"]

    # ── JWT Security ─────────────────────────────────────────────────
    # Secret used to sign/verify JWT tokens.
    # Generate with: python -c "import secrets; print(secrets.token_hex(32))"
    JWT_SECRET: str = os.getenv("JWT_SECRET", _secrets.token_hex(32))
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_HOURS: int = int(os.getenv("JWT_ACCESS_HOURS", 6))
    JWT_REFRESH_TOKEN_EXPIRE_DAYS: int = int(os.getenv("JWT_REFRESH_DAYS", 30))

    # Comma-separated list of allowed frontend origins (no trailing slashes).
    FRONTEND_ORIGINS: list[str] = [
        o.strip()
        for o in os.getenv("FRONTEND_ORIGINS", "http://localhost:3000").split(",")
        if o.strip()
    ]

    # ── Etlab ────────────────────────────────────────────────────────
    ETLAB_BASE_URL: str = "https://sahrdaya.etlab.in"

    # ── Refresh policy (seconds) ─────────────────────────────────────
    ATTENDANCE_MAX_AGE_SECONDS: int = int(os.getenv("ATTENDANCE_MAX_AGE_SECONDS", 7200))    # 2 h
    MARKS_MAX_AGE_SECONDS:      int = int(os.getenv("MARKS_MAX_AGE_SECONDS",      604800))  # 7 d
    TIMETABLE_MAX_AGE_SECONDS:  int = int(os.getenv("TIMETABLE_MAX_AGE_SECONDS",  604800))  # 7 d
    PROFILE_MAX_AGE_SECONDS:    int = int(os.getenv("PROFILE_MAX_AGE_SECONDS",    604800))  # 7 d
    UNI_RESULTS_MAX_AGE_SECONDS: int = int(os.getenv("UNI_RESULTS_MAX_AGE_SECONDS", 604800))

    # ── HTTP ─────────────────────────────────────────────────────────
    REQUEST_TIMEOUT: int = int(os.getenv("REQUEST_TIMEOUT", 90))


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
