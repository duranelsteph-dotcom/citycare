from uuid import uuid4

from fastapi.testclient import TestClient

from app.core.enums import UserRole
from app.main import app
from simulator.scenario import DEMO_STEPS, SCHOOL

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


def _kit(young: dict) -> dict:
    created = client.post("/api/v1/trackers", headers=_auth(young), json={"label": "Simu"})
    assert created.status_code == 200, created.text
    return created.json()


def _creds(kit: dict) -> dict:
    return {"device_uid": kit["device_uid"], "device_secret": kit["device_secret"]}


def test_kit_location_is_iot_not_live() -> None:
    young = _register(UserRole.YOUNG, "Amina Sim")
    kit = _kit(young)
    ping = client.post(
        "/api/v1/iot/location",
        json={**_creds(kit), **POINT, "accuracy": 12, "battery_level": 72, "speed": 1.1, "heading": 80},
    )
    assert ping.status_code == 200, ping.text
    body = ping.json()
    assert body["source"] == "IOT"
    assert body["latitude"] == POINT["latitude"]
    latest = client.get("/api/v1/locations/me/latest", headers=_auth(young))
    assert latest.json()["source"] == "IOT"
    listed = client.get("/api/v1/trackers/me", headers=_auth(young))
    row = listed.json()[0]
    assert row["last_latitude"] == POINT["latitude"]
    assert row["battery_level"] == 72
    assert row["status"] == "ACTIVE"


def test_kit_location_triggers_geofence_exit() -> None:
    young = _register(UserRole.YOUNG, "Paul SimGeo")
    parent = _register(UserRole.PARENT, "Marie SimGeo")
    _pair(young, parent)
    kit = _kit(young)
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
    creds = _creds(kit)
    inside = client.post(
        "/api/v1/iot/location",
        json={**creds, **SCHOOL, "accuracy": 12, "recorded_at": "2026-08-24T10:00:00+01:00"},
    )
    assert inside.status_code == 200, inside.text
    outside = client.post(
        "/api/v1/iot/location",
        json={
            **creds,
            "latitude": 3.873,
            "longitude": 11.521,
            "accuracy": 12,
            "recorded_at": "2026-08-24T15:20:00+01:00",
        },
    )
    assert outside.status_code == 200, outside.text
    inbox = client.get("/api/v1/notifications/me", headers=_auth(parent))
    notes = [note for note in inbox.json() if note["notification_type"] == "GEOFENCE_EXIT"]
    assert len(notes) == 1
    assert "École" in notes[0]["body"]
    assert "kidnapping" in notes[0]["body"].lower()


def test_signal_lost_notifies_once_not_kidnapping() -> None:
    young = _register(UserRole.YOUNG, "Sara Lost")
    parent = _register(UserRole.PARENT, "Lucie Lost")
    _pair(young, parent)
    kit = _kit(young)
    first = client.post("/api/v1/iot/events", json={**_creds(kit), "event_type": "SIGNAL_LOST", **POINT})
    assert first.status_code == 200, first.text
    assert first.json()["tracker"]["status"] == "SIGNAL_LOST"
    second = client.post("/api/v1/iot/events", json={**_creds(kit), "event_type": "SIGNAL_LOST"})
    assert second.status_code == 200
    inbox = client.get("/api/v1/notifications/me", headers=_auth(parent))
    notes = [note for note in inbox.json() if note["notification_type"] == "SIGNAL_LOST"]
    assert len(notes) == 1
    assert "perdue" in notes[0]["body"].lower() or "perdue" in notes[0]["title"].lower()
    assert "dernière position connue" in notes[0]["body"].lower()
    assert "actuelle" in notes[0]["body"].lower()
    assert "kidnapping" in notes[0]["body"].lower()
    ping = client.post("/api/v1/iot/location", json={**_creds(kit), **POINT, "battery_level": 60})
    assert ping.status_code == 200
    listed = client.get("/api/v1/trackers/me", headers=_auth(young))
    assert listed.json()[0]["status"] == "ACTIVE"


def test_kit_event_history_is_trace_not_live() -> None:
    young = _register(UserRole.YOUNG, "Nina Hist")
    parent = _register(UserRole.PARENT, "Odile Hist")
    stranger = _register(UserRole.PARENT, "Inconnu Hist")
    _pair(young, parent)
    kit = _kit(young)
    lost = client.post(
        "/api/v1/iot/events",
        json={**_creds(kit), "event_type": "SIGNAL_LOST", **POINT, "recorded_at": "2026-08-24T16:54:00+01:00"},
    )
    assert lost.status_code == 200, lost.text
    events = client.get(f"/api/v1/trackers/{kit['id']}/events", headers=_auth(young))
    assert events.status_code == 200, events.text
    assert events.json()[0]["event_type"] == "SIGNAL_LOST"
    assert "2026-08-24T" in events.json()[0]["recorded_at"]
    parent_view = client.get(f"/api/v1/trackers/{kit['id']}/events", headers=_auth(parent))
    assert parent_view.status_code == 200
    assert parent_view.json()[0]["event_type"] == "SIGNAL_LOST"
    blocked = client.get(f"/api/v1/trackers/{kit['id']}/events", headers=_auth(stranger))
    assert blocked.status_code == 403


def test_device_removed_and_low_battery() -> None:
    young = _register(UserRole.YOUNG, "Léo Batt")
    parent = _register(UserRole.PARENT, "Jean Batt")
    _pair(young, parent)
    kit = _kit(young)
    creds = _creds(kit)
    removed = client.post("/api/v1/iot/events", json={**creds, "event_type": "DEVICE_REMOVED", **POINT})
    assert removed.status_code == 200
    assert removed.json()["tracker"]["status"] == "REMOVED"
    inbox = client.get("/api/v1/notifications/me", headers=_auth(parent))
    notes = [note for note in inbox.json() if note["notification_type"] == "DEVICE_REMOVED"]
    assert len(notes) == 1
    assert "retrait" in notes[0]["body"].lower()
    assert "dernière communication" in notes[0]["body"].lower()
    low = client.post(
        "/api/v1/iot/location",
        json={**creds, **POINT, "battery_level": 10},
    )
    assert low.status_code == 200
    listed = client.get("/api/v1/trackers/me", headers=_auth(young))
    assert listed.json()[0]["status"] == "LOW_BATTERY"
    again = client.post("/api/v1/iot/location", json={**creds, **POINT, "battery_level": 8})
    assert again.status_code == 200
    batt = [
        note
        for note in client.get("/api/v1/notifications/me", headers=_auth(parent)).json()
        if note["notification_type"] == "LOW_BATTERY"
    ]
    assert len(batt) == 1


def test_inactive_kit_rejects_telemetry() -> None:
    young = _register(UserRole.YOUNG, "Nadia Off")
    kit = _kit(young)
    client.patch(f"/api/v1/trackers/{kit['id']}", headers=_auth(young), json={"enabled": False})
    ping = client.post("/api/v1/iot/location", json={**_creds(kit), **POINT})
    assert ping.status_code == 403
    event = client.post("/api/v1/iot/events", json={**_creds(kit), "event_type": "SIGNAL_LOST"})
    assert event.status_code == 403


def test_demo_scenario_plays() -> None:
    young = _register(UserRole.YOUNG, "Scénario")
    parent = _register(UserRole.PARENT, "Parent Scénario")
    _pair(young, parent)
    kit = _kit(young)
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
    creds = _creds(kit)
    for step in DEMO_STEPS:
        if step["kind"] == "location":
            body = {
                **creds,
                "latitude": step["latitude"],
                "longitude": step["longitude"],
                "accuracy": step.get("accuracy"),
                "battery_level": step.get("battery_level"),
                "speed": step.get("speed"),
                "heading": step.get("heading"),
                "recorded_at": step["recorded_at"],
            }
            response = client.post("/api/v1/iot/location", json=body)
        else:
            body = {
                **creds,
                "event_type": step["event_type"],
                "recorded_at": step["recorded_at"],
                "latitude": step.get("latitude"),
                "longitude": step.get("longitude"),
            }
            response = client.post("/api/v1/iot/events", json=body)
        assert response.status_code == 200, f"{step['label']}: {response.text}"
    listed = client.get("/api/v1/trackers/me", headers=_auth(young))
    assert listed.json()[0]["status"] == "SIGNAL_LOST"
    inbox = client.get("/api/v1/notifications/me", headers=_auth(parent))
    types = {note["notification_type"] for note in inbox.json()}
    assert "GEOFENCE_EXIT" in types
    assert "SIGNAL_LOST" in types
    history = client.get("/api/v1/locations/me/history", headers=_auth(young))
    assert history.json()[0]["source"] == "IOT"
    assert history.json()[0]["is_stale"] is True
