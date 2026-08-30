from uuid import uuid4

from fastapi.testclient import TestClient

from app.core.enums import UserRole
from app.core.password_rules import PASSWORD_RULE_MESSAGE, password_strength_error
from app.core.security import hash_password
from app.db.session import SessionLocal
from app.main import app
from app.models.user import User

client = TestClient(app)

STRONG = "VilleCare1!"


def _phone() -> str:
    return f"+2376{uuid4().hex[:8]}"


def test_password_rules_match_product() -> None:
    assert password_strength_error("motdepasse") is not None
    assert password_strength_error("VilleCare") is not None
    assert password_strength_error("villecare1!") is not None
    assert password_strength_error(STRONG) is None


def test_register_rejects_weak_password() -> None:
    response = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Faible",
            "phone": _phone(),
            "password": "motdepasse",
            "role": UserRole.PARENT.value,
        },
    )
    assert response.status_code == 422
    text = response.text.lower()
    assert "majuscule" in text or "spécial" in text or "password" in text


def test_register_accepts_strong_password() -> None:
    phone = _phone()
    response = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Fort",
            "phone": phone,
            "password": STRONG,
            "role": UserRole.PARENT.value,
        },
    )
    assert response.status_code == 200, response.text
    assert response.json()["access_token"]


def test_legacy_motdepasse_still_logs_in() -> None:
    phone = _phone()
    db = SessionLocal()
    try:
        db.add(
            User(
                full_name="Legacy Demo",
                phone=phone,
                password_hash=hash_password("motdepasse"),
                role=UserRole.PARENT,
                is_active=True,
            )
        )
        db.commit()
    finally:
        db.close()

    login = client.post("/api/v1/auth/login", json={"phone": phone, "password": "motdepasse"})
    assert login.status_code == 200, login.text
    body = login.json()
    assert body.get("otp_dev")
    verified = client.post(
        "/api/v1/auth/verify-otp",
        json={"challenge_id": body["challenge_id"], "code": body["otp_dev"]},
    )
    assert verified.status_code == 200, verified.text


def test_reset_rejects_weak_new_password() -> None:
    phone = _phone()
    created = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Reset Weak",
            "phone": phone,
            "password": STRONG,
            "role": UserRole.PARENT.value,
        },
    )
    assert created.status_code == 200
    forgot = client.post("/api/v1/auth/forgot-password", json={"phone": phone})
    assert forgot.status_code == 200
    reset = client.post(
        "/api/v1/auth/reset-password",
        json={
            "phone": phone,
            "code": forgot.json()["reset_code_dev"],
            "new_password": "motdepasse",
        },
    )
    assert reset.status_code == 422
    assert PASSWORD_RULE_MESSAGE.split()[0].lower() in reset.text.lower() or "majuscule" in reset.text.lower()
