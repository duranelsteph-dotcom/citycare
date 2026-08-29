from datetime import datetime, timedelta, timezone
from uuid import UUID, uuid4

from fastapi.testclient import TestClient

from app.core.enums import UserRole
from app.db.session import SessionLocal
from app.main import app
from app.models.tracker import PositionShare

client = TestClient(app)
POINT = {"latitude": 3.8480, "longitude": 11.5021}


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


def test_share_lets_parent_watch_without_permanent_permission() -> None:
    young = _register(UserRole.YOUNG, "Amina Share")
    parent = _register(UserRole.PARENT, "Marie Share")
    _pair(young, parent)
    young_id = young["user"]["young_person_id"]
    client.post("/api/v1/locations", headers=_auth(young), json=POINT)
    denied = client.get(f"/api/v1/locations/children/{young_id}/watch", headers=_auth(parent))
    assert denied.status_code == 403
    created = client.post(
        "/api/v1/shares",
        headers=_auth(young),
        json={"target_user_id": parent["user"]["id"], "duration_minutes": 60},
    )
    assert created.status_code == 200, created.text
    assert created.json()["is_active"] is True
    assert "device_secret" not in created.json()
    watch = client.get(f"/api/v1/locations/children/{young_id}/watch", headers=_auth(parent))
    assert watch.status_code == 200, watch.text
    body = watch.json()
    assert body["access"] == "SHARE"
    assert body["latest"]["latitude"] == POINT["latitude"]
    assert body["poll_after_seconds"] >= 10
    assert "continu" in body["message"].lower() or "connue" in body["message"].lower()
    inbox = client.get("/api/v1/notifications/me", headers=_auth(parent))
    notes = [note for note in inbox.json() if note["notification_type"] == "POSITION_SHARE"]
    assert len(notes) == 1
    assert "direct" in notes[0]["body"].lower() or "kidnapping" in notes[0]["body"].lower()
    received = client.get("/api/v1/shares/received", headers=_auth(parent))
    assert received.status_code == 200, received.text
    assert received.json()[0]["is_active"] is True
    assert received.json()[0]["young_person_id"] == young_id


def test_revoke_and_expiry_block_watch() -> None:
    young = _register(UserRole.YOUNG, "Paul Share")
    parent = _register(UserRole.PARENT, "Lucie Share")
    _pair(young, parent)
    young_id = young["user"]["young_person_id"]
    client.post("/api/v1/locations", headers=_auth(young), json=POINT)
    created = client.post(
        "/api/v1/shares",
        headers=_auth(young),
        json={"target_user_id": parent["user"]["id"], "duration_minutes": 30},
    )
    share_id = created.json()["id"]
    revoked = client.post(f"/api/v1/shares/{share_id}/revoke", headers=_auth(young))
    assert revoked.status_code == 200
    assert revoked.json()["is_active"] is False
    denied = client.get(f"/api/v1/locations/children/{young_id}/latest", headers=_auth(parent))
    assert denied.status_code == 403

    again = client.post(
        "/api/v1/shares",
        headers=_auth(young),
        json={"target_user_id": parent["user"]["id"], "duration_minutes": 30},
    )
    assert again.status_code == 200
    with SessionLocal() as db:
        row = db.get(PositionShare, UUID(again.json()["id"]))
        assert row is not None
        row.expires_at = datetime.now(timezone.utc) - timedelta(minutes=1)
        db.commit()
    expired = client.get(f"/api/v1/locations/children/{young_id}/watch", headers=_auth(parent))
    assert expired.status_code == 403


def test_sos_shortens_watch_interval() -> None:
    young = _register(UserRole.YOUNG, "Sara Watch")
    calm = client.get("/api/v1/locations/me/watch", headers=_auth(young))
    assert calm.status_code == 200
    assert calm.json()["effective_mode"] == "NORMAL"
    assert calm.json()["poll_after_seconds"] == 60
    assert calm.json()["latest"] is None
    sos = client.post("/api/v1/alerts/sos", headers=_auth(young), json={})
    assert sos.status_code == 200
    urgent = client.get("/api/v1/locations/me/watch", headers=_auth(young))
    assert urgent.json()["effective_mode"] == "EMERGENCY"
    assert urgent.json()["poll_after_seconds"] == 10


def test_kit_config_follows_power_save_and_sos() -> None:
    young = _register(UserRole.YOUNG, "Léo Config")
    kit = client.post("/api/v1/trackers", headers=_auth(young), json={}).json()
    creds = {"device_uid": kit["device_uid"], "device_secret": kit["device_secret"]}
    cfg = client.post("/api/v1/iot/config", json=creds)
    assert cfg.status_code == 200, cfg.text
    assert cfg.json()["effective_mode"] == "NORMAL"
    assert cfg.json()["suggested_interval_seconds"] == 60
    client.patch(f"/api/v1/trackers/{kit['id']}", headers=_auth(young), json={"tracking_mode": "POWER_SAVE"})
    save = client.post("/api/v1/iot/config", json=creds)
    assert save.json()["effective_mode"] == "POWER_SAVE"
    assert save.json()["suggested_interval_seconds"] == 180
    client.post("/api/v1/alerts/sos", headers=_auth(young), json={})
    sos = client.post("/api/v1/iot/config", json=creds)
    assert sos.json()["effective_mode"] == "EMERGENCY"
    assert sos.json()["open_sos"] is True
    assert sos.json()["suggested_interval_seconds"] == 10
