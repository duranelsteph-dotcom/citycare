from uuid import uuid4

from fastapi.testclient import TestClient

from app.core.enums import UserRole
from app.main import app

client = TestClient(app)

STILL = {"latitude": 3.8480, "longitude": 11.5021, "accuracy": 15}
NORTH = {"latitude": 3.8510, "longitude": 11.5021, "accuracy": 15}
SCHOOL = {"latitude": 3.868, "longitude": 11.521}
NEAR_OUT = {"latitude": 3.873, "longitude": 11.521}


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


def _post_fix(young: dict, coords: dict, recorded_at: str) -> None:
    response = client.post(
        "/api/v1/locations",
        headers=_auth(young),
        json={**coords, "recorded_at": recorded_at},
    )
    assert response.status_code == 200, response.text


def _anomaly_notes(session: dict) -> list[dict]:
    inbox = client.get("/api/v1/notifications/me", headers=_auth(session))
    assert inbox.status_code == 200
    return [note for note in inbox.json() if note["notification_type"] == "ANOMALY"]


def test_health_reports_anomaly_phase_version() -> None:
    health = client.get("/api/v1/health")
    assert health.status_code == 200
    assert health.json()["version"] == "0.43.0"


def test_prolonged_stop_outside_safety_notifies_rules_not_ml() -> None:
    young = _register(UserRole.YOUNG, "Amina Ano")
    parent = _register(UserRole.PARENT, "Marie Ano")
    _pair(young, parent)
    _post_fix(young, STILL, "2026-08-24T10:00:00+01:00")
    _post_fix(young, STILL, "2026-08-24T10:08:00+01:00")
    _post_fix(young, STILL, "2026-08-24T10:16:00+01:00")
    _post_fix(young, STILL, "2026-08-24T10:24:00+01:00")
    notes = _anomaly_notes(parent)
    assert len(notes) == 1
    note = notes[0]
    assert note["title"] == "Anomalie détectée"
    assert "Anomalie détectée" in note["body"]
    assert "arrêt prolongé" in note["body"].lower()
    assert "machine learning" in note["body"].lower()
    assert "pas un kidnapping confirmé" in note["body"].lower()
    assert note["context"]["target"] == "MAP"
    assert note["context"]["channel"] == "IN_APP"
    assert note["context"]["is_live_position"] is False


def test_stop_inside_safety_zone_does_not_notify() -> None:
    young = _register(UserRole.YOUNG, "Paul Ano")
    parent = _register(UserRole.PARENT, "Lucie Ano")
    _pair(young, parent)
    young_id = young["user"]["young_person_id"]
    zone = client.post(
        "/api/v1/zones",
        headers=_auth(parent),
        json={
            "young_person_id": young_id,
            "name": "École",
            **SCHOOL,
            "radius_meters": 300,
            "min_exit_duration_seconds": 0,
            "schedules": [{"weekday": day, "start_time": "07:30:00", "end_time": "17:00:00"} for day in range(5)],
        },
    )
    assert zone.status_code == 200, zone.text
    _post_fix(young, {**SCHOOL, "accuracy": 12}, "2026-08-24T10:00:00+01:00")
    _post_fix(young, {**SCHOOL, "accuracy": 12}, "2026-08-24T10:08:00+01:00")
    _post_fix(young, {**SCHOOL, "accuracy": 12}, "2026-08-24T10:16:00+01:00")
    _post_fix(young, {**SCHOOL, "accuracy": 12}, "2026-08-24T10:24:00+01:00")
    assert _anomaly_notes(parent) == []


def test_geofence_exit_alone_does_not_duplicate_anomaly() -> None:
    young = _register(UserRole.YOUNG, "Sara Ano")
    parent = _register(UserRole.PARENT, "Jean Ano")
    _pair(young, parent)
    young_id = young["user"]["young_person_id"]
    client.post(
        "/api/v1/zones",
        headers=_auth(parent),
        json={
            "young_person_id": young_id,
            "name": "École",
            **SCHOOL,
            "radius_meters": 300,
            "min_exit_duration_seconds": 0,
            "schedules": [{"weekday": day, "start_time": "07:30:00", "end_time": "17:00:00"} for day in range(5)],
        },
    )
    _post_fix(young, {**SCHOOL, "accuracy": 12}, "2026-08-24T10:00:00+01:00")
    _post_fix(young, {**NEAR_OUT, "accuracy": 12}, "2026-08-24T10:08:00+01:00")
    inbox = client.get("/api/v1/notifications/me", headers=_auth(parent))
    types = [note["notification_type"] for note in inbox.json()]
    assert types.count("GEOFENCE_EXIT") == 1
    assert "ANOMALY" not in types


def test_signal_gap_notifies_anomaly() -> None:
    young = _register(UserRole.YOUNG, "Ngo Ano")
    parent = _register(UserRole.PARENT, "Pauline Ano")
    _pair(young, parent)
    _post_fix(young, STILL, "2026-08-24T10:00:00+01:00")
    _post_fix(young, NORTH, "2026-08-24T10:25:00+01:00")
    notes = _anomaly_notes(parent)
    assert len(notes) == 1
    assert "trou de communication" in notes[0]["body"].lower()
    assert "kidnapping confirmé" in notes[0]["body"].lower()


def test_unusual_heading_notifies_trajectory_rule() -> None:
    young = _register(UserRole.YOUNG, "Léa Ano")
    parent = _register(UserRole.PARENT, "Marc Ano")
    _pair(young, parent)
    _post_fix(young, {"latitude": 3.8480, "longitude": 11.5021, "accuracy": 12}, "2026-08-24T10:00:00+01:00")
    _post_fix(young, {"latitude": 3.8500, "longitude": 11.5021, "accuracy": 12}, "2026-08-24T10:02:00+01:00")
    _post_fix(young, {"latitude": 3.8485, "longitude": 11.4995, "accuracy": 12}, "2026-08-24T10:04:00+01:00")
    notes = _anomaly_notes(parent)
    assert len(notes) == 1
    assert "changement de cap" in notes[0]["body"].lower()
    assert "machine learning" in notes[0]["body"].lower()


def test_anomaly_cooldown_does_not_spam() -> None:
    young = _register(UserRole.YOUNG, "Ibrahim Ano")
    parent = _register(UserRole.PARENT, "Fatou Ano")
    _pair(young, parent)
    _post_fix(young, STILL, "2026-08-24T10:00:00+01:00")
    _post_fix(young, STILL, "2026-08-24T10:08:00+01:00")
    _post_fix(young, STILL, "2026-08-24T10:16:00+01:00")
    _post_fix(young, STILL, "2026-08-24T10:24:00+01:00")
    assert len(_anomaly_notes(parent)) == 1
    _post_fix(young, STILL, "2026-08-24T10:26:00+01:00")
    _post_fix(young, STILL, "2026-08-24T10:28:00+01:00")
    assert len(_anomaly_notes(parent)) == 1
