"""
db.students
───────────
CRUD operations for the `students` table.
All functions are synchronous wrappers around the Supabase client.
"""
import logging
from datetime import datetime, timezone

from supabase import Client

log = logging.getLogger(__name__)


def get_or_create_student(
    client: Client,
    roll_number: str,
    admission_number: str | None = None,
    etlab_user_id: str | None = None,
) -> dict:
    """
    Returns the existing student row (dict) or creates a new one.
    Also updates etlab_user_id if it was previously unknown.
    """
    resp = (
        client.table("students")
        .select("*")
        .eq("roll_number", roll_number)
        .limit(1)
        .execute()
    )

    if resp.data:
        student = resp.data[0]
        patch: dict = {}
        if etlab_user_id and not student.get("etlab_user_id"):
            patch["etlab_user_id"] = etlab_user_id
        if admission_number and student.get("admission_number") != admission_number:
            patch["admission_number"] = admission_number
        if patch:
            patch["updated_at"] = _now()
            client.table("students").update(patch).eq("id", student["id"]).execute()
            student.update(patch)
        return student

    # Create new
    payload: dict = {
        "roll_number": roll_number,
        "updated_at":  _now(),
    }
    if admission_number:
        payload["admission_number"] = admission_number
    if etlab_user_id:
        payload["etlab_user_id"] = etlab_user_id

    resp = client.table("students").insert(payload).execute()
    log.info("Created student row for roll=%s", roll_number)
    return resp.data[0]


def get_student_by_roll(client: Client, roll_number: str) -> dict | None:
    resp = (
        client.table("students")
        .select("*")
        .eq("roll_number", roll_number)
        .limit(1)
        .execute()
    )
    return resp.data[0] if resp.data else None


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()
