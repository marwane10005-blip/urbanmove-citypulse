from __future__ import annotations

import os
import threading
import time
from dataclasses import dataclass

import httpx
import structlog
from fastapi import Depends, HTTPException, Request, status
from jose import JWTError, jwk, jwt
from jose.utils import base64url_decode

log = structlog.get_logger(__name__)

@dataclass(frozen=True)
class User:
    sub: str
    email: str | None
    groups: tuple[str, ...]
    claims: dict

    def has_group(self, group: str) -> bool:
        return group in self.groups

_REGION = os.environ.get("COGNITO_REGION", "eu-west-3")
_POOL_ID = os.environ.get("COGNITO_USER_POOL_ID")
_CLIENT_ID = os.environ.get("COGNITO_APP_CLIENT_ID")
_SKIP_AUD_CHECK = os.environ.get("COGNITO_SKIP_AUD_CHECK") == "1"

_ISSUER: str | None = (
    f"https://cognito-idp.{_REGION}.amazonaws.com/{_POOL_ID}" if _POOL_ID else None
)
_JWKS_URL: str | None = f"{_ISSUER}/.well-known/jwks.json" if _ISSUER else None

_JWKS_TTL = 3600
_jwks_lock = threading.Lock()
_jwks_cache: dict = {}
_jwks_fetched_at: float = 0.0

def _refresh_jwks() -> dict:
    global _jwks_cache, _jwks_fetched_at
    if not _JWKS_URL:
        raise RuntimeError(
            "Cognito env vars not set. Populate COGNITO_USER_POOL_ID / "
            "COGNITO_APP_CLIENT_ID on the container."
        )
    r = httpx.get(_JWKS_URL, timeout=3.0)
    r.raise_for_status()
    _jwks_cache = {k["kid"]: k for k in r.json()["keys"]}
    _jwks_fetched_at = time.monotonic()
    return _jwks_cache

def _get_key(kid: str) -> dict:
    with _jwks_lock:
        stale = time.monotonic() - _jwks_fetched_at > _JWKS_TTL
        if not _jwks_cache or stale or kid not in _jwks_cache:
            _refresh_jwks()
        key = _jwks_cache.get(kid)
        if not key:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="unknown signing key",
            )
        return key

def _verify_signature(token: str, key_dict: dict) -> None:
    public_key = jwk.construct(key_dict)
    message, _, encoded_signature = token.rpartition(".")
    decoded_signature = base64url_decode(encoded_signature.encode("utf-8"))
    if not public_key.verify(message.encode("utf-8"), decoded_signature):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="signature verification failed",
        )

def _extract_bearer(request: Request) -> str:
    header = request.headers.get("authorization") or request.headers.get("Authorization")
    if not header or not header.lower().startswith("bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="missing bearer token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return header.split(" ", 1)[1].strip()

def current_user(request: Request) -> User:
    token = _extract_bearer(request)
    try:
        unverified_headers = jwt.get_unverified_headers(token)
        claims = jwt.get_unverified_claims(token)
    except JWTError as exc:
        raise HTTPException(status_code=401, detail=f"malformed token: {exc}") from exc

    _verify_signature(token, _get_key(unverified_headers["kid"]))

    if claims.get("iss") != _ISSUER:
        raise HTTPException(status_code=401, detail="issuer mismatch")
    if claims.get("token_use") not in ("access", "id"):
        raise HTTPException(status_code=401, detail="unexpected token_use")
    if claims.get("exp", 0) < time.time():
        raise HTTPException(status_code=401, detail="token expired")
    if not _SKIP_AUD_CHECK and _CLIENT_ID:

        if claims.get("client_id") != _CLIENT_ID and claims.get("aud") != _CLIENT_ID:
            raise HTTPException(status_code=401, detail="client id mismatch")

    groups = tuple(claims.get("cognito:groups", []) or [])
    return User(
        sub=claims["sub"],
        email=claims.get("email"),
        groups=groups,
        claims=claims,
    )

def require_group(group: str):

    def _guard(user: User = Depends(current_user)) -> User:
        if not user.has_group(group):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"missing group: {group}",
            )
        return user

    return _guard
