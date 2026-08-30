from uuid import uuid4

from fastapi.testclient import TestClient

from app.core.enums import UserRole
from app.main import app
from app.services.geofence_service import haversine_meters

client = TestClient(app)

SCHOOL = {"latitude": 3.868, "longitude": 11.521}
FAR = {"latitude": 4.05, "longitude": 9.70}
NEAR_OUT = {"latitude": 3.873, "longitude": 11.521}
MONDAY_IN = "2026-08-24T10:00:00+01:00"
MONDAY_OUT = "2026-08-24T15:20:00+01:00"
SATURDAY = "2026-08-22T10:00:00+01:00"


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


def _pair(young: dict, parent: dict) -> dict:
    code = client.post("/api/v1/family/young/pairing-code", headers=_auth(young))
    linked = client.post(
        "/api/v1/family/links/code",
        headers=_auth(parent),
        json={"code": code.json()["code"]},
    )
    assert linked.status_code == 200, linked.text
    return linked.json()


def _school_zone(young_id: str, min_exit: int = 0) -> dict:
    return {
        "young_person_id": young_id,
        "name": "École",
        **SCHOOL,
        "radius_meters": 300,
        "min_exit_duration_seconds": min_exit,
        "schedules": [{"weekday": day, "start_time": "07:30:00", "end_time": "17:00:00"} for day in range(5)],
    }


def _post_fix(young: dict, coords: dict, recorded_at: str, accuracy: float = 12) -> dict:
    response = client.post(
        "/api/v1/locations",
        headers=_auth(young),
        json={**coords, "accuracy": accuracy, "recorded_at": recorded_at},
    )
    assert response.status_code == 200, response.text
    return response.json()


def _geofence_notes(session: dict) -> list[dict]:
    inbox = client.get("/api/v1/notifications/me", headers=_auth(session))
    assert inbox.status_code == 200
    return [note for note in inbox.json() if note["notification_type"] == "GEOFENCE_EXIT"]


def test_haversine_zero_at_same_point() -> None:
    assert haversine_meters(3.868, 11.521, 3.868, 11.521) < 1


def test_exit_notifies_parent_not_kidnapping() -> None:
    young = _register(UserRole.YOUNG, "Amina Geo")
    parent = _register(UserRole.PARENT, "Marie Geo")
    _pair(young, parent)
    young_id = young["user"]["young_person_id"]
    created = client.post("/api/v1/zones", headers=_auth(parent), json=_school_zone(young_id))
    assert created.status_code == 200, created.text

    _post_fix(young, SCHOOL, MONDAY_IN)
    assert _geofence_notes(parent) == []

    _post_fix(young, FAR, MONDAY_OUT)
    notes = _geofence_notes(parent)
    assert len(notes) == 1
    note = notes[0]
    assert note["notification_type"] == "GEOFENCE_EXIT"
    assert "École" in note["body"]
    assert "kidnapping" in note["body"].lower()
    assert note["is_read"] is False

    read = client.post(f"/api/v1/notifications/{note['id']}/read", headers=_auth(parent))
    assert read.status_code == 200
    assert read.json()["is_read"] is True


def test_never_inside_does_not_notify() -> None:
    young = _register(UserRole.YOUNG, "Paul Geo")
    parent = _register(UserRole.PARENT, "Lucie Geo")
    _pair(young, parent)
    young_id = young["user"]["young_person_id"]
    client.post("/api/v1/zones", headers=_auth(parent), json=_school_zone(young_id))
    _post_fix(young, FAR, MONDAY_OUT)
    assert _geofence_notes(parent) == []


def test_poor_accuracy_does_not_notify() -> None:
    young = _register(UserRole.YOUNG, "Sara Geo")
    parent = _register(UserRole.PARENT, "Jean Geo")
    _pair(young, parent)
    young_id = young["user"]["young_person_id"]
    client.post("/api/v1/zones", headers=_auth(parent), json=_school_zone(young_id))
    _post_fix(young, SCHOOL, MONDAY_IN)
    _post_fix(young, FAR, MONDAY_OUT, accuracy=800)
    assert _geofence_notes(parent) == []


def test_outside_schedule_does_not_notify() -> None:
    young = _register(UserRole.YOUNG, "Ngo Geo")
    parent = _register(UserRole.PARENT, "Pauline Geo")
    _pair(young, parent)
    young_id = young["user"]["young_person_id"]
    client.post("/api/v1/zones", headers=_auth(parent), json=_school_zone(young_id))
    _post_fix(young, SCHOOL, MONDAY_IN)
    _post_fix(young, FAR, SATURDAY)
    assert _geofence_notes(parent) == []


def test_min_exit_duration_blocks_immediate_exit() -> None:
    young = _register(UserRole.YOUNG, "Léa Geo")
    parent = _register(UserRole.PARENT, "Marc Geo")
    _pair(young, parent)
    young_id = young["user"]["young_person_id"]
    client.post("/api/v1/zones", headers=_auth(parent), json=_school_zone(young_id, min_exit=90))
    _post_fix(young, SCHOOL, MONDAY_IN)
    _post_fix(young, NEAR_OUT, "2026-08-24T10:00:30+01:00")
    assert _geofence_notes(parent) == []
