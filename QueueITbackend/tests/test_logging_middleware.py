import pytest
import logging
from httpx import AsyncClient, ASGITransport
import structlog
from app.main import app
from app.logging_config import configure_logging

# Ensure logging is configured
configure_logging()

@pytest.mark.asyncio
async def test_request_id_header():
    """Verify X-Request-ID header is present in response"""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        response = await ac.get("/healthz")
    
    assert response.status_code == 200
    assert "X-Request-ID" in response.headers
    assert len(response.headers["X-Request-ID"]) > 0

@pytest.mark.asyncio
async def test_access_log_generated(caplog):
    """Verify access logs are generated with expected fields"""
    # Set to capture INFO
    caplog.set_level(logging.INFO)
    
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        # Request a non-healthz endpoint to ensure access log middleware logs it
        # (Assuming /healthz is filtered out or logged at debug, but here we check a 404)
        response = await ac.get("/api/v1/non-existent-endpoint-for-logging-test")
    
    assert response.status_code == 404
    
    # Search for the access log message
    found = False
    for record in caplog.records:
        if "request_completed" in str(record.msg) or "request_completed" in str(record.message):
            # Check for context fields
            # Note: structlog formatting in tests might put fields in the message string
            msg = str(record.message)
            if "status=404" in msg or "'status': 404" in msg:
                 found = True
                 break
    
    assert found, "Access log for 404 request not found in caplog"

@pytest.mark.asyncio
async def test_request_id_propagation_to_logs(caplog):
    """Verify request_id is present in the logs"""
    caplog.set_level(logging.INFO)
    
    custom_id = "test-request-id-123"
    
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        response = await ac.get("/api/v1/non-existent", headers={"X-Request-ID": custom_id})
        
    assert response.headers["X-Request-ID"] == custom_id
    
    # Check logs for this ID
    found_id = False
    for record in caplog.records:
        if custom_id in str(record.message) or getattr(record, "request_id", "") == custom_id:
            found_id = True
            break
            
    assert found_id, f"Request ID {custom_id} not found in logs"

