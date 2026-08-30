from uuid import uuid4

from fastapi.testclient import TestClient

from app.core.enums import UserRole
from app.main import app
from app.services.notification_service import DISCLAIMER

client = TestClient(app)

SCHOOL = {"latitude": 3.868, "longitude": 11.521}
FAR = {"latitude": 4.05, "longitude": 9.70}


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


def test_health_reports_notification_phase_version() -> None:
    health = client.get("/api/v1/health")
    assert health.status_code == 200
    assert health.json()["version"] == "0.43.0"


def test_geofence_notification_is_contextual_in_app_not_push() -> None:
    young = _register(UserRole.YOUNG, "Amina Notif")
    parent = _register(UserRole.PARENT, "Marie Notif")
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
    client.post(
        "/api/v1/locations",
        headers=_auth(young),
        json={**SCHOOL, "accuracy": 12, "recorded_at": "2026-08-24T10:00:00+01:00"},
    )
    client.post(
        "/api/v1/locations",
        headers=_auth(young),
        json={"latitude": 3.873, "longitude": 11.521, "accuracy": 12, "recorded_at": "2026-08-24T15:20:00+01:00"},
    )
    inbox = client.get("/api/v1/notifications/me", headers=_auth(parent))
    assert inbox.status_code == 200
    notes = [note for note in inbox.json() if note["notification_type"] == "GEOFENCE_EXIT"]
    assert len(notes) == 1
    note = notes[0]
    context = note["context"]
    assert context["channel"] == "IN_APP"
    assert context["target"] == "MAP"
    assert context["is_live_position"] is False
    assert context["zone_name"] == "École"
    assert context["latitude"] == 3.873
    assert "push" in context["disclaimer"].lower()
    assert "kidnapping" in context["disclaimer"].lower()
    assert "kidnapping" in note["body"].lower()

    unread = client.get("/api/v1/notifications/unread-count", headers=_auth(parent))
    assert unread.status_code == 200
    assert unread.json()["unread"] >= 1
    assert unread.json()["channel"] == "IN_APP"
    assert unread.json()["disclaimer"] == DISCLAIMER

    filtered = client.get("/api/v1/notifications/me?unread_only=true", headers=_auth(parent))
    assert all(item["is_read"] is False for item in filtered.json())

    marked = client.post("/api/v1/notifications/read-all", headers=_auth(parent))
    assert marked.status_code == 200
    assert marked.json()["updated"] >= 1
    after = client.get("/api/v1/notifications/unread-count", headers=_auth(parent))
    assert after.json()["unread"] == 0


def test_implausible_gps_jump_notifies_anomaly_not_geofence() -> None:
    young = _register(UserRole.YOUNG, "Paul Jump")
    parent = _register(UserRole.PARENT, "Lucie Jump")
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
    client.post(
        "/api/v1/locations",
        headers=_auth(young),
        json={**SCHOOL, "accuracy": 12, "recorded_at": "2026-08-24T10:00:00+01:00"},
    )
    jump = client.post(
        "/api/v1/locations",
        headers=_auth(young),
        json={**FAR, "accuracy": 12, "recorded_at": "2026-08-24T10:00:20+01:00"},
    )
    assert jump.status_code == 200, jump.text
    inbox = client.get("/api/v1/notifications/me", headers=_auth(parent))
    types = {note["notification_type"] for note in inbox.json()}
    assert "ANOMALY" in types
    assert "GEOFENCE_EXIT" not in types
    anomaly = next(note for note in inbox.json() if note["notification_type"] == "ANOMALY")
    assert anomaly["context"]["target"] == "MAP"
    assert anomaly["context"]["channel"] == "IN_APP"
    assert "kidnapping" in anomaly["body"].lower()
    assert "sortie" in anomaly["body"].lower()


def test_sos_notification_targets_alert_not_live_gps() -> None:
    young = _register(UserRole.YOUNG, "Sara SosN")
    parent = _register(UserRole.PARENT, "Jean SosN")
    _pair(young, parent)
    sos = client.post(
        "/api/v1/alerts/sos",
        headers=_auth(young),
        json={**SCHOOL, "accuracy": 15},
    )
    assert sos.status_code == 200, sos.text
    inbox = client.get("/api/v1/notifications/me", headers=_auth(parent))
    notes = [note for note in inbox.json() if note["notification_type"] == "SOS"]
    assert len(notes) == 1
    assert notes[0]["context"]["target"] == "SOS"
    assert notes[0]["context"]["is_live_position"] is False
    assert notes[0]["alert_id"] == sos.json()["id"]
    assert "kidnapping" in notes[0]["body"].lower()
