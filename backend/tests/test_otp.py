from datetime import datetime, timedelta, timezone
from uuid import UUID, uuid4

from fastapi.testclient import TestClient

from app.core.config import settings
from app.core.enums import UserRole
from app.db.session import SessionLocal
from app.main import app
from app.models.otp import OtpChallenge

client = TestClient(app)


def _phone() -> str:
    return f"+2376{uuid4().hex[:8]}"


def _register(phone: str | None = None) -> dict:
    number = phone or _phone()
    response = client.post(
        "/api/v1/auth/register",
        json={"full_name": "Parent 2FA", "phone": number, "password": "VilleCare1!", "role": UserRole.PARENT.value},
    )
    assert response.status_code == 200, response.text
    body = response.json()
    body["_phone"] = number
    return body


def test_login_does_not_return_jwt() -> None:
    session = _register()
    response = client.post(
        "/api/v1/auth/login",
        json={"phone": session["_phone"], "password": "VilleCare1!"},
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert "access_token" not in body
    assert body["challenge_id"]
    assert body["expires_in"] <= settings.otp_ttl_seconds
    assert body["otp_dev"] is not None
    assert len(body["otp_dev"]) == 6
    assert body["otp_dev"].isdigit()
    assert "sms" in body["message"].lower()


def test_otp_is_hashed_in_database() -> None:
    session = _register()
    response = client.post(
        "/api/v1/auth/login",
        json={"phone": session["_phone"], "password": "VilleCare1!"},
    )
    body = response.json()
    db = SessionLocal()
    try:
        challenge = db.get(OtpChallenge, UUID(body["challenge_id"]))
        assert challenge is not None
        assert challenge.code_hash != body["otp_dev"]
        assert body["otp_dev"] not in challenge.code_hash
        assert len(challenge.code_hash) == 64
    finally:
        db.close()


def test_verify_otp_issues_access_token() -> None:
    session = _register()
    challenge = client.post(
        "/api/v1/auth/login",
        json={"phone": session["_phone"], "password": "VilleCare1!"},
    ).json()
    verified = client.post(
        "/api/v1/auth/verify-otp",
        json={"challenge_id": challenge["challenge_id"], "code": challenge["otp_dev"]},
    )
    assert verified.status_code == 200, verified.text
    token = verified.json()["access_token"]
    me = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me.status_code == 200
    assert me.json()["phone"] == session["_phone"]


def test_verify_otp_accepts_spaces_around_six_digits() -> None:
    session = _register()
    challenge = client.post(
        "/api/v1/auth/login",
        json={"phone": session["_phone"], "password": "VilleCare1!"},
    ).json()
    spaced = f" {challenge['otp_dev'][0:3]} {challenge['otp_dev'][3:6]} "
    verified = client.post(
        "/api/v1/auth/verify-otp",
        json={"challenge_id": challenge["challenge_id"], "code": spaced},
    )
    assert verified.status_code == 200, verified.text


def test_wrong_otp_is_rejected() -> None:
    session = _register()
    challenge = client.post(
        "/api/v1/auth/login",
        json={"phone": session["_phone"], "password": "VilleCare1!"},
    ).json()
    wrong = "000000" if challenge["otp_dev"] != "000000" else "111111"
    response = client.post(
        "/api/v1/auth/verify-otp",
        json={"challenge_id": challenge["challenge_id"], "code": wrong},
    )
    assert response.status_code == 401
    assert "incorrect" in response.json()["detail"].lower()


def test_otp_reuse_is_rejected() -> None:
    session = _register()
    challenge = client.post(
        "/api/v1/auth/login",
        json={"phone": session["_phone"], "password": "VilleCare1!"},
    ).json()
    payload = {"challenge_id": challenge["challenge_id"], "code": challenge["otp_dev"]}
    first = client.post("/api/v1/auth/verify-otp", json=payload)
    assert first.status_code == 200
    second = client.post("/api/v1/auth/verify-otp", json=payload)
    assert second.status_code == 401


def test_expired_otp_is_rejected() -> None:
    session = _register()
    challenge = client.post(
        "/api/v1/auth/login",
        json={"phone": session["_phone"], "password": "VilleCare1!"},
    ).json()
    db = SessionLocal()
    try:
        row = db.get(OtpChallenge, UUID(challenge["challenge_id"]))
        assert row is not None
        row.expires_at = datetime.now(timezone.utc) - timedelta(seconds=1)
        db.commit()
    finally:
        db.close()
    response = client.post(
        "/api/v1/auth/verify-otp",
        json={"challenge_id": challenge["challenge_id"], "code": challenge["otp_dev"]},
    )
    assert response.status_code == 401


def test_resend_is_rate_limited() -> None:
    session = _register()
    challenge = client.post(
        "/api/v1/auth/login",
        json={"phone": session["_phone"], "password": "VilleCare1!"},
    ).json()
    too_soon = client.post(
        "/api/v1/auth/resend-otp",
        json={"challenge_id": challenge["challenge_id"]},
    )
    assert too_soon.status_code == 429


def test_resend_after_cooldown_rotates_code() -> None:
    session = _register()
    first = client.post(
        "/api/v1/auth/login",
        json={"phone": session["_phone"], "password": "VilleCare1!"},
    ).json()
    db = SessionLocal()
    try:
        row = db.get(OtpChallenge, UUID(first["challenge_id"]))
        assert row is not None
        row.last_sent_at = datetime.now(timezone.utc) - timedelta(seconds=settings.otp_resend_seconds + 1)
        db.commit()
    finally:
        db.close()
    second = client.post(
        "/api/v1/auth/resend-otp",
        json={"challenge_id": first["challenge_id"]},
    )
    assert second.status_code == 200, second.text
    body = second.json()
    assert body["challenge_id"] == first["challenge_id"]
    assert body["otp_dev"] is not None
    old = client.post(
        "/api/v1/auth/verify-otp",
        json={"challenge_id": first["challenge_id"], "code": first["otp_dev"]},
    )
    if first["otp_dev"] != body["otp_dev"]:
        assert old.status_code == 401
    fresh = client.post(
        "/api/v1/auth/verify-otp",
        json={"challenge_id": first["challenge_id"], "code": body["otp_dev"]},
    )
    assert fresh.status_code == 200, fresh.text


def test_production_hides_otp_dev(monkeypatch) -> None:
    session = _register()
    monkeypatch.setattr(settings, "app_env", "production")
    response = client.post(
        "/api/v1/auth/login",
        json={"phone": session["_phone"], "password": "VilleCare1!"},
    )
    assert response.status_code == 200
    assert response.json().get("otp_dev") is None
