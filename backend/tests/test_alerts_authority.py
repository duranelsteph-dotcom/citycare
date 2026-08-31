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
        json={"full_name": name, "phone": phone, "password": "VilleCare1!", "role": role.value},
    )
    assert response.status_code == 200, response.text
    body = response.json()
    body["_phone"] = phone
    return body


def _auth(session: dict) -> dict:
    return {"Authorization": f"Bearer {session['access_token']}"}


def _pair(young: dict, guardian: dict) -> dict:
    code = client.post("/api/v1/family/young/pairing-code", headers=_auth(young))
    linked = client.post(
        "/api/v1/family/links/code",
        headers=_auth(guardian),
        json={"code": code.json()["code"]},
    )
    assert linked.status_code == 200, linked.text
    return linked.json()


def test_authority_lists_sos_and_acknowledges() -> None:
    young = _register(UserRole.YOUNG, "SOS Amina")
    parent = _register(UserRole.PARENT, "SOS Marie")
    authority = _register(UserRole.AUTHORITY, "Agent SOS")
    _pair(young, parent)

    posted = client.post("/api/v1/locations", headers=_auth(young), json=POINT)
    assert posted.status_code == 200, posted.text

    sos = client.post("/api/v1/alerts/sos", headers=_auth(young), json={})
    assert sos.status_code == 200, sos.text
    alert_id = sos.json()["id"]

    listed = client.get("/api/v1/alerts/mine", headers=_auth(authority))
    assert listed.status_code == 200, listed.text
    ids = [row["id"] for row in listed.json()]
    assert alert_id in ids

    ack = client.post(f"/api/v1/alerts/{alert_id}/acknowledge", headers=_auth(authority))
    assert ack.status_code == 200, ack.text
    assert ack.json()["status"] == "ACKNOWLEDGED"
