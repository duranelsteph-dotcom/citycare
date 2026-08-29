from uuid import uuid4

from fastapi.testclient import TestClient

from app.core.enums import UserRole
from app.main import app
from app.services.notification_service import DISCLAIMER

client = TestClient(app)

POINT = {"latitude": 3.8480, "longitude": 11.5021, "accuracy": 15}


def _register(role: UserRole, name: str) -> dict:
    phone = f"+2377{uuid4().hex[:8]}"
    response = client.post(
        "/api/v1/auth/register",
        json={"full_name": name, "phone": phone, "password": "motdepasse", "role": role.value},
    )
    assert response.status_code == 200, response.text
    body = response.json()
    body["_phone"] = phone
    return body


def _auth(session: dict) -> dict:
    return {"Authorization": f"Bearer {session['access_token']}"}


def _pair(young: dict, parent: dict) -> dict:
    code = client.post("/api/v1/family/young/pairing-code", headers=_auth(young))
    linked = client.post(
        "/api/v1/family/links/code",
        headers=_auth(parent),
        json={"code": code.json()["code"]},
    )
    assert linked.status_code == 200, linked.text
    return linked.json()


def test_register_and_list_device_token() -> None:
    parent = _register(UserRole.PARENT, "Marie Push")
    created = client.post(
        "/api/v1/devices/me",
        headers=_auth(parent),
        json={"token": "fcm-token-marie-1", "platform": "ANDROID"},
    )
    assert created.status_code == 200, created.text
    assert created.json()["platform"] == "ANDROID"
    assert created.json()["is_active"] is True
    listed = client.get("/api/v1/devices/me", headers=_auth(parent))
    assert listed.status_code == 200
    assert len(listed.json()) == 1
    unread = client.get("/api/v1/notifications/unread-count", headers=_auth(parent))
    assert unread.json()["push"] == "DISABLED"
    assert "FCM" in DISCLAIMER or "push" in DISCLAIMER.lower()


def test_token_moves_to_new_user() -> None:
    first = _register(UserRole.PARENT, "A Token")
    second = _register(UserRole.PARENT, "B Token")
    client.post(
        "/api/v1/devices/me",
        headers=_auth(first),
        json={"token": "shared-fcm-token", "platform": "ANDROID"},
    )
    moved = client.post(
        "/api/v1/devices/me",
        headers=_auth(second),
        json={"token": "shared-fcm-token", "platform": "IOS"},
    )
    assert moved.status_code == 200
    assert moved.json()["platform"] == "IOS"
    assert client.get("/api/v1/devices/me", headers=_auth(first)).json() == []
    assert len(client.get("/api/v1/devices/me", headers=_auth(second)).json()) == 1


def test_unregister_device_token() -> None:
    young = _register(UserRole.YOUNG, "Amina Push")
    client.post(
        "/api/v1/devices/me",
        headers=_auth(young),
        json={"token": "fcm-token-amina", "platform": "ANDROID"},
    )
    deleted = client.request(
        "DELETE",
        "/api/v1/devices/me",
        headers=_auth(young),
        json={"token": "fcm-token-amina", "platform": "ANDROID"},
    )
    assert deleted.status_code == 200, deleted.text
    assert deleted.json()["updated"] == 1
    assert client.get("/api/v1/devices/me", headers=_auth(young)).json() == []


def test_sos_dispatches_fcm_when_configured(monkeypatch) -> None:
    sent: list = []

    def fake_dispatch(db, ids):
        sent.extend(ids)
        return len(ids)

    monkeypatch.setattr("app.services.fcm_service.is_configured", lambda: True)
    monkeypatch.setattr("app.services.fcm_service.dispatch_ids", fake_dispatch)
    young = _register(UserRole.YOUNG, "Sara Fcm")
    parent = _register(UserRole.PARENT, "Jean Fcm")
    _pair(young, parent)
    client.post(
        "/api/v1/devices/me",
        headers=_auth(parent),
        json={"token": "fcm-parent-sos", "platform": "ANDROID"},
    )
    sos = client.post("/api/v1/alerts/sos", headers=_auth(young), json=POINT)
    assert sos.status_code == 200, sos.text
    assert sent, "le hook FCM doit voir les notifications après commit"
