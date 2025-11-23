from __future__ import annotations

import json
import os
import sys

import pytest
import structlog

sys.path.append(os.path.dirname(os.path.dirname(__file__)))
from fastapi import BackgroundTasks, FastAPI, HTTPException, Request
from fastapi.testclient import TestClient

from app.exception_handlers import install_exception_handlers
from app.logging_config import configure_logging
from app.middleware import AccessLogMiddleware, RequestIDMiddleware
from app.utils.log_context import bind_background_task, get_request_id


@pytest.fixture(autouse=True)
def _configure_logging():
    configure_logging(force_reconfigure=True, testing=True, json_logs=True)


def _build_test_app() -> FastAPI:
    app = FastAPI()
    app.add_middleware(AccessLogMiddleware, metrics_enabled=False)
    app.add_middleware(RequestIDMiddleware)
    install_exception_handlers(app)

    @app.get("/ping")
    def ping(request: Request):
        return {"ok": True, "request_id": getattr(request.state, "request_id", None)}

    @app.get("/boom")
    def boom():
        raise HTTPException(status_code=400, detail="nope")

    @app.get("/crash")
    def crash():
        raise ValueError("kaboom")

    @app.post("/bg")
    def trigger_background(background_tasks: BackgroundTasks):
        logger = structlog.get_logger("tests.background")

        def worker():
            logger.info("background.test.log", observed_request_id=get_request_id())

        background_tasks.add_task(bind_background_task(worker))
        return {"ok": True}

    return app


def _parse_log(record) -> dict:
    return json.loads(record.message)


def _build_client() -> TestClient:
    app = _build_test_app()
    return TestClient(app, raise_server_exceptions=False)


def test_request_id_header_added():
    client = _build_client()

    response = client.get("/ping")
    assert response.status_code == 200
    header_value = response.headers.get("X-Request-ID")
    assert header_value
    assert response.json()["request_id"] == header_value


def test_request_id_respects_incoming_header():
    client = _build_client()

    response = client.get("/ping", headers={"X-Request-ID": "abc-123"})
    assert response.headers["X-Request-ID"] == "abc-123"
    assert response.json()["request_id"] == "abc-123"


def test_access_log_contains_enriched_fields(caplog):
    client = _build_client()

    with caplog.at_level("INFO"):
        client.get("/ping")

    access_record = next(r for r in caplog.records if "request.completed" in r.message)
    payload = _parse_log(access_record)
    assert payload["event"] == "request.completed"
    assert payload["method"] == "GET"
    assert payload["route"] == "/ping"
    assert payload["status"] == 200
    assert "request_id" in payload


def test_exception_handler_adds_request_id_header(caplog):
    client = _build_client()

    with caplog.at_level("WARNING"):
        response = client.get("/boom")

    assert response.status_code == 400
    assert response.headers.get("X-Request-ID")
    exception_record = next(r for r in caplog.records if "http_exception" in r.message)
    payload = _parse_log(exception_record)
    assert payload["event"] == "http_exception"
    assert payload["status"] == 400
    assert payload["request_id"] == response.headers["X-Request-ID"]


def test_unhandled_exception_logs_stack(caplog):
    client = _build_client()

    with caplog.at_level("ERROR"):
        response = client.get("/crash")

    assert response.status_code == 500
    error_record = next(r for r in caplog.records if "unhandled_exception" in r.message)
    payload = _parse_log(error_record)
    assert payload["event"] == "unhandled_exception"
    assert payload["error_type"] == "ValueError"


def test_background_task_inherits_request_id(caplog):
    client = _build_client()

    with caplog.at_level("INFO"):
        response = client.post("/bg")

    assert response.status_code == 200
    bg_record = next(r for r in caplog.records if "background.test.log" in r.message)
    payload = _parse_log(bg_record)
    assert payload["observed_request_id"] == payload["request_id"]

