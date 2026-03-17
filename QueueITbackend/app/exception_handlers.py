"""
Centralized exception handlers with structured logging.

Provides consistent error responses and comprehensive error logging with:
- Full stack traces
- Request context (request_id, user_id, path, method)
- Structured error details
- Appropriate HTTP status codes
"""

import time
from typing import Union

import structlog
from fastapi import Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from postgrest.exceptions import APIError as PostgrestAPIError
from slowapi.errors import RateLimitExceeded
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.exceptions import DuplicateJoinCodeError

logger = structlog.get_logger(__name__)


async def http_exception_handler(request: Request, exc: StarletteHTTPException) -> JSONResponse:
    """
    Handler for HTTP exceptions (4xx, 5xx errors).
    
    Logs error with context and returns standardized JSON response.
    """
    request_id = getattr(request.state, "request_id", "unknown")
    user_id = getattr(request.state, "user_id", None)
    
    # Log the error
    log_data = {
        "event": "http_exception",
        "error_type": type(exc).__name__,
        "status": exc.status_code,
        "detail": exc.detail,
        "method": request.method,
        "path": str(request.url.path),
        "request_id": request_id,
    }
    
    if user_id:
        log_data["user_id"] = user_id
    
    if exc.status_code >= 500:
        logger.error(**log_data)
    else:
        logger.warning(**log_data)
    
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": exc.detail,
            "status_code": exc.status_code,
            "request_id": request_id,
        },
        headers={"X-Request-ID": request_id},
    )


async def duplicate_join_code_handler(request: Request, exc: DuplicateJoinCodeError) -> JSONResponse:
    """
    Handler for duplicate join code on session create (409 Conflict).
    """
    request_id = getattr(request.state, "request_id", "unknown")
    user_id = getattr(request.state, "user_id", None)
    detail = "This join code is already in use. Please choose another."

    logger.warning(
        "duplicate_join_code",
        method=request.method,
        path=str(request.url.path),
        request_id=request_id,
        user_id=user_id,
    )

    return JSONResponse(
        status_code=status.HTTP_409_CONFLICT,
        content={
            "error": detail,
            "status_code": status.HTTP_409_CONFLICT,
            "request_id": request_id,
        },
        headers={"X-Request-ID": request_id},
    )


async def validation_exception_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    """
    Handler for request validation errors (422 Unprocessable Entity).
    
    Logs validation errors and returns detailed field-level error information.
    """
    request_id = getattr(request.state, "request_id", "unknown")
    user_id = getattr(request.state, "user_id", None)
    
    # Extract validation errors
    errors = exc.errors()
    
    # Log validation error
    logger.warning(
        "validation_error",
        error_type="RequestValidationError",
        method=request.method,
        path=str(request.url.path),
        errors=errors,
        request_id=request_id,
        user_id=user_id,
    )
    
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "error": "Validation error",
            "status_code": status.HTTP_422_UNPROCESSABLE_ENTITY,
            "detail": errors,
            "request_id": request_id,
        },
        headers={"X-Request-ID": request_id},
    )


async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """
    Handler for unhandled exceptions (500 Internal Server Error).
    
    Logs full stack trace and returns generic error response to avoid leaking internals.
    """
    request_id = getattr(request.state, "request_id", "unknown")
    user_id = getattr(request.state, "user_id", None)
    
    # Log with full stack trace
    logger.error(
        "unhandled_exception",
        error_type=type(exc).__name__,
        error_message=str(exc),
        method=request.method,
        path=str(request.url.path),
        request_id=request_id,
        user_id=user_id,
        exc_info=True,  # Include full traceback
    )
    
    # Return generic error to avoid leaking internals
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "error": "Internal server error",
            "status_code": status.HTTP_500_INTERNAL_SERVER_ERROR,
            "request_id": request_id,
        },
        headers={"X-Request-ID": request_id},
    )


async def rate_limit_exceeded_handler(request: Request, exc: RateLimitExceeded) -> JSONResponse:
    """
    Handler for rate limit violations (429 Too Many Requests).

    Includes a Retry-After header computed from the limit expiry when available,
    so clients can implement back-off without guessing.
    """
    request_id = getattr(request.state, "request_id", "unknown")

    retry_after = ""
    try:
        limit_obj = getattr(getattr(exc, "limit", None), "limit", None)
        if limit_obj and hasattr(limit_obj, "get_expiry"):
            secs = max(0, int(limit_obj.get_expiry() - time.time()))
            retry_after = str(secs)
    except Exception:
        pass

    logger.warning(
        "rate_limit_exceeded",
        method=request.method,
        path=str(request.url.path),
        request_id=request_id,
        user_id=getattr(request.state, "user_id", None),
        retry_after=retry_after or None,
        limit_detail=getattr(exc, "detail", str(exc)),
    )

    headers = {"X-Request-ID": request_id}
    if retry_after:
        headers["Retry-After"] = retry_after

    return JSONResponse(
        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
        content={
            "error": "Too Many Requests",
            "status_code": status.HTTP_429_TOO_MANY_REQUESTS,
            "request_id": request_id,
        },
        headers=headers,
    )


async def postgrest_api_error_handler(request: Request, exc: PostgrestAPIError) -> JSONResponse:
    """
    Handler for PostgREST/Supabase API errors (e.g. RLS violations).

    Converts database permission errors (42501) to 403 Forbidden with a
    user-friendly message instead of exposing a 500 stack trace.
    """
    request_id = getattr(request.state, "request_id", "unknown")
    user_id = getattr(request.state, "user_id", None)

    # PostgREST APIError stores error details; code may be in details dict or as attribute
    details = getattr(exc, "details", None) or getattr(exc, "args", ({}))[0] if exc.args else {}
    if isinstance(details, dict):
        code = details.get("code")
        msg = details.get("message", str(exc))
    else:
        code = getattr(exc, "code", None)
        msg = str(exc)

    if code == "42501":
        logger.warning(
            "rls_violation",
            method=request.method,
            path=str(request.url.path),
            request_id=request_id,
            user_id=user_id,
            message=msg,
        )
        return JSONResponse(
            status_code=status.HTTP_403_FORBIDDEN,
            content={
                "error": "You don't have permission to perform this action. Make sure you've joined the session.",
                "status_code": status.HTTP_403_FORBIDDEN,
                "request_id": request_id,
            },
            headers={"X-Request-ID": request_id},
        )

    # Other PostgREST errors: log and return 500
    logger.error(
        "postgrest_api_error",
        error_type=type(exc).__name__,
        code=code,
        message=msg,
        method=request.method,
        path=str(request.url.path),
        request_id=request_id,
        user_id=user_id,
        exc_info=True,
    )
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "error": "Internal server error",
            "status_code": status.HTTP_500_INTERNAL_SERVER_ERROR,
            "request_id": request_id,
        },
        headers={"X-Request-ID": request_id},
    )


def register_exception_handlers(app) -> None:
    """
    Register all exception handlers with the FastAPI app.
    
    Args:
        app: FastAPI application instance
    """
    app.add_exception_handler(RateLimitExceeded, rate_limit_exceeded_handler)
    app.add_exception_handler(StarletteHTTPException, http_exception_handler)
    app.add_exception_handler(DuplicateJoinCodeError, duplicate_join_code_handler)
    app.add_exception_handler(RequestValidationError, validation_exception_handler)
    app.add_exception_handler(PostgrestAPIError, postgrest_api_error_handler)
    app.add_exception_handler(Exception, unhandled_exception_handler)

