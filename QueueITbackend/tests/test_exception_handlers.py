"""
Tests for centralized exception handlers.
"""

import pytest
from fastapi import FastAPI, HTTPException, Request
from fastapi.testclient import TestClient

from app.exception_handlers import register_exception_handlers


@pytest.fixture
def test_app():
    """Create a test FastAPI app with exception handlers."""
    app = FastAPI()
    register_exception_handlers(app)
    
    # Add test routes
    @app.get("/test-404")
    def test_404():
        raise HTTPException(status_code=404, detail="Not found")
    
    @app.get("/test-500")
    def test_500():
        raise Exception("Internal server error")
    
    @app.post("/test-validation")
    def test_validation(value: int):
        return {"value": value}
    
    return app


@pytest.fixture
def test_client(test_app):
    """Create test client."""
    return TestClient(test_app)


class TestHTTPExceptionHandler:
    """Tests for HTTP exception handler."""
    
    def test_404_returns_structured_error(self, test_client):
        """Test that 404 errors return structured JSON response."""
        response = test_client.get("/test-404")
        
        assert response.status_code == 404
        
        data = response.json()
        assert "error" in data
        assert "status_code" in data
        assert "request_id" in data
        assert data["status_code"] == 404
        
        # Check X-Request-ID header
        assert "X-Request-ID" in response.headers
        assert response.headers["X-Request-ID"] == data["request_id"]
    
    def test_http_exception_logs_error(self, test_client, caplog):
        """Test that HTTP exceptions are logged."""
        with caplog.at_level("WARNING"):
            response = test_client.get("/test-404")
        
        assert response.status_code == 404


class TestValidationExceptionHandler:
    """Tests for validation exception handler."""
    
    def test_validation_error_returns_422(self, test_client):
        """Test that validation errors return 422 status."""
        # Send invalid data (string instead of int)
        response = test_client.post(
            "/test-validation?value=invalid"
        )
        
        assert response.status_code == 422
        
        data = response.json()
        assert "error" in data
        assert "detail" in data
        assert "request_id" in data
        assert data["status_code"] == 422
    
    def test_validation_error_includes_field_details(self, test_client):
        """Test that validation errors include field-level details."""
        response = test_client.post("/test-validation?value=not-an-int")
        
        assert response.status_code == 422
        
        data = response.json()
        assert "detail" in data
        assert isinstance(data["detail"], list)


class TestUnhandledExceptionHandler:
    """Tests for unhandled exception handler."""
    
    def test_unhandled_exception_returns_500(self, test_client):
        """Test that unhandled exceptions return 500 status."""
        response = test_client.get("/test-500")
        
        assert response.status_code == 500
        
        data = response.json()
        assert "error" in data
        assert data["error"] == "Internal server error"
        assert "request_id" in data
        assert data["status_code"] == 500
    
    def test_unhandled_exception_logs_with_traceback(self, test_client, caplog):
        """Test that unhandled exceptions are logged with full traceback."""
        with caplog.at_level("ERROR"):
            response = test_client.get("/test-500")
        
        assert response.status_code == 500
        
        # Check that error was logged
        error_logs = [r for r in caplog.records if r.levelname == "ERROR"]
        assert len(error_logs) > 0
    
    def test_exception_does_not_leak_internals(self, test_client):
        """Test that exception details are not leaked to client."""
        response = test_client.get("/test-500")
        
        data = response.json()
        
        # Should return generic error message, not exception details
        assert data["error"] == "Internal server error"
        assert "traceback" not in data
        assert "Exception" not in data["error"]

