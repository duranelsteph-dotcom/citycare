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


def test_young_sos_notifies_parent_not_kidnapping() -> None:
    young = _register(UserRole.YOUNG, "Amina Sos")
    parent = _register(UserRole.PARENT, "Marie Sos")
    _pair(young, parent)
    created = client.post("/api/v1/alerts/sos", headers=_auth(young), json=POINT)
    assert created.status_code == 200, created.text
    body = created.json()
    assert body["source"] == "MOBILE"
    assert body["status"] == "ACTIVE"
    assert body["severity"] == "CRITICAL"
    assert body["latitude"] == POINT["latitude"]
    assert body["young_display_name"] == "Amina Sos"

    inbox = client.get("/api/v1/notifications/me", headers=_auth(parent))
    notes = [note for note in inbox.json() if note["notification_type"] == "SOS"]
    assert len(notes) == 1
    assert "Amina Sos" in notes[0]["body"]
    assert "kidnapping" in notes[0]["body"].lower()
    assert notes[0]["alert_id"] == body["id"]

    own = client.get("/api/v1/alerts/me", headers=_auth(young))
    assert own.status_code == 200
    assert own.json()[0]["id"] == body["id"]

    listed = client.get("/api/v1/alerts/mine", headers=_auth(parent))
    assert listed.status_code == 200
    assert listed.json()[0]["id"] == body["id"]


def test_parent_cannot_trigger_sos() -> None:
    parent = _register(UserRole.PARENT, "Lucie Sos")
    posted = client.post("/api/v1/alerts/sos", headers=_auth(parent), json=POINT)
    assert posted.status_code == 403


def test_second_sos_reuses_open_alert() -> None:
    young = _register(UserRole.YOUNG, "Paul Sos")
    first = client.post("/api/v1/alerts/sos", headers=_auth(young), json={})
    second = client.post("/api/v1/alerts/sos", headers=_auth(young), json=POINT)
    assert first.status_code == 200
    assert second.status_code == 200
    assert first.json()["id"] == second.json()["id"]
    inbox = client.get("/api/v1/notifications/me", headers=_auth(young))
    sos_notes = [note for note in inbox.json() if note["notification_type"] == "SOS"]
    assert len(sos_notes) == 1


def test_sos_without_gps_still_opens() -> None:
    young = _register(UserRole.YOUNG, "Sara Sos")
    created = client.post("/api/v1/alerts/sos", headers=_auth(young), json={})
    assert created.status_code == 200, created.text
    assert created.json()["status"] == "ACTIVE"
    assert created.json()["latitude"] is None


def test_cancel_and_acknowledge() -> None:
    young = _register(UserRole.YOUNG, "Nadia Sos")
    parent = _register(UserRole.PARENT, "Pierre Sos")
    _pair(young, parent)
    created = client.post("/api/v1/alerts/sos", headers=_auth(young), json=POINT)
    alert_id = created.json()["id"]

    ack = client.post(f"/api/v1/alerts/{alert_id}/acknowledge", headers=_auth(parent))
    assert ack.status_code == 200, ack.text
    assert ack.json()["status"] == "ACKNOWLEDGED"
    young_inbox = client.get("/api/v1/notifications/me", headers=_auth(young))
    assert any("pris en compte" in note["body"] for note in young_inbox.json())

    cancelled = client.post(f"/api/v1/alerts/{alert_id}/cancel", headers=_auth(young))
    assert cancelled.status_code == 200
    assert cancelled.json()["status"] == "CANCELLED"

    again = client.post("/api/v1/alerts/sos", headers=_auth(young), json={})
    assert again.status_code == 200
    assert again.json()["id"] != alert_id


def test_parent_resolves_sos_is_not_kidnapping() -> None:
    young = _register(UserRole.YOUNG, "Amina Clos")
    parent = _register(UserRole.PARENT, "Marie Clos")
    _pair(young, parent)
    created = client.post("/api/v1/alerts/sos", headers=_auth(young), json=POINT)
    alert_id = created.json()["id"]
    closed = client.post(f"/api/v1/alerts/{alert_id}/resolve", headers=_auth(parent))
    assert closed.status_code == 200, closed.text
    assert closed.json()["status"] == "RESOLVED"
    again = client.post(f"/api/v1/alerts/{alert_id}/resolve", headers=_auth(parent))
    assert again.status_code == 200
    inbox = client.get("/api/v1/notifications/me", headers=_auth(parent))
    notes = [note for note in inbox.json() if "clos" in note["title"].lower() or "clos" in note["body"].lower()]
    assert notes
    assert "kidnapping" in notes[0]["body"].lower()
    assert "push" in notes[0]["body"].lower()
    nxt = client.post("/api/v1/alerts/sos", headers=_auth(young), json={})
    assert nxt.status_code == 200
    assert nxt.json()["id"] != alert_id
    cancelled = client.post(f"/api/v1/alerts/{nxt.json()['id']}/cancel", headers=_auth(young))
    assert cancelled.status_code == 200
    blocked = client.post(f"/api/v1/alerts/{nxt.json()['id']}/resolve", headers=_auth(parent))
    assert blocked.status_code == 409


def test_young_voice_sos_is_not_kidnapping() -> None:
    young = _register(UserRole.YOUNG, "Amina Voice")
    parent = _register(UserRole.PARENT, "Marie Voice")
    _pair(young, parent)
    created = client.post(
        "/api/v1/alerts/sos",
        headers=_auth(young),
        json={**POINT, "source": "VOICE", "description": "Phrase « au secours » reconnue"},
    )
    assert created.status_code == 200, created.text
    assert created.json()["source"] == "VOICE"
    notes = [note for note in client.get("/api/v1/notifications/me", headers=_auth(parent)).json() if note["notification_type"] == "SOS"]
    assert notes
    assert "vocal" in notes[0]["body"].lower()
    assert "kidnapping" in notes[0]["body"].lower()


def test_young_cannot_spoof_iot_source() -> None:
    young = _register(UserRole.YOUNG, "Paul Voice")
    created = client.post("/api/v1/alerts/sos", headers=_auth(young), json={**POINT, "source": "IOT"})
    assert created.status_code == 200
    assert created.json()["source"] == "MOBILE"


def test_relative_cannot_spoof_voice_source() -> None:
    young = _register(UserRole.YOUNG, "Léo Voice")
    relative = _register(UserRole.RELATIVE, "Marc Voice")
    link = _pair(young, relative)
    allowed = client.patch(
        f"/api/v1/family/links/{link['id']}/permissions",
        headers=_auth(young),
        json={"can_trigger_alert": True},
    )
    assert allowed.status_code == 200, allowed.text
    sos = client.post(
        "/api/v1/alerts/sos",
        headers=_auth(relative),
        json={**POINT, "young_person_id": link["young_person_id"], "source": "VOICE"},
    )
    assert sos.status_code == 200, sos.text
    assert sos.json()["source"] == "RELATIVE"


def test_guardian_without_alerts_is_not_notified() -> None:
    young = _register(UserRole.YOUNG, "Léo Sos")
    parent = _register(UserRole.PARENT, "Marc Sos")
    link = _pair(young, parent)
    muted = client.patch(
        f"/api/v1/family/links/{link['id']}/permissions",
        headers=_auth(young),
        json={"can_receive_alerts": False},
    )
    assert muted.status_code == 200, muted.text
    client.post("/api/v1/alerts/sos", headers=_auth(young), json=POINT)
    inbox = client.get("/api/v1/notifications/me", headers=_auth(parent))
    assert [note for note in inbox.json() if note["notification_type"] == "SOS"] == []
    listed = client.get("/api/v1/alerts/mine", headers=_auth(parent))
    assert listed.status_code == 200
    assert len(listed.json()) == 1


def test_relative_cannot_sos_without_permission() -> None:
    young = _register(UserRole.YOUNG, "Amina Rel")
    relative = _register(UserRole.RELATIVE, "Marc Rel")
    link = _pair(young, relative)
    young_id = link["young_person_id"]
    denied = client.post(
        "/api/v1/alerts/sos",
        headers=_auth(relative),
        json={**POINT, "young_person_id": young_id},
    )
    assert denied.status_code == 403


def test_relative_sos_with_permission_is_not_kidnapping() -> None:
    young = _register(UserRole.YOUNG, "Paul Rel")
    relative = _register(UserRole.RELATIVE, "Lucie Rel")
    link = _pair(young, relative)
    allowed = client.patch(
        f"/api/v1/family/links/{link['id']}/permissions",
        headers=_auth(young),
        json={"can_trigger_alert": True},
    )
    assert allowed.status_code == 200, allowed.text
    sos = client.post(
        "/api/v1/alerts/sos",
        headers=_auth(relative),
        json={**POINT, "young_person_id": link["young_person_id"]},
    )
    assert sos.status_code == 200, sos.text
    assert sos.json()["source"] == "RELATIVE"
    notes = [note for note in client.get("/api/v1/notifications/me", headers=_auth(young)).json() if note["notification_type"] == "SOS"]
    assert notes
    assert "kidnapping" in notes[0]["body"].lower()
