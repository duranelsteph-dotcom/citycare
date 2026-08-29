from datetime import datetime, timedelta, timezone
from uuid import uuid4

import jwt
import pytest
from fastapi.testclient import TestClient

from app.core.config import settings
from app.core.enums import UserRole
from app.core.security import INSECURE_DEFAULT_SECRET, assert_runtime_security
from app.main import app

client = TestClient(app)


def _phone() -> str:
    return f"+2376{uuid4().hex[:8]}"


def _register(role: UserRole = UserRole.PARENT) -> dict:
    phone = _phone()
    response = client.post(
        "/api/v1/auth/register",
        json={"full_name": "Sec Test", "phone": phone, "password": "motdepasse", "role": role.value},
    )
    assert response.status_code == 200, response.text
    body = response.json()
    body["_phone"] = phone
    return body


def test_security_headers_on_health() -> None:
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    assert response.json()["version"] == "0.34.0"
    assert response.headers["x-content-type-options"] == "nosniff"
    assert response.headers["x-frame-options"] == "DENY"
    assert "no-store" in response.headers["cache-control"]


def test_security_status_exposes_no_secret() -> None:
    response = client.get("/api/v1/security")
    assert response.status_code == 200, response.text
    body = response.json()
    assert "secret_key" not in body
    assert body["passwords_hashed"] is True
    assert body["kit_secrets_hashed"] is True
    assert body["jwt_in_query_forbidden"] is True
    assert body["default_parent_live_location"] is False
    assert body["database_dialect"] in {"sqlite", "postgresql"}
    assert body["fcm_configured"] is False
    assert "https" in body["tls_note"].lower()
    assert "kidnapping" in body["disclaimer"].lower()
    dumped = str(body).lower()
    assert INSECURE_DEFAULT_SECRET not in dumped
    assert settings.secret_key not in dumped


def test_token_rejected_in_query_string() -> None:
    session = _register()
    response = client.get(f"/api/v1/auth/me?access_token={session['access_token']}")
    assert response.status_code == 400
    assert "url" in response.json()["detail"].lower()


def test_me_rejects_tampered_jwt() -> None:
    session = _register()
    token = session["access_token"]
    tampered = token[:-4] + ("AAAA" if not token.endswith("AAAA") else "BBBB")
    response = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {tampered}"})
    assert response.status_code == 401


def test_me_rejects_expired_jwt() -> None:
    session = _register()
    user_id = session["user"]["id"]
    expired = jwt.encode(
        {
            "sub": user_id,
            "role": "PARENT",
            "typ": "access",
            "iss": settings.jwt_issuer,
            "exp": datetime.now(timezone.utc) - timedelta(minutes=1),
            "iat": datetime.now(timezone.utc) - timedelta(hours=1),
        },
        settings.secret_key,
        algorithm=settings.jwt_algorithm,
    )
    response = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {expired}"})
    assert response.status_code == 401


def test_me_rejects_token_without_typ() -> None:
    session = _register()
    bare = jwt.encode(
        {
            "sub": session["user"]["id"],
            "role": "PARENT",
            "iss": settings.jwt_issuer,
            "exp": datetime.now(timezone.utc) + timedelta(hours=1),
            "iat": datetime.now(timezone.utc),
        },
        settings.secret_key,
        algorithm=settings.jwt_algorithm,
    )
    response = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {bare}"})
    assert response.status_code == 401


def test_location_requires_auth() -> None:
    response = client.get("/api/v1/locations/me/latest")
    assert response.status_code == 401


def test_login_same_message_unknown_or_wrong_password() -> None:
    phone = _phone()
    client.post(
        "/api/v1/auth/register",
        json={"full_name": "Login Sec", "phone": phone, "password": "motdepasse", "role": UserRole.PARENT.value},
    )
    unknown = client.post("/api/v1/auth/login", json={"phone": _phone(), "password": "motdepasse"})
    wrong = client.post("/api/v1/auth/login", json={"phone": phone, "password": "incorrect1"})
    assert unknown.status_code == 401
    assert wrong.status_code == 401
    assert unknown.json()["detail"] == wrong.json()["detail"]
    assert "incorrect" in unknown.json()["detail"].lower()


def test_short_password_rejected() -> None:
    response = client.post(
        "/api/v1/auth/register",
        json={"full_name": "Court", "phone": _phone(), "password": "abc", "role": UserRole.PARENT.value},
    )
    assert response.status_code == 422


def test_failed_logins_are_rate_limited() -> None:
    phone = _phone()
    client.post(
        "/api/v1/auth/register",
        json={"full_name": "Rate Sec", "phone": phone, "password": "motdepasse", "role": UserRole.PARENT.value},
    )
    last = None
    for _ in range(settings.login_fail_max):
        last = client.post("/api/v1/auth/login", json={"phone": phone, "password": "incorrect1"})
        assert last.status_code == 401
    blocked = client.post("/api/v1/auth/login", json={"phone": phone, "password": "incorrect1"})
    assert blocked.status_code == 429


def test_production_rejects_default_secret(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(settings, "app_env", "production")
    monkeypatch.setattr(settings, "secret_key", INSECURE_DEFAULT_SECRET)
    monkeypatch.setattr(settings, "https_only", True)
    with pytest.raises(RuntimeError, match="SECRET_KEY"):
        assert_runtime_security()


def test_production_requires_https_only(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(settings, "app_env", "production")
    monkeypatch.setattr(settings, "secret_key", "a" * 32)
    monkeypatch.setattr(settings, "https_only", False)
    with pytest.raises(RuntimeError, match="HTTPS"):
        assert_runtime_security()


def test_valid_token_still_works() -> None:
    session = _register()
    me = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {session['access_token']}"})
    assert me.status_code == 200
    payload = jwt.decode(
        session["access_token"],
        settings.secret_key,
        algorithms=[settings.jwt_algorithm],
        issuer=settings.jwt_issuer,
    )
    assert payload["typ"] == "access"
