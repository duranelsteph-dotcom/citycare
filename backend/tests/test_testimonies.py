from datetime import datetime, timedelta, timezone
from uuid import uuid4

from fastapi.testclient import TestClient

from app.core.enums import UserRole
from app.main import app

client = TestClient(app)

POINT = {"latitude": 3.8480, "longitude": 11.5021, "accuracy": 15}
SIGHT = {"latitude": 3.8600, "longitude": 11.5100}


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


def _open_case(young: dict, parent: dict) -> str:
    link = _pair(young, parent)
    old = (datetime.now(timezone.utc) - timedelta(minutes=40)).isoformat()
    client.post("/api/v1/locations", headers=_auth(young), json={**POINT, "recorded_at": old})
    created = client.post("/api/v1/cases", headers=_auth(parent), json={"young_person_id": link["young_person_id"]})
    assert created.status_code == 200, created.text
    return created.json()["id"]


def test_parent_submits_testimony_with_estimated_consistency() -> None:
    young = _register(UserRole.YOUNG, "Amina Temoin")
    parent = _register(UserRole.PARENT, "Marie Temoin")
    case_id = _open_case(young, parent)
    observed = (datetime.now(timezone.utc) - timedelta(minutes=12)).isoformat()
    created = client.post(
        f"/api/v1/cases/{case_id}/testimonies",
        headers=_auth(parent),
        json={
            "description": "Je l'ai aperçu près du carrefour vers 16h48.",
            **SIGHT,
            "observed_at": observed,
        },
    )
    assert created.status_code == 200, created.text
    body = created.json()
    assert body["status"] == "SUBMITTED"
    assert body["consistency"] in {"LOW", "MEDIUM", "HIGH"}
    assert body["consistency_note"]
    assert "preuve" in body["consistency_note"].lower()
    assert "preuve" in body["disclaimer"].lower() or "kidnapping" in body["disclaimer"].lower()
    assert body["submitter_name"] == "Marie Temoin"

    listed = client.get(f"/api/v1/cases/{case_id}/testimonies", headers=_auth(parent))
    assert listed.status_code == 200
    assert len(listed.json()) == 1

    young_view = client.get(f"/api/v1/cases/{case_id}/testimonies", headers=_auth(young))
    assert young_view.status_code == 200
    assert len(young_view.json()) == 1

    inbox = client.get("/api/v1/notifications/me", headers=_auth(young))
    notes = [note for note in inbox.json() if note["notification_type"] == "TESTIMONY"]
    assert len(notes) == 1
    assert notes[0]["case_id"] == case_id
    assert "kidnapping" in notes[0]["body"].lower()
    assert "preuve" in notes[0]["body"].lower()

    parent_inbox = client.get("/api/v1/notifications/me", headers=_auth(parent))
    parent_notes = [note for note in parent_inbox.json() if note["notification_type"] == "TESTIMONY"]
    assert parent_notes == []

    children = client.get("/api/v1/family/children", headers=_auth(parent))
    assert children.json()[0]["can_view_location"] is False

    refreshed = client.post(f"/api/v1/cases/{case_id}/intelligence", headers=_auth(parent))
    factors = refreshed.json()["factors"]["testimonies"]
    assert factors["count"] == 1
    assert factors["by_consistency"][body["consistency"]] == 1
    note = factors["note"].lower()
    assert "croisés" in note or "croises" in note
    assert "preuve" in note


def test_parent_can_review_verify_and_reject() -> None:
    young = _register(UserRole.YOUNG, "Paul Temoin")
    parent = _register(UserRole.PARENT, "Lucie Temoin")
    case_id = _open_case(young, parent)
    first = client.post(
        f"/api/v1/cases/{case_id}/testimonies",
        headers=_auth(parent),
        json={"description": "Vu près de l'école, tee-shirt bleu.", **SIGHT},
    ).json()
    reviewed = client.post(
        f"/api/v1/cases/{case_id}/testimonies/{first['id']}/review",
        headers=_auth(parent),
    )
    assert reviewed.status_code == 200
    assert reviewed.json()["status"] == "UNDER_REVIEW"
    assert reviewed.json()["consistency"] in {"LOW", "MEDIUM", "HIGH"}

    verified = client.post(
        f"/api/v1/cases/{case_id}/testimonies/{first['id']}/verify",
        headers=_auth(parent),
    )
    assert verified.status_code == 200
    assert verified.json()["status"] == "VERIFIED"
    assert verified.json()["consistency"] in {"LOW", "MEDIUM", "HIGH"}
    again = client.post(
        f"/api/v1/cases/{case_id}/testimonies/{first['id']}/verify",
        headers=_auth(parent),
    )
    assert again.status_code == 409

    second = client.post(
        f"/api/v1/cases/{case_id}/testimonies",
        headers=_auth(parent),
        json={"description": "Autre signalement peu fiable au marché.", "latitude": 3.87, "longitude": 11.52},
    ).json()
    rejected = client.post(
        f"/api/v1/cases/{case_id}/testimonies/{second['id']}/reject",
        headers=_auth(parent),
    )
    assert rejected.status_code == 200
    assert rejected.json()["status"] == "REJECTED"


def test_young_cannot_submit_testimony() -> None:
    young = _register(UserRole.YOUNG, "Sara Temoin")
    parent = _register(UserRole.PARENT, "Jean Temoin")
    case_id = _open_case(young, parent)
    denied = client.post(
        f"/api/v1/cases/{case_id}/testimonies",
        headers=_auth(young),
        json={"description": "Je me suis vu moi-même au carrefour.", **SIGHT},
    )
    assert denied.status_code == 403


def test_relative_can_submit_but_not_verify() -> None:
    young = _register(UserRole.YOUNG, "Noah Temoin")
    parent = _register(UserRole.PARENT, "Claire Temoin")
    relative = _register(UserRole.RELATIVE, "Marc Temoin")
    case_id = _open_case(young, parent)
    _pair(young, relative)
    created = client.post(
        f"/api/v1/cases/{case_id}/testimonies",
        headers=_auth(relative),
        json={"description": "Aperçu près de la station de bus.", **SIGHT},
    )
    assert created.status_code == 200, created.text
    verify = client.post(
        f"/api/v1/cases/{case_id}/testimonies/{created.json()['id']}/verify",
        headers=_auth(relative),
    )
    assert verify.status_code == 403


def test_stranger_cannot_read_or_submit_testimony() -> None:
    young = _register(UserRole.YOUNG, "Lea Temoin")
    parent = _register(UserRole.PARENT, "Hugo Temoin")
    stranger = _register(UserRole.PARENT, "Nina Temoin")
    case_id = _open_case(young, parent)
    listed = client.get(f"/api/v1/cases/{case_id}/testimonies", headers=_auth(stranger))
    assert listed.status_code == 403
    created = client.post(
        f"/api/v1/cases/{case_id}/testimonies",
        headers=_auth(stranger),
        json={"description": "Un inconnu dépose un témoignage.", **SIGHT},
    )
    assert created.status_code == 403


def test_closed_case_rejects_new_testimony() -> None:
    young = _register(UserRole.YOUNG, "Ivy Temoin")
    parent = _register(UserRole.PARENT, "Omar Temoin")
    case_id = _open_case(young, parent)
    closed = client.post(f"/api/v1/cases/{case_id}/found", headers=_auth(parent))
    assert closed.status_code == 200
    created = client.post(
        f"/api/v1/cases/{case_id}/testimonies",
        headers=_auth(parent),
        json={"description": "Témoignage trop tardif après clôture.", **SIGHT},
    )
    assert created.status_code == 409
    listed = client.get(f"/api/v1/cases/{case_id}/testimonies", headers=_auth(parent))
    assert listed.status_code == 200
    assert listed.json() == []
