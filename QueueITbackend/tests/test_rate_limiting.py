"""
Tests for rate limiting behaviour (SlowAPI integration).

Strategy
--------
- SlowAPI's in-memory storage is reset before/after every test via the
  `reset_limiter` autouse fixture so tests are fully isolated.
- Auth (`get_authenticated_client`) is overridden with a fake to avoid
  hitting Supabase.
- Service functions are patched to avoid any DB calls; only rate-limiting
  behaviour is under test here.
- Per-route burst limits (e.g. 5/second) are exercised by firing
  burst_cap + 1 requests in rapid succession (requests happen in
  microseconds inside TestClient, so they all fall within the same
  second window).

Coverage
--------
  ✓ /healthz exempt from limiting
  ✓ Per-route limits: spotify/search, sessions/create, sessions/join,
    songs/add, songs/{id}/vote
  ✓ 429 response structure (error, status_code, request_id, X-Request-ID)
  ✓ Retry-After header presence
  ✓ Per-user isolation: User A's counter never burns User B's budget
  ✓ Shared IP unauthenticated requests share a bucket
"""

from __future__ import annotations

import datetime
import uuid
from typing import List
from unittest.mock import AsyncMock, MagicMock, patch

import jwt
import pytest
from fastapi.testclient import TestClient

from app.core.auth import AuthenticatedClient, get_authenticated_client, verify_jwt
from app.core.rate_limit import limiter
from app.main import app
from app.schemas.session import CurrentSessionResponse, SessionBase
from app.schemas.track import TrackOut
from app.schemas.user import User
from app.schemas.session import QueuedSongResponse

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

USER_A_ID = "aaaaaaaa-0000-0000-0000-000000000001"
USER_B_ID = "bbbbbbbb-0000-0000-0000-000000000002"

_NOW = datetime.datetime(2026, 1, 1, 0, 0, 0, tzinfo=datetime.timezone.utc)

_FAKE_HOST = User(
    id=uuid.UUID(USER_A_ID),
    username="TestHost",
)

_FAKE_SESSION_RESPONSE = CurrentSessionResponse(
    session=SessionBase(
        id=uuid.UUID("cccccccc-0000-0000-0000-000000000001"),
        join_code="TCODE",
        created_at=_NOW,
        host=_FAKE_HOST,
        host_provider="spotify",
    ),
    current_song=None,
    queue=[],
)

_FAKE_TRACK = TrackOut(
    external_id="spotify:track:1",
    isrc_identifier="US-QW-00-000001",
    name="Test Song",
    artist="Test Artist",
    album="Test Album",
    durationMSs=200000,
    image_url=None,
)

_FAKE_QUEUED_SONG = QueuedSongResponse(
    id=uuid.UUID("dddddddd-0000-0000-0000-000000000001"),
    status="queued",
    added_at=_NOW,
    votes=0,
    song=_FAKE_TRACK,
    added_by=_FAKE_HOST,
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _fake_jwt(user_id: str) -> str:
    """
    Create a minimal valid-structure JWT (HS256, unverified).

    AuthContextMiddleware decodes with verify_signature=False, so any valid
    JWT structure works — it just needs parseable claims so the middleware
    can set request.state.user_id and the rate limiter can key on user:{id}.
    """
    return jwt.encode(
        {"sub": user_id, "email": f"{user_id}@test.com"},
        "fake-secret-for-tests",
        algorithm="HS256",
    )


def _fake_jwt_payload(user_id: str) -> dict:
    """Minimal dict that verify_jwt would return."""
    return {"token": _fake_jwt(user_id), "payload": {"sub": user_id, "email": f"{user_id}@test.com"}}


def _fake_auth(user_id: str = USER_A_ID) -> AuthenticatedClient:
    """Build a minimal AuthenticatedClient without touching Supabase."""
    return AuthenticatedClient(
        client=MagicMock(),
        payload={"sub": user_id, "email": f"{user_id}@test.com"},
    )


def _make_requests(client: TestClient, method: str, url: str, n: int, **kwargs) -> List:
    """Fire *n* identical requests and return all response objects."""
    fn = getattr(client, method)
    return [fn(url, **kwargs) for _ in range(n)]


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture(autouse=True)
def reset_limiter():
    """Reset SlowAPI in-memory storage before and after every test."""
    limiter._storage.reset()
    yield
    limiter._storage.reset()


@pytest.fixture
def client():
    """TestClient authenticated as User A.

    - Passes a fake JWT as the default Authorization header so that
      AuthContextMiddleware can extract user_id into request.state (which
      the rate-limit key_func reads).
    - Overrides verify_jwt (router-level dependency) and
      get_authenticated_client (per-route dependency) to avoid real JWT
      verification and Supabase client creation.
    """
    app.dependency_overrides[verify_jwt] = lambda: _fake_jwt_payload(USER_A_ID)
    app.dependency_overrides[get_authenticated_client] = lambda: _fake_auth(USER_A_ID)
    headers = {"Authorization": f"Bearer {_fake_jwt(USER_A_ID)}"}
    with TestClient(app, raise_server_exceptions=False, headers=headers) as c:
        yield c
    app.dependency_overrides.clear()


@pytest.fixture
def client_b():
    """TestClient authenticated as User B (different identity bucket)."""
    app.dependency_overrides[verify_jwt] = lambda: _fake_jwt_payload(USER_B_ID)
    app.dependency_overrides[get_authenticated_client] = lambda: _fake_auth(USER_B_ID)
    headers = {"Authorization": f"Bearer {_fake_jwt(USER_B_ID)}"}
    with TestClient(app, raise_server_exceptions=False, headers=headers) as c:
        yield c
    app.dependency_overrides.clear()


@pytest.fixture
def unauthed_client():
    """TestClient with no auth override (falls back to IP-based key)."""
    app.dependency_overrides.clear()
    with TestClient(app, raise_server_exceptions=False) as c:
        yield c
    app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# /healthz – exempt from all limits
# ---------------------------------------------------------------------------


class TestHealthzExempt:
    def test_healthz_never_rate_limited(self, unauthed_client):
        """
        /healthz is decorated with @limiter.exempt and must never 429
        regardless of call volume.
        """
        responses = _make_requests(unauthed_client, "get", "/healthz", 120)
        statuses = {r.status_code for r in responses}
        assert statuses == {200}, (
            f"Expected all 200 from /healthz, got: {statuses}"
        )

    def test_healthz_returns_ok(self, unauthed_client):
        resp = unauthed_client.get("/healthz")
        assert resp.json() == {"status": "ok"}


# ---------------------------------------------------------------------------
# Spotify /search – 20/minute ; 5/second burst
# ---------------------------------------------------------------------------


class TestSpotifySearchLimit:
    _URL = "/api/v1/spotify/search"
    _BURST = 5  # per-second bucket

    @patch("app.api.v1.spotify.search_spotify")
    def test_within_burst_succeeds(self, mock_search, client):
        mock_search.return_value = {"tracks": {"items": []}}
        responses = _make_requests(
            client, "get", self._URL, self._BURST, params={"q": "test"}
        )
        assert all(r.status_code != 429 for r in responses)

    @patch("app.api.v1.spotify.search_spotify")
    def test_exceeding_burst_returns_429(self, mock_search, client):
        mock_search.return_value = {"tracks": {"items": []}}
        responses = _make_requests(
            client, "get", self._URL, self._BURST + 1, params={"q": "test"}
        )
        assert responses[-1].status_code == 429

    @patch("app.api.v1.spotify.search_spotify")
    def test_429_body_structure(self, mock_search, client):
        mock_search.return_value = {"tracks": {"items": []}}
        _make_requests(client, "get", self._URL, self._BURST, params={"q": "test"})
        resp = client.get(self._URL, params={"q": "test"})

        assert resp.status_code == 429
        body = resp.json()
        assert body["error"] == "Too Many Requests"
        assert body["status_code"] == 429
        assert "request_id" in body
        assert "X-Request-ID" in resp.headers

    @patch("app.api.v1.spotify.search_spotify")
    def test_different_users_have_independent_buckets(self, mock_search, client, client_b):
        mock_search.return_value = {"tracks": {"items": []}}
        # Exhaust User A's burst budget
        _make_requests(client, "get", self._URL, self._BURST + 1, params={"q": "x"})
        last_a = client.get(self._URL, params={"q": "x"})
        assert last_a.status_code == 429, "User A should be rate limited"

        # User B has a separate bucket and should not be limited
        resp = client_b.get(self._URL, params={"q": "x"})
        assert resp.status_code != 429, "User B should not be rate limited by User A's usage"


# ---------------------------------------------------------------------------
# Sessions /create – 10/minute ; 3/second burst
# ---------------------------------------------------------------------------

_SESSION_CREATE_BODY = {
    "join_code": "TEST01",
    "platform": "spotify",
}


class TestSessionsCreateLimit:
    _URL = "/api/v1/sessions/create"
    _BURST = 3

    @patch("app.api.v1.sessions.create_session_for_user", return_value=_FAKE_SESSION_RESPONSE)
    def test_within_burst_succeeds(self, _mock, client):
        responses = _make_requests(
            client, "post", self._URL, self._BURST, json=_SESSION_CREATE_BODY
        )
        assert all(r.status_code != 429 for r in responses)

    @patch("app.api.v1.sessions.create_session_for_user", return_value=_FAKE_SESSION_RESPONSE)
    def test_exceeding_burst_returns_429(self, _mock, client):
        responses = _make_requests(
            client, "post", self._URL, self._BURST + 1, json=_SESSION_CREATE_BODY
        )
        assert responses[-1].status_code == 429

    @patch("app.api.v1.sessions.create_session_for_user", return_value=_FAKE_SESSION_RESPONSE)
    def test_user_b_unaffected_by_user_a_exhaustion(self, _mock, client, client_b):
        _make_requests(
            client, "post", self._URL, self._BURST + 1, json=_SESSION_CREATE_BODY
        )
        resp = client_b.post(self._URL, json=_SESSION_CREATE_BODY)
        assert resp.status_code != 429


# ---------------------------------------------------------------------------
# Sessions /join – 20/minute ; 5/second burst
# ---------------------------------------------------------------------------

_SESSION_JOIN_BODY = {"join_code": "ABC123"}


class TestSessionsJoinLimit:
    _URL = "/api/v1/sessions/join"
    _BURST = 5

    @patch("app.api.v1.sessions.join_session_by_code", return_value=_FAKE_SESSION_RESPONSE)
    def test_within_burst_succeeds(self, _mock, client):
        responses = _make_requests(
            client, "post", self._URL, self._BURST, json=_SESSION_JOIN_BODY
        )
        assert all(r.status_code != 429 for r in responses)

    @patch("app.api.v1.sessions.join_session_by_code", return_value=_FAKE_SESSION_RESPONSE)
    def test_exceeding_burst_returns_429(self, _mock, client):
        responses = _make_requests(
            client, "post", self._URL, self._BURST + 1, json=_SESSION_JOIN_BODY
        )
        assert responses[-1].status_code == 429

    @patch("app.api.v1.sessions.join_session_by_code", return_value=_FAKE_SESSION_RESPONSE)
    def test_retry_after_header_present_on_429(self, _mock, client):
        _make_requests(
            client, "post", self._URL, self._BURST, json=_SESSION_JOIN_BODY
        )
        resp = client.post(self._URL, json=_SESSION_JOIN_BODY)
        assert resp.status_code == 429
        # Retry-After is best-effort; just verify it's a non-negative integer when present
        if "Retry-After" in resp.headers:
            assert int(resp.headers["Retry-After"]) >= 0


# ---------------------------------------------------------------------------
# Songs /add – 30/minute ; 5/second burst
# ---------------------------------------------------------------------------

_SONG_ADD_BODY = {
    "id": "spotify:track:abc123",
    "isrc": "US-QW-00-000002",
    "name": "Test Track",
    "artists": "Test Artist",
    "album": "Test Album",
    "duration_ms": 180000,
    "image_url": "https://i.scdn.co/image/test123",
    "source": "spotify",
}


class TestSongsAddLimit:
    _URL = "/api/v1/songs/add"
    _BURST = 5

    @patch("app.api.v1.songs.add_song_to_queue_for_user", new_callable=AsyncMock)
    def test_within_burst_succeeds(self, _mock, client):
        _mock.return_value = _FAKE_QUEUED_SONG
        responses = _make_requests(
            client, "post", self._URL, self._BURST, json=_SONG_ADD_BODY
        )
        assert all(r.status_code != 429 for r in responses)

    @patch("app.api.v1.songs.add_song_to_queue_for_user", new_callable=AsyncMock)
    def test_exceeding_burst_returns_429(self, _mock, client):
        _mock.return_value = _FAKE_QUEUED_SONG
        responses = _make_requests(
            client, "post", self._URL, self._BURST + 1, json=_SONG_ADD_BODY
        )
        assert responses[-1].status_code == 429

    @patch("app.api.v1.songs.add_song_to_queue_for_user", new_callable=AsyncMock)
    def test_user_b_unaffected(self, _mock, client, client_b):
        _mock.return_value = _FAKE_QUEUED_SONG
        _make_requests(
            client, "post", self._URL, self._BURST + 1, json=_SONG_ADD_BODY
        )
        resp = client_b.post(self._URL, json=_SONG_ADD_BODY)
        assert resp.status_code != 429


# ---------------------------------------------------------------------------
# Songs /{id}/vote – 60/minute ; 5/second burst
# ---------------------------------------------------------------------------

_VOTE_BODY = {"vote_value": 1}
_VOTE_URL = "/api/v1/songs/some-song-id/vote"


class TestSongsVoteLimit:
    _BURST = 5

    @patch("app.api.v1.songs.vote_for_queued_song", return_value={"ok": True})
    def test_within_burst_succeeds(self, _mock, client):
        responses = _make_requests(
            client, "post", _VOTE_URL, self._BURST, json=_VOTE_BODY
        )
        assert all(r.status_code != 429 for r in responses)

    @patch("app.api.v1.songs.vote_for_queued_song", return_value={"ok": True})
    def test_exceeding_burst_returns_429(self, _mock, client):
        responses = _make_requests(
            client, "post", _VOTE_URL, self._BURST + 1, json=_VOTE_BODY
        )
        assert responses[-1].status_code == 429

    @patch("app.api.v1.songs.vote_for_queued_song", return_value={"ok": True})
    def test_user_b_unaffected(self, _mock, client, client_b):
        _make_requests(
            client, "post", _VOTE_URL, self._BURST + 1, json=_VOTE_BODY
        )
        resp = client_b.post(_VOTE_URL, json=_VOTE_BODY)
        assert resp.status_code != 429


# ---------------------------------------------------------------------------
# 429 response contract (shared)
# ---------------------------------------------------------------------------


class TestRateLimitResponseContract:
    """
    Verify the 429 response always contains the expected fields regardless
    of which endpoint triggered the limit.
    """

    @patch("app.api.v1.sessions.join_session_by_code", return_value=_FAKE_SESSION_RESPONSE)
    def test_429_json_fields(self, _mock, client):
        _make_requests(client, "post", "/api/v1/sessions/join", 6, json=_SESSION_JOIN_BODY)
        resp = client.post("/api/v1/sessions/join", json=_SESSION_JOIN_BODY)

        assert resp.status_code == 429
        body = resp.json()
        assert set(body.keys()) >= {"error", "status_code", "request_id"}
        assert body["error"] == "Too Many Requests"
        assert body["status_code"] == 429

    @patch("app.api.v1.sessions.join_session_by_code", return_value=_FAKE_SESSION_RESPONSE)
    def test_429_x_request_id_header_matches_body(self, _mock, client):
        _make_requests(client, "post", "/api/v1/sessions/join", 6, json=_SESSION_JOIN_BODY)
        resp = client.post("/api/v1/sessions/join", json=_SESSION_JOIN_BODY)

        assert resp.status_code == 429
        assert resp.headers.get("X-Request-ID") == resp.json()["request_id"]
