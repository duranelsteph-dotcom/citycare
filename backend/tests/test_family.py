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


def test_pairing_code_links_parent_immediately() -> None:
    young = _register(UserRole.YOUNG, "Amina")
    parent = _register(UserRole.PARENT, "Marie")
    code = client.post(
        "/api/v1/family/young/pairing-code",
        headers={"Authorization": f"Bearer {young['access_token']}"},
    )
    assert code.status_code == 200, code.text
    linked = client.post(
        "/api/v1/family/links/code",
        headers={"Authorization": f"Bearer {parent['access_token']}"},
        json={"code": code.json()["code"]},
    )
    assert linked.status_code == 200, linked.text
    assert linked.json()["status"] == "ACTIVE"
    assert linked.json()["can_view_location"] is False

    children = client.get(
        "/api/v1/family/children",
        headers={"Authorization": f"Bearer {parent['access_token']}"},
    )
    assert children.status_code == 200
    assert len(children.json()) == 1
    assert children.json()[0]["young_display_name"] == "Amina"


def test_invite_requires_young_accept() -> None:
    young = _register(UserRole.YOUNG, "Paul")
    parent = _register(UserRole.PARENT, "Lucie")
    invite = client.post(
        "/api/v1/family/links/invite",
        headers={"Authorization": f"Bearer {parent['access_token']}"},
        json={"phone": young["_phone"]},
    )
    assert invite.status_code == 200, invite.text
    assert invite.json()["status"] == "PENDING"
    link_id = invite.json()["id"]

    accepted = client.post(
        f"/api/v1/family/links/{link_id}/accept",
        headers={"Authorization": f"Bearer {young['access_token']}"},
    )
    assert accepted.status_code == 200
    assert accepted.json()["status"] == "ACTIVE"


def test_young_can_grant_location_permission() -> None:
    young = _register(UserRole.YOUNG, "Sara")
    parent = _register(UserRole.PARENT, "Jean")
    code = client.post(
        "/api/v1/family/young/pairing-code",
        headers={"Authorization": f"Bearer {young['access_token']}"},
    ).json()["code"]
    link = client.post(
        "/api/v1/family/links/code",
        headers={"Authorization": f"Bearer {parent['access_token']}"},
        json={"code": code},
    ).json()
    patched = client.patch(
        f"/api/v1/family/links/{link['id']}/permissions",
        headers={"Authorization": f"Bearer {young['access_token']}"},
        json={"can_view_location": True},
    )
    assert patched.status_code == 200, patched.text
    assert patched.json()["can_view_location"] is True
