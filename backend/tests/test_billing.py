from uuid import uuid4

from fastapi.testclient import TestClient

from app.core.enums import UserRole
from app.main import app

client = TestClient(app)


def _phone() -> str:
    return f"+2376{uuid4().hex[:8]}"


def _register() -> dict:
    number = _phone()
    response = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Billing Test",
            "phone": number,
            "password": "VilleCare1!",
            "role": UserRole.PARENT.value,
        },
    )
    assert response.status_code == 200, response.text
    return response.json()


def _auth(session: dict) -> dict:
    return {"Authorization": f"Bearer {session['access_token']}"}


def test_billing_requires_jwt() -> None:
    response = client.get("/api/v1/billing/me")
    assert response.status_code == 401


def test_billing_starts_empty_then_records_annual_without_charge() -> None:
    session = _register()
    me = client.get("/api/v1/billing/me", headers=_auth(session))
    assert me.status_code == 200, me.text
    body = me.json()
    assert body["status"] == "none"
    assert body["amount"] == 12000
    assert body["currency"] == "XAF"
    assert "paiement" in (body.get("message") or "").lower() or body["status"] == "none"

    recorded = client.post("/api/v1/billing/subscribe", headers=_auth(session), json={"plan": "annual_xaf"})
    assert recorded.status_code == 200, recorded.text
    data = recorded.json()
    assert data["status"] == "active"
    assert data["amount"] == 12000
    assert data["currency"] == "XAF"
    assert "débité" in (data.get("message") or "").lower()
    assert "actif" in (data.get("message") or "").lower()

    again = client.get("/api/v1/billing/me", headers=_auth(session))
    assert again.json()["status"] == "active"


def test_marketplace_order_is_persisted() -> None:
    session = _register()
    empty = client.get("/api/v1/billing/orders", headers=_auth(session))
    assert empty.status_code == 200
    assert empty.json() == []

    created = client.post(
        "/api/v1/billing/orders",
        headers=_auth(session),
        json={"product_id": "kit-gps", "product_name": "Kit GPS CityCare", "amount": 45000},
    )
    assert created.status_code == 200, created.text
    assert created.json()["status"] == "recorded"
    assert created.json()["product_id"] == "kit-gps"
    assert "débité" in (created.json().get("message") or "").lower()

    listed = client.get("/api/v1/billing/orders", headers=_auth(session))
    assert len(listed.json()) == 1
    assert listed.json()[0]["id"] == created.json()["id"]
