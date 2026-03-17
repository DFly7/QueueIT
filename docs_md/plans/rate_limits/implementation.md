# Backend Rate Limiting – Implementation Notes

**Plan:** `backend_rate_limiting_e322ed8d.plan.md`  
**Date completed:** 2026-03-17  
**Library:** SlowAPI 0.1.9+

---

## What was done

### 1. Dependency (`requirements.txt`)
Added `slowapi>=0.1.9`.

---

### 2. New module: `app/core/rate_limit.py`

Contains the limiter instance and two helper functions:

| Symbol | Purpose |
|---|---|
| `get_client_ip(request)` | Extracts real client IP. Reads rightmost `X-Forwarded-For` value (Railway's trusted entry), falls back to `X-Real-IP`, then `request.client.host`. |
| `get_rate_limit_key(request)` | Returns `user:{user_id}` when `request.state.user_id` is set (after AuthContextMiddleware runs), otherwise `ip:{get_client_ip(request)}`. |
| `limiter` | `Limiter(key_func=get_rate_limit_key, default_limits=["100/minute"])` |

The in-memory backend is appropriate for single-instance Railway deploys. For multi-instance, pass `storage_uri="redis://..."` to `Limiter`.

---

### 3. `app/core/config.py`

Two new settings added (both overridable via env vars):

```
RATE_LIMIT_ENABLED=true    # set false to disable in dev
RATE_LIMIT_DEFAULT=100/minute
```

---

### 4. `app/main.py`

Changes:
- Imports `limiter`, `SlowAPIMiddleware`, `RateLimitExceeded`.
- Sets `app.state.limiter = limiter` (required by `SlowAPIMiddleware`).
- Adds `SlowAPIMiddleware` to middleware stack between `AuthContextMiddleware` and `AccessLogMiddleware`.
- Decorates `healthz` with `@limiter.exempt` (metrics endpoint is mounted via `app.mount` and is inherently exempt).

**Middleware order** (request flow, not registration order):

```
RequestIDMiddleware → AuthContextMiddleware → SlowAPIMiddleware → AccessLogMiddleware → route
```

This ordering is critical: `AuthContextMiddleware` must run first so that `request.state.user_id` is populated before `SlowAPIMiddleware` calls `get_rate_limit_key`.

---

### 5. `app/exception_handlers.py`

New handler `rate_limit_exceeded_handler` registered for `RateLimitExceeded`:

- Returns HTTP 429 with structured JSON (`error`, `status_code`, `request_id`) matching existing handler format.
- Adds `Retry-After` response header (seconds until limit resets) when available from the limits library. Uses defensive `getattr` access in case `exc.limit` is absent.
- Logs `warning` with `rate_limit_exceeded` event, path, user_id, and retry_after.
- Registered **before** the generic `StarletteHTTPException` handler so SlowAPI's exception is caught first.

---

### 6. Per-route limits

Five high-risk endpoints decorated with `@limiter.limit(...)` and `request: Request` added as first parameter:

| Endpoint | Limits | Rationale |
|---|---|---|
| `GET /api/v1/spotify/search` | `20/minute;5/second` | External Spotify API cost; 5/s burst covers autocomplete |
| `POST /api/v1/sessions/create` | `10/minute;3/second` | Session spam prevention |
| `POST /api/v1/sessions/join` | `20/minute;5/second` | Join-code brute force protection |
| `POST /api/v1/songs/add` | `30/minute;5/second` | Queue flooding prevention |
| `POST /api/v1/songs/{id}/vote` | `60/minute;5/second` | Vote manipulation; 5/s allows human bursts, blocks scripts |

The global `100/minute` limit via `SlowAPIMiddleware` covers all other routes with no code changes required.

> **Note on `songs.py`:** The `add_song` handler's `Body(...)` parameter was renamed `body` (from `request`) to avoid shadowing the `Request` argument required by SlowAPI.

---

### 7. `app/middleware/access_log.py`

Fixed `get_client_ip` to use `split(",")[-1]` (rightmost) instead of `split(",")[0]` (leftmost) for `X-Forwarded-For`. This aligns with Railway's proxy behaviour and eliminates spoofable IP logging.

---

## Files changed

| File | Change |
|---|---|
| `requirements.txt` | Added `slowapi>=0.1.9` |
| `app/core/rate_limit.py` | **New** – limiter + key_func |
| `app/core/config.py` | Added `rate_limit_enabled`, `rate_limit_default` settings |
| `app/main.py` | Attached limiter, added `SlowAPIMiddleware`, exempted `/healthz` |
| `app/exception_handlers.py` | Added `rate_limit_exceeded_handler` for 429 responses |
| `app/api/v1/spotify.py` | `@limiter.limit("20/minute;5/second")` + `request: Request` |
| `app/api/v1/sessions.py` | Per-route limits on `/create` and `/join` |
| `app/api/v1/songs.py` | Per-route limits on `/add` and `/{id}/vote` |
| `app/middleware/access_log.py` | Fixed X-Forwarded-For to use rightmost IP |

---

## Testing guidance

```python
# Assert 429 after exceeding limit
# Assert /healthz is not limited
# Assert different JWTs get independent counters (per-user keying)
```

See plan section "Testing" for full test checklist.
