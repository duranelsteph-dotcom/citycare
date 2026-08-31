from fastapi import APIRouter, HTTPException
from fastapi.responses import Response

from app.services.tile_proxy_service import TileProxyError, fetch_map_tile

router = APIRouter(tags=["map"])


@router.get("/map/tiles/{z}/{x}/{y}.png")
def map_tile(z: int, x: int, y: int) -> Response:
    """Tuile OSM relayée par le PC de dev (adb reverse / LAN sans Internet mobile)."""
    try:
        data, content_type = fetch_map_tile(z, x, y)
    except TileProxyError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc
    return Response(
        content=data,
        media_type=content_type,
        headers={"Cache-Control": "public, max-age=86400"},
    )
