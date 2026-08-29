from datetime import datetime, timedelta, timezone
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


def test_intelligence_runs_on_case_with_rules_not_ml() -> None:
    young = _register(UserRole.YOUNG, "Amina Intel")
    parent = _register(UserRole.PARENT, "Marie Intel")
    link = _pair(young, parent)
    young_id = link["young_person_id"]
    old = (datetime.now(timezone.utc) - timedelta(minutes=40)).isoformat()
    client.post("/api/v1/locations", headers=_auth(young), json={**POINT, "recorded_at": old})
    sos = client.post("/api/v1/alerts/sos", headers=_auth(young), json={})
    assert sos.status_code == 200, sos.text

    created = client.post("/api/v1/cases", headers=_auth(parent), json={"young_person_id": young_id})
    assert created.status_code == 200, created.text
    case_id = created.json()["id"]

    intel = client.get(f"/api/v1/cases/{case_id}/intelligence", headers=_auth(parent))
    assert intel.status_code == 200, intel.text
    body = intel.json()
    assert body["method"] == "rules"
    assert body["has_search_zone"] is True
    assert body["risk_level"] in {"LOW", "MEDIUM", "HIGH"}
    assert body["factors"]["score"] >= 3
    assert "kidnapping" in body["disclaimer"].lower()
    assert "zone de recherche" in body["disclaimer"].lower()
    assert "machine learning" in body["disclaimer"].lower()
    codes = {item["code"] for item in body["factors"]["contributors"]}
    assert "OPEN_SOS" in codes
    assert "STALE_POSITION" in codes
    assert body["factors"]["has_search_zone"] is True
    assert body["factors"]["crude_range_meters"] is not None
    assert "zone de recherche" in body["explanation"].lower()

    inbox = client.get("/api/v1/notifications/me", headers=_auth(parent))
    search_notes = [note for note in inbox.json() if note["notification_type"] == "SEARCH_UPDATE"]
    assert len(search_notes) == 1
    assert search_notes[0]["case_id"] == case_id
    assert "kidnapping" in search_notes[0]["body"].lower()

    children = client.get("/api/v1/family/children", headers=_auth(parent))
    assert children.json()[0]["can_view_location"] is False

    young_view = client.get(f"/api/v1/cases/{case_id}/intelligence", headers=_auth(young))
    assert young_view.status_code == 200

    again = client.post(f"/api/v1/cases/{case_id}/intelligence", headers=_auth(parent))
    assert again.status_code == 200
    inbox2 = client.get("/api/v1/notifications/me", headers=_auth(parent))
    search_notes2 = [note for note in inbox2.json() if note["notification_type"] == "SEARCH_UPDATE"]
    assert len(search_notes2) == 1


def test_intelligence_without_fix_is_low() -> None:
    young = _register(UserRole.YOUNG, "Paul Intel")
    parent = _register(UserRole.PARENT, "Lucie Intel")
    link = _pair(young, parent)
    created = client.post("/api/v1/cases", headers=_auth(parent), json={"young_person_id": link["young_person_id"]})
    case_id = created.json()["id"]
    intel = client.get(f"/api/v1/cases/{case_id}/intelligence", headers=_auth(parent))
    assert intel.status_code == 200, intel.text
    body = intel.json()
    assert body["risk_level"] == "LOW"
    assert body["has_search_zone"] is False
    codes = {item["code"] for item in body["factors"]["contributors"]}
    assert "NO_FIX" in codes


def test_stranger_cannot_read_intelligence() -> None:
    young = _register(UserRole.YOUNG, "Sara Intel")
    parent = _register(UserRole.PARENT, "Jean Intel")
    stranger = _register(UserRole.PARENT, "Marc Intel")
    link = _pair(young, parent)
    created = client.post("/api/v1/cases", headers=_auth(parent), json={"young_person_id": link["young_person_id"]})
    case_id = created.json()["id"]
    denied = client.get(f"/api/v1/cases/{case_id}/intelligence", headers=_auth(stranger))
    assert denied.status_code == 403
