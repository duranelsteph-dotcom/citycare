"""Seed démo idempotent."""

from fastapi.testclient import TestClient

from app.core.security import verify_password
from app.db import seed_demo
from app.db.seed_demo import ensure_demo_accounts
from app.db.session import SessionLocal
from app.main import app
from app.models.user import User


client = TestClient(app)


def test_ensure_demo_accounts_idempotent(monkeypatch) -> None:
    accounts = (
        {"full_name": "Seed Test Parent", "phone": "+237688111001", "role": "PARENT"},
        {"full_name": "Seed Test Young", "phone": "+237688111002", "role": "YOUNG"},
    )
    monkeypatch.setattr(seed_demo, "_DEMO_ACCOUNTS", accounts)
    ensure_demo_accounts()
    assert ensure_demo_accounts() == 0
    db = SessionLocal()
    try:
        parent = db.query(User).filter(User.phone == "+237688111001").one()
        assert parent.full_name == "Seed Test Parent"
        assert verify_password("motdepasse", parent.password_hash)
    finally:
        db.close()


def test_seed_demo_http_route() -> None:
    response = client.post("/api/v1/auth/seed-demo")
    assert response.status_code == 200, response.text
    body = response.json()
    assert isinstance(body["created"], int)
    assert body["created"] >= 0
