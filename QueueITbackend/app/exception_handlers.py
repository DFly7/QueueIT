from fastapi import Request, FastAPI
from fastapi.responses import JSONResponse
import structlog

logger = structlog.get_logger("api.exceptions")

def add_exception_handlers(app: FastAPI):
    @app.exception_handler(Exception)
    async def global_exception_handler(request: Request, exc: Exception):
        logger.error("unhandled_exception", 
                     exc_info=exc,
                     path=request.url.path,
                     method=request.method,
                     request_id=getattr(request.state, "request_id", None))
        
        return JSONResponse(
            status_code=500,
            content={"detail": "Internal Server Error", "request_id": getattr(request.state, "request_id", None)},
        )

