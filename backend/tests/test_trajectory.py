from datetime import datetime, timedelta, timezone
from uuid import uuid4

from fastapi.testclient import TestClient

from app.core.enums import UserRole
from app.main import app

client = TestClient(app)

A = {"latitude": 3.8480, "longitude": 11.5021, "accuracy": 12}
B = {"latitude": 3.8520, "longitude": 11.5060, "accuracy": 14}
C = {"latitude": 3.8560, "longitude": 11.5100, "accuracy": 18}


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


def _stamp(minutes_ago: int) -> str:
    return (datetime.now(timezone.utc) - timedelta(minutes=minutes_ago)).isoformat()


def test_young_trajectory_is_chronological_and_honest() -> None:
    young = _register(UserRole.YOUNG, "Amina Traj")
    now = datetime.now(timezone.utc)
    client.post(
        "/api/v1/locations",
        headers=_auth(young),
        json={**A, "recorded_at": (now - timedelta(minutes=12)).isoformat()},
    )
    client.post(
        "/api/v1/locations",
        headers=_auth(young),
        json={**B, "recorded_at": (now - timedelta(minutes=6)).isoformat()},
    )
    client.post(
        "/api/v1/locations",
        headers=_auth(young),
        json={**C, "recorded_at": (now - timedelta(minutes=1)).isoformat()},
    )
    traj = client.get("/api/v1/locations/me/trajectory", headers=_auth(young))
    assert traj.status_code == 200, traj.text
    body = traj.json()
    assert body["point_count"] == 3
    assert body["points"][0]["latitude"] == A["latitude"]
    assert body["points"][-1]["latitude"] == C["latitude"]
    assert body["access"] == "SELF"
    assert body["distance_meters"] > 0
    assert "suivi en direct" in body["disclaimer"]
    assert "zone de recherche" in body["disclaimer"]
    assert body["points"][0]["gap_after"] is False


def test_parent_needs_permission_or_open_case() -> None:
    young = _register(UserRole.YOUNG, "Paul Traj")
    parent = _register(UserRole.PARENT, "Lucie Traj")
    link = _pair(young, parent)
    young_id = link["young_person_id"]
    client.post("/api/v1/locations", headers=_auth(young), json=A)

    denied = client.get(f"/api/v1/locations/children/{young_id}/trajectory", headers=_auth(parent))
    assert denied.status_code == 403
    latest = client.get(f"/api/v1/locations/children/{young_id}/latest", headers=_auth(parent))
    assert latest.status_code == 403

    created = client.post("/api/v1/cases", headers=_auth(parent), json={"young_person_id": young_id})
    assert created.status_code == 200, created.text
    case_id = created.json()["id"]

    via_case = client.get(f"/api/v1/cases/{case_id}/trajectory", headers=_auth(parent))
    assert via_case.status_code == 200, via_case.text
    assert via_case.json()["access"] == "CASE"
    assert via_case.json()["point_count"] == 1
    assert "zone de recherche" in via_case.json()["disclaimer"]

    via_child = client.get(f"/api/v1/locations/children/{young_id}/trajectory", headers=_auth(parent))
    assert via_child.status_code == 200, via_child.text
    assert via_child.json()["access"] == "CASE"

    still_no_live = client.get(f"/api/v1/locations/children/{young_id}/latest", headers=_auth(parent))
    assert still_no_live.status_code == 403
    children = client.get("/api/v1/family/children", headers=_auth(parent))
    assert children.json()[0]["can_view_location"] is False

    urgent = client.get("/api/v1/locations/me/watch", headers=_auth(young))
    assert urgent.status_code == 200
    assert urgent.json()["effective_mode"] == "EMERGENCY"


def test_permission_grants_trajectory_without_case() -> None:
    young = _register(UserRole.YOUNG, "Sara Traj")
    parent = _register(UserRole.PARENT, "Jean Traj")
    link = _pair(young, parent)
    young_id = link["young_person_id"]
    client.post("/api/v1/locations", headers=_auth(young), json=B)
    granted = client.patch(
        f"/api/v1/family/links/{link['id']}/permissions",
        headers=_auth(young),
        json={"can_view_location": True},
    )
    assert granted.status_code == 200
    traj = client.get(f"/api/v1/locations/children/{young_id}/trajectory", headers=_auth(parent))
    assert traj.status_code == 200, traj.text
    assert traj.json()["access"] == "PERMISSION"
    assert traj.json()["point_count"] == 1


def test_gap_is_counted_not_interpolated() -> None:
    young = _register(UserRole.YOUNG, "Nadia Traj")
    client.post("/api/v1/locations", headers=_auth(young), json={**A, "recorded_at": _stamp(45)})
    client.post("/api/v1/locations", headers=_auth(young), json={**C, "recorded_at": _stamp(2)})
    traj = client.get("/api/v1/locations/me/trajectory", headers=_auth(young))
    assert traj.status_code == 200, traj.text
    body = traj.json()
    assert body["point_count"] == 2
    assert body["gap_count"] == 1
    assert body["points"][0]["gap_after"] is True
    assert body["distance_meters"] == 0
    assert body["points"][1]["gap_after"] is False


def test_empty_trajectory_is_not_an_error() -> None:
    young = _register(UserRole.YOUNG, "Léo Traj")
    traj = client.get("/api/v1/locations/me/trajectory", headers=_auth(young))
    assert traj.status_code == 200, traj.text
    assert traj.json()["point_count"] == 0
    assert traj.json()["points"] == []
