from uuid import uuid4

from fastapi.testclient import TestClient

from app.core.enums import UserRole
from app.main import app

client = TestClient(app)

POINT = {"latitude": 3.8480, "longitude": 11.5021, "accuracy": 15}


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


def test_parent_creates_case_with_snapshot_and_notify() -> None:
    young = _register(UserRole.YOUNG, "Amina Case")
    parent = _register(UserRole.PARENT, "Marie Case")
    link = _pair(young, parent)
    young_id = link["young_person_id"]
    assert link["can_view_location"] is False
    assert link["can_report_missing"] is True

    posted = client.post("/api/v1/locations", headers=_auth(young), json=POINT)
    assert posted.status_code == 200, posted.text

    created = client.post(
        "/api/v1/cases",
        headers=_auth(parent),
        json={
            "young_person_id": young_id,
            "circumstances": "Pas rentré de l'école",
            "clothing": "T-shirt bleu",
        },
    )
    assert created.status_code == 200, created.text
    body = created.json()
    assert body["status"] == "OPEN"
    assert body["young_display_name"] == "Amina Case"
    assert body["reporter_name"] == "Marie Case"
    assert body["last_known_latitude"] == POINT["latitude"]
    assert body["last_known_longitude"] == POINT["longitude"]
    snapshot = body["snapshot"]
    assert snapshot is not None
    assert "kidnapping" in snapshot["disclaimer"].lower()
    assert "trajectoire" in snapshot["disclaimer"].lower()
    assert snapshot["last_known"]["latitude"] == POINT["latitude"]
    assert snapshot["last_known"]["source"] == "PHONE"
    assert len(snapshot["recent_points"]) == 1
    assert snapshot["open_sos"] is None

    still = client.get("/api/v1/family/children", headers=_auth(parent))
    assert still.json()[0]["can_view_location"] is False

    inbox = client.get("/api/v1/notifications/me", headers=_auth(parent))
    notes = [note for note in inbox.json() if note["notification_type"] == "MISSING_CASE"]
    assert len(notes) == 1
    assert notes[0]["case_id"] == body["id"]
    assert "kidnapping" in notes[0]["body"].lower()

    young_inbox = client.get("/api/v1/notifications/me", headers=_auth(young))
    young_notes = [note for note in young_inbox.json() if note["notification_type"] == "MISSING_CASE"]
    assert len(young_notes) == 1

    listed = client.get("/api/v1/cases/mine", headers=_auth(parent))
    assert listed.status_code == 200
    assert listed.json()[0]["id"] == body["id"]

    own = client.get("/api/v1/cases/me", headers=_auth(young))
    assert own.status_code == 200
    assert own.json()[0]["id"] == body["id"]


def test_relative_cannot_report_missing_by_default() -> None:
    young = _register(UserRole.YOUNG, "Paul Case")
    relative = _register(UserRole.RELATIVE, "Lucie Case")
    link = _pair(young, relative)
    assert link["can_report_missing"] is False
    denied = client.post(
        "/api/v1/cases",
        headers=_auth(relative),
        json={"young_person_id": link["young_person_id"]},
    )
    assert denied.status_code == 403


def test_second_case_reuses_open() -> None:
    young = _register(UserRole.YOUNG, "Sara Case")
    parent = _register(UserRole.PARENT, "Jean Case")
    link = _pair(young, parent)
    first = client.post(
        "/api/v1/cases",
        headers=_auth(parent),
        json={"young_person_id": link["young_person_id"]},
    )
    second = client.post(
        "/api/v1/cases",
        headers=_auth(parent),
        json={"young_person_id": link["young_person_id"], "description": "encore"},
    )
    assert first.status_code == 200
    assert second.status_code == 200
    assert first.json()["id"] == second.json()["id"]
    inbox = client.get("/api/v1/notifications/me", headers=_auth(parent))
    notes = [note for note in inbox.json() if note["notification_type"] == "MISSING_CASE"]
    assert len(notes) == 1


def test_young_cannot_create_but_can_mark_found() -> None:
    young = _register(UserRole.YOUNG, "Nadia Case")
    parent = _register(UserRole.PARENT, "Pierre Case")
    link = _pair(young, parent)
    young_id = link["young_person_id"]
    denied = client.post("/api/v1/cases", headers=_auth(young), json={"young_person_id": young_id})
    assert denied.status_code == 403

    created = client.post("/api/v1/cases", headers=_auth(parent), json={"young_person_id": young_id})
    case_id = created.json()["id"]

    found = client.post(f"/api/v1/cases/{case_id}/found", headers=_auth(young))
    assert found.status_code == 200, found.text
    assert found.json()["status"] == "FOUND"

    closed = client.post(f"/api/v1/cases/{case_id}/close", headers=_auth(young))
    assert closed.status_code == 403

    again = client.post("/api/v1/cases", headers=_auth(parent), json={"young_person_id": young_id})
    assert again.status_code == 200
    assert again.json()["id"] != case_id


def test_parent_can_close_case() -> None:
    young = _register(UserRole.YOUNG, "Léo Case")
    parent = _register(UserRole.PARENT, "Marc Case")
    link = _pair(young, parent)
    created = client.post("/api/v1/cases", headers=_auth(parent), json={"young_person_id": link["young_person_id"]})
    case_id = created.json()["id"]
    closed = client.post(f"/api/v1/cases/{case_id}/close", headers=_auth(parent))
    assert closed.status_code == 200
    assert closed.json()["status"] == "CLOSED"
    inbox = client.get("/api/v1/notifications/me", headers=_auth(parent))
    notes = [note for note in inbox.json() if note["notification_type"] == "MISSING_CASE"]
    assert any("clôturé" in note["body"] for note in notes)


def test_parent_starts_search_is_not_kidnapping() -> None:
    young = _register(UserRole.YOUNG, "Amina Search")
    parent = _register(UserRole.PARENT, "Marie Search")
    link = _pair(young, parent)
    created = client.post("/api/v1/cases", headers=_auth(parent), json={"young_person_id": link["young_person_id"]})
    case_id = created.json()["id"]
    assert created.json()["status"] == "OPEN"
    denied = client.post(f"/api/v1/cases/{case_id}/searching", headers=_auth(young))
    assert denied.status_code == 403
    started = client.post(f"/api/v1/cases/{case_id}/searching", headers=_auth(parent))
    assert started.status_code == 200, started.text
    assert started.json()["status"] == "SEARCHING"
    again = client.post(f"/api/v1/cases/{case_id}/searching", headers=_auth(parent))
    assert again.status_code == 200
    assert again.json()["id"] == case_id
    inbox = client.get("/api/v1/notifications/me", headers=_auth(parent))
    notes = [note for note in inbox.json() if note["notification_type"] == "SEARCH_UPDATE"]
    assert notes
    assert "kidnapping" in notes[0]["body"].lower()
    assert "push" in notes[0]["body"].lower()
    closed = client.post(f"/api/v1/cases/{case_id}/close", headers=_auth(parent))
    assert closed.status_code == 200
    blocked = client.post(f"/api/v1/cases/{case_id}/searching", headers=_auth(parent))
    assert blocked.status_code == 409
