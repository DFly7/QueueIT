# QueueIT Backend (FastAPI)

## Setup

1. Create and activate a virtualenv (optional if you use the existing one):

```bash
python3 -m venv venv
source venv/bin/activate
```

2. Install dependencies:

```bash
pip install -r requirements.txt
```

3. Environment variables:

- Copy `ENV.example` to `.env` and fill in values:

```bash
cp ENV.example .env
```

## Run

- Dev server with reload:

```bash
python main.py
```

- Or via uvicorn directly:

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## Endpoints

- Health: `GET /healthz`
- Ping: `GET /api/v1/ping`
- Spotify search: `GET /api/v1/spotify/search?q=<query>&type=track|artist|album|playlist&limit=5`

## Notes

- CORS allowed origins are controlled via `ALLOWED_ORIGINS` in `.env` (comma-separated), `*` to allow any.
- Requires Spotify `CLIENT_ID` and `CLIENT_SECRET` for the search endpoint.
