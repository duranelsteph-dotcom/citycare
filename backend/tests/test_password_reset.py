from uuid import UUID, uuid4

from fastapi.testclient import TestClient

from app.core.config import settings
from app.core.enums import UserRole
from app.db.session import SessionLocal
from app.main import app
from app.models.password_reset import PasswordResetChallenge

client = TestClient(app)


def _phone() -> str:
    return f"+2376{uuid4().hex[:8]}"


def _register(phone: str | None = None, password: str = "VilleCare1!") -> dict:
    number = phone or _phone()
    response = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Reset Test",
            "phone": number,
            "password": password,
            "role": UserRole.PARENT.value,
        },
    )
    assert response.status_code == 200, response.text
    body = response.json()
    body["_phone"] = number
    return body


def test_forgot_unknown_phone_does_not_leak() -> None:
    known_phone = _phone()
    _register(known_phone)
    known = client.post("/api/v1/auth/forgot-password", json={"phone": known_phone})
    unknown = client.post("/api/v1/auth/forgot-password", json={"phone": _phone()})
    assert known.status_code == 200, known.text
    assert unknown.status_code == 200, unknown.text
    known_body = known.json()
    unknown_body = unknown.json()
    assert known_body["message"] == unknown_body["message"]
    assert set(known_body.keys()) == set(unknown_body.keys())
    assert "introuvable" not in unknown_body["message"].lower()
    assert "inconnu" not in unknown_body["message"].lower()
    assert known_body["reset_code_dev"] is not None
    assert unknown_body["reset_code_dev"] is not None
    assert len(unknown_body["reset_code_dev"]) == 6
    leaked = client.post(
        "/api/v1/auth/reset-password",
        json={
            "phone": known_phone,
            "code": unknown_body["reset_code_dev"],
            "new_password": "NouveauPass1!",
        },
    )
    if unknown_body["reset_code_dev"] != known_body["reset_code_dev"]:
        assert leaked.status_code == 400


def test_reset_wrong_code_is_400() -> None:
    session = _register()
    forgot = client.post("/api/v1/auth/forgot-password", json={"phone": session["_phone"]})
    assert forgot.status_code == 200
    real = forgot.json()["reset_code_dev"]
    wrong = "000000" if real != "000000" else "111111"
    response = client.post(
        "/api/v1/auth/reset-password",
        json={"phone": session["_phone"], "code": wrong, "new_password": "NouveauPass1!"},
    )
    assert response.status_code == 400
    assert "invalide" in response.json()["detail"].lower()


def test_reset_succeeds_and_old_password_fails() -> None:
    session = _register(password="AncienPass1!")
    old_token = session["access_token"]
    forgot = client.post("/api/v1/auth/forgot-password", json={"phone": session["_phone"]})
    assert forgot.status_code == 200
    code = forgot.json()["reset_code_dev"]
    assert code is not None
    db = SessionLocal()
    try:
        rows = db.query(PasswordResetChallenge).all()
        assert any(row.code_hash != code and code not in row.code_hash for row in rows)
        hashed = db.get(PasswordResetChallenge, UUID(str(rows[-1].id)))
        assert hashed is not None
        assert len(hashed.code_hash) == 64
    finally:
        db.close()

    reset = client.post(
        "/api/v1/auth/reset-password",
        json={"phone": session["_phone"], "code": code, "new_password": "NouveauPass1!"},
    )
    assert reset.status_code == 200, reset.text
    assert "reconnectez" in reset.json()["message"].lower()

    old_login = client.post(
        "/api/v1/auth/login",
        json={"phone": session["_phone"], "password": "AncienPass1!"},
    )
    assert old_login.status_code == 401

    me = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {old_token}"})
    assert me.status_code == 401

    challenge = client.post(
        "/api/v1/auth/login",
        json={"phone": session["_phone"], "password": "NouveauPass1!"},
    )
    assert challenge.status_code == 200, challenge.text
    assert "access_token" not in challenge.json()
    verified = client.post(
        "/api/v1/auth/verify-otp",
        json={"challenge_id": challenge.json()["challenge_id"], "code": challenge.json()["otp_dev"]},
    )
    assert verified.status_code == 200, verified.text
    me_ok = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {verified.json()['access_token']}"},
    )
    assert me_ok.status_code == 200
    assert me_ok.json()["phone"] == session["_phone"]


def test_forgot_is_rate_limited() -> None:
    phone = _phone()
    last = None
    for _ in range(settings.login_fail_max):
        last = client.post("/api/v1/auth/forgot-password", json={"phone": phone})
        assert last.status_code == 200
    blocked = client.post("/api/v1/auth/forgot-password", json={"phone": phone})
    assert blocked.status_code == 429


def test_production_hides_reset_code_dev(monkeypatch) -> None:
    session = _register()
    monkeypatch.setattr(settings, "app_env", "production")
    response = client.post("/api/v1/auth/forgot-password", json={"phone": session["_phone"]})
    assert response.status_code == 200
    assert response.json().get("reset_code_dev") is None
