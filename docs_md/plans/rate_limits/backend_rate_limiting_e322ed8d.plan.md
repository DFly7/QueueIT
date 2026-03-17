---
name: Backend Rate Limiting
overview: Add application-level rate limiting to the FastAPI backend using SlowAPI. No rate limiting exists today; the backend review already flagged this as a MAJOR security gap for a public API. The plan covers global limits, per-route limits for high-risk endpoints, and integration with existing auth and exception handling.
todos: []
isProject: false
---

# Backend Rate Limiting Plan

## Current State

**No rate limiting exists.** The backend ([QueueITbackend/](QueueITbackend/)) is a FastAPI app deployed on Railway. All `/api/v1` routes require JWT via `verify_jwt` in [app/api/v1/router.py](QueueITbackend/app/api/v1/router.py). Public endpoints `/healthz` and `/metrics` are unauthenticated.

Your own [backend_review.md](QueueITbackend/docs/review_231125/backend_review.md) (lines 283–318) already identified this as a **MAJOR** issue and suggested SlowAPI. That recommendation was never implemented.

---

## Risk Overview

| Endpoint                  | Risk                               |
| ------------------------- | ---------------------------------- |
| `/api/v1/spotify/search`  | External Spotify API costs; no cap |
| `/api/v1/sessions/create` | Session spam                       |
| `/api/v1/sessions/join`   | Join-code brute force              |
| `/api/v1/songs/add`       | Queue flooding                     |
| `/api/v1/songs/{id}/vote` | Vote manipulation                  |

---

## Recommended Approach: SlowAPI

**Why SlowAPI:** Works with FastAPI/Starlette, supports per-route and global limits, Redis/memory backends, and custom key functions. Your docs already reference it.

**Important:** Use `SlowAPIMiddleware` + `default_limits` for global limits so most routes need no changes. Only routes with stricter per-route limits require `request: Request`.

---

## Architecture

```mermaid
flowchart TB
    subgraph middleware [Middleware Stack]
        RID[RequestIDMiddleware]
        AUTH[AuthContextMiddleware]
        ACCESS[AccessLogMiddleware]
        SLOW[SlowAPIMiddleware]
    end

    subgraph rateLimit [Rate Limiting]
        KEY[key_func: user_id or IP]
        LIMITER[Limiter + default_limits]
    end

    subgraph routes [Routes]
        HEALTH[/healthz - exempt]
        METRICS[/metrics - exempt]
        API[/api/v1/* - 100/min global, 5 routes stricter]
    end

    RID --> AUTH --> ACCESS --> SLOW
    AUTH -->|sets request.state.user_id| KEY
    KEY --> LIMITER
    SLOW --> LIMITER
    LIMITER --> routes
```

---

## Implementation Plan

### 1. Add SlowAPI dependency

- Add `slowapi` to [requirements.txt](QueueITbackend/requirements.txt) (pin version, e.g. `slowapi>=0.1.9`)

### 2. Create rate limiter module

- New file: `app/core/rate_limit.py`
  - **Custom `key_func`** – do NOT use `get_remote_address` from slowapi; it uses `request.client.host`, which on Railway returns the proxy IP, not the user's.
  - Implement `get_client_ip(request)` that checks (in order):
    - `X-Forwarded-For` **rightmost** value (Railway prepends real IP; leftmost can be spoofed)
    - `X-Real-IP` (Railway fixed spoofing; now trusted)
    - `request.client.host` (fallback for local dev)
  - Implement `get_rate_limit_key(request)`: prefer `user:{request.state.user_id}` when set, else `ip:{get_client_ip(request)}`
  - Initialize `Limiter(key_func=get_rate_limit_key, default_limits=["100/minute"])` for global cap

```python
# app/core/rate_limit.py - key_func snippet
def get_client_ip(request: Request) -> str:
    forwarded_for = request.headers.get("X-Forwarded-For")
    if forwarded_for:
        return forwarded_for.split(",")[-1].strip()  # rightmost = trusted on Railway
    real_ip = request.headers.get("X-Real-IP")
    if real_ip:
        return real_ip.strip()
    return request.client.host if request.client else "unknown"

def get_rate_limit_key(request: Request) -> str:
    user_id = getattr(request.state, "user_id", None)
    if user_id:
        return f"user:{user_id}"
    return f"ip:{get_client_ip(request)}"
```

### 3. Wire into main app

- In [app/main.py](QueueITbackend/app/main.py):
  - Import limiter, `RateLimitExceeded`, and `SlowAPIMiddleware`
  - Set `app.state.limiter = limiter` with `default_limits=["100/minute"]`
  - Add `app.add_middleware(SlowAPIMiddleware)` – **order matters:** add it **after** `AccessLogMiddleware` and **before** `AuthContextMiddleware`. Middleware runs in reverse order of registration (last added = first to run). So we need: RequestID → AuthContext → SlowAPI → AccessLog → route. That way, when SlowAPI's `key_func` runs, `request.state.user_id` is already set by AuthContext.

```python
# Correct order (AuthContext must run before SlowAPI so key_func sees user_id)
app.add_middleware(AccessLogMiddleware)
app.add_middleware(SlowAPIMiddleware)    # After AuthContext in request flow
app.add_middleware(AuthContextMiddleware)
app.add_middleware(RequestIDMiddleware)
```

- Register `RateLimitExceeded` exception handler
- Exempt `/healthz` and `/metrics` via `@limiter.exempt` on those route handlers (no Request needed on exempt routes)

### 4. Add RateLimitExceeded handler

- In [app/exception_handlers.py](QueueITbackend/app/exception_handlers.py):
  - Add handler that returns 429 with structured JSON (aligned with existing handlers)
  - Include `request_id`, `error`, `status_code` for consistency
  - **Retry-After header:** Use `exc.limit.limit.get_expiry()` (limits library) to get reset time; compute seconds until then. Include in response headers so frontend can show "Try again in X seconds". Defensive: use `getattr` in case `exc.limit` is missing (e.g. storage backend failure). Verify exact API during implementation.

```python
async def rate_limit_exceeded_handler(request: Request, exc: RateLimitExceeded) -> JSONResponse:
    request_id = getattr(request.state, "request_id", "unknown")
    retry_after = ""
    try:
        expiry = getattr(getattr(exc, "limit", None), "limit", None)
        if expiry and hasattr(expiry, "get_expiry"):
            secs = max(0, int(expiry.get_expiry() - time.time()))
            retry_after = str(secs)
    except Exception:
        pass
    headers = {"X-Request-ID": request_id}
    if retry_after:
        headers["Retry-After"] = retry_after
    return JSONResponse(
        status_code=429,
        content={"error": "Too Many Requests", "status_code": 429, "request_id": request_id},
        headers=headers,
    )
```

### 5. Apply limits to routes

**Global:** `SlowAPIMiddleware` + `default_limits=["100/minute"]` applies to all routes. No `request: Request` needed on most routes.

**Per-route (stricter + burst protection):** Only these 5 routes need `@limiter.limit(...)` and `request: Request`. Use multiple limits (`;`-separated) to allow human bursts while blocking rapid-fire scripts:

| File                                                            | Endpoint          | Limit (avg + burst)  |
| --------------------------------------------------------------- | ----------------- | -------------------- |
| [app/api/v1/spotify.py](QueueITbackend/app/api/v1/spotify.py)   | `GET /search`     | `20/minute;5/second` |
| [app/api/v1/sessions.py](QueueITbackend/app/api/v1/sessions.py) | `POST /create`    | `10/minute;3/second` |
| [app/api/v1/sessions.py](QueueITbackend/app/api/v1/sessions.py) | `POST /join`      | `20/minute;5/second` |
| [app/api/v1/songs.py](QueueITbackend/app/api/v1/songs.py)       | `POST /add`       | `30/minute;5/second` |
| [app/api/v1/songs.py](QueueITbackend/app/api/v1/songs.py)       | `POST /{id}/vote` | `60/minute;5/second` |

Example: `60/minute;5/second` allows 5 votes in 5 seconds (human burst) but blocks 20 votes in 2 seconds (script).

### 6. Config (optional)

- Add to [app/core/config.py](QueueITbackend/app/core/config.py):
  - `rate_limit_enabled: bool` (default `True`, `False` in dev if desired)
  - `rate_limit_default: str` (e.g. `"100/minute"`)

---

## File Changes Summary

| File                           | Change                                                        |
| ------------------------------ | ------------------------------------------------------------- |
| `requirements.txt`             | Add `slowapi`                                                 |
| `app/core/rate_limit.py`       | **New** – limiter + key_func                                  |
| `app/core/config.py`           | Optional: rate limit settings                                 |
| `app/main.py`                  | Attach limiter, add SlowAPIMiddleware, exempt healthz/metrics |
| `app/exception_handlers.py`    | Add `RateLimitExceeded` handler                               |
| `app/api/v1/router.py`         | No changes (middleware handles global limit)                  |
| `app/api/v1/spotify.py`        | `@limiter.limit("20/minute")` + `request: Request`            |
| `app/api/v1/sessions.py`       | Per-route limits + `request: Request`                         |
| `app/api/v1/songs.py`          | Per-route limits + `request: Request`                         |
| `app/middleware/access_log.py` | Fix `get_client_ip`: use `split(",")[-1]` for Railway         |

---

## Deployment Notes

- **Memory backend:** Default in-memory storage is fine for single-instance Railway deploys. For multiple instances, use Redis via `storage_uri` (SlowAPI uses the `limits` library, which supports Redis).
- **Railway proxy:** Do not use `get_remote_address` from slowapi (it returns proxy IP). The custom `get_client_ip` in step 2 uses `X-Forwarded-For` **rightmost** (Railway's trusted value) and `X-Real-IP` as fallback. **Related:** [access_log.py](QueueITbackend/app/middleware/access_log.py) uses leftmost and can be spoofed; consider `split(",")[-1]` there too.

---

## Testing

- Add tests that:
  - Exceed limit and assert 429
  - Verify exempt routes (`/healthz`, `/metrics`) are not limited
  - Verify per-user limits (different JWTs = different limits)
