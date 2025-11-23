"""
Pytest configuration and fixtures for testing.
"""

import pytest
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture
def client():
    """
    Create a test client for the FastAPI application.
    """
    return TestClient(app)


@pytest.fixture
def mock_request_id():
    """
    Return a mock request ID for testing.
    """
    return "test-request-id-12345"

