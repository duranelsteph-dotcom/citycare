from uuid import uuid4

from fastapi.testclient import TestClient

from app.core.enums import UserRole
from app.main import app

client = TestClient(app)


def _register(role: UserRole, name: str) -> dict:
    phone = f"+2377{uuid4().hex[:8]}"
    response = client.post(
        "/api/v1/auth/register",
        json={"full_name": name, "phone": phone, "password": "VilleCare1!", "role": role.value},
    )
    assert response.status_code == 200, response.text
    return response.json()


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


def test_create_circle() -> None:
    parent = _register(UserRole.PARENT, "Marie Cercle")
    created = client.post(
        "/api/v1/circles",
        headers=_auth(parent),
        json={"name": "  Famille Steph  "},
    )
    assert created.status_code == 200, created.text
    body = created.json()
    assert body["name"] == "Famille Steph"
    assert body["my_role"] == "OWNER"
    assert body["member_count"] == 1
    assert len(body["invite_code"]) == 6
    listed = client.get("/api/v1/circles", headers=_auth(parent))
    assert listed.status_code == 200
    assert len(listed.json()) == 1
    assert listed.json()[0]["id"] == body["id"]


def test_join_by_code() -> None:
    parent = _register(UserRole.PARENT, "Lucie Cercle")
    young = _register(UserRole.YOUNG, "Paul Cercle")
    created = client.post(
        "/api/v1/circles",
        headers=_auth(parent),
        json={"name": "Famille Lucie"},
    )
    assert created.status_code == 200, created.text
    code = created.json()["invite_code"]
    joined = client.post("/api/v1/circles/join", headers=_auth(young), json={"code": code.lower()})
    assert joined.status_code == 200, joined.text
    assert joined.json()["my_role"] == "MEMBER"
    assert joined.json()["member_count"] == 2
    members = client.get(
        f"/api/v1/circles/{created.json()['id']}/members",
        headers=_auth(parent),
    )
    assert members.status_code == 200, members.text
    names = {item["full_name"] for item in members.json()}
    assert names == {"Lucie Cercle", "Paul Cercle"}


def test_non_member_members_forbidden() -> None:
    owner = _register(UserRole.PARENT, "Owner Cercle")
    stranger = _register(UserRole.PARENT, "Intrus Cercle")
    created = client.post(
        "/api/v1/circles",
        headers=_auth(owner),
        json={"name": "Privé"},
    )
    assert created.status_code == 200, created.text
    circle_id = created.json()["id"]
    members = client.get(f"/api/v1/circles/{circle_id}/members", headers=_auth(stranger))
    assert members.status_code == 403
    leave = client.post(f"/api/v1/circles/{circle_id}/leave", headers=_auth(stranger))
    assert leave.status_code == 403
    regen = client.post(f"/api/v1/circles/{circle_id}/invite-code", headers=_auth(stranger))
    assert regen.status_code == 403


def test_leave_does_not_revoke_guardian_link() -> None:
    young = _register(UserRole.YOUNG, "Amina Cercle")
    parent = _register(UserRole.PARENT, "Marie Lien")
    link = _pair(young, parent)
    assert link["status"] == "ACTIVE"
    created = client.post(
        "/api/v1/circles",
        headers=_auth(parent),
        json={"name": "Famille Lien"},
    )
    client.post(
        "/api/v1/circles/join",
        headers=_auth(young),
        json={"code": created.json()["invite_code"]},
    )
    left = client.post(f"/api/v1/circles/{created.json()['id']}/leave", headers=_auth(young))
    assert left.status_code == 204, left.text
    children = client.get("/api/v1/family/children", headers=_auth(parent))
    assert children.status_code == 200
    assert children.json()[0]["id"] == link["id"]
    assert children.json()[0]["status"] == "ACTIVE"


def test_get_current_invite_code() -> None:
    owner = _register(UserRole.PARENT, "Lina Code")
    member = _register(UserRole.YOUNG, "Tom Code")
    stranger = _register(UserRole.PARENT, "Intrus Code")
    created = client.post("/api/v1/circles", headers=_auth(owner), json={"name": "Code actuel"})
    assert created.status_code == 200, created.text
    circle_id = created.json()["id"]
    code = created.json()["invite_code"]
    client.post("/api/v1/circles/join", headers=_auth(member), json={"code": code})

    as_owner = client.get(f"/api/v1/circles/{circle_id}/invite-code", headers=_auth(owner))
    assert as_owner.status_code == 200, as_owner.text
    assert as_owner.json()["invite_code"] == code

    as_member = client.get(f"/api/v1/circles/{circle_id}/invite-code", headers=_auth(member))
    assert as_member.status_code == 200, as_member.text
    assert as_member.json()["invite_code"] == code

    forbidden = client.get(f"/api/v1/circles/{circle_id}/invite-code", headers=_auth(stranger))
    assert forbidden.status_code == 403

    regen = client.post(f"/api/v1/circles/{circle_id}/invite-code", headers=_auth(owner))
    assert regen.status_code == 200
    assert regen.json()["invite_code"] != code
    refreshed = client.get(f"/api/v1/circles/{circle_id}/invite-code", headers=_auth(member))
    assert refreshed.json()["invite_code"] == regen.json()["invite_code"]


def test_member_cannot_remove_other() -> None:
    owner = _register(UserRole.PARENT, "Chef Cercle")
    member = _register(UserRole.RELATIVE, "Marc Cercle")
    target = _register(UserRole.YOUNG, "Cible Cercle")
    created = client.post("/api/v1/circles", headers=_auth(owner), json={"name": "Trio"})
    code = created.json()["invite_code"]
    client.post("/api/v1/circles/join", headers=_auth(member), json={"code": code})
    client.post("/api/v1/circles/join", headers=_auth(target), json={"code": code})
    removed = client.delete(
        f"/api/v1/circles/{created.json()['id']}/members/{target['user']['id']}",
        headers=_auth(member),
    )
    assert removed.status_code == 403
