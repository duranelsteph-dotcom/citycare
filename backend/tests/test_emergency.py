from uuid import uuid4

from fastapi.testclient import TestClient

from app.core.enums import UserRole
from app.main import app

client = TestClient(app)

POINT = {"latitude": 3.8480, "longitude": 11.5021, "accuracy": 15}


def _register(role: UserRole, name: str) -> dict:
    phone = f"+2377{uuid4().hex[:8]}"
    response = client.post(
        "/api/v1/auth/register",
        json={"full_name": name, "phone": phone, "password": "motdepasse", "role": role.value},
    )
    assert response.status_code == 200, response.text
    return response.json()


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


def test_emergency_after_sos_is_last_known_not_live() -> None:
    young = _register(UserRole.YOUNG, "Amina Urg")
    parent = _register(UserRole.PARENT, "Marie Urg")
    link = _pair(young, parent)
    young_id = link["young_person_id"]
    client.post("/api/v1/locations", headers=_auth(young), json=POINT)
    sos = client.post("/api/v1/alerts/sos", headers=_auth(young), json=POINT)
    assert sos.status_code == 200, sos.text
    emergency = client.get(f"/api/v1/emergency/children/{young_id}", headers=_auth(parent))
    assert emergency.status_code == 200, emergency.text
    body = emergency.json()
    assert body["is_live"] is False
    assert body["open_sos"] is not None
    assert body["last_known"] is not None
    assert body["effective_mode"] == "EMERGENCY"
    assert "kidnapping" in body["disclaimer"].lower()
    assert "direct" in body["disclaimer"].lower()
    assert body["kit_events"] == []


def test_emergency_without_sos_or_location_permission_is_forbidden() -> None:
    young = _register(UserRole.YOUNG, "Paul Urg")
    parent = _register(UserRole.PARENT, "Lucie Urg")
    link = _pair(young, parent)
    blocked = client.get(f"/api/v1/emergency/children/{link['young_person_id']}", headers=_auth(parent))
    assert blocked.status_code == 403


def test_emergency_contacts_are_owned_by_young() -> None:
    young = _register(UserRole.YOUNG, "Sara Contact")
    created = client.post(
        "/api/v1/family/young/contacts",
        headers=_auth(young),
        json={"name": "Oncle Jean", "phone": "+237699000099"},
    )
    assert created.status_code == 200, created.text
    listed = client.get("/api/v1/family/young/contacts", headers=_auth(young))
    assert listed.status_code == 200
    assert len(listed.json()) == 1
    contact_id = listed.json()[0]["id"]
    deleted = client.delete(f"/api/v1/family/young/contacts/{contact_id}", headers=_auth(young))
    assert deleted.status_code == 204
    empty = client.get("/api/v1/family/young/contacts", headers=_auth(young))
    assert empty.json() == []


def test_emergency_includes_kit_event_traces() -> None:
    young = _register(UserRole.YOUNG, "Amina KitUrg")
    parent = _register(UserRole.PARENT, "Marie KitUrg")
    link = _pair(young, parent)
    young_id = link["young_person_id"]
    kit = client.post("/api/v1/trackers", headers=_auth(young), json={"label": "UrgKit"})
    assert kit.status_code == 200, kit.text
    lost = client.post(
        "/api/v1/iot/events",
        json={
            "device_uid": kit.json()["device_uid"],
            "device_secret": kit.json()["device_secret"],
            "event_type": "SIGNAL_LOST",
            **POINT,
        },
    )
    assert lost.status_code == 200, lost.text
    sos = client.post("/api/v1/alerts/sos", headers=_auth(young), json=POINT)
    assert sos.status_code == 200, sos.text
    emergency = client.get(f"/api/v1/emergency/children/{young_id}", headers=_auth(parent))
    assert emergency.status_code == 200, emergency.text
    body = emergency.json()
    assert body["is_live"] is False
    assert body["kit_status"] == "SIGNAL_LOST"
    assert body["kit_events"]
    assert body["kit_events"][0]["event_type"] == "SIGNAL_LOST"
