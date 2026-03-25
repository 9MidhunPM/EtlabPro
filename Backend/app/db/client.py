"""
db.client
─────────
Supabase client singleton.
Import `supabase_client` wherever you need DB access.

The service role key bypasses Row-Level Security — it is only
used here in the backend.  Never expose it to clients.
"""
from functools import lru_cache

from supabase import create_client, Client

from app.config import get_settings


@lru_cache(maxsize=1)
def get_supabase() -> Client:
    cfg = get_settings()
    return create_client(cfg.SUPABASE_URL, cfg.SUPABASE_SERVICE_ROLE_KEY)
