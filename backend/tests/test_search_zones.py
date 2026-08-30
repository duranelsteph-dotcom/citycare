from datetime import datetime, timedelta, timezone
from uuid import uuid4

from fastapi.testclient import TestClient

from app.core.enums import UserRole
from app.main import app
from app.services.geofence_service import haversine_meters

client = TestClient(app)

POINT = {"latitude": 3.8480, "longitude": 11.5021, "accuracy": 15}
SOUTH = {"latitude": 3.8460, "longitude": 11.5021, "accuracy": 15}


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


def test_probable_zone_is_estimate_not_real_position() -> None:
    young = _register(UserRole.YOUNG, "Amina Zone")
    parent = _register(UserRole.PARENT, "Marie Zone")
    link = _pair(young, parent)
    young_id = link["young_person_id"]
    old = (datetime.now(timezone.utc) - timedelta(minutes=40)).isoformat()
    client.post("/api/v1/locations", headers=_auth(young), json={**POINT, "recorded_at": old})

    created = client.post("/api/v1/cases", headers=_auth(parent), json={"young_person_id": young_id})
    assert created.status_code == 200, created.text
    case_id = created.json()["id"]

    zones = client.get(f"/api/v1/cases/{case_id}/search-zones", headers=_auth(parent))
    assert zones.status_code == 200, zones.text
    body = zones.json()
    probable = [item for item in body if item["kind"] == "PROBABLE_DISPLACEMENT"]
    assert len(probable) == 1
    zone = probable[0]
    assert zone["kind"] == "PROBABLE_DISPLACEMENT"
    assert zone["radius_meters"] >= 150
    assert zone["radius_meters"] <= 50_000
    assert "estimée" in zone["explanation"].lower() or "estimee" in zone["explanation"].lower()
    assert "position actuelle" in zone["explanation"].lower()
    assert "kidnapping" in zone["explanation"].lower()
    assert "prioritaire" in zone["explanation"].lower()
    assert "position actuelle" in zone["disclaimer"].lower()
    distance = haversine_meters(
        POINT["latitude"],
        POINT["longitude"],
        zone["center_latitude"],
        zone["center_longitude"],
    )
    assert distance <= zone["radius_meters"]

    intel = client.get(f"/api/v1/cases/{case_id}/intelligence", headers=_auth(parent))
    assert intel.json()["has_search_zone"] is True

    children = client.get("/api/v1/family/children", headers=_auth(parent))
    assert children.json()[0]["can_view_location"] is False

    young_view = client.get(f"/api/v1/cases/{case_id}/search-zones", headers=_auth(young))
    assert young_view.status_code == 200
    assert len([item for item in young_view.json() if item["kind"] == "PROBABLE_DISPLACEMENT"]) == 1

    again = client.post(f"/api/v1/cases/{case_id}/intelligence", headers=_auth(parent))
    assert again.status_code == 200
    zones2 = client.get(f"/api/v1/cases/{case_id}/search-zones", headers=_auth(parent))
    probable2 = [item for item in zones2.json() if item["kind"] == "PROBABLE_DISPLACEMENT"]
    assert len(probable2) == 1
    assert probable2[0]["kind"] == "PROBABLE_DISPLACEMENT"


def test_probable_zone_shifts_along_last_heading() -> None:
    young = _register(UserRole.YOUNG, "Paul Cap")
    parent = _register(UserRole.PARENT, "Lucie Cap")
    link = _pair(young, parent)
    now = datetime.now(timezone.utc)
    client.post(
        "/api/v1/locations",
        headers=_auth(young),
        json={**SOUTH, "recorded_at": (now - timedelta(minutes=42)).isoformat()},
    )
    client.post(
        "/api/v1/locations",
        headers=_auth(young),
        json={**POINT, "recorded_at": (now - timedelta(minutes=40)).isoformat(), "heading": 0},
    )
    created = client.post("/api/v1/cases", headers=_auth(parent), json={"young_person_id": link["young_person_id"]})
    case_id = created.json()["id"]
    zones = client.get(f"/api/v1/cases/{case_id}/search-zones", headers=_auth(parent)).json()
    zone = next(item for item in zones if item["kind"] == "PROBABLE_DISPLACEMENT")
    assert zone["center_latitude"] > POINT["latitude"]
    distance = haversine_meters(
        POINT["latitude"],
        POINT["longitude"],
        zone["center_latitude"],
        zone["center_longitude"],
    )
    assert distance <= zone["radius_meters"]


def test_probable_zone_absent_without_fix() -> None:
    young = _register(UserRole.YOUNG, "Sara SansFix")
    parent = _register(UserRole.PARENT, "Jean SansFix")
    link = _pair(young, parent)
    created = client.post("/api/v1/cases", headers=_auth(parent), json={"young_person_id": link["young_person_id"]})
    case_id = created.json()["id"]
    zones = client.get(f"/api/v1/cases/{case_id}/search-zones", headers=_auth(parent))
    assert zones.status_code == 200
    assert zones.json() == []
    intel = client.get(f"/api/v1/cases/{case_id}/intelligence", headers=_auth(parent))
    assert intel.json()["has_search_zone"] is False


def test_stranger_cannot_read_search_zones() -> None:
    young = _register(UserRole.YOUNG, "Noah Zone")
    parent = _register(UserRole.PARENT, "Claire Zone")
    stranger = _register(UserRole.PARENT, "Marc Zone")
    link = _pair(young, parent)
    created = client.post("/api/v1/cases", headers=_auth(parent), json={"young_person_id": link["young_person_id"]})
    denied = client.get(
        f"/api/v1/cases/{created.json()['id']}/search-zones",
        headers=_auth(stranger),
    )
    assert denied.status_code == 403
