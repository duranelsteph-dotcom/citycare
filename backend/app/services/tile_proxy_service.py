"""Proxy tuiles OSM via le PC de dev.

Le téléphone peut joindre l'API (adb reverse ou LAN) sans Internet public ;
les tuiles directes vers tile.openstreetmap.org échouent alors. Le PC, lui, a
Internet et sert les PNG au client Flutter.
"""

from __future__ import annotations

import urllib.error
import urllib.request
from functools import lru_cache

OSM_TILE_URL = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
OSM_FR_TILE_URL = "https://a.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png"
CARTO_TILE_URL = "https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png"
USER_AGENT = "CityCare/0.43.0 (com.citycare.citycare; tile-proxy)"

_SOURCES = (OSM_TILE_URL, OSM_FR_TILE_URL, CARTO_TILE_URL)


class TileProxyError(Exception):
    def __init__(self, message: str, status_code: int = 502):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


def _fetch_url(url: str) -> tuple[bytes, str]:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            data = response.read()
            content_type = response.headers.get("Content-Type", "image/png")
            return data, content_type
    except urllib.error.HTTPError as exc:
        raise TileProxyError(f"Tuile amont HTTP {exc.code}", status_code=502) from exc
    except urllib.error.URLError as exc:
        raise TileProxyError(f"Tuile amont injoignable: {exc.reason}", status_code=502) from exc


@lru_cache(maxsize=512)
def fetch_map_tile(z: int, x: int, y: int) -> tuple[bytes, str]:
    max_index = 2**z
    if z < 0 or z > 19 or x < 0 or y < 0 or x >= max_index or y >= max_index:
        raise TileProxyError("Coordonnées de tuile invalides", status_code=400)

    last_error: TileProxyError | None = None
    for template in _SOURCES:
        url = template.format(z=z, x=x, y=y)
        try:
            return _fetch_url(url)
        except TileProxyError as exc:
            last_error = exc
    raise last_error or TileProxyError("Aucune source de tuile disponible", status_code=502)
