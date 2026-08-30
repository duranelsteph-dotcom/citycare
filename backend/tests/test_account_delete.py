from io import BytesIO
from uuid import UUID, uuid4

from fastapi.testclient import TestClient

from app.core.enums import UserRole
from app.db.session import SessionLocal
from app.main import app
from app.models.circle import CircleMembership
from app.models.device import DevicePushToken
from app.models.otp import OtpChallenge
from app.models.user import User
from app.services.photo_service import ensure_upload_dir

client = TestClient(app)

_JPEG = (
    b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00"
    b"\xff\xdb\x00C\x00"
    + bytes([8] * 64)
    + b"\xff\xc0\x00\x0b\x08\x00\x01\x00\x01\x01\x01\x11\x00"
    b"\xff\xc4\x00\x14\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00"
    b"\x00\x00\x00\x00\x00\x00\x00\x00"
    b"\xff\xda\x00\x08\x01\x01\x00\x00?\x00\x7f\xff\xd9"
)


def _phone() -> str:
    return f"+2376{uuid4().hex[:8]}"


def _register(role: UserRole = UserRole.PARENT, password: str = "VilleCare1!") -> dict:
    number = _phone()
    response = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Delete Test",
            "phone": number,
            "password": password,
            "role": role.value,
        },
    )
    assert response.status_code == 200, response.text
    body = response.json()
    body["_phone"] = number
    return body


def _auth(session: dict) -> dict:
    return {"Authorization": f"Bearer {session['access_token']}"}


def test_delete_requires_jwt() -> None:
    response = client.request("DELETE", "/api/v1/auth/me", json={"password": "VilleCare1!"})
    assert response.status_code == 401


def test_delete_wrong_password_is_403() -> None:
    session = _register()
    response = client.request(
        "DELETE",
        "/api/v1/auth/me",
        headers=_auth(session),
        json={"password": "incorrect1"},
    )
    assert response.status_code == 403
    assert "mot de passe" in response.json()["detail"].lower()
    me = client.get("/api/v1/auth/me", headers=_auth(session))
    assert me.status_code == 200
    assert me.json()["is_active"] is True


def test_delete_succeeds_invalidates_jwt_and_login() -> None:
    session = _register(password="VilleCare1!")
    deleted = client.request(
        "DELETE",
        "/api/v1/auth/me",
        headers=_auth(session),
        json={"password": "VilleCare1!"},
    )
    assert deleted.status_code == 200, deleted.text
    assert "supprimé" in deleted.json()["message"].lower()

    me = client.get("/api/v1/auth/me", headers=_auth(session))
    assert me.status_code == 401

    login = client.post(
        "/api/v1/auth/login",
        json={"phone": session["_phone"], "password": "VilleCare1!"},
    )
    assert login.status_code == 401
    assert "incorrect" in login.json()["detail"].lower()

    db = SessionLocal()
    try:
        user = db.get(User, UUID(session["user"]["id"]))
        assert user is not None
        assert user.is_active is False
        assert user.phone != session["_phone"]
        assert user.full_name == "Compte supprimé"
        assert user.photo_url is None
        assert user.email is None
    finally:
        db.close()


def test_delete_does_not_break_other_user_login() -> None:
    victim = _register(password="VilleCare1!")
    neighbour = _register(password="autrepass1")
    deleted = client.request(
        "DELETE",
        "/api/v1/auth/me",
        headers=_auth(victim),
        json={"password": "VilleCare1!"},
    )
    assert deleted.status_code == 200, deleted.text

    challenge = client.post(
        "/api/v1/auth/login",
        json={"phone": neighbour["_phone"], "password": "autrepass1"},
    )
    assert challenge.status_code == 200, challenge.text
    verified = client.post(
        "/api/v1/auth/verify-otp",
        json={
            "challenge_id": challenge.json()["challenge_id"],
            "code": challenge.json()["otp_dev"],
        },
    )
    assert verified.status_code == 200, verified.text
    me = client.get("/api/v1/auth/me", headers=_auth(verified.json()))
    assert me.status_code == 200
    assert me.json()["phone"] == neighbour["_phone"]


def test_delete_cleans_fcm_otp_memberships_photo_and_frees_phone() -> None:
    session = _register(UserRole.YOUNG, password="VilleCare1!")
    token = session["access_token"]
    uploaded = client.post(
        "/api/v1/auth/me/photo",
        headers={"Authorization": f"Bearer {token}"},
        files={"file": ("avatar.jpg", BytesIO(_JPEG), "image/jpeg")},
    )
    assert uploaded.status_code == 200, uploaded.text
    photo_url = uploaded.json()["photo_url"]
    disk = ensure_upload_dir() / photo_url.rsplit("/", 1)[-1]
    assert disk.is_file()

    client.post(
        "/api/v1/devices/me",
        headers={"Authorization": f"Bearer {token}"},
        json={"token": f"fcm-delete-{uuid4().hex[:8]}", "platform": "ANDROID"},
    )
    client.post("/api/v1/auth/login", json={"phone": session["_phone"], "password": "VilleCare1!"})

    parent = _register(UserRole.PARENT)
    circle = client.post(
        "/api/v1/circles",
        headers=_auth(parent),
        json={"name": "Famille Delete"},
    )
    assert circle.status_code == 200, circle.text
    client.post(
        "/api/v1/circles/join",
        headers={"Authorization": f"Bearer {token}"},
        json={"code": circle.json()["invite_code"]},
    )

    deleted = client.request(
        "DELETE",
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {token}"},
        json={"password": "VilleCare1!"},
    )
    assert deleted.status_code == 200, deleted.text
    assert not disk.exists()

    uid = UUID(session["user"]["id"])
    db = SessionLocal()
    try:
        assert db.query(DevicePushToken).filter(DevicePushToken.user_id == uid).count() == 0
        assert db.query(OtpChallenge).filter(OtpChallenge.user_id == uid).count() == 0
        assert db.query(CircleMembership).filter(CircleMembership.user_id == uid).count() == 0
    finally:
        db.close()

    again = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Nouveau Compte",
            "phone": session["_phone"],
            "password": "VilleCare1!",
            "role": UserRole.PARENT.value,
        },
    )
    assert again.status_code == 200, again.text
    assert again.json()["user"]["phone"] == session["_phone"]
    assert again.json()["user"]["id"] != session["user"]["id"]
