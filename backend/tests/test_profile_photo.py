from io import BytesIO
from uuid import UUID, uuid4

from fastapi.testclient import TestClient

from app.core.enums import UserRole
from app.db.session import SessionLocal
from app.main import app
from app.models.people import YoungPerson
from app.models.user import User
from app.services.photo_service import ensure_upload_dir

client = TestClient(app)

# JPEG 1×1 minimal (signature FF D8 FF, pas un GIF).
_JPEG = (
    b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00"
    b"\xff\xdb\x00C\x00"
    + bytes([8] * 64)
    + b"\xff\xc0\x00\x0b\x08\x00\x01\x00\x01\x01\x01\x11\x00"
    b"\xff\xc4\x00\x14\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00"
    b"\x00\x00\x00\x00\x00\x00\x00\x00"
    b"\xff\xda\x00\x08\x01\x01\x00\x00?\x00\x7f\xff\xd9"
)


def _register(role: UserRole = UserRole.PARENT) -> dict:
    phone = f"+2376{uuid4().hex[:8]}"
    response = client.post(
        "/api/v1/auth/register",
        json={"full_name": "Photo Test", "phone": phone, "password": "VilleCare1!", "role": role.value},
    )
    assert response.status_code == 200, response.text
    return response.json()


def test_photo_requires_jwt() -> None:
    response = client.post(
        "/api/v1/auth/me/photo",
        files={"file": ("avatar.jpg", BytesIO(_JPEG), "image/jpeg")},
    )
    assert response.status_code == 401


def test_photo_rejects_invalid_type() -> None:
    session = _register()
    response = client.post(
        "/api/v1/auth/me/photo",
        headers={"Authorization": f"Bearer {session['access_token']}"},
        files={"file": ("notes.txt", BytesIO(b"ceci n'est pas une image"), "text/plain")},
    )
    assert response.status_code == 400
    assert "jpeg" in response.json()["detail"].lower() or "png" in response.json()["detail"].lower()


def test_photo_stores_and_updates_young() -> None:
    session = _register(UserRole.YOUNG)
    token = session["access_token"]
    uploaded = client.post(
        "/api/v1/auth/me/photo",
        headers={"Authorization": f"Bearer {token}"},
        files={"file": ("avatar.jpg", BytesIO(_JPEG), "image/jpeg")},
    )
    assert uploaded.status_code == 200, uploaded.text
    body = uploaded.json()
    assert body["photo_url"]
    assert body["photo_url"].startswith("/static/uploads/")
    assert body["photo_url"].endswith(".jpg")

    served = client.get(body["photo_url"])
    assert served.status_code == 200
    assert served.content.startswith(b"\xff\xd8\xff")

    me = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me.json()["photo_url"] == body["photo_url"]

    db = SessionLocal()
    try:
        user = db.get(User, UUID(session["user"]["id"]))
        assert user is not None
        assert user.photo_url == body["photo_url"]
        young = db.query(YoungPerson).filter(YoungPerson.user_id == user.id).one()
        assert young.photo_url == body["photo_url"]
        disk = ensure_upload_dir() / body["photo_url"].rsplit("/", 1)[-1]
        assert disk.is_file()
    finally:
        db.close()

    parent = _register(UserRole.PARENT)
    circle = client.post(
        "/api/v1/circles",
        headers={"Authorization": f"Bearer {parent['access_token']}"},
        json={"name": "Famille Photo"},
    )
    assert circle.status_code == 200, circle.text
    client.post(
        "/api/v1/circles/join",
        headers={"Authorization": f"Bearer {token}"},
        json={"code": circle.json()["invite_code"]},
    )
    members = client.get(
        f"/api/v1/circles/{circle.json()['id']}/members",
        headers={"Authorization": f"Bearer {parent['access_token']}"},
    )
    assert members.status_code == 200, members.text
    young_row = next(item for item in members.json() if item["user_id"] == session["user"]["id"])
    assert young_row["photo_url"] == body["photo_url"]
