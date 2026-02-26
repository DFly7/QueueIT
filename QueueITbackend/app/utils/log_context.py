"""
Logging context utilities for PII masking and background task logging.

Provides:
- PII masking utilities
- Context managers for structured logging
- Background task logging with request ID propagation
- Helper functions for safe logging of user data
"""

import asyncio
import re
import uuid
from contextlib import contextmanager
from typing import Any, Callable, Coroutine, Dict, Optional, TypeVar

import structlog

logger = structlog.get_logger(__name__)

T = TypeVar("T")

# Regex patterns for common PII
EMAIL_PATTERN = re.compile(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b')
PHONE_PATTERN = re.compile(r'\b\d{3}[-.]?\d{3}[-.]?\d{4}\b')
SSN_PATTERN = re.compile(r'\b\d{3}-\d{2}-\d{4}\b')
CREDIT_CARD_PATTERN = re.compile(r'\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b')


def mask_sensitive_value(value: Any, mask_char: str = "*", visible_chars: int = 4) -> Any:
    """
    Mask sensitive values for safe logging.
    
    Args:
        value: Value to mask (string, dict, list, or other)
        mask_char: Character to use for masking
        visible_chars: Number of trailing characters to leave visible
        
    Returns:
        Masked value (same type as input)
        
    Example:
        >>> mask_sensitive_value("secret_password_123")
        '***********_123'
        >>> mask_sensitive_value({"password": "secret", "username": "john"})
        {'password': '***MASKED***', 'username': 'john'}
    """
    if isinstance(value, str):
        if len(value) <= visible_chars:
            return mask_char * len(value)
        masked_length = len(value) - visible_chars
        return (mask_char * masked_length) + value[-visible_chars:]
    
    elif isinstance(value, dict):
        return {k: mask_sensitive_value(v, mask_char, visible_chars) for k, v in value.items()}
    
    elif isinstance(value, (list, tuple)):
        return type(value)(mask_sensitive_value(item, mask_char, visible_chars) for item in value)
    
    return value


def mask_pii_in_text(text: str) -> str:
    """
    Mask PII patterns in free-form text.
    
    Args:
        text: Text that may contain PII
        
    Returns:
        Text with PII patterns masked
        
    Example:
        >>> mask_pii_in_text("Email me at john@example.com or call 555-123-4567")
        'Email me at ***@***.com or call ***-***-4567'
    """
    # Mask emails (show domain)
    text = EMAIL_PATTERN.sub(lambda m: f"***@{m.group().split('@')[1]}", text)
    
    # Mask phone numbers (show last 4 digits)
    text = PHONE_PATTERN.sub(lambda m: f"***-***-{m.group()[-4:]}", text)
    
    # Mask SSN completely
    text = SSN_PATTERN.sub("***-**-****", text)
    
    # Mask credit card (show last 4 digits)
    text = CREDIT_CARD_PATTERN.sub(lambda m: f"****-****-****-{m.group()[-4:]}", text)
    
    return text


@contextmanager
def log_context(**kwargs: Any):
    """
    Context manager to temporarily add context to logs.
    
    Args:
        **kwargs: Key-value pairs to add to log context
        
    Example:
        with log_context(operation="data_import", batch_id=123):
            logger.info("starting_import")  # Will include operation and batch_id
            process_data()
            logger.info("import_complete")   # Will include operation and batch_id
    """
    # Bind context vars
    structlog.contextvars.bind_contextvars(**kwargs)
    
    try:
        yield
    finally:
        # Unbind context vars
        structlog.contextvars.unbind_contextvars(*kwargs.keys())


class BackgroundTaskLogger:
    """
    Context manager for background task logging with request correlation.
    
    Ensures background tasks include proper context in logs even when
    the original request has completed.
    
    Example:
        async with BackgroundTaskLogger(
            task_name="send_email",
            request_id=request.state.request_id,
            user_id=user.id
        ) as task_logger:
            task_logger.info("email_sending_started")
            await send_email(user)
            task_logger.info("email_sent_successfully")
    """
    
    def __init__(
        self,
        task_name: str,
        request_id: Optional[str] = None,
        user_id: Optional[str] = None,
        **extra_context: Any,
    ):
        """
        Initialize background task logger.
        
        Args:
            task_name: Name of the background task
            request_id: Request ID to correlate with (if available)
            user_id: User ID associated with task (if available)
            **extra_context: Additional context to include in logs
        """
        self.task_name = task_name
        self.request_id = request_id or str(uuid.uuid4())
        self.user_id = user_id
        self.extra_context = extra_context
        self.logger = structlog.get_logger(task_name)
        self._token = None
    
    async def __aenter__(self):
        """Enter async context - bind context vars."""
        context = {
            "task_name": self.task_name,
            "request_id": self.request_id,
            **self.extra_context,
        }
        
        if self.user_id:
            context["user_id"] = self.user_id
        
        structlog.contextvars.bind_contextvars(**context)
        
        self.logger.info("background_task_started")
        return self.logger
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Exit async context - log completion or error."""
        if exc_type is not None:
            self.logger.error(
                "background_task_failed",
                error_type=exc_type.__name__,
                error_message=str(exc_val),
                exc_info=True,
            )
        else:
            self.logger.info("background_task_completed")
        
        # Clear context vars
        structlog.contextvars.clear_contextvars()
        
        # Don't suppress exceptions
        return False


async def run_in_background(
    coro: Coroutine[Any, Any, T],
    task_name: str,
    request_id: Optional[str] = None,
    user_id: Optional[str] = None,
    **extra_context: Any,
) -> asyncio.Task[T]:
    """
    Run a coroutine as a background task with proper logging context.
    
    Args:
        coro: Coroutine to run in background
        task_name: Name for the background task
        request_id: Request ID to correlate with (if available)
        user_id: User ID associated with task (if available)
        **extra_context: Additional context to include in logs
        
    Returns:
        asyncio.Task object
        
    Example:
        # In a route handler
        task = await run_in_background(
            send_notification(user_id, message),
            task_name="send_notification",
            request_id=request.state.request_id,
            user_id=user_id,
            notification_type="email"
        )
    """
    async def _wrapped_coro():
        async with BackgroundTaskLogger(
            task_name=task_name,
            request_id=request_id,
            user_id=user_id,
            **extra_context,
        ):
            return await coro
    
    return asyncio.create_task(_wrapped_coro())


def safe_log_dict(data: Dict[str, Any], sensitive_keys: Optional[set] = None) -> Dict[str, Any]:
    """
    Create a safe-to-log version of a dictionary by masking sensitive keys.
    
    Args:
        data: Dictionary to sanitize
        sensitive_keys: Additional keys to mask (beyond defaults)
        
    Returns:
        Sanitized dictionary safe for logging
        
    Example:
        user_data = {"username": "john", "password": "secret123", "email": "john@example.com"}
        safe_data = safe_log_dict(user_data)
        logger.info("user_created", **safe_data)
    """
    from app.logging_config import SENSITIVE_FIELDS
    
    sensitive = SENSITIVE_FIELDS.copy()
    if sensitive_keys:
        sensitive.update(sensitive_keys)
    
    safe_dict = {}
    for key, value in data.items():
        if any(sensitive_field in key.lower() for sensitive_field in sensitive):
            safe_dict[key] = "***MASKED***"
        elif isinstance(value, dict):
            safe_dict[key] = safe_log_dict(value, sensitive_keys)
        else:
            safe_dict[key] = value
    
    return safe_dict

