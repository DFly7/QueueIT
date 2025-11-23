from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import api_router
from app.core.config import get_settings
from app.core.auth import verify_jwt

# Logging and middleware
from app.logging_config import setup_logging, get_logger
from app.middleware import RequestIDMiddleware, AccessLogMiddleware
from app.exception_handlers import register_exception_handlers

# Optional: Sentry for error tracking
import sentry_sdk
from sentry_sdk.integrations.fastapi import FastApiIntegration
from sentry_sdk.integrations.starlette import StarletteIntegration

settings = get_settings()

# Initialize structured logging
setup_logging()
logger = get_logger(__name__)

# Initialize Sentry if configured
if settings.sentry_dsn:
    sentry_sdk.init(
        dsn=settings.sentry_dsn,
        environment=settings.sentry_environment,
        traces_sample_rate=settings.sentry_traces_sample_rate,
        integrations=[
            StarletteIntegration(),
            FastApiIntegration(),
        ],
    )
    logger.info("sentry_initialized", environment=settings.sentry_environment)

app = FastAPI(
    title=settings.app_name,
    swagger_ui_parameters={"persistAuthorization": True},  # Keeps JWT after refresh
)

# Register exception handlers for structured error logging
register_exception_handlers(app)

# Add logging middleware (order matters - request ID first, then access log)
app.add_middleware(AccessLogMiddleware)
app.add_middleware(RequestIDMiddleware)

# CORS middleware
cors_origins = ["*"] if settings.allowed_origins == ["*"] else settings.allowed_origins

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/healthz")
def healthz() -> dict:
    return {"status": "ok"}


# Prometheus metrics endpoint (optional)
if settings.enable_metrics:
    from prometheus_client import make_asgi_app
    
    metrics_app = make_asgi_app()
    app.mount("/metrics", metrics_app)
    
    logger.info("prometheus_metrics_enabled", endpoint="/metrics")


app.include_router(
    api_router, 
    prefix="/api/v1"
    # dependencies=[Depends(verify_jwt)]
    # tags=["Protected"]
)


@app.on_event("startup")
def on_startup() -> None:
    logger.info(
        "application_started",
        app_name=settings.app_name,
        environment=settings.environment,
        debug=settings.debug,
        log_level=settings.log_level,
        log_json=settings.log_json,
    )
    # Print relative docs paths; runner prints absolute URL
    print("FastAPI app started. Docs: /docs | Redoc: /redoc | Health: /healthz")


@app.on_event("shutdown")
def on_shutdown() -> None:
    logger.info("application_shutdown", app_name=settings.app_name)

# --- Custom OpenAPI Schema (adds global BearerAuth once) ---
from fastapi.openapi.utils import get_openapi

def custom_openapi():
    if app.openapi_schema:
        return app.openapi_schema

    openapi_schema = get_openapi(
        title=settings.app_name,
        version="1.0.0",
        routes=app.routes,
    )

    openapi_schema["components"]["securitySchemes"] = {
        "BearerAuth": {
            "type": "http",
            "scheme": "bearer",
            "bearerFormat": "JWT",
        }
    }

    # Apply this security scheme globally
    # openapi_schema["security"] = [{"BearerAuth": []}]

        # ✅ Apply BearerAuth only to /api/v1 routes
    for path, methods in openapi_schema["paths"].items():
        if path.startswith("/api/v1"):
            for method in methods.values():
                method["security"] = [{"BearerAuth": []}]
        else:
            # Explicitly mark public endpoints (e.g., /healthz) as no auth
            for method in methods.values():
                method["security"] = []

    app.openapi_schema = openapi_schema

    return openapi_schema

app.openapi = custom_openapi