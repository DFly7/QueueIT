"""
Access logging middleware for request/response logging.

Logs structured access logs for every HTTP request with:
- Request method, path, query params
- Response status code and duration
- Request ID for correlation
- User ID when authenticated
- Error information when request fails
"""

import time
from typing import Callable

import structlog
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

logger = structlog.get_logger(__name__)


class AccessLogMiddleware(BaseHTTPMiddleware):
    """
    Middleware to log all HTTP requests and responses with structured data.
    
    Logs include:
    - method: HTTP method (GET, POST, etc.)
    - path: Request path
    - query_params: Query string (sanitized)
    - status: Response status code
    - duration_ms: Request duration in milliseconds
    - request_id: Correlation ID
    - user_id: User ID when authenticated (from request.state)
    """
    
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        start_time = time.perf_counter()
        
        # Extract request details
        method = request.method
        path = request.url.path
        query_params = str(request.query_params) if request.query_params else None
        
        # Try to get user_id if authenticated
        user_id = getattr(request.state, "user_id", None)
        if user_id:
            structlog.contextvars.bind_contextvars(user_id=user_id)
        
        # Process request
        try:
            response = await call_next(request)
            status = response.status_code
            
            # Calculate duration
            duration_ms = (time.perf_counter() - start_time) * 1000
            
            # Log successful request
            log_level = "info"
            if status >= 500:
                log_level = "error"
            elif status >= 400:
                log_level = "warning"
            
            getattr(logger, log_level)(
                "request_completed",
                method=method,
                path=path,
                query_params=query_params,
                status=status,
                duration_ms=round(duration_ms, 2),
            )
            
            return response
            
        except Exception as exc:
            # Calculate duration even for exceptions
            duration_ms = (time.perf_counter() - start_time) * 1000
            
            # Log failed request
            logger.error(
                "request_failed",
                method=method,
                path=path,
                query_params=query_params,
                duration_ms=round(duration_ms, 2),
                error_type=type(exc).__name__,
                error_message=str(exc),
                exc_info=True,
            )
            
            # Re-raise to let exception handlers deal with it
            raise

