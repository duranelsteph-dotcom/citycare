from uuid import uuid4

from fastapi.testclient import TestClient

from app.core.enums import UserRole
from app.main import app

client = TestClient(app)


def _phone() -> str:
    return f"+2376{uuid4().hex[:8]}"


def test_register_young_and_me() -> None:
    phone = _phone()
    response = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Amina Test",
            "phone": phone,
            "password": "motdepasse",
            "role": UserRole.YOUNG.value,
        },
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["token_type"] == "bearer"
    assert body["user"]["role"] == "YOUNG"
    assert body["user"]["young_person_id"] is not None

    me = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {body['access_token']}"})
    assert me.status_code == 200
    assert me.json()["phone"] == phone


def test_register_parent_has_no_young_profile() -> None:
    response = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Parent Test",
            "phone": _phone(),
            "password": "motdepasse",
            "role": UserRole.PARENT.value,
        },
    )
    assert response.status_code == 200, response.text
    assert response.json()["user"]["young_person_id"] is None


def test_login_rejects_bad_password() -> None:
    phone = _phone()
    client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Login Test",
            "phone": phone,
            "password": "motdepasse",
            "role": UserRole.PARENT.value,
        },
    )
    response = client.post("/api/v1/auth/login", json={"phone": phone, "password": "incorrect1"})
    assert response.status_code == 401


def test_me_requires_token() -> None:
    response = client.get("/api/v1/auth/me")
    assert response.status_code == 401
