## QueueIT Backend Code Review

### Overview

Your FastAPI backend is cleanly structured with versioned routing, centralized config, JWT auth dependency, and a Spotify integration. The foundations are solid, but there are a few correctness bugs (blocking runtime), security hardening gaps, and some DX/testing/documentation improvements that will meaningfully raise quality and reliability.

---

### Architecture & Project Structure

- **Good**: Clear layout under `app/` with `core/`, `api/v1/`, `services/`, `schemas/`, and an app-level `main.py`. Versioned router setup is neat.
- **Good**: Separate `services/spotify_service.py` and a Pydantic schema for response shaping.
- **Opportunity**: `sessions.py` and `songs.py` are currently stubs; the comments outline intent well. Concretize contracts (request/response models) to guide frontend integration and tests.

---

### Configuration & Environment Handling

- **Good**: Central `Settings` with `@lru_cache` and `.env` support.
- **Bug (runtime)**: `Settings` is missing `client_id` and `client_secret`, but the Spotify service accesses them. This raises `AttributeError` at runtime.

```12:23:/Users/darraghflynn/Desktop/codeAdventures/QueueIT/QueueITbackend/app/core/config.py
class Settings(BaseModel):
    app_name: str = "QueueIT API"
    environment: str = os.getenv("ENVIRONMENT", "development")
    debug: bool = environment != "production"

    supabase_url: str | None = os.getenv("SUPABASE_URL")
    supabase_public_anon_key: str | None = os.getenv("SUPABASE_PUBLIC_ANON_KEY")

    allowed_origins: List[str] = Field(
        default_factory=lambda: [o for o in os.getenv("ALLOWED_ORIGINS", "*").split(",") if o]
    )
```

```20:24:/Users/darraghflynn/Desktop/codeAdventures/QueueIT/QueueITbackend/app/services/spotify_service.py
settings = get_settings()
client_id = settings.client_id or os.getenv("CLIENT_ID")
client_secret = settings.client_secret or os.getenv("CLIENT_SECRET")
if not client_id or not client_secret:
    raise ValueError("Missing CLIENT_ID or CLIENT_SECRET environment variables")
```

- **Fix**: Either add fields to `Settings`:
  - `client_id: str | None = os.getenv("CLIENT_ID")`
  - `client_secret: str | None = os.getenv("CLIENT_SECRET")`
  - Or use `getattr(settings, "client_id", None)` pattern in the service and prefer env vars.
- **Docs**: README mentions `ENV.example` but it’s missing. Provide this file with placeholders for all envs (SUPABASE_URL, SUPABASE_PUBLIC_ANON_KEY, CLIENT_ID, CLIENT_SECRET, ALLOWED_ORIGINS, ENVIRONMENT).

````20:24:/Users/darraghflynn/Desktop/codeAdventures/QueueIT/QueueITbackend/README.md
- Copy `ENV.example` to `.env` and fill in values:

```bash
cp ENV.example .env
````

````

---

### Authentication & Security (Supabase JWT)
- **Good**: Global protection of `/api/v1/*` via `Depends(verify_jwt)` and OpenAPI security scheme injection limited to v1 paths.
- **Concern**: JWKS are fetched at module import. If `SUPABASE_URL` is missing/invalid at startup, app import can fail.

```10:12:/Users/darraghflynn/Desktop/codeAdventures/QueueIT/QueueITbackend/app/core/auth.py
settings = get_settings()
JWK_URL = f"{settings.supabase_url}/auth/v1/.well-known/jwks.json"
````

```64:69:/Users/darraghflynn/Desktop/codeAdventures/QueueIT/QueueITbackend/app/core/auth.py
# --- Create a single instance to be used by the app ---
# This line runs when the module is first imported.
jwk_manager = JWKSManager(JWK_URL)

# --- FastAPI Dependency ---
def verify_jwt(authorization: Optional[str] = Header(None)) -> Dict:
```

- **Harden**:
  - Lazy-initialize JWKS on first request or in an app `startup` handler, with a clear error if `SUPABASE_URL` is missing. Add a network timeout when fetching JWKS.
  - Verify `iss` in addition to `aud` to ensure the token is issued by your Supabase project (`iss` typically `https://<project-ref>.supabase.co/auth/v1`).
  - Consider more explicit error messages for missing `Authorization` vs invalid `kid` vs network failures.
  - Add small in-memory TTL for JWK refresh (e.g., 1 hour) in addition to refresh-on-miss to handle key rotation.

```88:94:/Users/darraghflynn/Desktop/codeAdventures/QueueIT/QueueITbackend/app/core/auth.py
decoded = jwt.decode(
    token,
    public_key,
    algorithms=["RS256", "ES256"], # Support both algs
    audience="authenticated",      # CRITICAL: Verify audience
)
```

- **Dependency**: `jwt` (PyJWT) is used but not declared in `requirements.txt`. Add `PyJWT>=2.8`.
- **CORS**: `allow_credentials=True` with `allow_origins=["*"]` is not allowed per CORS spec and will be rejected by browsers for credentialed requests. Either:
  - set `allow_credentials=False` when using `*`, or
  - configure explicit origins.

```18:24:/Users/darraghflynn/Desktop/codeAdventures/QueueIT/QueueITbackend/app/main.py
app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

---

### API Endpoints, Routing & Error Handling

- **Good**: `api_router` groups v1 sub-routers and adds a simple `/ping`.
- **OpenAPI**: Custom security scheme applied only to v1 paths is thoughtful.
- **Stubs**: `sessions` and `songs` endpoints are placeholders. Define request/response models and error cases early to stabilize contracts.
- **Spotify search**:
  - The endpoint enforces `type="track"` (hardcoded in service), but README advertises `type` as a query param; introduce `type: str = Query("track", regex="^(track|artist|album|playlist)$")` and pass through.
  - `isrc` may be absent in search results; your schema requires it, causing validation errors. Make it optional or enrich by fetching track details.

```41:53:/Users/darraghflynn/Desktop/codeAdventures/QueueIT/QueueITbackend/app/api/v1/spotify.py
@router.get("/search", response_model=SearchResults) # <-- ADDED: response_model
def search(
    q: str = Query(..., min_length=1, description="Search query for a track"),
    limit: int = Query(10, ge=1, le=50, description="Number of results to return"),
):
    """
    Search for tracks on Spotify.
    """
    try:
        # The service still returns raw data
        raw_results = search_spotify(query=q, search_type="track", limit=limit)
        # We parse the raw data into our clean Pydantic model before returning
        return parse_spotify_results(raw_results)
```

```19:37:/Users/darraghflynn/Desktop/codeAdventures/QueueIT/QueueITbackend/app/api/v1/spotify.py
# Helper function to parse the complex Spotify response and fit it to our model
def parse_spotify_results(spotify_data: dict) -> SearchResults:
    items = spotify_data.get("tracks", {}).get("items", [])
    tracks = []
    for item in items:
        # Check if essential data is present
        if not item or not item.get("album"):
            continue

        tracks.append(
            TrackOut(
                id=item.get("id"),
                isrc=item.get("external_ids", {}).get("isrc"),
                name=item.get("name"),
                artists=' & '.join([artist["name"] for artist in item.get("artists", [])]),
                album=item.get("album", {}).get("name"),
                duration_ms=item.get("duration_ms"),
                image_url=item.get("album", {}).get("images", [{}])[0].get("url")
            )
        )
    return SearchResults(tracks=tracks)
```

---

### Schemas & Validation

- **Bug (runtime)**: `TrackOut.isrc` is required but often missing from search results, causing response validation errors.

```6:14:/Users/darraghflynn/Desktop/codeAdventures/QueueIT/QueueITbackend/app/schemas/track.py
class TrackOut(BaseModel):
    id: str = Field(..., description="Spotify track ID")
    isrc: str = Field(..., description="International Standard Recording Code")
    name: str = Field(..., description="Track title")
    artists: str = Field(..., description="Primary artists names in a & separated list")
    album: str = Field(..., description="Album name")
    duration_ms: int = Field(..., ge=0, description="Duration in milliseconds")
    image_url: Optional[HttpUrl] = Field(None, description="Album art URL (largest available)")
```

- **Fix Options**:
  - Make `isrc: Optional[str]` and update docs; or
  - Hydrate missing fields by calling `GET /v1/tracks/{id}` when `external_ids` absent (slower, but richer).
  - Validate `duration_ms` presence (it should exist) and default `image_url` to best available.

---

### Spotify Service Integration

- **Good**: Uses Client Credentials flow and caches the token with a safety margin.
- **Bugs/Improvements**:
  - Settings bug as noted above.
  - Add retries with backoff for `429 Too Many Requests` and transient 5xx errors.
  - Concurrency: guard token refresh with a simple lock to avoid thundering herd when the token expires.
  - Observability: log rate limit headers (`Retry-After`) when applicable.
  - Timeouts: already set to 10s — good; consider making configurable via settings.

---

### Error Handling & Observability

- **Good**: Spotify endpoint maps `requests.HTTPError` to downstream status codes and uses `HTTPException` for client/unknown errors.
- **Improve**:
  - Use structured logging (`logging` with JSON formatter) for key events: auth failures, external API errors, and request IDs.
  - Normalize error response shapes across endpoints (consistent `code`, `message`, `details`).

---

### Requirements & Dependencies

- **Issues**:
  - `PyJWT` is missing (required by `app/core/auth.py`).
  - Duplicate/conflicting dotenv packages: both `dotenv` and `python-dotenv` are listed. Only `python-dotenv` is needed.

```6:16:/Users/darraghflynn/Desktop/codeAdventures/QueueIT/QueueITbackend/requirements.txt
dotenv==0.9.9
fastapi==0.115.0
h11==0.16.0
httptools==0.7.1
idna==3.11
pydantic==2.8.2
pydantic_core==2.20.1
python-dotenv==1.0.1
PyYAML==6.0.3
requests==2.32.5
```

- **Recommendations**:
  - Add: `PyJWT>=2.8` (or `python-jose[cryptography]` if you prefer JOSE; code currently uses PyJWT APIs).
  - Remove: `dotenv==0.9.9` (keep `python-dotenv`).
  - Verify `fastapi==0.115.0` and `starlette==0.38.6` compatibility (they look aligned, but keep them in sync with FastAPI’s pinned Starlette version).
  - Consider using a `constraints.txt` or looser pins for leaf dependencies to reduce resolver churn.

---

### CORS & OpenAPI Customization

- **OpenAPI**: Security scheme injected and applied only to `/api/v1/*` — good separation of public vs protected routes.
- **CORS**: As noted, avoid `allow_credentials=True` with wildcard origins. Recommend explicit origin allowlist for production.

---

### Testing

- **Current**: No unit tests; a notebook exists for manual checks.
- **Add**:
  - Tests for `verify_jwt` happy-path and error cases (expired, wrong aud/iss, bad kid, network errors – mock `requests.get`).
  - Tests for Spotify search parsing (`parse_spotify_results`) including missing `external_ids` and empty images.
  - Contract tests on the `/api/v1/spotify/search` endpoint using `TestClient`.
  - Smoke test for CORS and `/healthz`.

---

### Documentation / DX

- **README**: Update to include all env vars and add a missing `ENV.example` file. Align endpoint docs with actual parameters (e.g., `type` in search).
- **Developer Tips**: Document how to obtain Spotify creds, and how to set Supabase project URL.

---

### Security Hardening

- Rate limiting for public endpoints (per-IP or per-token).
- Add request/response size limits.
- Validate Authorization header format strictly (`Bearer <token>`).
- Consider RBAC (host vs participant actions) once sessions/songs are implemented.

---

### Performance

- Uvicorn with `uvloop` and `httptools` is great. Consider `workers` configuration for deployment.
- JWKS caching is good; add TTL-based refresh and network timeouts.

---

### Prioritized Action Items

1. Fix `Settings` vs Spotify service mismatch (add fields or use `getattr` + env fallback).
2. Add `PyJWT` to `requirements.txt`; remove `dotenv` (keep `python-dotenv`).
3. Make `isrc` optional or enrich via an additional Spotify lookup to avoid response validation errors.
4. Adjust CORS: set explicit origins, or disable `allow_credentials` when using `*`.
5. Add timeouts and `iss` verification to JWT validation; consider lazy JWKS initialization.
6. Implement `type` query param in the Spotify search endpoint to match README.
7. Add basic unit/integration tests for auth and Spotify.
8. Provide `ENV.example` and expand README with env details and endpoint contracts.
9. Add retries/backoff for Spotify 429/5xx and log rate-limiting headers.

---

### Nice-to-Have Improvements

- Structured logging and request correlation IDs.
- Central error response schema for consistency.
- Simple app-level rate limiter (e.g., `slowapi`) on public endpoints.
- CI to run tests and linting; pre-commit hooks for formatting.

---

### Notable Code References

- Config Settings fields:

```12:23:/Users/darraghflynn/Desktop/codeAdventures/QueueIT/QueueITbackend/app/core/config.py
class Settings(BaseModel):
    app_name: str = "QueueIT API"
    environment: str = os.getenv("ENVIRONMENT", "development")
    debug: bool = environment != "production"

    supabase_url: str | None = os.getenv("SUPABASE_URL")
    supabase_public_anon_key: str | None = os.getenv("SUPABASE_PUBLIC_ANON_KEY")

    allowed_origins: List[str] = Field(
        default_factory=lambda: [o for o in os.getenv("ALLOWED_ORIGINS", "*").split(",") if o]
    )
```

- JWKS initialization & decode:

```64:69:/Users/darraghflynn/Desktop/codeAdventures/QueueIT/QueueITbackend/app/core/auth.py
# --- Create a single instance to be used by the app ---
# This line runs when the module is first imported.
jwk_manager = JWKSManager(JWK_URL)

# --- FastAPI Dependency ---
def verify_jwt(authorization: Optional[str] = Header(None)) -> Dict:
```

```88:94:/Users/darraghflynn/Desktop/codeAdventures/QueueIT/QueueITbackend/app/core/auth.py
decoded = jwt.decode(
    token,
    public_key,
    algorithms=["RS256", "ES256"], # Support both algs
    audience="authenticated",      # CRITICAL: Verify audience
)
```

- Spotify parse vs schema requirement for `isrc`:

```19:37:/Users/darraghflynn/Desktop/codeAdventures/QueueIT/QueueITbackend/app/api/v1/spotify.py
# Helper function to parse the complex Spotify response and fit it to our model
def parse_spotify_results(spotify_data: dict) -> SearchResults:
    items = spotify_data.get("tracks", {}).get("items", [])
    tracks = []
    for item in items:
        # Check if essential data is present
        if not item or not item.get("album"):
            continue

        tracks.append(
            TrackOut(
                id=item.get("id"),
                isrc=item.get("external_ids", {}).get("isrc"),
                name=item.get("name"),
                artists=' & '.join([artist["name"] for artist in item.get("artists", [])]),
                album=item.get("album", {}).get("name"),
                duration_ms=item.get("duration_ms"),
                image_url=item.get("album", {}).get("images", [{}])[0].get("url")
            )
        )
    return SearchResults(tracks=tracks)
```

```6:14:/Users/darraghflynn/Desktop/codeAdventures/QueueIT/QueueITbackend/app/schemas/track.py
class TrackOut(BaseModel):
    id: str = Field(..., description="Spotify track ID")
    isrc: str = Field(..., description="International Standard Recording Code")
    name: str = Field(..., description="Track title")
    artists: str = Field(..., description="Primary artists names in a & separated list")
    album: str = Field(..., description="Album name")
    duration_ms: int = Field(..., ge=0, description="Duration in milliseconds")
    image_url: Optional[HttpUrl] = Field(None, description="Album art URL (largest available)")
```

- Requirements anomalies:

```6:16:/Users/darraghflynn/Desktop/codeAdventures/QueueIT/QueueITbackend/requirements.txt
dotenv==0.9.9
fastapi==0.115.0
h11==0.16.0
httptools==0.7.1
idna==3.11
pydantic==2.8.2
pydantic_core==2.20.1
python-dotenv==1.0.1
PyYAML==6.0.3
requests==2.32.5
```

---

If you want, I can implement the quick fixes (Settings, schema optionality, requirements) in a small PR to unblock local runs, then follow with tests and docs.
