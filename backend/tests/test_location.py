from datetime import datetime, timedelta, timezone
from uuid import uuid4

from fastapi.testclient import TestClient

from app.core.enums import UserRole
from app.main import app

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


def test_young_posts_phone_location() -> None:
    young = _register(UserRole.YOUNG, "Amina GPS")
    posted = client.post(
        "/api/v1/locations",
        headers=_auth(young),
        json={"latitude": 3.8480, "longitude": 11.5021, "accuracy": 12},
    )
    assert posted.status_code == 200, posted.text
    body = posted.json()
    assert body["source"] == "PHONE"
    assert body["tracker_id"] is None
    assert body["latitude"] == 3.8480
    assert body["is_stale"] is False
    assert body["age_seconds"] >= 0

    latest = client.get("/api/v1/locations/me/latest", headers=_auth(young))
    assert latest.status_code == 200
    assert latest.json()["id"] == body["id"]


def test_parent_cannot_post_location() -> None:
    parent = _register(UserRole.PARENT, "Marie GPS")
    posted = client.post(
        "/api/v1/locations",
        headers=_auth(parent),
        json={"latitude": 3.84, "longitude": 11.50},
    )
    assert posted.status_code == 403


def test_parent_needs_location_permission() -> None:
    young = _register(UserRole.YOUNG, "Paul GPS")
    parent = _register(UserRole.PARENT, "Lucie GPS")
    link = _pair(young, parent)
    young_id = young["user"]["young_person_id"]

    posted = client.post(
        "/api/v1/locations",
        headers=_auth(young),
        json={"latitude": 4.05, "longitude": 9.70},
    )
    assert posted.status_code == 200, posted.text

    denied = client.get(f"/api/v1/locations/children/{young_id}/latest", headers=_auth(parent))
    assert denied.status_code == 403
    assert "autorisé" in denied.json()["detail"].lower() or "autoris" in denied.json()["detail"].lower()

    granted = client.patch(
        f"/api/v1/family/links/{link['id']}/permissions",
        headers=_auth(young),
        json={"can_view_location": True},
    )
    assert granted.status_code == 200
    assert granted.json()["can_view_location"] is True

    allowed = client.get(f"/api/v1/locations/children/{young_id}/latest", headers=_auth(parent))
    assert allowed.status_code == 200, allowed.text
    assert allowed.json()["latitude"] == 4.05
    assert allowed.json()["source"] == "PHONE"


def test_old_fix_is_marked_stale() -> None:
    young = _register(UserRole.YOUNG, "Sara GPS")
    old = (datetime.now(timezone.utc) - timedelta(minutes=10)).isoformat()
    posted = client.post(
        "/api/v1/locations",
        headers=_auth(young),
        json={"latitude": 3.87, "longitude": 11.52, "recorded_at": old},
    )
    assert posted.status_code == 200, posted.text
    assert posted.json()["is_stale"] is True
    assert posted.json()["age_seconds"] >= 300
