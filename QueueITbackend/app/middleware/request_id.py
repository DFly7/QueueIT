from __future__ import annotations

from typing import Optional
from uuid import uuid4

import structlog
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response
from starlette.types import ASGIApp, Receive, Scope, Send

from app.utils.log_context import clear_log_context, set_request_id


class RequestIDMiddleware(BaseHTTPMiddleware):
    """Ensures every request has a correlation id shared back via X-Request-ID."""

    def __init__(self, app: ASGIApp, *, header_name: str = "X-Request-ID"):
        super().__init__(app)
        self.header_name = header_name
        self.logger = structlog.get_logger("middleware.request_id")

    async def dispatch(self, request: Request, call_next):  # type: ignore[override]
        incoming_id = request.headers.get(self.header_name)
        request_id = incoming_id or str(uuid4())
        set_request_id(request_id)
        request.state.request_id = request_id

        if incoming_id:
            self.logger.debug("request_id.reused", request_id=request_id)
        else:
            self.logger.debug("request_id.generated", request_id=request_id)

        response: Optional[Response] = None
        try:
            response = await call_next(request)
            return response
        finally:
            if response:
                response.headers[self.header_name] = request_id
            clear_log_context()

