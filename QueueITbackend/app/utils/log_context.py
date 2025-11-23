import asyncio
import structlog
from typing import Coroutine, Any

logger = structlog.get_logger("background")

async def _wrapped_background_task(coro: Coroutine[Any, Any, Any], context: dict):
    """
    Internal wrapper that binds context variables before awaiting the coroutine.
    """
    # Clear and bind new context
    structlog.contextvars.clear_contextvars()
    structlog.contextvars.bind_contextvars(**context)
    
    try:
        await coro
    except Exception as e:
        logger.error("background_task_failed", exc_info=e)

def run_in_background(coro: Coroutine[Any, Any, Any], request_id: str | None = None, user_id: str | None = None, **kwargs):
    """
    Schedules a coroutine to run in the background with preserved logging context.
    
    If request_id is not provided, it attempts to capture it from the current context.
    """
    context = {}
    
    # Capture current context defaults if not explicitly provided
    current_context = structlog.contextvars.get_contextvars()
    
    context["request_id"] = request_id or current_context.get("request_id")
    context["user_id"] = user_id or current_context.get("user_id")
    
    # Add any extra kwargs
    context.update(kwargs)
    
    # Filter out None values
    context = {k: v for k, v in context.items() if v is not None}

    asyncio.create_task(_wrapped_background_task(coro, context))

