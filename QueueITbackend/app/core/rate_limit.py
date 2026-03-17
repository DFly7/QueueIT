"""
Rate limiting configuration for the QueueIT API.

Uses SlowAPI (a FastAPI/Starlette wrapper around the `limits` library).

Key design decisions:
- Custom key_func prefers authenticated user_id over IP to avoid shared-IP false positives
  (e.g. university NAT, mobile carriers).
- IP extraction uses the RIGHTMOST value from X-Forwarded-For; on Railway the platform
  appends the real client IP as the rightmost entry, so leftmost values can be spoofed
  but rightmost cannot.
- In-memory storage is fine for single-instance Railway deploys. For multi-instance,
  pass storage_uri="redis://..." to Limiter.
"""

from slowapi import Limiter
from starlette.requests import Request


def get_client_ip(request: Request) -> str:
    """Extract the real client IP, accounting for Railway's proxy behaviour."""
    forwarded_for = request.headers.get("X-Forwarded-For")
    if forwarded_for:
        # Railway prepends the real IP; rightmost entry is trusted
        return forwarded_for.split(",")[-1].strip()
    real_ip = request.headers.get("X-Real-IP")
    if real_ip:
        return real_ip.strip()
    return request.client.host if request.client else "unknown"


def get_rate_limit_key(request: Request) -> str:
    """
    Prefer per-user keying when the JWT has already been resolved by
    AuthContextMiddleware; fall back to IP for unauthenticated requests.
    """
    user_id = getattr(request.state, "user_id", None)
    if user_id:
        return f"user:{user_id}"
    return f"ip:{get_client_ip(request)}"


limiter = Limiter(
    key_func=get_rate_limit_key,
    default_limits=["100/minute"],
)
