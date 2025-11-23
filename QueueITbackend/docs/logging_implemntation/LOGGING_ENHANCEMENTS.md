# Logging Enhancements - Enriched Access Logs

**Date:** November 23, 2025  
**Status:** ✅ Complete

---

## 🎯 What Was Enhanced

Your access logs now include **much richer context** automatically:

### Before
```
[info] request_completed method=PATCH path=/api/v1/sessions/control_session query_params=None status=200 duration_ms=322.09
```

### After
```json
{
  "ts": "2025-11-23T12:17:35.108911Z",
  "level": "info",
  "event": "request_completed",
  "method": "PATCH",
  "path": "/api/v1/sessions/control_session",
  "query_params": {
    "session_id": "abc123",
    "action": "skip"
  },
  "status": 200,
  "duration_ms": 322.09,
  "request_id": "35953048-bf8d-4072-bbb2-abf5f6c01b02",
  "user_id": "e34258de-27c6-4107-9aa4-d2be3f8eb313",
  "user_email": "test@gmail.com",
  "client_ip": "192.168.1.100",
  "service": "api",
  "env": "development"
}
```

---

## ✨ New Features

### 1. User ID and Email (Automatic)
Every authenticated request now logs:
- `user_id` - Extracted from JWT `sub` claim
- `user_email` - Extracted from JWT `email` claim

**How it works:**
- New `AuthContextMiddleware` extracts JWT claims without verification
- Sets `request.state.user_id` and `request.state.user_email`
- Access log middleware picks them up automatically

### 2. Client IP Address (Automatic)
Logs the client's IP address from:
1. `X-Forwarded-For` header (if behind proxy/load balancer)
2. `X-Real-IP` header (if behind nginx)
3. Direct connection IP (fallback)

### 3. Query Parameters as Dictionary
Instead of:
```
query_params=None
```

Or:
```
query_params="session_id=abc123&action=skip"
```

Now shows:
```json
"query_params": {
  "session_id": "abc123",
  "action": "skip"
}
```

### 4. Request Body Logging (Optional)
Enable with `LOG_REQUEST_BODY=true`:

```json
{
  "event": "request_completed",
  "method": "POST",
  "path": "/api/v1/sessions",
  "request_body": {
    "name": "My Session",
    "is_public": true,
    "password": "***MASKED***"
  }
}
```

**Features:**
- Only logs POST/PUT/PATCH requests
- Size limited (default 1000 bytes, configurable)
- Automatically masks sensitive fields (passwords, tokens, etc.)
- Shows body size if too large:
  ```json
  "request_body": {
    "size_bytes": 5000,
    "logged": false,
    "reason": "body_too_large (max: 1000 bytes)"
  }
  ```

### 5. Silenced Noisy HTTP Debug Output
Those verbose HTTP/2 logs are now automatically silenced:
```
Encoding 71 with 7 bits  ❌ GONE
Adding (b'accept-encoding'...)  ❌ GONE
Decoded 8, consumed 1 bytes  ❌ GONE
```

**Silenced loggers:**
- `httpx`
- `httpcore`
- `h2`
- `hpack`
- `urllib3`
- `requests`

### 6. Structured Logging in Auth Code
Replaced print statements with structured logs:

**Before:**
```python
print(f"Authenticated client for user: {user_email} ({user_id})")
```

**After:**
```python
logger.debug(
    "authenticated_client_created",
    user_id=user_id,
    user_email=user_email,
)
```

---

## 📁 Files Modified

1. **`app/core/config.py`**
   - Added `LOG_REQUEST_BODY` configuration
   - Added `LOG_REQUEST_BODY_MAX_SIZE` configuration

2. **`app/middleware/access_log.py`** (major upgrade)
   - Added `get_client_ip()` function
   - Added `get_user_details()` function
   - Added `get_request_body()` function
   - Enhanced logging to include all new fields
   - Query params now logged as dict

3. **`app/middleware/auth_context.py`** (new file)
   - Extracts user details from JWT
   - Sets in `request.state` for logging
   - Non-intrusive (doesn't enforce auth)

4. **`app/middleware/__init__.py`**
   - Exported `AuthContextMiddleware`

5. **`app/main.py`**
   - Added `AuthContextMiddleware` to middleware stack
   - Middleware order: RequestID → AuthContext → AccessLog

6. **`app/core/auth.py`**
   - Replaced print statements with structured logging
   - Added `structlog` import

7. **`app/logging_config.py`**
   - Added silencing for HTTP client libraries
   - Silences httpx, h2, hpack, urllib3, requests

8. **`ENV.example`**
   - Added `LOG_REQUEST_BODY` documentation
   - Added `LOG_REQUEST_BODY_MAX_SIZE` documentation

9. **`docs/LOGGING.md`**
   - Added troubleshooting for HTTP/2 debug output

---

## 🚀 Configuration

### Environment Variables

```bash
# Enable request body logging (default: false)
LOG_REQUEST_BODY=true

# Maximum body size to log in bytes (default: 1000)
LOG_REQUEST_BODY_MAX_SIZE=1000
```

**Recommended settings:**

**Development:**
```bash
LOG_REQUEST_BODY=true
LOG_REQUEST_BODY_MAX_SIZE=2000
```

**Production:**
```bash
LOG_REQUEST_BODY=false  # Don't log bodies in prod (privacy/performance)
```

---

## 📊 Example Log Outputs

### GET Request (Authenticated)
```json
{
  "ts": "2025-11-23T12:17:35.520545Z",
  "level": "info",
  "event": "request_completed",
  "service": "api",
  "env": "development",
  "request_id": "43ee3fb5-618c-40c9-8058-19aae4633474",
  "user_id": "e34258de-27c6-4107-9aa4-d2be3f8eb313",
  "user_email": "test@gmail.com",
  "client_ip": "192.168.1.100",
  "method": "GET",
  "path": "/api/v1/sessions/current",
  "status": 200,
  "duration_ms": 398.34
}
```

### POST Request with Body Logging
```json
{
  "ts": "2025-11-23T12:18:00.123Z",
  "level": "info",
  "event": "request_completed",
  "service": "api",
  "env": "development",
  "request_id": "9b5c0d4e-1f6a-4c3d-0e9f-7a8b9c0d1e2f",
  "user_id": "e34258de-27c6-4107-9aa4-d2be3f8eb313",
  "user_email": "test@gmail.com",
  "client_ip": "192.168.1.100",
  "method": "POST",
  "path": "/api/v1/sessions",
  "query_params": {
    "include": "host"
  },
  "request_body": {
    "name": "Party Session",
    "is_public": true,
    "join_code": "PARTY2024"
  },
  "status": 201,
  "duration_ms": 145.67
}
```

### Request with Sensitive Body Data
```json
{
  "request_body": {
    "email": "user@example.com",
    "password": "***MASKED***",
    "api_key": "***MASKED***"
  }
}
```

### Request with Large Body
```json
{
  "request_body": {
    "size_bytes": 5000,
    "logged": false,
    "reason": "body_too_large (max: 1000 bytes)"
  }
}
```

### Unauthenticated Request
```json
{
  "ts": "2025-11-23T12:18:30.456Z",
  "level": "info",
  "event": "request_completed",
  "service": "api",
  "env": "development",
  "request_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "client_ip": "192.168.1.100",
  "method": "GET",
  "path": "/healthz",
  "status": 200,
  "duration_ms": 12.34
}
```
_(No user_id or user_email when not authenticated)_

---

## 🔍 Query Examples

Now you can query logs by:

### Find all requests by a specific user
```
user_id="e34258de-27c6-4107-9aa4-d2be3f8eb313"
```

### Find all requests by user email
```
user_email="test@gmail.com"
```

### Find all requests from a specific IP
```
client_ip="192.168.1.100"
```

### Find slow requests by a user
```
user_id="e34258de..." AND duration_ms>1000
```

### Find errors for a specific user
```
user_email="test@gmail.com" AND level="error"
```

### Find POST requests with bodies logged
```
method="POST" AND request_body.logged!=false
```

---

## 🎯 Benefits

### 1. Better Debugging
- Know exactly which user triggered an error
- See what data they sent
- Track requests across services with request_id + user_id

### 2. Security & Compliance
- Track user actions with full context
- Audit trail with user email + IP + timestamp
- Automatic PII masking in request bodies

### 3. Performance Analysis
- Identify slow endpoints per user
- Track duration by user/IP/endpoint
- Correlate performance issues with users

### 4. Support & Operations
- Quickly find user's requests by email
- See full context of support tickets
- Reproduce issues with exact request details

---

## ✅ What to Test

1. **Start server and make authenticated request:**
   ```bash
   curl -H "Authorization: Bearer <your-jwt>" http://localhost:8000/api/v1/sessions/current
   ```
   
   **Check logs include:** `user_id`, `user_email`, `client_ip`

2. **Test request body logging:**
   ```bash
   # Enable body logging
   export LOG_REQUEST_BODY=true
   
   # Restart server
   uvicorn app.main:app --reload
   
   # Make POST request
   curl -X POST http://localhost:8000/api/v1/sessions \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer <jwt>" \
     -d '{"name": "Test", "password": "secret123"}'
   ```
   
   **Check logs show:** `request_body` with `password: "***MASKED***"`

3. **Test query params:**
   ```bash
   curl "http://localhost:8000/api/v1/sessions?limit=10&offset=20"
   ```
   
   **Check logs show:** `query_params: {"limit": "10", "offset": "20"}`

4. **Verify noisy logs are gone:**
   - No more "Encoding X with Y bits"
   - No more "Adding (b'...')"
   - Clean structured logs only

---

## 🔐 Security Notes

### Automatic PII Masking
Request bodies are automatically sanitized:
- `password` → `***MASKED***`
- `token` → `***MASKED***`
- `api_key` → `***MASKED***`
- `secret` → `***MASKED***`
- And more (see `SENSITIVE_FIELDS` in `logging_config.py`)

### IP Privacy
Client IPs are logged for security/audit purposes. In production:
- Consider GDPR compliance (pseudonymization, retention limits)
- May want to hash IPs for privacy
- Document in privacy policy

### Request Body Logging
**Recommendation:** Only enable in development/staging
- Production: `LOG_REQUEST_BODY=false`
- Development: `LOG_REQUEST_BODY=true`

---

## 📚 Documentation Updated

- **`docs/LOGGING.md`** - Added HTTP/2 debug troubleshooting
- **`ENV.example`** - Added new config options
- **This file** - Complete enhancement guide

---

## 🚀 Ready to Use!

All enhancements are **active now**. Just restart your server:

```bash
cd QueueITbackend
uvicorn app.main:app --reload
```

Your logs now include:
- ✅ User ID and email
- ✅ Client IP address
- ✅ Query params as dict
- ✅ Optional request body logging
- ✅ No more noisy HTTP debug output
- ✅ Structured logging everywhere

**Enjoy your enriched logs! 🎉**

---

**Author:** @agent  
**Date:** November 23, 2025  
**Status:** ✅ Complete

