from datetime import datetime, timedelta, timezone
from uuid import uuid4

from fastapi.testclient import TestClient

from app.core.enums import UserRole
from app.main import app
from app.services.geofence_service import haversine_meters

client = TestClient(app)

POINT = {"latitude": 3.8480, "longitude": 11.5021, "accuracy": 15}
SOUTH = {"latitude": 3.8460, "longitude": 11.5021, "accuracy": 15}
RISK_POINT = {"latitude": 4.051, "longitude": 11.521}


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


def _priority(body: list[dict]) -> list[dict]:
    return [item for item in body if item["kind"] == "PRIORITY_SEARCH"]


def test_priority_zones_rank_last_known_and_explain() -> None:
    young = _register(UserRole.YOUNG, "Amina Prio")
    parent = _register(UserRole.PARENT, "Marie Prio")
    link = _pair(young, parent)
    old = (datetime.now(timezone.utc) - timedelta(minutes=40)).isoformat()
    client.post("/api/v1/locations", headers=_auth(young), json={**POINT, "recorded_at": old})
    created = client.post("/api/v1/cases", headers=_auth(parent), json={"young_person_id": link["young_person_id"]})
    case_id = created.json()["id"]

    zones = client.get(f"/api/v1/cases/{case_id}/search-zones", headers=_auth(parent))
    assert zones.status_code == 200, zones.text
    priorities = _priority(zones.json())
    assert len(priorities) >= 1
    assert all(item["priority"] in {"LOW", "MEDIUM", "HIGH"} for item in priorities)
    first = next(
        item
        for item in priorities
        if "dernière position" in item["explanation"].lower() or "derniere position" in item["explanation"].lower()
    )
    assert first["priority"] == "HIGH"
    assert "dernière position" in first["explanation"].lower() or "derniere position" in first["explanation"].lower()
    assert "kidnapping" in first["explanation"].lower()
    assert "témoignages" in first["disclaimer"].lower() or "temoignages" in first["disclaimer"].lower()
    assert "position actuelle" in first["disclaimer"].lower()
    distance = haversine_meters(
        POINT["latitude"],
        POINT["longitude"],
        first["center_latitude"],
        first["center_longitude"],
    )
    assert distance <= first["radius_meters"]
    assert first["radius_meters"] < 20_000

    intel = client.get(f"/api/v1/cases/{case_id}/intelligence", headers=_auth(parent))
    body = intel.json()
    assert len(body["factors"]["priority_zones"]) == len(priorities)
    assert "prioritaire" in body["explanation"].lower()

    children = client.get("/api/v1/family/children", headers=_auth(parent))
    assert children.json()[0]["can_view_location"] is False

    again = client.post(f"/api/v1/cases/{case_id}/intelligence", headers=_auth(parent))
    assert again.status_code == 200
    zones2 = client.get(f"/api/v1/cases/{case_id}/search-zones", headers=_auth(parent))
    assert len(_priority(zones2.json())) == len(priorities)


def test_priority_zone_follows_heading() -> None:
    young = _register(UserRole.YOUNG, "Paul PrioCap")
    parent = _register(UserRole.PARENT, "Lucie PrioCap")
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
    priorities = _priority(
        client.get(f"/api/v1/cases/{created.json()['id']}/search-zones", headers=_auth(parent)).json()
    )
    assert len(priorities) >= 2
    forward = [item for item in priorities if "direction" in item["explanation"].lower()]
    assert forward
    assert forward[0]["center_latitude"] > POINT["latitude"]
    assert forward[0]["priority"] == "HIGH"


def test_priority_zone_includes_active_risk_area() -> None:
    young = _register(UserRole.YOUNG, "Sara PrioRisk")
    parent = _register(UserRole.PARENT, "Jean PrioRisk")
    link = _pair(young, parent)
    listed = client.get("/api/v1/risk-zones/list", headers=_auth(parent))
    for zone in listed.json():
        if abs(zone["latitude"] - RISK_POINT["latitude"]) < 0.002:
            client.delete(f"/api/v1/risk-zones/{zone['id']}", headers=_auth(parent))
    created_zone = client.post(
        "/api/v1/risk-zones",
        headers=_auth(parent),
        json={"name": "Carrefour prio test", **RISK_POINT, "radius_meters": 300},
    )
    assert created_zone.status_code == 200, created_zone.text
    old = (datetime.now(timezone.utc) - timedelta(minutes=40)).isoformat()
    client.post("/api/v1/locations", headers=_auth(young), json={**RISK_POINT, "accuracy": 12, "recorded_at": old})
    created = client.post("/api/v1/cases", headers=_auth(parent), json={"young_person_id": link["young_person_id"]})
    priorities = _priority(
        client.get(f"/api/v1/cases/{created.json()['id']}/search-zones", headers=_auth(parent)).json()
    )
    riskish = [item for item in priorities if "zone à risque" in item["explanation"].lower() or "zone a risque" in item["explanation"].lower()]
    assert riskish
    assert riskish[0]["priority"] == "HIGH"
    client.delete(f"/api/v1/risk-zones/{created_zone.json()['id']}", headers=_auth(parent))


def test_priority_zones_absent_without_fix() -> None:
    young = _register(UserRole.YOUNG, "Noah SansPrio")
    parent = _register(UserRole.PARENT, "Claire SansPrio")
    link = _pair(young, parent)
    created = client.post("/api/v1/cases", headers=_auth(parent), json={"young_person_id": link["young_person_id"]})
    zones = client.get(f"/api/v1/cases/{created.json()['id']}/search-zones", headers=_auth(parent))
    assert _priority(zones.json()) == []
