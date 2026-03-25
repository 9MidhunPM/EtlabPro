"""
app.api.deps
────────────
Reusable FastAPI dependencies.

JWT-based authentication: every protected endpoint declares
    current_user = Depends(get_current_user)
"""
import logging
from datetime import datetime, timezone, timedelta

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.config import get_settings

log = logging.getLogger(__name__)

_bearer_scheme = HTTPBearer(auto_error=False)


# ── Token helpers ─────────────────────────────────────────────────────

def create_access_token(roll_number: str, device_id: str | None = None) -> str:
    """Create a short-lived access token (default 6 hours)."""
    settings = get_settings()
    now = datetime.now(timezone.utc)
    payload = {
        "sub": roll_number,
        "type": "access",
        "iat": now,
        "exp": now + timedelta(hours=settings.JWT_ACCESS_TOKEN_EXPIRE_HOURS),
    }
    if device_id:
        payload["device"] = device_id
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)


def create_refresh_token(roll_number: str, device_id: str | None = None) -> str:
    """Create a long-lived refresh token (default 30 days)."""
    settings = get_settings()
    now = datetime.now(timezone.utc)
    payload = {
        "sub": roll_number,
        "type": "refresh",
        "iat": now,
        "exp": now + timedelta(days=settings.JWT_REFRESH_TOKEN_EXPIRE_DAYS),
    }
    if device_id:
        payload["device"] = device_id
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)


def decode_token(token: str) -> dict:
    """Decode and validate a JWT token. Raises on expired / invalid."""
    settings = get_settings()
    return jwt.decode(
        token,
        settings.JWT_SECRET,
        algorithms=[settings.JWT_ALGORITHM],
    )


# ── FastAPI dependency ────────────────────────────────────────────────

async def get_current_user(
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer_scheme),
) -> dict:
    """
    Dependency that validates Bearer JWT on every protected request.
    Returns the decoded token payload (contains 'sub' = roll_number).
    """
    if creds is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing authorization header.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    try:
        payload = decode_token(creds.credentials)
        if payload.get("type") != "access":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token type. Use an access token.",
            )
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except jwt.InvalidTokenError:
        log.warning("Rejected request — invalid JWT")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token.",
            headers={"WWW-Authenticate": "Bearer"},
        )
