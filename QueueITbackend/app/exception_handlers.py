"""
Centralized exception handlers with structured logging.

Provides consistent error responses and comprehensive error logging with:
- Full stack traces
- Request context (request_id, user_id, path, method)
- Structured error details
- Appropriate HTTP status codes
"""

from typing import Union

import structlog
from fastapi import Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

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


def register_exception_handlers(app) -> None:
    """
    Register all exception handlers with the FastAPI app.
    
    Args:
        app: FastAPI application instance
    """
    app.add_exception_handler(StarletteHTTPException, http_exception_handler)
    app.add_exception_handler(RequestValidationError, validation_exception_handler)
    app.add_exception_handler(Exception, unhandled_exception_handler)

