from uuid import uuid4

from fastapi.testclient import TestClient

from app.core.enums import UserRole
from app.main import app

client = TestClient(app)

POINT = {"latitude": 3.8480, "longitude": 11.5021}


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


def test_parent_updates_label_and_mode() -> None:
    young = _register(UserRole.YOUNG, "Amina Gestion")
    parent = _register(UserRole.PARENT, "Marie Gestion")
    _pair(young, parent)
    kit = client.post("/api/v1/trackers", headers=_auth(young), json={"label": "Bracelet"}).json()
    patched = client.patch(
        f"/api/v1/trackers/{kit['id']}",
        headers=_auth(parent),
        json={"label": "Pendentif école", "tracking_mode": "POWER_SAVE"},
    )
    assert patched.status_code == 200, patched.text
    body = patched.json()
    assert body["label"] == "Pendentif école"
    assert body["tracking_mode"] == "POWER_SAVE"
    assert "device_secret" not in body
    one = client.get(f"/api/v1/trackers/{kit['id']}", headers=_auth(parent))
    assert one.status_code == 200
    assert one.json()["label"] == "Pendentif école"


def test_deactivate_blocks_iot_sos_reactivate_allows() -> None:
    young = _register(UserRole.YOUNG, "Paul Gestion")
    kit = client.post("/api/v1/trackers", headers=_auth(young), json={}).json()
    creds = {"device_uid": kit["device_uid"], "device_secret": kit["device_secret"]}
    off = client.patch(f"/api/v1/trackers/{kit['id']}", headers=_auth(young), json={"enabled": False})
    assert off.status_code == 200
    assert off.json()["status"] == "INACTIVE"
    blocked = client.post("/api/v1/iot/sos", json={**creds, **POINT})
    assert blocked.status_code == 403
    on = client.patch(f"/api/v1/trackers/{kit['id']}", headers=_auth(young), json={"enabled": True})
    assert on.json()["status"] == "ACTIVE"
    ok = client.post("/api/v1/iot/sos", json={**creds, **POINT})
    assert ok.status_code == 200
    assert ok.json()["source"] == "IOT"


def test_rotate_secret_invalidates_old() -> None:
    young = _register(UserRole.YOUNG, "Sara Secret")
    kit = client.post("/api/v1/trackers", headers=_auth(young), json={}).json()
    old = {"device_uid": kit["device_uid"], "device_secret": kit["device_secret"]}
    rotated = client.post(f"/api/v1/trackers/{kit['id']}/secret", headers=_auth(young))
    assert rotated.status_code == 200, rotated.text
    new_secret = rotated.json()["device_secret"]
    assert new_secret
    assert new_secret != kit["device_secret"]
    listed = client.get("/api/v1/trackers/me", headers=_auth(young))
    assert "device_secret" not in listed.json()[0]
    old_sos = client.post("/api/v1/iot/sos", json={**old, **POINT})
    assert old_sos.status_code == 401
    new_sos = client.post(
        "/api/v1/iot/sos",
        json={"device_uid": kit["device_uid"], "device_secret": new_secret, **POINT},
    )
    assert new_sos.status_code == 200


def test_unregister_kit_rejects_sos() -> None:
    young = _register(UserRole.YOUNG, "Léo Retrait")
    kit = client.post("/api/v1/trackers", headers=_auth(young), json={}).json()
    creds = {"device_uid": kit["device_uid"], "device_secret": kit["device_secret"]}
    removed = client.delete(f"/api/v1/trackers/{kit['id']}", headers=_auth(young))
    assert removed.status_code == 204
    missing = client.get(f"/api/v1/trackers/{kit['id']}", headers=_auth(young))
    assert missing.status_code == 404
    sos = client.post("/api/v1/iot/sos", json={**creds, **POINT})
    assert sos.status_code == 401


def test_relative_can_view_not_manage() -> None:
    young = _register(UserRole.YOUNG, "Nadia Vue")
    parent = _register(UserRole.PARENT, "Lucie Vue")
    relative = _register(UserRole.RELATIVE, "Jean Vue")
    _pair(young, parent)
    code = client.post("/api/v1/family/young/pairing-code", headers=_auth(young))
    linked = client.post(
        "/api/v1/family/links/code",
        headers=_auth(relative),
        json={"code": code.json()["code"]},
    )
    assert linked.status_code == 200
    kit = client.post("/api/v1/trackers", headers=_auth(young), json={"label": "Boîtier"}).json()
    young_id = young["user"]["young_person_id"]
    listed = client.get(f"/api/v1/trackers/children/{young_id}", headers=_auth(relative))
    assert listed.status_code == 200
    assert listed.json()[0]["id"] == kit["id"]
    forbidden = client.patch(
        f"/api/v1/trackers/{kit['id']}",
        headers=_auth(relative),
        json={"label": "Interdit"},
    )
    assert forbidden.status_code == 403
    rotate = client.post(f"/api/v1/trackers/{kit['id']}/secret", headers=_auth(relative))
    assert rotate.status_code == 403
    delete = client.delete(f"/api/v1/trackers/{kit['id']}", headers=_auth(relative))
    assert delete.status_code == 403
