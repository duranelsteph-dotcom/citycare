from datetime import datetime, timedelta, timezone
from uuid import uuid4

from fastapi.testclient import TestClient

from app.core.enums import UserRole
from app.main import app

client = TestClient(app)

POINT = {"latitude": 3.8480, "longitude": 11.5021, "accuracy": 15}
NORTH = {"latitude": 3.8490, "longitude": 11.5021, "accuracy": 15}
MID = {"latitude": 3.8485, "longitude": 11.5021}
FAR = {"latitude": 10.0, "longitude": 15.0}


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


def _open_case(young: dict, parent: dict) -> tuple[str, dict]:
    link = _pair(young, parent)
    created = client.post("/api/v1/cases", headers=_auth(parent), json={"young_person_id": link["young_person_id"]})
    assert created.status_code == 200, created.text
    return created.json()["id"], link


def test_interpolated_midpoint_is_high() -> None:
    young = _register(UserRole.YOUNG, "Amina Coh")
    parent = _register(UserRole.PARENT, "Marie Coh")
    t0 = datetime.now(timezone.utc) - timedelta(minutes=4)
    t1 = t0 + timedelta(minutes=2)
    mid = t0 + timedelta(minutes=1)
    client.post("/api/v1/locations", headers=_auth(young), json={**POINT, "recorded_at": t0.isoformat()})
    client.post("/api/v1/locations", headers=_auth(young), json={**NORTH, "recorded_at": t1.isoformat()})
    case_id, _ = _open_case(young, parent)
    created = client.post(
        f"/api/v1/cases/{case_id}/testimonies",
        headers=_auth(parent),
        json={
            "description": "Vu pile sur le trajet, à mi-chemin.",
            **MID,
            "observed_at": mid.isoformat(),
        },
    )
    assert created.status_code == 200, created.text
    body = created.json()
    assert body["consistency"] == "HIGH"
    note = body["consistency_note"].lower()
    assert "interpol" in note
    assert "preuve" in note
    assert "kidnapping" in note


def test_far_sighting_is_low() -> None:
    young = _register(UserRole.YOUNG, "Paul Coh")
    parent = _register(UserRole.PARENT, "Lucie Coh")
    at = datetime.now(timezone.utc) - timedelta(minutes=5)
    client.post("/api/v1/locations", headers=_auth(young), json={**POINT, "recorded_at": at.isoformat()})
    case_id, _ = _open_case(young, parent)
    created = client.post(
        f"/api/v1/cases/{case_id}/testimonies",
        headers=_auth(parent),
        json={
            "description": "Vu à des centaines de kilomètres, même heure.",
            **FAR,
            "observed_at": at.isoformat(),
        },
    )
    assert created.status_code == 200, created.text
    body = created.json()
    assert body["consistency"] == "LOW"
    assert "preuve" in body["consistency_note"].lower()


def test_no_gps_around_testimony_is_low() -> None:
    young = _register(UserRole.YOUNG, "Sara Coh")
    parent = _register(UserRole.PARENT, "Jean Coh")
    case_id, _ = _open_case(young, parent)
    created = client.post(
        f"/api/v1/cases/{case_id}/testimonies",
        headers=_auth(parent),
        json={"description": "Vu près du marché, sans GPS autour.", **MID},
    )
    assert created.status_code == 200, created.text
    body = created.json()
    assert body["consistency"] == "LOW"
    note = body["consistency_note"].lower()
    assert "aucune position" in note or "aucune" in note
    assert "preuve" in note


def test_does_not_interpolate_across_communication_gap() -> None:
    young = _register(UserRole.YOUNG, "Noah Coh")
    parent = _register(UserRole.PARENT, "Claire Coh")
    t0 = datetime.now(timezone.utc) - timedelta(minutes=30)
    t1 = t0 + timedelta(minutes=20)
    mid = t0 + timedelta(minutes=10)
    client.post("/api/v1/locations", headers=_auth(young), json={**POINT, "recorded_at": t0.isoformat()})
    client.post("/api/v1/locations", headers=_auth(young), json={**POINT, "recorded_at": t1.isoformat()})
    case_id, _ = _open_case(young, parent)
    created = client.post(
        f"/api/v1/cases/{case_id}/testimonies",
        headers=_auth(parent),
        json={
            "description": "Vu très loin pendant un trou de communication.",
            **FAR,
            "observed_at": mid.isoformat(),
        },
    )
    assert created.status_code == 200, created.text
    body = created.json()
    assert body["consistency"] == "LOW"
    note = body["consistency_note"].lower()
    assert "interpol" in note or "trou" in note
    assert "preuve" in note


def test_young_can_refresh_consistency_stranger_cannot() -> None:
    young = _register(UserRole.YOUNG, "Lea Coh")
    parent = _register(UserRole.PARENT, "Hugo Coh")
    stranger = _register(UserRole.PARENT, "Nina Coh")
    at = datetime.now(timezone.utc) - timedelta(minutes=8)
    client.post("/api/v1/locations", headers=_auth(young), json={**POINT, "recorded_at": at.isoformat()})
    case_id, _ = _open_case(young, parent)
    created = client.post(
        f"/api/v1/cases/{case_id}/testimonies",
        headers=_auth(parent),
        json={"description": "Aperçu près de l'école.", **MID, "observed_at": at.isoformat()},
    )
    assert created.status_code == 200, created.text

    denied = client.post(f"/api/v1/cases/{case_id}/testimonies/consistency", headers=_auth(stranger))
    assert denied.status_code == 403

    refreshed = client.post(f"/api/v1/cases/{case_id}/testimonies/consistency", headers=_auth(young))
    assert refreshed.status_code == 200, refreshed.text
    rows = refreshed.json()
    assert len(rows) == 1
    assert rows[0]["consistency"] in {"LOW", "MEDIUM", "HIGH"}
    assert "preuve" in rows[0]["consistency_note"].lower()

    children = client.get("/api/v1/family/children", headers=_auth(parent))
    assert children.json()[0]["can_view_location"] is False
