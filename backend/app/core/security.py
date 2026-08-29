from datetime import datetime, timedelta, timezone
from uuid import UUID

import bcrypt
import jwt
from jwt.exceptions import InvalidTokenError

from app.core.config import settings

_BCRYPT_MAX_BYTES = 72
INSECURE_DEFAULT_SECRET = "change-me-in-local-env-not-in-source"
ACCESS_TOKEN_TYPE = "access"


def hash_password(password: str) -> str:
    payload = password.encode("utf-8")
    if len(payload) > _BCRYPT_MAX_BYTES:
        raise ValueError("Password is too long")
    return bcrypt.hashpw(payload, bcrypt.gensalt(rounds=12)).decode("utf-8")


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return bcrypt.checkpw(password.encode("utf-8"), password_hash.encode("utf-8"))
    except ValueError:
        return False


def assert_runtime_security() -> None:
    """Refuse a default or short JWT secret outside local development."""
    if not settings.is_production:
        return
    secret = settings.secret_key or ""
    if secret == INSECURE_DEFAULT_SECRET or len(secret) < 32:
        raise RuntimeError(
            "SECRET_KEY trop faible pour la production. "
            "Définir via l'environnement, jamais dans le code source."
        )
    if settings.https_only is False:
        raise RuntimeError(
            "HTTPS_ONLY doit être activé en production. "
            "Le TLS est attendu sur le reverse proxy ; cette API n'implémente pas HTTPS elle-même."
        )


def create_access_token(*, user_id: UUID, role: str) -> str:
    now = datetime.now(timezone.utc)
    expire = now + timedelta(minutes=settings.access_token_expire_minutes)
    payload = {
        "sub": str(user_id),
        "role": role,
        "typ": ACCESS_TOKEN_TYPE,
        "iss": settings.jwt_issuer,
        "exp": expire,
        "iat": now,
    }
    return jwt.encode(payload, settings.secret_key, algorithm=settings.jwt_algorithm)


def decode_access_token(token: str) -> dict:
    payload = jwt.decode(
        token,
        settings.secret_key,
        algorithms=[settings.jwt_algorithm],
        issuer=settings.jwt_issuer,
    )
    if payload.get("typ") != ACCESS_TOKEN_TYPE:
        raise InvalidTokenError("Type de jeton invalide")
    return payload


InvalidTokenError = InvalidTokenError
