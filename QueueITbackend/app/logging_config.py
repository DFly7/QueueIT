"""
Structured logging configuration using structlog.

This module sets up production-grade JSON logging with:
- Structured JSON output for log aggregators (Loki, ELK, Datadog)
- Request ID correlation
- Context-rich logs with service/env metadata
- PII masking capabilities
- Development-friendly console output when LOG_JSON=false
"""

import logging
import sys
from typing import Any

import structlog
from structlog.types import EventDict, Processor

from app.core.config import get_settings

settings = get_settings()


# Sensitive field names to mask in logs
SENSITIVE_FIELDS = {
    "password",
    "token",
    "secret",
    "api_key",
    "apikey",
    "authorization",
    "auth",
    "credentials",
    "credit_card",
    "ssn",
}


def mask_sensitive_data(logger: Any, method_name: str, event_dict: EventDict) -> EventDict:
    """
    Processor to mask sensitive data in log records.
    
    Recursively searches for sensitive field names and replaces values with '***MASKED***'.
    """
    def _mask_dict(d: dict) -> dict:
        masked = {}
        for key, value in d.items():
            if isinstance(key, str) and any(sensitive in key.lower() for sensitive in SENSITIVE_FIELDS):
                masked[key] = "***MASKED***"
            elif isinstance(value, dict):
                masked[key] = _mask_dict(value)
            elif isinstance(value, (list, tuple)):
                masked[key] = [_mask_dict(item) if isinstance(item, dict) else item for item in value]
            else:
                masked[key] = value
        return masked
    
    return _mask_dict(event_dict)


def add_service_context(logger: Any, method_name: str, event_dict: EventDict) -> EventDict:
    """
    Processor to add service-level context to all logs.
    """
    event_dict.setdefault("service", settings.app_name)
    event_dict.setdefault("env", settings.environment)
    return event_dict


def rename_event_key(logger: Any, method_name: str, event_dict: EventDict) -> EventDict:
    """
    Rename 'event' key to 'message' for better compatibility with some log systems.
    Keep 'event' for structured logging but add 'message' alias.
    """
    if "event" in event_dict:
        event_dict["message"] = event_dict["event"]
    return event_dict


def setup_logging() -> None:
    """
    Configure structured logging for the application.
    
    Sets up structlog with appropriate processors for development or production.
    In development (LOG_JSON=false): human-readable console output with colors
    In production (LOG_JSON=true): JSON output to stdout for log aggregators
    """
    
    # Configure standard library logging
    logging.basicConfig(
        format="%(message)s",
        stream=sys.stdout,
        level=getattr(logging, settings.log_level.upper()),
    )
    
    # Silence noisy loggers
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("uvicorn.error").setLevel(logging.WARNING)
    
    # Silence HTTP client debug output (httpx, h2, hpack)
    logging.getLogger("httpx").setLevel(logging.WARNING)
    logging.getLogger("httpcore").setLevel(logging.WARNING)
    logging.getLogger("h2").setLevel(logging.WARNING)
    logging.getLogger("hpack").setLevel(logging.WARNING)
    
    # Silence other noisy third-party libraries
    logging.getLogger("urllib3").setLevel(logging.WARNING)
    logging.getLogger("requests").setLevel(logging.WARNING)
    
    # Common processors for all environments
    shared_processors: list[Processor] = [
        structlog.contextvars.merge_contextvars,  # Merge context vars (request_id, user_id)
        structlog.stdlib.add_log_level,
        structlog.stdlib.add_logger_name,
        structlog.processors.TimeStamper(fmt="iso", utc=True, key="ts"),
        add_service_context,
        mask_sensitive_data,
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,  # Format exceptions
        rename_event_key,
    ]
    
    if settings.log_json:
        # Production: JSON output
        processors = shared_processors + [
            structlog.processors.JSONRenderer()
        ]
    else:
        # Development: Human-readable console output
        processors = shared_processors + [
            structlog.dev.ConsoleRenderer(colors=True)
        ]
    
    # Configure structlog
    structlog.configure(
        processors=processors,
        wrapper_class=structlog.stdlib.BoundLogger,
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )


def get_logger(name: str | None = None) -> structlog.stdlib.BoundLogger:
    """
    Get a structured logger instance.
    
    Args:
        name: Logger name (typically __name__ of the calling module)
        
    Returns:
        Configured structlog logger
        
    Example:
        logger = get_logger(__name__)
        logger.info("user_logged_in", user_id=user.id, method="email")
    """
    return structlog.get_logger(name)


# Convenience logger for quick imports
logger = get_logger(__name__)

