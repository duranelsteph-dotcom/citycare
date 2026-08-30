from uuid import uuid4

from fastapi.testclient import TestClient

from app.core.enums import UserRole
from app.main import app

client = TestClient(app)

POINT = {"latitude": 3.8480, "longitude": 11.5021, "accuracy": 14}


def _register(role: UserRole = UserRole.YOUNG) -> dict:
    phone = f"+2376{uuid4().hex[:8]}"
    response = client.post(
        "/api/v1/auth/register",
        json={"full_name": "Amina Batt", "phone": phone, "password": "VilleCare1!", "role": role.value},
    )
    assert response.status_code == 200, response.text
    return response.json()


def _auth(session: dict) -> dict:
    return {"Authorization": f"Bearer {session['access_token']}"}


def test_phone_location_stores_battery_level() -> None:
    young = _register()
    posted = client.post(
        "/api/v1/locations",
        headers=_auth(young),
        json={**POINT, "battery_level": 72},
    )
    assert posted.status_code == 200, posted.text
    body = posted.json()
    assert body["source"] == "PHONE"
    assert body["battery_level"] == 72

    latest = client.get("/api/v1/locations/me/latest", headers=_auth(young))
    assert latest.status_code == 200
    assert latest.json()["battery_level"] == 72


def test_phone_location_omits_battery_when_absent() -> None:
    young = _register()
    posted = client.post(
        "/api/v1/locations",
        headers=_auth(young),
        json=POINT,
    )
    assert posted.status_code == 200, posted.text
    assert posted.json()["battery_level"] is None


def test_phone_location_rejects_invalid_battery() -> None:
    young = _register()
    posted = client.post(
        "/api/v1/locations",
        headers=_auth(young),
        json={**POINT, "battery_level": 101},
    )
    assert posted.status_code == 422
