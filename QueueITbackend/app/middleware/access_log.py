"""
Access logging middleware for request/response logging.

Logs structured access logs for every HTTP request with:
- Request method, path, query params
- Response status code and duration
- Request ID for correlation
- User ID, email when authenticated
- Client IP address
- Request body (optional, with size limit and masking)
- Error information when request fails
"""

import json
import time
from typing import Callable, Optional

import structlog
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

from app.core.config import get_settings
from app.utils.log_context import safe_log_dict

logger = structlog.get_logger(__name__)
settings = get_settings()


def get_client_ip(request: Request) -> Optional[str]:
    """
    Extract client IP address from request.
    
    Checks in order:
    1. X-Forwarded-For header (proxy/load balancer)
    2. X-Real-IP header (nginx)
    3. request.client.host (direct connection)
    """
    # Check X-Forwarded-For (may contain multiple IPs, take first)
    forwarded_for = request.headers.get("X-Forwarded-For")
    if forwarded_for:
        return forwarded_for.split(",")[0].strip()
    
    # Check X-Real-IP
    real_ip = request.headers.get("X-Real-IP")
    if real_ip:
        return real_ip.strip()
    
    # Fallback to direct connection
    if request.client:
        return request.client.host
    
    return None


def get_user_details(request: Request) -> tuple[Optional[str], Optional[str]]:
    """
    Extract user ID and email from request state or JWT claims.
    
    Returns:
        tuple: (user_id, user_email)
    """
    # Try to get from request.state (set by auth middleware)
    user_id = getattr(request.state, "user_id", None)
    user_email = getattr(request.state, "user_email", None)
    
    # If not in state, try to extract from user object
    user = getattr(request.state, "user", None)
    if user:
        if not user_id and hasattr(user, "id"):
            user_id = user.id
        if not user_email and hasattr(user, "email"):
            user_email = user.email
    
    return user_id, user_email


async def get_request_body(request: Request, max_size: int = 1000) -> Optional[dict]:
    """
    Extract and parse request body for logging.
    
    Args:
        request: FastAPI request object
        max_size: Maximum body size to log (in bytes)
        
    Returns:
        Parsed JSON body (sanitized) or size info if too large/not JSON
    """
    try:
        # Check content type
        content_type = request.headers.get("content-type", "")
        if "application/json" not in content_type:
            return {"content_type": content_type, "logged": False}
        
        # Get body
        body_bytes = await request.body()
        body_size = len(body_bytes)
        
        # Check size limit
        if body_size > max_size:
            return {
                "size_bytes": body_size,
                "logged": False,
                "reason": f"body_too_large (max: {max_size} bytes)"
            }
        
        # Parse JSON
        if body_bytes:
            body_json = json.loads(body_bytes)
            # Sanitize sensitive fields
            return safe_log_dict(body_json)
        
        return None
        
    except json.JSONDecodeError:
        return {"error": "invalid_json"}
    except Exception as exc:
        return {"error": type(exc).__name__}


class AccessLogMiddleware(BaseHTTPMiddleware):
    """
    Middleware to log all HTTP requests and responses with structured data.
    
    Logs include:
    - method: HTTP method (GET, POST, etc.)
    - path: Request path
    - query_params: Query string parameters (as dict)
    - status: Response status code
    - duration_ms: Request duration in milliseconds
    - request_id: Correlation ID
    - user_id: User ID when authenticated
    - user_email: User email when authenticated
    - client_ip: Client IP address (from headers or connection)
    - request_body: Request body (optional, sanitized, size-limited)
    """
    
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        start_time = time.perf_counter()
        
        # Extract request details
        method = request.method
        path = request.url.path
        
        # Parse query params as dict for better readability
        query_params = dict(request.query_params) if request.query_params else None
        
        # Get user details (ID and email)
        user_id, user_email = get_user_details(request)
        
        # Get client IP
        client_ip = get_client_ip(request)
        
        # Bind user context to all logs in this request
        if user_id:
            structlog.contextvars.bind_contextvars(
                user_id=user_id,
                user_email=user_email,
                client_ip=client_ip,
            )
        
        # Optionally log request body (for POST/PUT/PATCH)
        request_body = None
        if settings.log_request_body and method in ["POST", "PUT", "PATCH"]:
            request_body = await get_request_body(request, settings.log_request_body_max_size)
        
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
            
            # Build log data
            log_data = {
                "event": "request_completed",
                "method": method,
                "path": path,
                "status": status,
                "duration_ms": round(duration_ms, 2),
                "client_ip": client_ip,
            }
            
            # Add optional fields
            if query_params:
                log_data["query_params"] = query_params
            
            if user_id:
                log_data["user_id"] = user_id
                if user_email:
                    log_data["user_email"] = user_email
            
            if request_body is not None:
                log_data["request_body"] = request_body
            
            getattr(logger, log_level)(**log_data)
            
            return response
            
        except Exception as exc:
            # Calculate duration even for exceptions
            duration_ms = (time.perf_counter() - start_time) * 1000
            
            # Build error log data
            error_log_data = {
                "event": "request_failed",
                "method": method,
                "path": path,
                "duration_ms": round(duration_ms, 2),
                "error_type": type(exc).__name__,
                "error_message": str(exc),
                "client_ip": client_ip,
                "exc_info": True,
            }
            
            if query_params:
                error_log_data["query_params"] = query_params
            
            if user_id:
                error_log_data["user_id"] = user_id
                if user_email:
                    error_log_data["user_email"] = user_email
            
            if request_body is not None:
                error_log_data["request_body"] = request_body
            
            logger.error(**error_log_data)
            
            # Re-raise to let exception handlers deal with it
            raise

