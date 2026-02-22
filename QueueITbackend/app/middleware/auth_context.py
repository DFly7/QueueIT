"""
Auth context middleware to extract user details from JWT and set in request state.

This middleware runs before access logging to ensure user_id and user_email
are available in request.state for logging purposes.
"""

from typing import Callable, Optional

import jwt
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

import structlog

logger = structlog.get_logger(__name__)


class AuthContextMiddleware(BaseHTTPMiddleware):
    """
    Middleware to extract user context from JWT and set in request.state.
    
    This middleware does NOT enforce authentication (that's done by dependencies).
    It only extracts user details when present for logging purposes.
    
    Sets in request.state:
    - user_id: User ID from JWT 'sub' claim
    - user_email: User email from JWT 'email' claim
    - user_role: User role from JWT 'role' claim
    """
    
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        # Try to extract user details from Authorization header
        auth_header = request.headers.get("Authorization")
        
        if auth_header and auth_header.startswith("Bearer "):
            try:
                token = auth_header.replace("Bearer ", "")
                
                # Decode WITHOUT verification (just to extract claims for logging)
                # Actual verification happens in auth dependencies
                decoded = jwt.decode(
                    token,
                    options={"verify_signature": False},  # Don't verify here
                )
                
                # Extract user details
                user_id = decoded.get("sub")
                user_email = decoded.get("email")
                user_role = decoded.get("role")
                
                # Set in request state for logging
                if user_id:
                    request.state.user_id = user_id
                if user_email:
                    request.state.user_email = user_email
                if user_role:
                    request.state.user_role = user_role
                
            except Exception as exc:
                # If token is malformed, just skip - auth dependency will handle it
                logger.debug(
                    "failed_to_extract_user_context",
                    error=type(exc).__name__,
                )
        
        # Continue processing request
        response = await call_next(request)
        return response

