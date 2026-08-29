from uuid import uuid4

from fastapi.testclient import TestClient

from app.core.enums import UserRole
from app.main import app

client = TestClient(app)

POINT = {"latitude": 3.8480, "longitude": 11.5021, "accuracy": 18, "battery_level": 72}


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


def test_iot_sos_notifies_parent_not_kidnapping() -> None:
    young = _register(UserRole.YOUNG, "Amina Kit")
    parent = _register(UserRole.PARENT, "Marie Kit")
    _pair(young, parent)
    created = client.post("/api/v1/trackers", headers=_auth(young), json={"label": "Bracelet démo"})
    assert created.status_code == 200, created.text
    kit = created.json()
    assert kit["device_uid"].startswith("CCKIT-")
    assert kit["device_secret"]
    listed = client.get("/api/v1/trackers/me", headers=_auth(young))
    assert listed.status_code == 200
    assert listed.json()[0]["id"] == kit["id"]
    assert "device_secret" not in listed.json()[0]

    sos = client.post(
        "/api/v1/iot/sos",
        json={
            "device_uid": kit["device_uid"],
            "device_secret": kit["device_secret"],
            **POINT,
        },
    )
    assert sos.status_code == 200, sos.text
    body = sos.json()
    assert body["source"] == "IOT"
    assert body["status"] == "ACTIVE"
    assert body["latitude"] == POINT["latitude"]
    assert body["triggered_by_user_id"] is None

    inbox = client.get("/api/v1/notifications/me", headers=_auth(parent))
    notes = [note for note in inbox.json() if note["notification_type"] == "SOS"]
    assert len(notes) == 1
    assert "kit" in notes[0]["body"].lower()
    assert "kidnapping" in notes[0]["body"].lower()
    assert notes[0]["alert_id"] == body["id"]

    young_inbox = client.get("/api/v1/notifications/me", headers=_auth(young))
    assert any(note["notification_type"] == "SOS" for note in young_inbox.json())

    latest = client.get("/api/v1/locations/me/latest", headers=_auth(young))
    assert latest.status_code == 200, latest.text
    assert latest.json()["source"] == "IOT"
    listed = client.get(f"/api/v1/trackers/children/{young['user']['young_person_id']}", headers=_auth(parent))
    assert listed.status_code == 200
    assert listed.json()[0]["device_uid"] == kit["device_uid"]


def test_iot_sos_rejects_bad_secret() -> None:
    young = _register(UserRole.YOUNG, "Paul Kit")
    created = client.post("/api/v1/trackers", headers=_auth(young), json={})
    kit = created.json()
    bad = client.post(
        "/api/v1/iot/sos",
        json={"device_uid": kit["device_uid"], "device_secret": "pas-le-bon-secret", **POINT},
    )
    assert bad.status_code == 401
    unknown = client.post(
        "/api/v1/iot/sos",
        json={"device_uid": "CCKIT-UNKNOWN", "device_secret": kit["device_secret"], **POINT},
    )
    assert unknown.status_code == 401


def test_parent_registers_kit_relative_cannot() -> None:
    young = _register(UserRole.YOUNG, "Sara Kit")
    parent = _register(UserRole.PARENT, "Lucie Kit")
    relative = _register(UserRole.RELATIVE, "Jean Kit")
    _pair(young, parent)
    code = client.post("/api/v1/family/young/pairing-code", headers=_auth(young))
    linked = client.post(
        "/api/v1/family/links/code",
        headers=_auth(relative),
        json={"code": code.json()["code"]},
    )
    assert linked.status_code == 200, linked.text
    young_id = young["user"]["young_person_id"]
    created = client.post(
        "/api/v1/trackers",
        headers=_auth(parent),
        json={"young_person_id": young_id, "label": "Pendentif"},
    )
    assert created.status_code == 200, created.text
    forbidden = client.post(
        "/api/v1/trackers",
        headers=_auth(relative),
        json={"young_person_id": young_id, "label": "Interdit"},
    )
    assert forbidden.status_code == 403


def test_second_iot_sos_reuses_open_alert() -> None:
    young = _register(UserRole.YOUNG, "Nadia Kit")
    kit = client.post("/api/v1/trackers", headers=_auth(young), json={}).json()
    creds = {"device_uid": kit["device_uid"], "device_secret": kit["device_secret"]}
    first = client.post("/api/v1/iot/sos", json={**creds, **POINT})
    second = client.post("/api/v1/iot/sos", json={**creds})
    assert first.status_code == 200
    assert second.status_code == 200
    assert first.json()["id"] == second.json()["id"]
    inbox = client.get("/api/v1/notifications/me", headers=_auth(young))
    assert len([note for note in inbox.json() if note["notification_type"] == "SOS"]) == 1


def test_open_mobile_sos_blocks_duplicate_iot() -> None:
    young = _register(UserRole.YOUNG, "Léo Kit")
    kit = client.post("/api/v1/trackers", headers=_auth(young), json={}).json()
    mobile = client.post("/api/v1/alerts/sos", headers=_auth(young), json={})
    iot = client.post(
        "/api/v1/iot/sos",
        json={"device_uid": kit["device_uid"], "device_secret": kit["device_secret"], **POINT},
    )
    assert mobile.status_code == 200
    assert iot.status_code == 200
    assert iot.json()["id"] == mobile.json()["id"]
    assert iot.json()["source"] == "MOBILE"
