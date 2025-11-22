# app/core/auth.py

from fastapi import Header, HTTPException, Depends
from typing import Optional, Dict
import jwt
import requests
from app.core.config import get_settings
from supabase import create_client, Client
from typing import TypedDict, Any
from pydantic import BaseModel


class AuthenticatedClient(BaseModel):
    client: Client
    payload: dict  # This is the auth_data["payload"]

    class Config:
        arbitrary_types_allowed = True # Needed to allow the 'Client' type


class AuthData(TypedDict):
    """Defines the structure of the verified auth data."""
    token: str
    payload: Dict[str, Any]

# --- Configuration ---
settings = get_settings()
JWK_URL = f"{settings.supabase_url}/auth/v1/.well-known/jwks.json"

class JWKSManager:
    """
    Manages fetching and caching Supabase's JSON Web Keys (JWKs).

    This class fetches JWKs on startup and then only refetches them
    if it encounters a Key ID (kid) it doesn't have in its cache.
    """
    def __init__(self, jwk_url: str):
        self.jwk_url = jwk_url
        self.jwks: Dict = {"keys": []}
        # Fetch keys on application startup
        self.fetch_jwks()

    def fetch_jwks(self):
        """Fetches the JWKs from Supabase and updates the internal cache."""
        try:
            response = requests.get(self.jwk_url)
            response.raise_for_status()
            self.jwks = response.json()
        except requests.exceptions.RequestException as e:
            # If fetching fails, we'll keep the old cache.
            # If the cache is empty, we must raise an error.
            if not self.jwks["keys"]:
                raise RuntimeError(f"Could not fetch JWKs on startup: {e}")

    def get_public_key(self, kid: str):
        """
        Finds a specific public key (by 'kid') in our cache.
        Refreshes cache if 'kid' is not found.
        """
        key = next((k for k in self.jwks["keys"] if k["kid"] == kid), None)

        if not key:
            # Key not found. Refresh cache and try one more time.
            self.fetch_jwks()
            key = next((k for k in self.jwks["keys"] if k["kid"] == kid), None)

            if not key:
                # If still not found, the token's kid is invalid
                raise HTTPException(status_code=401, detail="Invalid Key ID (kid)")

        try:
            if key['kty'] == 'RSA':
                return jwt.algorithms.RSAAlgorithm.from_jwk(key)
            elif key['kty'] == 'EC':
                return jwt.algorithms.ECAlgorithm.from_jwk(key)
            else:
                raise HTTPException(status_code=401, detail=f"Unsupported key type: {key['kty']}")
        except Exception as e:
            raise HTTPException(status_code=401, detail=f"Failed to parse key: {e}")

# --- Create a single instance to be used by the app ---
# This line runs when the module is first imported.
jwk_manager = JWKSManager(JWK_URL)

# --- FastAPI Dependency ---
def verify_jwt(authorization: Optional[str] = Header(None)) -> Dict:
    """
    Verifies Supabase JWT using the JWKSManager.
    This is the dependency that will be used in your routers.
    """
    print(f"[DEBUG] Verifying JWT: {authorization}")
    if not authorization:
        raise HTTPException(status_code=401, detail="Missing Authorization header")

    try:
        token = authorization.replace("Bearer ", "")
        
        # 1. Get the 'kid' from the unverified token header
        header = jwt.get_unverified_header(token)
        kid = header["kid"]

        # 2. Get the public key from our manager instance
        public_key = jwk_manager.get_public_key(kid)

        # 3. Verify and decode the token
        decoded = jwt.decode(
            token,
            public_key,
            algorithms=["RS256", "ES256"], # Support both algs
            audience="authenticated",      # CRITICAL: Verify audience
        )
        return {"token": token, "payload": decoded}   

    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError as e:
        raise HTTPException(status_code=401, detail=f"Invalid token: {e}")
    except HTTPException as e:
        # Re-raise HTTPExceptions (like "Invalid Kid")
        raise e
    except Exception as e:
        # Catch-all for other errors
        raise HTTPException(status_code=401, detail=f"Token verification failed: {e}")


# --- FastAPI Dependency: Get User-Specific Supabase Client ---
def get_supabase_client_as_user(
    auth_data: AuthData = Depends(verify_jwt)
) -> Client:
    """
    FastAPI dependency that provides a Supabase client
    authenticated as the user from their JWT.
    
    RLS is enforced on all queries made with this client.
    """

    user_id = auth_data["payload"]["sub"]

    # You can also get other details from the token
    user_email = auth_data["payload"].get("email")
    user_role = auth_data["payload"].get("role")

    print(f"User ID: {user_id}")
    print(f"User Email: {user_email}")
    print(f"User Role: {user_role}")

    supabase = create_client(
        settings.supabase_url,
        settings.supabase_public_anon_key 
    )
    
    supabase.postgrest.auth(auth_data["token"])
    
    return supabase



def get_authenticated_client(
    auth_data: AuthData = Depends(verify_jwt)
) -> AuthenticatedClient:
    """
    FastAPI dependency that provides both the user-authenticated
    Supabase client and the user's JWT payload.
    """
    user_id = auth_data["payload"]["sub"]
    user_email = auth_data["payload"].get("email")
    print(f"Authenticated client for user: {user_email} ({user_id})")

    supabase = create_client(
        settings.supabase_url,
        settings.supabase_public_anon_key 
    )
    
    # Authenticate the client for RLS
    supabase.postgrest.auth(auth_data["token"])
    
    # Return the client and the payload in one object
    return AuthenticatedClient(
        client=supabase, 
        payload=auth_data["payload"]
    )