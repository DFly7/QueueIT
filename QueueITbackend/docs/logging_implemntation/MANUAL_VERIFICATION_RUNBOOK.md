# Manual Verification Runbook

**Quick guide to verify structured logging works correctly.**

---

## Prerequisites

```bash
cd /Users/darraghflynn/.cursor/worktrees/QueueIT/V2h2I/QueueITbackend
pip install -r requirements.txt
```

---

## Step 1: Run All Tests ✅

```bash
pytest -v
```

**Expected Output:**
```
tests/test_logging_middleware.py::TestRequestIDMiddleware::test_generates_request_id_when_not_provided PASSED
tests/test_logging_middleware.py::TestRequestIDMiddleware::test_preserves_incoming_request_id PASSED
...
================================ 42 passed in 2.34s ================================
```

**✅ PASS if:** All 42 tests pass

---

## Step 2: Start Server (Development Mode) 🖥️

```bash
LOG_JSON=false LOG_LEVEL=DEBUG uvicorn app.main:app --reload
```

**Expected Output:**
```
2025-11-23T14:22:10.123Z [info] application_started app_name=QueueIT API environment=development
FastAPI app started. Docs: /docs | Redoc: /redoc | Health: /healthz
INFO:     Uvicorn running on http://127.0.0.1:8000 (Press CTRL+C to quit)
```

**✅ PASS if:** Server starts without errors and shows structured startup log

---

## Step 3: Check Health Endpoint with X-Request-ID 🏥

**Terminal 1:** (server running)

**Terminal 2:**
```bash
curl -v http://localhost:8000/healthz
```

**Expected Output:**
```http
HTTP/1.1 200 OK
content-type: application/json
x-request-id: a1b2c3d4-e5f6-7890-abcd-ef1234567890

{"status":"ok"}
```

**Terminal 1 (server logs):**
```
2025-11-23T14:23:15.456Z [info] request_completed method=GET path=/healthz status=200 duration_ms=12.34 request_id=a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

**✅ PASS if:**
- Response status is 200
- Response has `X-Request-ID` header
- Header value is a valid UUID4
- Server log shows structured access log with request_id

---

## Step 4: Test Custom Request ID 🔑

```bash
curl -v -H "X-Request-ID: my-test-id-12345" http://localhost:8000/healthz
```

**Expected Output:**
```http
x-request-id: my-test-id-12345
```

**Server Log:**
```
... request_id=my-test-id-12345 ...
```

**✅ PASS if:**
- Response has `X-Request-ID: my-test-id-12345`
- Server log shows same request_id

---

## Step 5: Test JSON Logging (Production Mode) 📝

**Stop server (CTRL+C)**

**Start in JSON mode:**
```bash
LOG_JSON=true LOG_LEVEL=INFO uvicorn app.main:app --reload
```

**Make request:**
```bash
curl http://localhost:8000/healthz
```

**Expected Server Output (JSON):**
```json
{
  "ts": "2025-11-23T14:24:20.789Z",
  "level": "info",
  "event": "application_started",
  "message": "application_started",
  "service": "api",
  "env": "development",
  "app_name": "QueueIT API",
  "environment": "development",
  "debug": true,
  "log_level": "INFO",
  "log_json": true
}
```

```json
{
  "ts": "2025-11-23T14:24:25.123Z",
  "level": "info",
  "event": "request_completed",
  "message": "request_completed",
  "service": "api",
  "env": "development",
  "request_id": "7f3a8b2c-9d4e-4a1b-8c7d-5e6f7a8b9c0d",
  "method": "GET",
  "path": "/healthz",
  "status": 200,
  "duration_ms": 12.34
}
```

**✅ PASS if:**
- Logs are valid JSON
- Each log has required fields: `ts`, `level`, `event`, `service`, `env`, `request_id`

---

## Step 6: Test Exception Logging 💥

```bash
curl -v http://localhost:8000/nonexistent-endpoint
```

**Expected Response:**
```http
HTTP/1.1 404 Not Found
x-request-id: 8a4b9c3d-0e5f-4b2c-9d8e-6f7a8b9c0d1e

{
  "error": "Not Found",
  "status_code": 404,
  "request_id": "8a4b9c3d-0e5f-4b2c-9d8e-6f7a8b9c0d1e"
}
```

**Server Log (JSON):**
```json
{
  "ts": "2025-11-23T14:25:30.456Z",
  "level": "warning",
  "event": "http_exception",
  "service": "api",
  "env": "development",
  "request_id": "8a4b9c3d-0e5f-4b2c-9d8e-6f7a8b9c0d1e",
  "error_type": "HTTPException",
  "status": 404,
  "detail": "Not Found",
  "method": "GET",
  "path": "/nonexistent-endpoint"
}
```

**✅ PASS if:**
- Response status is 404
- Response includes `request_id`
- Server log shows structured error with same `request_id`
- Log level is "warning" (4xx errors)

---

## Step 7: Test Validation Error 📋

```bash
curl -X POST http://localhost:8000/api/v1/sessions \
  -H "Content-Type: application/json" \
  -d '{}'
```

**Expected Response:**
```http
HTTP/1.1 401 or 422
x-request-id: <uuid>

{
  "error": "Unauthorized" or "Validation error",
  "status_code": 401 or 422,
  "request_id": "<uuid>",
  ...
}
```

**✅ PASS if:**
- Error response includes `request_id`
- Server log shows structured error

---

## Step 8: Test Prometheus Metrics 📊

```bash
curl http://localhost:8000/metrics
```

**Expected Output:**
```
# HELP python_info Python platform information
# TYPE python_info gauge
python_info{implementation="CPython",major="3",minor="12",patchlevel="0",version="3.12.0"} 1.0
# HELP process_virtual_memory_bytes Virtual memory size in bytes.
# TYPE process_virtual_memory_bytes gauge
process_virtual_memory_bytes 1.23456789e+08
...
```

**✅ PASS if:**
- Endpoint returns Prometheus metrics format
- No errors

---

## Step 9: Test PII Masking 🔒

**Python REPL:**
```bash
python
```

```python
from app.utils.log_context import safe_log_dict, mask_pii_in_text

# Test 1: Dictionary masking
data = {
    "username": "john",
    "password": "secret123",
    "email": "john@example.com"
}
safe_data = safe_log_dict(data)
print(safe_data)
# Expected: {'username': 'john', 'password': '***MASKED***', 'email': 'john@example.com'}

# Test 2: Text masking
text = "Contact me at john@example.com or call 555-123-4567"
safe_text = mask_pii_in_text(text)
print(safe_text)
# Expected: 'Contact me at ***@example.com or call ***-***-4567'
```

**✅ PASS if:**
- Passwords are masked
- Email domain is visible, username masked
- Phone shows last 4 digits

---

## Step 10: Check Application Startup Logs 🚀

**Look at server startup logs (JSON mode):**

**Expected:**
```json
{
  "ts": "2025-11-23T14:30:00.000Z",
  "level": "info",
  "event": "application_started",
  "service": "api",
  "env": "development",
  "app_name": "QueueIT API",
  "environment": "development",
  "debug": true,
  "log_level": "INFO",
  "log_json": true
}
```

**If Sentry configured:**
```json
{
  "ts": "2025-11-23T14:30:00.100Z",
  "level": "info",
  "event": "sentry_initialized",
  "service": "api",
  "environment": "development"
}
```

**If metrics enabled:**
```json
{
  "ts": "2025-11-23T14:30:00.200Z",
  "level": "info",
  "event": "prometheus_metrics_enabled",
  "service": "api",
  "endpoint": "/metrics"
}
```

**✅ PASS if:**
- Startup logs are structured
- Configuration values logged correctly

---

## Step 11: Test Coverage Report 📈

```bash
pytest --cov=app --cov-report=term-missing --cov-report=html
```

**Expected Output:**
```
app/logging_config.py          95%
app/middleware/request_id.py   100%
app/middleware/access_log.py   92%
app/exception_handlers.py      100%
app/utils/log_context.py       88%
---------------------------------------
TOTAL                          93%
```

**Open HTML report:**
```bash
open htmlcov/index.html
```

**✅ PASS if:**
- Total coverage ≥ 90%
- All critical paths covered

---

## Step 12: Check Documentation 📚

```bash
# View main docs
cat docs/LOGGING.md | head -50

# View PR description
cat PR_DESCRIPTION.md | head -50

# Check ENV example
cat ENV.example
```

**✅ PASS if:**
- Documentation is comprehensive
- Examples are clear
- ENV.example has all variables

---

## Summary Checklist ✅

After completing all steps, verify:

- [ ] ✅ All 42 tests pass
- [ ] ✅ Server starts successfully
- [ ] ✅ X-Request-ID header present on all responses
- [ ] ✅ Request ID is valid UUID4
- [ ] ✅ Custom request IDs are preserved
- [ ] ✅ Logs are human-readable in dev mode (LOG_JSON=false)
- [ ] ✅ Logs are valid JSON in prod mode (LOG_JSON=true)
- [ ] ✅ Logs contain required fields: ts, level, event, service, env, request_id
- [ ] ✅ Exceptions are logged with structured data
- [ ] ✅ Error responses include request_id
- [ ] ✅ 4xx errors logged at WARNING level
- [ ] ✅ 5xx errors logged at ERROR level
- [ ] ✅ /metrics endpoint accessible
- [ ] ✅ PII masking works correctly
- [ ] ✅ Test coverage ≥ 90%
- [ ] ✅ Documentation complete

---

## Troubleshooting

### Problem: Tests fail with import errors

**Solution:**
```bash
pip install -r requirements.txt
```

### Problem: Server won't start

**Solution:**
```bash
# Check if port 8000 is in use
lsof -i :8000
# Kill process if needed
kill -9 <PID>
```

### Problem: X-Request-ID not in response

**Solution:**
- Check middleware is registered in main.py
- Verify RequestIDMiddleware is imported
- Check logs for middleware errors

### Problem: Logs not JSON formatted

**Solution:**
```bash
# Explicitly set LOG_JSON=true
LOG_JSON=true uvicorn app.main:app
```

### Problem: PII not being masked

**Solution:**
- Use `safe_log_dict()` before logging
- Add custom sensitive keys to SENSITIVE_FIELDS in logging_config.py

---

## Quick Commands Reference

```bash
# Run tests
pytest -v

# Run tests with coverage
pytest --cov=app --cov-report=term-missing

# Start dev server
LOG_JSON=false LOG_LEVEL=DEBUG uvicorn app.main:app --reload

# Start prod-like server
LOG_JSON=true LOG_LEVEL=INFO uvicorn app.main:app

# Test health endpoint
curl -v http://localhost:8000/healthz

# Test with custom request ID
curl -H "X-Request-ID: test-123" http://localhost:8000/healthz

# Test error handling
curl http://localhost:8000/nonexistent

# Check metrics
curl http://localhost:8000/metrics

# Check logs are JSON (pipe through jq)
LOG_JSON=true uvicorn app.main:app 2>&1 | grep request_completed | jq
```

---

## Success Criteria

**All checks must pass:**
- ✅ Tests: 42/42 passing
- ✅ Coverage: ≥90%
- ✅ X-Request-ID: Present on all responses
- ✅ Logs: Structured JSON in production
- ✅ Errors: Logged with stack traces
- ✅ PII: Masked correctly
- ✅ Docs: Complete and accurate

**If all checks pass → Ready to deploy to staging! 🚀**

---

**Estimated Time:** 15-20 minutes  
**Last Updated:** November 23, 2025

