"""
Request ID middleware for request correlation and tracing.

Generates or extracts a unique request ID for each HTTP request and:
- Stores it in request.state for access by route handlers
- Adds it to structlog context for automatic inclusion in all logs
- Returns it in X-Request-ID response header for client-side tracing
"""

import uuid
from typing import Callable

import structlog
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response


class RequestIDMiddleware(BaseHTTPMiddleware):
    """
    Middleware to inject request ID into every request.
    
    The request ID is:
    1. Extracted from incoming X-Request-ID header if present
    2. Generated as UUID4 if not present
    3. Stored in request.state.request_id
    4. Added to structlog context vars (appears in all logs during request)
    5. Returned in X-Request-ID response header
    """
    
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        # Extract or generate request ID
        request_id = request.headers.get("X-Request-ID") or str(uuid.uuid4())
        
        # Store in request state for access by handlers
        request.state.request_id = request_id
        
        # Bind to structlog context - will appear in all logs during this request
        structlog.contextvars.clear_contextvars()
        structlog.contextvars.bind_contextvars(
            request_id=request_id,
        )
        
        # Process request
        response = await call_next(request)
        
        # Add request ID to response headers
        response.headers["X-Request-ID"] = request_id
        
        return response

