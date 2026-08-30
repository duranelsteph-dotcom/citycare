from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

from app.core.enums import TrackingMode
from app.schemas.entities import TrackerLocationRead


class LocationCreate(BaseModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    accuracy: float | None = Field(default=None, ge=0)
    altitude: float | None = None
    speed: float | None = Field(default=None, ge=0)
    heading: float | None = Field(default=None, ge=0, le=360)
    recorded_at: datetime | None = None
    # Batterie téléphone (POST /locations) ou kit (IoT). Omis si inconnue — jamais 100 inventé.
    battery_level: int | None = Field(default=None, ge=0, le=100)


class ShareCreate(BaseModel):
    target_user_id: UUID
    duration_minutes: int = Field(default=60, ge=5, le=1440)


class LocationWatch(BaseModel):
    latest: TrackerLocationRead | None = None
    poll_after_seconds: int
    effective_mode: TrackingMode
    access: str
    stale_after_seconds: int = 300
    message: str = (
        "Rafraîchissement de la dernière position connue. "
        "Ce n'est pas un suivi GPS continu ni la position actuelle si le point est ancien."
    )
