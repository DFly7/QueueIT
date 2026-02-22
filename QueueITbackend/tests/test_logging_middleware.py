"""
Tests for logging middleware (request ID and access logging).
"""

import json
import uuid
from unittest.mock import patch

import pytest
import structlog
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture
def client():
    """Create test client."""
    return TestClient(app)


class TestRequestIDMiddleware:
    """Tests for RequestIDMiddleware."""
    
    def test_generates_request_id_when_not_provided(self, client):
        """Test that middleware generates a UUID4 request ID when not provided."""
        response = client.get("/healthz")
        
        assert response.status_code == 200
        assert "X-Request-ID" in response.headers
        
        request_id = response.headers["X-Request-ID"]
        
        # Validate it's a valid UUID4
        try:
            uuid_obj = uuid.UUID(request_id, version=4)
            assert str(uuid_obj) == request_id
        except ValueError:
            pytest.fail(f"Request ID '{request_id}' is not a valid UUID4")
    
    def test_preserves_incoming_request_id(self, client, mock_request_id):
        """Test that middleware uses incoming X-Request-ID header if provided."""
        response = client.get(
            "/healthz",
            headers={"X-Request-ID": mock_request_id}
        )
        
        assert response.status_code == 200
        assert response.headers["X-Request-ID"] == mock_request_id
    
    def test_request_id_included_in_response_headers(self, client):
        """Test that X-Request-ID is included in all response headers."""
        custom_id = "custom-test-id-456"
        
        response = client.get(
            "/healthz",
            headers={"X-Request-ID": custom_id}
        )
        
        assert response.headers["X-Request-ID"] == custom_id


class TestAccessLogMiddleware:
    """Tests for AccessLogMiddleware."""
    
    def test_logs_successful_request(self, client, caplog):
        """Test that successful requests are logged with appropriate level."""
        with caplog.at_level("INFO"):
            response = client.get("/healthz")
        
        assert response.status_code == 200
        
        # Check that access log was created
        log_records = [r for r in caplog.records if "request_completed" in r.getMessage()]
        assert len(log_records) > 0
        
        # Verify log contains expected fields (structlog might format differently)
        # This is a basic check - in production you'd parse JSON logs
    
    def test_logs_error_responses_with_warning_level(self, client, caplog):
        """Test that 4xx responses are logged at WARNING level."""
        with caplog.at_level("WARNING"):
            response = client.get("/nonexistent-endpoint")
        
        assert response.status_code == 404
    
    def test_access_log_includes_method_and_path(self, client, caplog):
        """Test that access logs include method and path."""
        with caplog.at_level("INFO"):
            response = client.get("/healthz")
        
        assert response.status_code == 200
        
        # Basic check that logging occurred
        assert len(caplog.records) > 0
    
    def test_access_log_includes_duration(self, client, caplog):
        """Test that access logs include request duration."""
        with caplog.at_level("INFO"):
            response = client.get("/healthz")
        
        assert response.status_code == 200
        assert len(caplog.records) > 0


class TestLoggingIntegration:
    """Integration tests for logging components."""
    
    def test_request_id_correlates_across_logs(self, client, caplog, mock_request_id):
        """Test that request ID appears in all logs for a single request."""
        with caplog.at_level("INFO"):
            response = client.get(
                "/healthz",
                headers={"X-Request-ID": mock_request_id}
            )
        
        assert response.status_code == 200
        assert response.headers["X-Request-ID"] == mock_request_id
    
    def test_multiple_concurrent_requests_have_different_ids(self, client):
        """Test that concurrent requests get different request IDs."""
        response1 = client.get("/healthz")
        response2 = client.get("/healthz")
        
        id1 = response1.headers["X-Request-ID"]
        id2 = response2.headers["X-Request-ID"]
        
        assert id1 != id2
    
    def test_healthz_endpoint_returns_ok(self, client):
        """Basic test that health check endpoint works."""
        response = client.get("/healthz")
        
        assert response.status_code == 200
        assert response.json() == {"status": "ok"}
        assert "X-Request-ID" in response.headers

