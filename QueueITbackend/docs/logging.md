# Logging & Observability Guide

This backend now emits **structured JSON logs** with automatic request correlation, slow-query detection, background task tracing, and optional integrations for Prometheus and Sentry.

---

## Quick Start

```bash
pip install -r requirements.txt
uvicorn app.main:app --reload

# In another terminal
curl -v http://localhost:8000/healthz
```

Standard logs are emitted to **stdout** to play nicely with container schedulers and log forwarders. The response includes `X-Request-ID`, which is attached to every log from that request.

Sample access log:

```json
{
  "ts": "2025-11-23T17:21:13.102Z",
  "event": "request.completed",
  "service": "queueit-backend",
  "env": "development",
  "method": "GET",
  "route": "/healthz",
  "status": 200,
  "duration_ms": 8.13,
  "request_id": "f61fde1a-7d82-4b45-8fab-93acdb0c9e07"
}
```

---

## Request Correlation

* `RequestIDMiddleware` generates or propagates `X-Request-ID`.
* Middleware stores the id on `request.state.request_id` and in `structlog` context.
* Exception handlers ensure the header is always returned (even on failures).

### Manual Access
```python
from app.utils.log_context import get_request_id
request_id = get_request_id()
```

---

## Access Logging & Metrics

* `AccessLogMiddleware` captures method, route template, status, duration, user id (if authenticated), and client IP (can be disabled via `LOG_ENRICHMENT=false`).
* Prometheus metrics are emitted when `ENABLE_PROMETHEUS=true` and are exposed at `/metrics`.
  * `queueit_requests_total{method,route,status}`
  * `queueit_request_duration_ms_bucket`

---

## Exception Logging

* `app/exception_handlers.py` centralizes exception handling.
* All HTTP errors log at `WARNING`; unhandled exceptions include stack traces, `request_id`, `user_id`, and path.
* Responses stay unchanged apart from the extra `X-Request-ID` header.

---

## Database & External Calls

* Repository methods are wrapped with `log_db_operation` which records duration, masked parameters, and flags queries exceeding `LOG_SLOW_QUERY_MS` (default 250ms).
* Spotify service logs token refresh and search calls, with latency and HTTP status. Errors include full context without leaking credentials.

---

## Background Tasks

Use `bind_background_task` to preserve correlation ids:

```python
from fastapi import BackgroundTasks
from app.utils.log_context import bind_background_task

def send_webhook(session_id: str):
    logger = structlog.get_logger("webhook")
    logger.info("webhook.notify", session_id=session_id)

background_tasks.add_task(bind_background_task(send_webhook), session.id)
```

The helper binds `request_id`, `user_id`, and emits `background.task.started/finished` logs automatically.

---

## Configuration Reference

| Env Var | Default | Description |
| --- | --- | --- |
| `LOG_LEVEL` | `INFO` | Global log level |
| `LOG_JSON` | `true` | Emit JSON logs (set `false` for dev console output) |
| `REQUEST_ID_HEADER` | `X-Request-ID` | Header name to read/write |
| `LOG_SLOW_QUERY_MS` | `250` | Threshold for slow-query warnings |
| `LOG_ENRICHMENT` | `true` | Include optional fields (client_ip, params) |
| `ENABLE_PROMETHEUS` | `true` | Expose `/metrics` and record counters/histograms |
| `SERVICE_NAME` | `queueit-backend` | Added to every log event |
| `SENTRY_DSN` | _unset_ | When present, enables Sentry logging integration |

---

## Integrations

### Sentry
Set `SENTRY_DSN` to enable automatic initialization. Errors logged at `ERROR` level are forwarded with the same `request_id` so you can cross-reference with logs.

### Prometheus
Scrape `GET /metrics`. Suggested Kubernetes annotations:

```yaml
prometheus.io/scrape: "true"
prometheus.io/path: /metrics
prometheus.io/port: "8000"
```

### Fluent Bit / Promtail
Because logs go to stdout as JSON, configure your collector to parse JSON and forward to Loki/ELK/Datadog. Example Fluent Bit snippet:

```ini
[INPUT]
    Name tail
    Path /var/log/containers/queueit-*.log
    Parser json

[FILTER]
    Name parser
    Parser json
    Reserve_Data On
```

---

## Testing & Verification

1. `pytest -q` — runs `tests/test_logging_middleware.py`.
2. `curl -v http://localhost:8000/healthz` — confirm `X-Request-ID`.
3. Trigger `/boom` (or any endpoint raising `HTTPException`) and verify `http_exception` logs with request id.
4. Trigger `/crash` (or raise an unhandled error) and ensure `unhandled_exception` logs include stack trace and that Sentry receives an event when `SENTRY_DSN` is set.
5. Add a background task using `bind_background_task` and watch for `background.task.*` logs sharing the same `request_id`.

---

## Operational Notes

* Always ship stdout/stderr to your aggregator. Do **not** write to log files inside containers.
* Feature-flag noisy enrichment via `LOG_ENRICHMENT=false` if log volume becomes excessive.
* When rolling out, deploy to staging first, watch `/metrics` latency histograms, and confirm Sentry dashboards stay quiet.

