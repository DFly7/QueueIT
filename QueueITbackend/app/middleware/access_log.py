from __future__ import annotations

import time
from typing import Optional

import structlog
from fastapi import HTTPException
from prometheus_client import Counter, Histogram
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response
from starlette.types import ASGIApp

from app.core.config import get_settings
from app.utils.log_context import get_request_id

settings = get_settings()

REQUEST_COUNTER = Counter(
    "queueit_requests_total",
    "Total HTTP requests processed",
    ["method", "route", "status"],
)
REQUEST_LATENCY = Histogram(
    "queueit_request_duration_ms",
    "HTTP request latency in milliseconds",
    ["method", "route"],
    buckets=(5, 25, 50, 100, 250, 500, 1000, 2500, 5000),
)


class AccessLogMiddleware(BaseHTTPMiddleware):
    """Emit structured access logs and basic Prometheus metrics."""

    def __init__(self, app: ASGIApp, *, metrics_enabled: bool = True):
        super().__init__(app)
        self.metrics_enabled = metrics_enabled and settings.enable_metrics
        self.logger = structlog.get_logger("middleware.access")

    async def dispatch(self, request: Request, call_next):  # type: ignore[override]
        start = time.perf_counter()
        method = request.method
        route = self._resolve_route_pattern(request)
        client_ip = request.client.host if request.client else None
        request_id = getattr(request.state, "request_id", None) or get_request_id()
        user_id = getattr(request.state, "user_id", None)

        try:
            response = await call_next(request)
            duration_ms = (time.perf_counter() - start) * 1000
            log_ctx = {
                "method": method,
                "route": route,
                "path": request.url.path,
                "status": response.status_code,
                "duration_ms": round(duration_ms, 3),
                "request_id": request_id,
                "user_id": user_id,
                "client_ip": client_ip,
                "content_length": response.headers.get("content-length"),
            }
            if not settings.log_enrichment_enabled:
                log_ctx.pop("client_ip", None)
            self.logger.info("request.completed", **log_ctx)
            self._record_metrics(method, route, response.status_code, duration_ms)
            response.headers.setdefault(settings.request_id_header, request_id or "")
            return response
        except HTTPException as exc:
            duration_ms = (time.perf_counter() - start) * 1000
            self.logger.warning(
                "request.failed",
                method=method,
                route=route,
                path=request.url.path,
                status=exc.status_code,
                duration_ms=round(duration_ms, 3),
                request_id=request_id,
                user_id=user_id,
                error_type=exc.__class__.__name__,
                detail=exc.detail,
            )
            self._record_metrics(method, route, exc.status_code, duration_ms)
            raise
        except Exception as exc:
            duration_ms = (time.perf_counter() - start) * 1000
            self.logger.error(
                "request.failed",
                method=method,
                route=route,
                path=request.url.path,
                status=500,
                duration_ms=round(duration_ms, 3),
                request_id=request_id,
                user_id=user_id,
                error_type=exc.__class__.__name__,
                exc_info=True,
            )
            self._record_metrics(method, route, 500, duration_ms)
            raise

    def _resolve_route_pattern(self, request: Request) -> str:
        route = request.scope.get("route")
        if route and getattr(route, "path", None):
            return route.path  # type: ignore[return-value]
        return request.url.path

    def _record_metrics(self, method: str, route: str, status: int, duration_ms: float) -> None:
        if not self.metrics_enabled:
            return
        REQUEST_COUNTER.labels(method=method, route=route, status=str(status)).inc()
        REQUEST_LATENCY.labels(method=method, route=route).observe(duration_ms)

