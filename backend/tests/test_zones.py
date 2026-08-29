from datetime import datetime, time
from uuid import uuid4

from fastapi.testclient import TestClient

from app.core.enums import UserRole
from app.main import app
from app.services.zone_service import is_window_active

client = TestClient(app)


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
    assert code.status_code == 200, code.text
    linked = client.post(
        "/api/v1/family/links/code",
        headers=_auth(parent),
        json={"code": code.json()["code"]},
    )
    assert linked.status_code == 200, linked.text
    return linked.json()


def _school_payload(young_id: str) -> dict:
    return {
        "young_person_id": young_id,
        "name": "École",
        "latitude": 3.868,
        "longitude": 11.521,
        "radius_meters": 300,
        "schedules": [
            {"weekday": day, "start_time": "07:30:00", "end_time": "17:00:00"} for day in range(5)
        ],
    }


def test_school_window_weekdays() -> None:
    monday_morning = datetime(2026, 8, 31, 8, 0)  # lundi
    monday_evening = datetime(2026, 8, 31, 18, 0)
    saturday = datetime(2026, 9, 5, 10, 0)
    assert is_window_active(0, time(7, 30), time(17, 0), monday_morning)
    assert not is_window_active(0, time(7, 30), time(17, 0), monday_evening)
    assert not is_window_active(0, time(7, 30), time(17, 0), saturday)


def test_home_window_crosses_midnight() -> None:
    monday_night = datetime(2026, 8, 31, 20, 0)
    tuesday_dawn = datetime(2026, 9, 1, 6, 0)
    tuesday_noon = datetime(2026, 9, 1, 12, 0)
    assert is_window_active(0, time(18, 0), time(7, 0), monday_night)
    assert is_window_active(0, time(18, 0), time(7, 0), tuesday_dawn)
    assert not is_window_active(0, time(18, 0), time(7, 0), tuesday_noon)


def test_parent_creates_school_zone_young_can_list() -> None:
    young = _register(UserRole.YOUNG, "Amina Zones")
    parent = _register(UserRole.PARENT, "Marie Zones")
    _pair(young, parent)
    young_id = young["user"]["young_person_id"]

    created = client.post("/api/v1/zones", headers=_auth(parent), json=_school_payload(young_id))
    assert created.status_code == 200, created.text
    body = created.json()
    assert body["name"] == "École"
    assert body["radius_meters"] == 300
    assert len(body["schedules"]) == 5
    assert body["is_active"] is True

    mine = client.get("/api/v1/zones/me", headers=_auth(young))
    assert mine.status_code == 200
    assert len(mine.json()) == 1
    assert mine.json()[0]["name"] == "École"

    listed = client.get(f"/api/v1/zones/children/{young_id}", headers=_auth(parent))
    assert listed.status_code == 200
    assert listed.json()[0]["id"] == body["id"]


def test_young_cannot_create_zone() -> None:
    young = _register(UserRole.YOUNG, "Paul Zones")
    posted = client.post(
        "/api/v1/zones",
        headers=_auth(young),
        json=_school_payload(young["user"]["young_person_id"]),
    )
    assert posted.status_code == 403


def test_relative_without_manage_permission_is_denied() -> None:
    young = _register(UserRole.YOUNG, "Sara Zones")
    relative = _register(UserRole.RELATIVE, "Luc Zones")
    link = _pair(young, relative)
    assert link["can_manage_zones"] is False
    young_id = young["user"]["young_person_id"]
    posted = client.post("/api/v1/zones", headers=_auth(relative), json=_school_payload(young_id))
    assert posted.status_code == 403

    granted = client.patch(
        f"/api/v1/family/links/{link['id']}/permissions",
        headers=_auth(young),
        json={"can_manage_zones": True},
    )
    assert granted.status_code == 200
    allowed = client.post("/api/v1/zones", headers=_auth(relative), json=_school_payload(young_id))
    assert allowed.status_code == 200, allowed.text


def test_parent_can_delete_zone() -> None:
    young = _register(UserRole.YOUNG, "Ngo Zones")
    parent = _register(UserRole.PARENT, "Jean Zones")
    _pair(young, parent)
    young_id = young["user"]["young_person_id"]
    created = client.post("/api/v1/zones", headers=_auth(parent), json=_school_payload(young_id))
    zone_id = created.json()["id"]
    deleted = client.delete(f"/api/v1/zones/{zone_id}", headers=_auth(parent))
    assert deleted.status_code == 204
    mine = client.get("/api/v1/zones/me", headers=_auth(young))
    assert mine.json() == []
