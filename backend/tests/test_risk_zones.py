from datetime import datetime
from uuid import uuid4

from fastapi.testclient import TestClient

from app.core.enums import UserRole
from app.main import app
from app.services.risk_zone_service import hour_window_active

client = TestClient(app)

# Distinct from the school point used by geofence tests (shared SQLite DB).
DANGER = {"latitude": 3.912, "longitude": 11.548}
NEAR_OUT = {"latitude": 3.918, "longitude": 11.548}
EVENING = "2026-08-24T20:00:00+01:00"
MORNING = "2026-08-24T10:00:00+01:00"
EVENING_LATER = "2026-08-24T20:30:00+01:00"


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


def _wipe_risk_zones(actor: dict) -> None:
    listed = client.get("/api/v1/risk-zones/list", headers=_auth(actor))
    assert listed.status_code == 200, listed.text
    for zone in listed.json():
        removed = client.delete(f"/api/v1/risk-zones/{zone['id']}", headers=_auth(actor))
        assert removed.status_code == 204, removed.text


def _danger_zone(**overrides: object) -> dict:
    payload = {
        "name": "Carrefour dangereux",
        **DANGER,
        "radius_meters": 250,
        "typical_start_hour": 18,
        "typical_end_hour": 23,
    }
    payload.update(overrides)
    return payload


def _post_fix(young: dict, coords: dict, recorded_at: str, accuracy: float = 12) -> dict:
    response = client.post(
        "/api/v1/locations",
        headers=_auth(young),
        json={**coords, "accuracy": accuracy, "recorded_at": recorded_at},
    )
    assert response.status_code == 200, response.text
    return response.json()


def test_hour_window_always_when_unbounded() -> None:
    at = datetime.fromisoformat("2026-08-24T20:00:00+01:00")
    assert hour_window_active(None, None, at) is True
    assert hour_window_active(18, 23, at) is True
    assert hour_window_active(18, 23, datetime.fromisoformat("2026-08-24T10:00:00+01:00")) is False
    assert hour_window_active(20, 6, at) is True
    assert hour_window_active(20, 6, datetime.fromisoformat("2026-08-24T10:00:00+01:00")) is False


def test_parent_and_authority_create_young_lists_young_cannot_create() -> None:
    young = _register(UserRole.YOUNG, "Amina Risk")
    parent = _register(UserRole.PARENT, "Marie Risk")
    authority = _register(UserRole.AUTHORITY, "Poste Risk")
    _wipe_risk_zones(parent)
    name = f"Carrefour {uuid4().hex[:6]}"
    created = client.post("/api/v1/risk-zones", headers=_auth(parent), json=_danger_zone(name=name))
    assert created.status_code == 200, created.text
    assert created.json()["is_hour_active_now"] in {True, False}

    listed = client.get("/api/v1/risk-zones/list", headers=_auth(young))
    assert listed.status_code == 200
    assert any(item["name"] == name for item in listed.json())

    forbidden = client.post("/api/v1/risk-zones", headers=_auth(young), json=_danger_zone(name="Interdit"))
    assert forbidden.status_code == 403

    official = client.post(
        "/api/v1/risk-zones",
        headers=_auth(authority),
        json=_danger_zone(name=f"Officiel {uuid4().hex[:6]}", typical_start_hour=None, typical_end_hour=None),
    )
    assert official.status_code == 200, official.text
    assert official.json()["typical_start_hour"] is None


def test_enter_during_hours_notifies_young_and_parent() -> None:
    young = _register(UserRole.YOUNG, "Paul Risk")
    parent = _register(UserRole.PARENT, "Lucie Risk")
    _pair(young, parent)
    _wipe_risk_zones(parent)
    name = f"Carrefour {uuid4().hex[:6]}"
    created = client.post("/api/v1/risk-zones", headers=_auth(parent), json=_danger_zone(name=name))
    assert created.status_code == 200, created.text

    _post_fix(young, NEAR_OUT, EVENING)
    assert client.get("/api/v1/notifications/me", headers=_auth(young)).json() == []
    assert client.get("/api/v1/notifications/me", headers=_auth(parent)).json() == []

    _post_fix(young, DANGER, EVENING_LATER)
    young_inbox = client.get("/api/v1/notifications/me", headers=_auth(young))
    parent_inbox = client.get("/api/v1/notifications/me", headers=_auth(parent))
    assert young_inbox.status_code == 200
    assert len(young_inbox.json()) == 1
    note = young_inbox.json()[0]
    assert note["notification_type"] == "RISK_ZONE_ENTER"
    assert name in note["body"]
    assert "kidnapping" in note["body"].lower()
    assert len(parent_inbox.json()) == 1
    assert parent_inbox.json()[0]["notification_type"] == "RISK_ZONE_ENTER"


def test_outside_typical_hours_does_not_notify() -> None:
    young = _register(UserRole.YOUNG, "Sara Hours")
    parent = _register(UserRole.PARENT, "Jean Hours")
    _pair(young, parent)
    _wipe_risk_zones(parent)
    client.post("/api/v1/risk-zones", headers=_auth(parent), json=_danger_zone(name=f"Soir {uuid4().hex[:6]}"))
    _post_fix(young, DANGER, MORNING)
    assert client.get("/api/v1/notifications/me", headers=_auth(young)).json() == []
    assert client.get("/api/v1/notifications/me", headers=_auth(parent)).json() == []


def test_poor_accuracy_does_not_notify() -> None:
    young = _register(UserRole.YOUNG, "Nadia Gps")
    parent = _register(UserRole.PARENT, "Pierre Gps")
    _pair(young, parent)
    _wipe_risk_zones(parent)
    client.post("/api/v1/risk-zones", headers=_auth(parent), json=_danger_zone(name=f"Gps {uuid4().hex[:6]}"))
    _post_fix(young, DANGER, EVENING, accuracy=800)
    assert client.get("/api/v1/notifications/me", headers=_auth(young)).json() == []


def test_incident_increments_count() -> None:
    parent = _register(UserRole.PARENT, "Incidents Parent")
    _wipe_risk_zones(parent)
    created = client.post("/api/v1/risk-zones", headers=_auth(parent), json=_danger_zone(name=f"Marché {uuid4().hex[:6]}"))
    zone_id = created.json()["id"]
    assert created.json()["incident_count"] == 0
    incident = client.post(
        f"/api/v1/risk-zones/{zone_id}/incidents",
        headers=_auth(parent),
        json={"title": "Agression signalée", "count": 2, "source": "déclaration"},
    )
    assert incident.status_code == 200, incident.text
    listed = client.get("/api/v1/risk-zones/list", headers=_auth(parent))
    zone = next(item for item in listed.json() if item["id"] == zone_id)
    assert zone["incident_count"] == 2
    history = client.get(f"/api/v1/risk-zones/{zone_id}/incidents", headers=_auth(parent))
    assert history.status_code == 200
    assert len(history.json()) == 1
    assert history.json()[0]["count"] == 2
