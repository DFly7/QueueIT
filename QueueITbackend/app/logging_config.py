from __future__ import annotations

import logging
from typing import Any, Dict, Optional

from pythonjsonlogger import jsonlogger
import structlog
from structlog.types import Processor

from app.core.config import get_settings

GLOBAL_FIELDS: Dict[str, Optional[str]] = {}
_CONFIGURED = False


def configure_logging(
    *,
    service_name: Optional[str] = None,
    environment: Optional[str] = None,
    log_level: Optional[str] = None,
    json_logs: Optional[bool] = None,
    force_reconfigure: bool = False,
    testing: bool = False,
) -> None:
    """
    Configure stdlib logging and structlog to emit JSON logs.

    This should be called once during startup. Tests can pass force_reconfigure/testing
    to reset handlers.
    """
    global _CONFIGURED, GLOBAL_FIELDS

    settings = get_settings()
    if _CONFIGURED and not force_reconfigure:
        return

    service_name = service_name or settings.service_name
    environment = environment or settings.environment
    log_level = (log_level or settings.log_level).upper()
    if json_logs is None:
        json_logs = settings.log_json

    GLOBAL_FIELDS = {"service": service_name, "env": environment}

    _configure_std_logging(level=log_level, json_logs=json_logs, force=force_reconfigure)
    _configure_structlog(json_logs=json_logs, testing=testing)

    if settings.sentry_dsn and not testing:
        _configure_sentry(settings.sentry_dsn, environment)

    _CONFIGURED = True


def _configure_std_logging(*, level: str, json_logs: bool, force: bool) -> None:
    formatter: logging.Formatter
    if json_logs:
        formatter = jsonlogger.JsonFormatter(
            "%(asctime)s %(levelname)s %(name)s %(message)s",
            timestamp=True,
        )
    else:
        formatter = logging.Formatter("%(asctime)s | %(levelname)s | %(name)s | %(message)s")

    handler = logging.StreamHandler()
    handler.setFormatter(formatter)

    root_logger = logging.getLogger()
    if force or root_logger.handlers:
        root_logger.handlers = []
    root_logger.addHandler(handler)
    root_logger.setLevel(level)


def _add_global_fields(_: Any, __: str, event_dict: Dict[str, Any]) -> Dict[str, Any]:
    for key, value in GLOBAL_FIELDS.items():
        if value is not None and key not in event_dict:
            event_dict[key] = value
    return event_dict


def _configure_structlog(*, json_logs: bool, testing: bool) -> None:
    renderer = structlog.processors.JSONRenderer(sort_keys=True) if json_logs else structlog.dev.ConsoleRenderer()  # type: ignore[arg-type]

    processors: list[Processor] = [
        structlog.contextvars.merge_contextvars,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.processors.TimeStamper(fmt="iso", key="ts"),
        _add_global_fields,
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
    ]
    processors.append(renderer)

    structlog.configure(
        processors=processors,
        wrapper_class=structlog.stdlib.BoundLogger,
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=not testing,
    )


def _configure_sentry(dsn: str, environment: Optional[str]) -> None:
    try:
        import sentry_sdk
        from sentry_sdk.integrations.logging import LoggingIntegration
    except ImportError:  # pragma: no cover - defensive (package installed in prod)
        return

    sentry_logging = LoggingIntegration(level=logging.ERROR, event_level=logging.ERROR)
    sentry_sdk.init(
        dsn=dsn,
        environment=environment,
        enable_tracing=False,
        integrations=[sentry_logging],
        traces_sample_rate=0.0,
    )


def get_logger(name: Optional[str] = None) -> structlog.stdlib.BoundLogger:
    """Convenience helper to fetch a structlog logger."""
    return structlog.get_logger(name)

