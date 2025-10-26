from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import api_router
from app.core.config import get_settings

from app.core.auth import verify_jwt

settings = get_settings()

app = FastAPI(
    title=settings.app_name,
    swagger_ui_parameters={"persistAuthorization": True},  # Keeps JWT after refresh
)

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


app.include_router(
    api_router, 
    prefix="/api/v1", 
    dependencies=[Depends(verify_jwt)]
    # tags=["Protected"]
)


@app.on_event("startup")
def on_startup() -> None:
    # Print relative docs paths; runner prints absolute URL
    print("FastAPI app started. Docs: /docs | Redoc: /redoc | Health: /healthz")

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