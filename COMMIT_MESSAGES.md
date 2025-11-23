# Commit Messages for Logging Implementation

This document outlines the logical commit sequence for the structured logging implementation.

## Recommended Commit Sequence

### 1. Dependencies and Configuration
```
chore(logging): add structured logging dependencies

- Add structlog, python-json-logger, sentry-sdk, prometheus-client
- Add missing production dependencies (supabase, PyJWT, cryptography)
- Add testing dependencies (pytest, pytest-asyncio, pytest-cov)
- Update requirements.txt with all logging and observability packages
```

### 2. Core Logging Configuration
```
feat(logging): implement structured logging with JSON output

- Create app/logging_config.py with structlog configuration
- Support JSON logs (production) and human-readable logs (development)
- Add automatic PII masking processor
- Add service context injection (service name, environment)
- Configure LOG_LEVEL and LOG_JSON environment variables
```

### 3. Configuration Updates
```
chore(config): add logging configuration variables

- Add LOG_LEVEL, LOG_JSON to Settings
- Add Sentry configuration (DSN, environment, traces sample rate)
- Add ENABLE_METRICS toggle for Prometheus
- Update app/core/config.py with new settings
```

### 4. Request ID Middleware
```
feat(logging): add request-id middleware and X-Request-ID header

- Create RequestIDMiddleware to generate/extract request IDs
- Generate UUID4 when X-Request-ID header not present
- Preserve incoming X-Request-ID from client
- Store request_id in request.state
- Bind request_id to structlog context for all logs
- Return X-Request-ID in response headers
```

### 5. Access Logging Middleware
```
feat(logging): add access log middleware

- Create AccessLogMiddleware for request/response logging
- Log method, path, query_params, status, duration_ms
- Include request_id and user_id in all access logs
- Use appropriate log levels (info/warning/error based on status)
- Handle exceptions and log failed requests with context
```

### 6. Exception Handlers
```
feat(logging): centralize exception handling with structured logging

- Create exception_handlers.py with structured error logging
- Add HTTP exception handler (4xx, 5xx)
- Add validation error handler (422) with field-level details
- Add unhandled exception handler with full stack traces
- Return standardized error responses with request_id
- Register all handlers in main.py
```

### 7. PII Masking and Utilities
```
feat(logging): add PII masking and log context utilities

- Create log_context.py with safe logging helpers
- Implement mask_sensitive_value() for passwords, tokens, etc.
- Implement mask_pii_in_text() for emails, phone, SSN, credit cards
- Add safe_log_dict() to mask sensitive dictionary fields
- Add BackgroundTaskLogger context manager
- Add run_in_background() for background task logging
- Add log_context() context manager for temporary context binding
```

### 8. Main Application Integration
```
feat(logging): integrate logging into FastAPI application

- Initialize structured logging in main.py startup
- Add RequestIDMiddleware and AccessLogMiddleware
- Register exception handlers
- Add Sentry initialization (optional, when DSN configured)
- Add Prometheus /metrics endpoint (optional, when enabled)
- Add structured startup and shutdown logging
```

### 9. Tests
```
test(logging): add comprehensive pytest tests for logging

- Add test_logging_middleware.py for middleware tests
  * Test request ID generation and preservation
  * Test access logging for success and error responses
  * Test request ID correlation across logs

- Add test_exception_handlers.py for exception handler tests
  * Test HTTP exception handling (404, etc.)
  * Test validation error handling (422)
  * Test unhandled exception handling (500)
  * Verify request_id in error responses

- Add test_log_context.py for PII masking tests
  * Test mask_sensitive_value() for strings, dicts, lists
  * Test mask_pii_in_text() for emails, phones, SSN, cards
  * Test safe_log_dict() with sensitive field names

- Add conftest.py with fixtures and test client
- Add pytest.ini with coverage configuration
```

### 10. Configuration Files
```
chore(logging): add environment configuration and examples

- Create ENV.example with logging configuration variables
- Document LOG_LEVEL, LOG_JSON, SENTRY_DSN, ENABLE_METRICS
- Add development, staging, and production examples
- Include comments and best practices
```

### 11. CI/CD Integration
```
ci(logging): add GitHub Actions workflow for backend tests

- Create .github/workflows/backend-tests.yml
- Run tests on Python 3.11 and 3.12
- Add test job with pytest and coverage
- Add logging verification job
  * Verify X-Request-ID header presence
  * Verify structured JSON logging works
  * Test server startup with logging enabled
- Upload coverage to Codecov (optional)
```

### 12. Documentation
```
docs(logging): add comprehensive logging documentation

- Create docs/LOGGING.md with complete logging guide
- Document log format (JSON and human-readable)
- Add configuration guide with environment variables
- Include usage examples for routes, exceptions, background tasks
- Document request correlation with X-Request-ID
- Add PII masking guide and examples
- Document integration with Sentry, Prometheus, Loki, ELK, Datadog
- Add troubleshooting section
- Add best practices and anti-patterns
- Include manual verification checklist
```

### 13. Shipping Plan Update
```
docs(shipping): update shipping plan with logging tasks

- Add "Structured Logging Implementation" section
- Document completed components and deliverables
- Add rollout plan (phases 1-4)
- Document rollback plan with feature flag option
- Add verification checklist (automated and manual)
- Document environment variables required per environment
- Add integration points for observability tools
- Add post-deploy monitoring plan
- Document success metrics and known limitations
- Update Day 6 tasks to mark logging as complete
```

---

## Example Git Commands

To commit these changes as separate logical commits:

```bash
# 1. Dependencies
git add QueueITbackend/requirements.txt
git commit -m "chore(logging): add structured logging dependencies"

# 2. Core logging
git add QueueITbackend/app/logging_config.py
git commit -m "feat(logging): implement structured logging with JSON output"

# 3. Config
git add QueueITbackend/app/core/config.py
git commit -m "chore(config): add logging configuration variables"

# 4. Request ID middleware
git add QueueITbackend/app/middleware/request_id.py
git commit -m "feat(logging): add request-id middleware and X-Request-ID header"

# 5. Access log middleware
git add QueueITbackend/app/middleware/access_log.py QueueITbackend/app/middleware/__init__.py
git commit -m "feat(logging): add access log middleware"

# 6. Exception handlers
git add QueueITbackend/app/exception_handlers.py
git commit -m "feat(logging): centralize exception handling with structured logging"

# 7. Utils
git add QueueITbackend/app/utils/
git commit -m "feat(logging): add PII masking and log context utilities"

# 8. Main integration
git add QueueITbackend/app/main.py
git commit -m "feat(logging): integrate logging into FastAPI application"

# 9. Tests
git add QueueITbackend/tests/ QueueITbackend/pytest.ini
git commit -m "test(logging): add comprehensive pytest tests for logging"

# 10. ENV example
git add QueueITbackend/ENV.example
git commit -m "chore(logging): add environment configuration and examples"

# 11. CI
git add .github/workflows/backend-tests.yml
git commit -m "ci(logging): add GitHub Actions workflow for backend tests"

# 12. Docs
git add QueueITbackend/docs/LOGGING.md
git commit -m "docs(logging): add comprehensive logging documentation"

# 13. Shipping plan
git add SHIPPING_PLAN.md
git commit -m "docs(shipping): update shipping plan with logging tasks"

# 14. PR description (optional)
git add PR_DESCRIPTION.md COMMIT_MESSAGES.md
git commit -m "docs(logging): add PR description and commit guide"
```

---

## Alternative: Squashed Commit

If you prefer a single commit:

```bash
git add .
git commit -m "feat(logging): implement structured, request-id aware logging

Implements production-grade structured logging across FastAPI backend:

Features:
- Structured JSON logs with context (request_id, user_id, service, env)
- Request ID middleware with X-Request-ID header (UUID4)
- Access logging middleware with request/response details
- Centralized exception handlers with stack traces
- PII masking utilities for safe logging
- Background task logging with context propagation
- Sentry integration for error tracking (optional)
- Prometheus /metrics endpoint (optional)

Components:
- app/logging_config.py - Core structlog configuration
- app/middleware/ - RequestID and AccessLog middleware
- app/exception_handlers.py - Structured error handling
- app/utils/log_context.py - PII masking and context utilities
- tests/ - Comprehensive pytest test suite
- docs/LOGGING.md - Complete documentation

Breaking changes: None (only adds X-Request-ID header)

Closes #XXX (if issue tracker used)
"
```

---

## Commit Message Convention

Following conventional commits:

**Format:** `<type>(<scope>): <subject>`

**Types:**
- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation changes
- `chore` - Maintenance (deps, config)
- `test` - Adding or updating tests
- `ci` - CI/CD changes
- `refactor` - Code refactoring

**Scopes:**
- `logging` - Logging system
- `config` - Configuration
- `middleware` - Middleware
- `tests` - Test suite
- `shipping` - Shipping plan
- `ci` - CI/CD

---

**Author:** @agent  
**Date:** November 23, 2025

