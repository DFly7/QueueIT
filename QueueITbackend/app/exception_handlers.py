from __future__ import annotations

import structlog
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse

from app.core.config import get_settings
from app.utils.log_context import get_request_id

settings = get_settings()
logger = structlog.get_logger("exceptions")


def install_exception_handlers(app: FastAPI) -> None:
    """Register JSON exception handlers that include correlation ids."""

    @app.exception_handler(HTTPException)
    async def http_exception_handler(request: Request, exc: HTTPException):
        request_id = getattr(request.state, "request_id", None) or get_request_id()
        user_id = getattr(request.state, "user_id", None)
        logger.warning(
            "http_exception",
            request_id=request_id,
            user_id=user_id,
            method=request.method,
            path=request.url.path,
            status=exc.status_code,
            detail=exc.detail,
            error_type=exc.__class__.__name__,
        )
        response = JSONResponse(status_code=exc.status_code, content={"detail": exc.detail})
        response.headers.setdefault(settings.request_id_header, request_id or "")
        return response

    @app.exception_handler(Exception)
    async def unhandled_exception_handler(request: Request, exc: Exception):
        request_id = getattr(request.state, "request_id", None) or get_request_id()
        user_id = getattr(request.state, "user_id", None)
        logger.error(
            "unhandled_exception",
            request_id=request_id,
            user_id=user_id,
            method=request.method,
            path=request.url.path,
            error_type=exc.__class__.__name__,
            exc_info=True,
        )
        response = JSONResponse(status_code=500, content={"detail": "Internal server error"})
        response.headers.setdefault(settings.request_id_header, request_id or "")
        return response

