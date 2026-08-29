from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field, model_validator

from app.core.enums import AlertSource


class SosCreate(BaseModel):
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    accuracy: float | None = Field(default=None, ge=0)
    recorded_at: datetime | None = None
    description: str | None = Field(default=None, max_length=500)
    battery_level: int | None = Field(default=None, ge=0, le=100)
    young_person_id: UUID | None = None
    source: AlertSource | None = None

    @model_validator(mode="after")
    def coords_together(self) -> "SosCreate":
        if (self.latitude is None) != (self.longitude is None):
            raise ValueError("latitude et longitude vont ensemble")
        return self
