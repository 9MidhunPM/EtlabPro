import re
import logging
import time

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from app.config import get_settings

log = logging.getLogger(__name__)

BASE_URL   = get_settings().ETLAB_BASE_URL
LOGIN_URL  = f"{BASE_URL}/user/login"
TIMEOUT    = get_settings().REQUEST_TIMEOUT

_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/125.0.0.0 Safari/537.36"
    ),
}

_RETRY_STRATEGY = Retry(
    total=4,
    backoff_factor=1.5,          # waits 0s, 1.5s, 3s, 6s between retries
    status_forcelist={500, 502, 503, 504},
    allowed_methods={"GET", "POST"},
    raise_on_status=False,
)


def _extract_csrf(html: str) -> str | None:
    match = re.search(r'"YII_CSRF_TOKEN"\s*:\s*"([^"]+)"', html)
    return match.group(1) if match else None


def scrape_etlab_user_id(session: requests.Session) -> str | None:
    """
    Fetch the KTU academics attendance overview page and extract the
    numeric etlab student ID from the nav link:
      /ktuacademics/student/viewattendancesubject/{id}
    This ID is required to build the attendance-by-subject URL.
    """
    BASE_URL = get_settings().ETLAB_BASE_URL
    url = f"{BASE_URL}/ktuacademics/student/attendance"
    try:
        resp = session.get(url, timeout=TIMEOUT)
        resp.raise_for_status()
        m = re.search(r'/viewattendancesubject/(\d+)', resp.text)
        if m:
            log.info("etlab_user_id extracted: %s", m.group(1))
            return m.group(1)
    except Exception as exc:
        log.warning("Could not extract etlab_user_id: %s", exc)
    return None


def create_session(username: str, password: str) -> requests.Session:
    """
    Log in with the supplied credentials and return an authenticated session.
    Raises RuntimeError on login failure.
    Includes automatic retry with exponential backoff for transient SSL/network errors.
    """
    session = requests.Session()
    session.headers.update(_HEADERS)

    # Mount retry adapter for both http and https
    adapter = HTTPAdapter(max_retries=_RETRY_STRATEGY)
    session.mount("https://", adapter)
    session.mount("http://", adapter)

    log.info("Fetching login page …")
    resp = session.get(LOGIN_URL, timeout=TIMEOUT)
    resp.raise_for_status()

    csrf = _extract_csrf(resp.text)
    payload: dict = {
        "LoginForm[username]": username,
        "LoginForm[password]": password,
        "yt0": "",
    }
    if csrf:
        payload["YII_CSRF_TOKEN"] = csrf

    log.info("Logging in as %s …", username)
    resp = session.post(LOGIN_URL, data=payload, allow_redirects=True, timeout=TIMEOUT)
    resp.raise_for_status()

    if "/user/login" in resp.url and "login-form" in resp.text:
        raise RuntimeError("Login failed — invalid credentials.")

    log.info("Login OK → %s", resp.url)
    return session
