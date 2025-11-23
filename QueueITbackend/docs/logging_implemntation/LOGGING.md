# Structured Logging Guide

**Last Updated:** November 23, 2025  
**Status:** ✅ Implemented

---

## Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Log Format](#log-format)
4. [Configuration](#configuration)
5. [Usage Examples](#usage-examples)
6. [Request Correlation](#request-correlation)
7. [PII Masking](#pii-masking)
8. [Background Tasks](#background-tasks)
9. [Integration with Observability Tools](#integration-with-observability-tools)
10. [Troubleshooting](#troubleshooting)
11. [Best Practices](#best-practices)

---

## Overview

The QueueIT backend uses **structured logging** with JSON output for production and human-readable output for development. All logs include:

- Request ID for correlation
- User ID when authenticated
- Service and environment context
- Timestamp in ISO 8601 format
- Structured fields for easy querying

**Technologies:**
- `structlog` - Structured logging library
- `sentry-sdk` - Error tracking (optional)
- `prometheus-client` - Metrics (optional)

---

## Quick Start

### Installation

Dependencies are already in `requirements.txt`:

```bash
cd QueueITbackend
pip install -r requirements.txt
```

### Run the Server

```bash
# Development (human-readable logs)
LOG_JSON=false LOG_LEVEL=DEBUG uvicorn app.main:app --reload

# Production (JSON logs)
LOG_JSON=true LOG_LEVEL=INFO uvicorn app.main:app
```

### Test Logging

```bash
# Make a request
curl -v http://localhost:8000/healthz

# Check for X-Request-ID header in response
# Check stdout for structured log entry
```

---

## Log Format

### Development (LOG_JSON=false)

Human-readable console output with colors:

```
2025-11-23T12:34:56.789Z [info     ] request_completed method=GET path=/healthz status=200 duration_ms=12.34 request_id=a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

### Production (LOG_JSON=true)

JSON output for log aggregators:

```json
{
  "ts": "2025-11-23T12:34:56.789Z",
  "level": "info",
  "event": "request_completed",
  "message": "request_completed",
  "service": "api",
  "env": "production",
  "request_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "user_id": "42",
  "method": "GET",
  "path": "/api/v1/sessions",
  "status": 200,
  "duration_ms": 34.12
}
```

### Log Levels

- `DEBUG` - Detailed diagnostic information
- `INFO` - General informational messages
- `WARNING` - Warning messages (4xx errors)
- `ERROR` - Error messages (5xx errors, exceptions)
- `CRITICAL` - Critical failures

---

## Configuration

### Environment Variables

Set these in your `.env` file or environment:

```bash
# Log Level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
LOG_LEVEL=INFO

# JSON output (true for production, false for development)
LOG_JSON=true

# Environment name (appears in logs)
ENVIRONMENT=production

# Sentry DSN (optional - for error tracking)
SENTRY_DSN=https://your-dsn@sentry.io/project-id
SENTRY_ENVIRONMENT=production
SENTRY_TRACES_SAMPLE_RATE=0.1

# Prometheus metrics (optional)
ENABLE_METRICS=true
```

### Change Log Level Dynamically

Restart the application with a different `LOG_LEVEL`:

```bash
LOG_LEVEL=DEBUG uvicorn app.main:app --reload
```

---

## Usage Examples

### Basic Logging in Route Handlers

```python
from app.logging_config import get_logger

logger = get_logger(__name__)

@app.get("/api/v1/sessions")
async def get_sessions(request: Request):
    logger.info(
        "fetching_sessions",
        user_id=request.state.user_id,
    )
    
    sessions = await session_service.get_all()
    
    logger.info(
        "sessions_fetched",
        count=len(sessions),
    )
    
    return sessions
```

### Logging with Additional Context

```python
logger.info(
    "session_created",
    session_id=session.id,
    host_id=session.host_id,
    join_code=session.join_code,
    is_public=session.is_public,
)
```

### Error Logging with Stack Trace

```python
try:
    result = await risky_operation()
except Exception as exc:
    logger.error(
        "operation_failed",
        operation="risky_operation",
        error_type=type(exc).__name__,
        error_message=str(exc),
        exc_info=True,  # Includes full stack trace
    )
    raise
```

### Logging Database Operations

```python
from app.logging_config import get_logger

logger = get_logger(__name__)

async def create_session(session_data: dict) -> Session:
    logger.debug("inserting_session", data=session_data)
    
    result = await supabase.table("sessions").insert(session_data).execute()
    
    logger.info("session_inserted", session_id=result.data[0]["id"])
    
    return Session(**result.data[0])
```

---

## Request Correlation

Every HTTP request gets a unique **Request ID** that appears in:
1. All logs generated during that request
2. The `X-Request-ID` response header
3. Error responses

### How It Works

The `RequestIDMiddleware` automatically:
1. Extracts `X-Request-ID` from incoming headers (if present)
2. Generates a UUID4 if not present
3. Stores it in `request.state.request_id`
4. Binds it to structlog context (appears in all logs)
5. Returns it in the `X-Request-ID` response header

### Client Usage

Clients can:
- Generate their own request ID and send it in the `X-Request-ID` header
- Use the returned `X-Request-ID` to correlate requests with logs

```bash
# Send custom request ID
curl -H "X-Request-ID: my-custom-id-123" http://localhost:8000/healthz

# Server returns same ID
# X-Request-ID: my-custom-id-123
```

### Searching Logs by Request ID

In your log aggregator (e.g., Loki, ELK):

```
# Find all logs for a specific request
request_id="a1b2c3d4-e5f6-7890-abcd-ef1234567890"

# Find failed requests
level="error" AND request_id!=""
```

---

## PII Masking

The logging system automatically masks sensitive data to protect user privacy.

### Automatic Masking

These field names are **automatically masked** in log output:
- `password`
- `token`
- `secret`
- `api_key`
- `authorization`
- `credentials`
- `credit_card`
- `ssn`

### Manual Masking

Use `safe_log_dict()` to mask sensitive fields before logging:

```python
from app.utils.log_context import safe_log_dict

user_data = {
    "username": "john",
    "password": "secret123",  # Will be masked
    "email": "john@example.com"
}

logger.info("user_created", **safe_log_dict(user_data))

# Log output:
# {"event": "user_created", "username": "john", "password": "***MASKED***", "email": "john@example.com"}
```

### Mask PII in Free-Form Text

```python
from app.utils.log_context import mask_pii_in_text

text = "Contact me at john@example.com or call 555-123-4567"
safe_text = mask_pii_in_text(text)

logger.info("message_received", text=safe_text)

# Masks:
# - Email addresses (shows domain)
# - Phone numbers (shows last 4 digits)
# - SSN (completely masked)
# - Credit card numbers (shows last 4 digits)
```

### Custom Sensitive Keys

```python
from app.utils.log_context import safe_log_dict

data = {"username": "john", "internal_id": "secret"}

safe_data = safe_log_dict(data, sensitive_keys={"internal_id"})

logger.info("data_processed", **safe_data)
```

---

## Background Tasks

Background tasks lose request context by default. Use `BackgroundTaskLogger` or `run_in_background()` to preserve it.

### Using BackgroundTaskLogger

```python
from app.utils.log_context import BackgroundTaskLogger

async def send_notification(user_id: str, message: str):
    async with BackgroundTaskLogger(
        task_name="send_notification",
        request_id=request.state.request_id,  # From original request
        user_id=user_id,
        notification_type="email"
    ) as logger:
        logger.info("notification_sending")
        
        await email_service.send(user_id, message)
        
        logger.info("notification_sent")
```

### Using run_in_background()

```python
from fastapi import BackgroundTasks
from app.utils.log_context import run_in_background

@app.post("/api/v1/sessions/{id}/notify")
async def notify_members(session_id: str, request: Request):
    # Start background task with request context
    task = await run_in_background(
        send_notifications(session_id),
        task_name="notify_session_members",
        request_id=request.state.request_id,
        session_id=session_id,
    )
    
    return {"status": "notifications_scheduled"}
```

### Temporary Context Binding

```python
from app.utils.log_context import log_context

with log_context(operation="batch_import", batch_id=123):
    logger.info("batch_started")  # Includes operation and batch_id
    
    for item in items:
        process(item)
    
    logger.info("batch_completed")  # Includes operation and batch_id
```

---

## Integration with Observability Tools

### Sentry (Error Tracking)

#### Setup

1. Create a Sentry project at [sentry.io](https://sentry.io)
2. Copy your DSN
3. Add to `.env`:

```bash
SENTRY_DSN=https://your-dsn@sentry.io/project-id
SENTRY_ENVIRONMENT=production
SENTRY_TRACES_SAMPLE_RATE=0.1
```

4. Restart the application

#### Verification

Trigger an error:

```bash
curl http://localhost:8000/nonexistent
```

Check Sentry dashboard for the error with:
- Request ID
- User ID (if authenticated)
- Stack trace
- Request context

### Prometheus (Metrics)

#### Enable Metrics

Set in `.env`:

```bash
ENABLE_METRICS=true
```

#### Access Metrics Endpoint

```bash
curl http://localhost:8000/metrics
```

Output (Prometheus format):

```
# HELP python_info Python platform information
# TYPE python_info gauge
python_info{implementation="CPython",major="3",minor="12"} 1.0
...
```

#### Integrate with Prometheus

Add to `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'queueit-api'
    static_configs:
      - targets: ['localhost:8000']
    metrics_path: '/metrics'
```

### Loki / Promtail (Log Aggregation)

#### Example Promtail Config

```yaml
server:
  http_listen_port: 9080

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: queueit-api
    static_configs:
      - targets:
          - localhost
        labels:
          job: queueit-api
          __path__: /var/log/queueit/*.log
    pipeline_stages:
      - json:
          expressions:
            level: level
            request_id: request_id
            user_id: user_id
            service: service
            env: env
      - labels:
          level:
          service:
          env:
```

### ELK Stack (Elasticsearch, Logstash, Kibana)

#### Example Logstash Config

```ruby
input {
  file {
    path => "/var/log/queueit/*.log"
    codec => "json"
  }
}

filter {
  json {
    source => "message"
  }
  
  date {
    match => ["ts", "ISO8601"]
  }
}

output {
  elasticsearch {
    hosts => ["localhost:9200"]
    index => "queueit-api-%{+YYYY.MM.dd}"
  }
}
```

### Datadog

#### Setup Datadog Agent

1. Install Datadog agent
2. Configure log collection in `/etc/datadog-agent/conf.d/queueit.d/conf.yaml`:

```yaml
logs:
  - type: file
    path: /var/log/queueit/*.log
    service: queueit-api
    source: python
    sourcecategory: sourcecode
```

---

## Troubleshooting

### Problem: Logs Not Appearing

**Solution:**
- Check `LOG_LEVEL` is not too restrictive (use `DEBUG` for testing)
- Ensure application is writing to stdout (not files)
- Check that structlog is initialized: `setup_logging()` called in `main.py`

### Problem: Request ID Not in Logs

**Solution:**
- Ensure `RequestIDMiddleware` is registered in `main.py`
- Check middleware order - `RequestIDMiddleware` should be added before route handlers
- Verify `request.state.request_id` is set

### Problem: Sensitive Data Appearing in Logs

**Solution:**
- Use `safe_log_dict()` before logging user data
- Add field names to `SENSITIVE_FIELDS` in `logging_config.py`
- Use `mask_pii_in_text()` for free-form text

### Problem: Logs Not JSON Formatted

**Solution:**
- Set `LOG_JSON=true` in environment
- Restart application
- Verify with: `curl http://localhost:8000/healthz 2>&1 | grep request_id`

### Problem: Too Many Logs in Production

**Solution:**
- Set `LOG_LEVEL=INFO` (not `DEBUG`)
- Silence noisy loggers in `logging_config.py`:

```python
logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)
```

### Problem: Verbose HTTP/2 Debug Output (httpx, h2, hpack)

**Symptoms:**
```
Encoding 71 with 7 bits
Adding (b'accept-encoding', b'gzip, deflate') to the header table...
Decoded 8, consumed 1 bytes
```

**Solution:**
These verbose logs are from httpx/h2/hpack debug logging. They're automatically silenced in `logging_config.py`:

```python
logging.getLogger("httpx").setLevel(logging.WARNING)
logging.getLogger("httpcore").setLevel(logging.WARNING)
logging.getLogger("h2").setLevel(logging.WARNING)
logging.getLogger("hpack").setLevel(logging.WARNING)
```

If you're still seeing them, ensure:
1. `setup_logging()` is called in `main.py` before any HTTP requests
2. You're not running with `PYTHONVERBOSE=1` or similar environment variables
3. Restart the application after changes

---

## Best Practices

### DO ✅

1. **Use structured logging with key-value pairs:**
   ```python
   logger.info("user_logged_in", user_id=user.id, method="email")
   ```

2. **Log at appropriate levels:**
   - `INFO` - Normal business events (user logged in, session created)
   - `WARNING` - Unexpected but handled (4xx errors, retries)
   - `ERROR` - Failures requiring attention (5xx errors, exceptions)

3. **Include context:**
   ```python
   logger.info("payment_processed", user_id=user.id, amount=100, currency="USD")
   ```

4. **Mask sensitive data:**
   ```python
   logger.info("user_data", **safe_log_dict(user_dict))
   ```

5. **Use request IDs for correlation:**
   ```python
   # Automatically included via middleware
   logger.info("processing_request")
   ```

6. **Log business events, not technical noise:**
   ```python
   # Good
   logger.info("session_created", session_id=session.id)
   
   # Bad
   logger.debug("Entering function create_session")
   ```

### DON'T ❌

1. **Don't log raw passwords or tokens:**
   ```python
   # BAD
   logger.info("user_data", password=user.password)
   
   # GOOD
   logger.info("user_data", **safe_log_dict(user_dict))
   ```

2. **Don't use string interpolation:**
   ```python
   # BAD
   logger.info(f"User {user_id} logged in")
   
   # GOOD
   logger.info("user_logged_in", user_id=user_id)
   ```

3. **Don't log large objects:**
   ```python
   # BAD
   logger.info("response", data=huge_response_object)
   
   # GOOD
   logger.info("response_sent", status=200, size_bytes=len(response))
   ```

4. **Don't log PII without masking:**
   ```python
   # BAD
   logger.info("email_sent", email=user.email, ssn=user.ssn)
   
   # GOOD
   logger.info("email_sent", user_id=user.id)
   ```

5. **Don't use print() statements:**
   ```python
   # BAD
   print("Debug info:", data)
   
   # GOOD
   logger.debug("debug_info", data=data)
   ```

---

## Example Log Queries

### Find All Errors for a User

```
level="error" AND user_id="42"
```

### Find Slow Requests (>1 second)

```
event="request_completed" AND duration_ms>1000
```

### Find Failed Session Creations

```
event="session_created" AND level="error"
```

### Trace a Specific Request

```
request_id="a1b2c3d4-e5f6-7890-abcd-ef1234567890"
```

### Find Authentication Errors

```
path="/api/v1/auth/login" AND status>=400
```

---

## Manual Verification Checklist

Before deploying to production, verify:

- [ ] Run local server: `uvicorn app.main:app --reload`
- [ ] Make request: `curl -v http://localhost:8000/healthz`
- [ ] **Response has `X-Request-ID` header**
- [ ] **Stdout logs are JSON format** (if `LOG_JSON=true`)
- [ ] **Logs contain `request_id`, `method`, `path`, `status`, `duration_ms`**
- [ ] Trigger error: `curl http://localhost:8000/nonexistent`
- [ ] **Error log includes `exc_info` (stack trace)**
- [ ] **Error response includes `request_id`**
- [ ] Run tests: `pytest -v`
- [ ] **All tests pass**

---

## Support

For questions or issues:
1. Check this documentation
2. Review example code in `tests/`
3. Check Sentry for production errors (if enabled)
4. Review logs in your log aggregator

**Documentation:** `docs/LOGGING.md`  
**Tests:** `tests/test_logging_*.py`  
**Configuration:** `app/logging_config.py`

---

**Last Updated:** November 23, 2025  
**Version:** 1.0.0

