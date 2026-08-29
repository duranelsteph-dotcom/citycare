from uuid import uuid4

from fastapi.testclient import TestClient

from app.core.enums import UserRole
from app.main import app
from simulator.seed import AUTHORITY, PARENT, RELATIVE, YOUNG, play_search_act, seed_demo
from simulator.scenario import SCHOOL

client = TestClient(app)

EXIT = {"latitude": 3.873, "longitude": 11.521}
SIGHT = {"latitude": 3.875, "longitude": 11.522}


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


def test_health_reports_demo_version() -> None:
    health = client.get("/api/v1/health")
    assert health.status_code == 200
    assert health.json()["version"] == "0.34.0"
    assert health.json()["status"] == "ok"


def test_soutenance_scenarios_prevention_to_testimony() -> None:
    young = _register(UserRole.YOUNG, "Amina Soutenance")
    parent = _register(UserRole.PARENT, "Marie Soutenance")
    link = _pair(young, parent)
    young_id = young["user"]["young_person_id"]
    assert link["can_view_location"] is False

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

    inside = client.post(
        "/api/v1/locations",
        headers=_auth(young),
        json={**SCHOOL, "accuracy": 12, "recorded_at": "2026-08-24T10:00:00+01:00"},
    )
    assert inside.status_code == 200, inside.text
    mine = client.get("/api/v1/zones/me", headers=_auth(young))
    assert mine.status_code == 200
    school = next(item for item in mine.json() if item["name"] == "École")
    assert school["inside_on_last_fix"] is True

    outside = client.post(
        "/api/v1/locations",
        headers=_auth(young),
        json={**EXIT, "accuracy": 12, "recorded_at": "2026-08-24T15:20:00+01:00"},
    )
    assert outside.status_code == 200, outside.text
    notes = [
        note
        for note in client.get("/api/v1/notifications/me", headers=_auth(parent)).json()
        if note["notification_type"] == "GEOFENCE_EXIT"
    ]
    assert len(notes) == 1
    assert "École" in notes[0]["body"]
    assert "kidnapping" in notes[0]["body"].lower()
    after_exit = client.get("/api/v1/zones/me", headers=_auth(young))
    school = next(item for item in after_exit.json() if item["name"] == "École")
    assert school["inside_on_last_fix"] is False

    sos = client.post("/api/v1/alerts/sos", headers=_auth(young), json={**EXIT, "accuracy": 15})
    assert sos.status_code == 200, sos.text
    assert sos.json()["source"] == "MOBILE"
    sos_notes = [
        note
        for note in client.get("/api/v1/notifications/me", headers=_auth(parent)).json()
        if note["notification_type"] == "SOS"
    ]
    assert len(sos_notes) == 1
    assert "kidnapping" in sos_notes[0]["body"].lower()

    created = client.post(
        "/api/v1/cases",
        headers=_auth(parent),
        json={"young_person_id": young_id, "circumstances": "Pas rentré de l'école"},
    )
    assert created.status_code == 200, created.text
    case_id = created.json()["id"]
    children = client.get("/api/v1/family/children", headers=_auth(parent))
    assert children.json()[0]["can_view_location"] is False
    snapshot = created.json()["snapshot"]
    assert snapshot is not None
    assert "kidnapping" in snapshot["disclaimer"].lower()

    intel = client.get(f"/api/v1/cases/{case_id}/intelligence", headers=_auth(parent))
    assert intel.status_code == 200, intel.text
    assert intel.json()["method"] == "rules"
    assert intel.json()["has_search_zone"] is True
    assert "kidnapping" in intel.json()["disclaimer"].lower()
    zones = client.get(f"/api/v1/cases/{case_id}/search-zones", headers=_auth(parent))
    kinds = {item["kind"] for item in zones.json()}
    assert "PROBABLE_DISPLACEMENT" in kinds
    assert "PRIORITY_SEARCH" in kinds

    ai = client.get(f"/api/v1/cases/{case_id}/ai-analysis", headers=_auth(parent))
    assert ai.status_code == 200, ai.text
    assert ai.json()["trained_model"] is False
    assert "kidnapping" in ai.json()["disclaimer"].lower()

    testimony = client.post(
        f"/api/v1/cases/{case_id}/testimonies",
        headers=_auth(parent),
        json={
            "description": "Je l'ai aperçu près du carrefour vers 16h48.",
            **SIGHT,
            "observed_at": "2026-08-24T16:48:00+01:00",
        },
    )
    assert testimony.status_code == 200, testimony.text
    assert testimony.json()["consistency"] in {"LOW", "MEDIUM", "HIGH"}
    assert "preuve" in testimony.json()["disclaimer"].lower()
    assert "preuve" in (testimony.json()["consistency_note"] or "").lower()


def test_demo_seed_is_idempotent() -> None:
    first = seed_demo(client, play=False)
    second = seed_demo(client, play=False)
    assert first["young_person_id"] == second["young_person_id"]
    assert first["can_view_location"] is False
    assert first["can_trigger_alert"] is True
    assert second["can_trigger_alert"] is True
    login = client.post("/api/v1/auth/login", json={"phone": PARENT["phone"], "password": "motdepasse"})
    assert login.status_code == 200
    young_login = client.post("/api/v1/auth/login", json={"phone": YOUNG["phone"], "password": "motdepasse"})
    assert young_login.status_code == 200
    relative_login = client.post("/api/v1/auth/login", json={"phone": RELATIVE["phone"], "password": "motdepasse"})
    assert relative_login.status_code == 200
    authority_login = client.post("/api/v1/auth/login", json={"phone": AUTHORITY["phone"], "password": "motdepasse"})
    assert authority_login.status_code == 200
    zones = client.get(
        f"/api/v1/zones/children/{second['young_person_id']}",
        headers={"Authorization": f"Bearer {login.json()['access_token']}"},
    )
    names = {zone["name"] for zone in zones.json()}
    assert "École" in names
    assert "Maison" in names
    risks = client.get(
        "/api/v1/risk-zones/list",
        headers={"Authorization": f"Bearer {login.json()['access_token']}"},
    )
    assert risks.status_code == 200, risks.text
    assert "Carrefour du marché" in {zone["name"] for zone in risks.json()}
    guardians = client.get(
        "/api/v1/family/guardians",
        headers={"Authorization": f"Bearer {young_login.json()['access_token']}"},
    )
    assert guardians.status_code == 200, guardians.text
    marc = next(link for link in guardians.json() if link["guardian_phone"] == RELATIVE["phone"])
    assert marc["can_trigger_alert"] is True
    received = client.get(
        "/api/v1/shares/received",
        headers={"Authorization": f"Bearer {login.json()['access_token']}"},
    )
    assert received.status_code == 200, received.text
    active = [share for share in received.json() if share["is_active"] and share["young_person_id"] == second["young_person_id"]]
    assert active


def test_demo_search_act_is_idempotent_not_kidnapping() -> None:
    first = seed_demo(client, play=False)
    young_id = first["young_person_id"]
    played = play_search_act(client, first["parent"], first["young"], young_id)
    again = play_search_act(client, first["parent"], first["young"], young_id)
    assert played["sos"]["id"] == again["sos"]["id"]
    assert played["case"]["id"] == again["case"]["id"]
    assert played["case"]["status"] == "SEARCHING"
    assert again["case"]["status"] == "SEARCHING"
    assert played["intelligence"]["method"] == "rules"
    assert played["intelligence"]["has_search_zone"] is True
    assert "kidnapping" in played["intelligence"]["disclaimer"].lower()
    notes = client.get(
        f"/api/v1/cases/{played['case']['id']}/testimonies",
        headers={"Authorization": f"Bearer {first['parent']['access_token']}"},
    )
    assert notes.status_code == 200
    assert notes.json()
    assert "preuve" in notes.json()[0]["disclaimer"].lower()
    emergency = client.get(
        f"/api/v1/emergency/children/{young_id}",
        headers={"Authorization": f"Bearer {first['parent']['access_token']}"},
    )
    assert emergency.status_code == 200, emergency.text
    assert emergency.json()["is_live"] is False
    assert "kidnapping" in emergency.json()["disclaimer"].lower()
