import time
import structlog
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware

access_logger = structlog.get_logger("api.access")

class AccessLogMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        start_time = time.perf_counter()
        status_code = 500
        
        try:
            response = await call_next(request)
            status_code = response.status_code
            return response
        except Exception:
            # We let the exception propagate to the exception handler
            # but we still want to log the access (as a failure)
            raise
        finally:
            process_time = time.perf_counter() - start_time
            
            # Extract user_id if available (set by auth dependency)
            user_id = getattr(request.state, "user_id", None)
            
            log_kwargs = {
                "method": request.method,
                "path": request.url.path,
                "status": status_code,
                "duration_ms": round(process_time * 1000, 2),
            }
            
            if user_id:
                log_kwargs["user_id"] = user_id
                
            # Determine log level
            if status_code >= 500:
                level = "error"
            elif status_code >= 400:
                level = "warning"
            else:
                level = "info"
                
            # Skip health check logging to reduce noise
            if request.url.path != "/healthz":
                 getattr(access_logger, level)("request_completed", **log_kwargs)

