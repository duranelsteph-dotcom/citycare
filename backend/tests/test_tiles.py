from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_map_tile_proxy_returns_png() -> None:
    response = client.get("/api/v1/map/tiles/13/4096/4096.png")
    assert response.status_code == 200
    assert response.headers["content-type"].startswith("image/")
    assert len(response.content) > 50


def test_map_tile_proxy_rejects_invalid_coords() -> None:
    response = client.get("/api/v1/map/tiles/99/0/0.png")
    assert response.status_code == 400
