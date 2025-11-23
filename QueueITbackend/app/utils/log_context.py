from __future__ import annotations

import inspect
from contextvars import ContextVar
from time import perf_counter
from typing import Any, Awaitable, Callable, Dict, Iterable, Optional, Protocol, TypeVar
from uuid import uuid4

import structlog

from app.core.config import get_settings

RequestCallable = TypeVar("RequestCallable", bound=Callable[..., Any])

request_id_var: ContextVar[Optional[str]] = ContextVar("request_id", default=None)
user_id_var: ContextVar[Optional[str]] = ContextVar("user_id", default=None)

SENSITIVE_KEYWORDS: tuple[str, ...] = (
    "password",
    "passwd",
    "secret",
    "token",
    "key",
    "credential",
    "authorization",
    "client_secret",
    "api_key",
    "refresh",
)

logger = structlog.get_logger("log_context")


def set_request_id(request_id: str) -> None:
    """Bind the given request id to contextvars and structlog."""
    request_id_var.set(request_id)
    structlog.contextvars.bind_contextvars(request_id=request_id)


def get_request_id() -> Optional[str]:
    return request_id_var.get()


def set_user_id(user_id: Optional[str]) -> None:
    """Bind the current user id (if present)."""
    user_id_var.set(user_id)
    structlog.contextvars.bind_contextvars(user_id=user_id)


def get_user_id() -> Optional[str]:
    return user_id_var.get()


def clear_log_context() -> None:
    """Clear request-scoped logging context."""
    request_id_var.set(None)
    user_id_var.set(None)
    structlog.contextvars.clear_contextvars()


def _is_sensitive(key: Optional[str]) -> bool:
    if not key:
        return False
    lowered = key.lower()
    return any(keyword in lowered for keyword in SENSITIVE_KEYWORDS)


def sanitize_params(params: Optional[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    """Mask sensitive values before logging."""
    if params is None:
        return None
    sanitized: Dict[str, Any] = {}
    for key, value in params.items():
        if _is_sensitive(key):
            sanitized[key] = "***"
        elif isinstance(value, dict):
            sanitized[key] = sanitize_params(value)  # type: ignore[arg-type]
        else:
            sanitized[key] = value
    return sanitized


def log_db_operation(
    *,
    operation: str,
    table: Optional[str],
    executor: Callable[[], Any],
    params: Optional[Dict[str, Any]] = None,
    threshold_ms: Optional[float] = None,
) -> Any:
    """Execute a DB call and emit structured timing logs."""
    settings = get_settings()
    slow_threshold = threshold_ms or settings.log_slow_query_ms
    safe_params = sanitize_params(params) if settings.log_enrichment_enabled else None
    start = perf_counter()
    db_logger = structlog.get_logger("db")
    try:
        result = executor()
        duration_ms = (perf_counter() - start) * 1000
        payload = {
            "operation": operation,
            "table": table,
            "duration_ms": round(duration_ms, 3),
            "request_id": get_request_id(),
            "params": safe_params,
        }
        if duration_ms >= slow_threshold:
            db_logger.warning("db.query.slow", **payload, slow=True)
        else:
            db_logger.debug("db.query", **payload)
        return result
    except Exception as exc:  # pragma: no cover - re-raised for callers/tested via caplog
        duration_ms = (perf_counter() - start) * 1000
        db_logger.error(
            "db.query.failed",
            operation=operation,
            table=table,
            duration_ms=round(duration_ms, 3),
            params=safe_params,
            error_type=exc.__class__.__name__,
            exc_info=True,
        )
        raise


def bind_background_task(
    fn: RequestCallable,
    *,
    request_id: Optional[str] = None,
    user_id: Optional[str] = None,
    background_task_id: Optional[str] = None,
) -> RequestCallable:
    """Wrap a sync or async callable so it inherits the current logging context."""

    resolved_request_id = request_id or get_request_id() or str(uuid4())
    resolved_user_id = user_id or get_user_id()
    task_id = background_task_id or str(uuid4())
    bg_logger = structlog.get_logger("background")

    if inspect.iscoroutinefunction(fn):

        async def async_wrapper(*args: Any, **kwargs: Any) -> Any:
            set_request_id(resolved_request_id)
            set_user_id(resolved_user_id)
            structlog.contextvars.bind_contextvars(background_task_id=task_id)
            bg_logger.info(
                "background.task.started",
                task=fn.__name__,
                background_task_id=task_id,
            )
            try:
                return await fn(*args, **kwargs)
            except Exception as exc:  # pragma: no cover - emitted via caplog in tests
                bg_logger.error(
                    "background.task.failed",
                    task=fn.__name__,
                    background_task_id=task_id,
                    error_type=exc.__class__.__name__,
                    exc_info=True,
                )
                raise
            finally:
                bg_logger.info(
                    "background.task.finished",
                    task=fn.__name__,
                    background_task_id=task_id,
                )
                clear_log_context()

        return async_wrapper  # type: ignore[return-value]

    def sync_wrapper(*args: Any, **kwargs: Any) -> Any:
        set_request_id(resolved_request_id)
        set_user_id(resolved_user_id)
        structlog.contextvars.bind_contextvars(background_task_id=task_id)
        bg_logger.info(
            "background.task.started",
            task=fn.__name__,
            background_task_id=task_id,
        )
        try:
            return fn(*args, **kwargs)
        except Exception as exc:  # pragma: no cover - emitted via caplog
            bg_logger.error(
                "background.task.failed",
                task=fn.__name__,
                background_task_id=task_id,
                error_type=exc.__class__.__name__,
                exc_info=True,
            )
            raise
        finally:
            bg_logger.info(
                "background.task.finished",
                task=fn.__name__,
                background_task_id=task_id,
            )
            clear_log_context()

    return sync_wrapper  # type: ignore[return-value]

