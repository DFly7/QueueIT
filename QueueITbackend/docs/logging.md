# Logging & Observability

QueueIT uses a structured logging approach powered by `structlog` to ensure all application logs are machine-readable, context-rich, and easily searchable.

## Overview

- **Format**: JSON in Production, Colored Text in Development.
- **Correlation**: `X-Request-ID` is generated for every request and propagated to all logs, including database queries and background tasks.
- **Context**: Logs automatically include `method`, `path`, `status`, `duration_ms`, `user_id` (if auth), and `request_id`.
- **Output**: `stdout` (12-factor app compliant).

## Configuration

Logging is configured via environment variables in `.env` (or deployment config).

| Variable | Default | Description |
|----------|---------|-------------|
| `LOG_LEVEL` | `INFO` | Level threshold (`DEBUG`, `INFO`, `WARNING`, `ERROR`). |
| `LOG_JSON` | `false` | Set to `true` in production to output JSON. |

## Request ID

Every request has a unique ID (UUIDv4).
- **Incoming**: If `X-Request-ID` header is present, it is used.
- **Generated**: If missing, a new UUID is generated.
- **Response**: The ID is returned in the `X-Request-ID` header.

## Logging in Code

Use `structlog` directly.

```python
import structlog

logger = structlog.get_logger("my_module")

def my_function():
    # Context (request_id, user_id) is automatically attached if running in a request
    logger.info("something_happened", count=42, item_id="abc")
```

### Exception Handling

Exceptions should be allowed to propagate to the global exception handler, or logged with `exc_info=True`.

```python
try:
    do_something()
except ValueError as e:
    # This will log the stack trace and structural context
    logger.error("operation_failed", exc_info=e)
```

### Background Tasks

When spawning background tasks, use the `run_in_background` helper to ensure the current request context (Request ID, User ID) is propagated to the background task logs.

```python
from app.utils.log_context import run_in_background

async def background_job():
    logger.info("job_running") # Will have request_id from the spawner

@app.post("/trigger")
async def trigger_job(request: Request):
    run_in_background(background_job())
```

## Verification

To verify logging locally:

1. **Start the app**: `uvicorn app.main:app --reload`
2. **Make a request**: `curl -v http://localhost:8000/healthz`
3. **Check Output**:
   ```text
   2025-11-23 12:00:00 [info     ] request_completed              duration_ms=2.5 method=GET path=/healthz request_id=... status=200
   ```
4. **Enable JSON**: `export LOG_JSON=true` and restart. Output should be JSON.

## Integration

- **Supabase**: `X-Request-ID` is sent as a header to Supabase for tracing on their end.
- **Sentry**: (Optional) Can be integrated in `exception_handlers.py`.

