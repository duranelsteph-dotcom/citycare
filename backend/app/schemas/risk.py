from datetime import datetime

from pydantic import BaseModel, Field


class RiskZoneCreate(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    radius_meters: float = Field(gt=20, le=5000)
    is_active: bool = True
    typical_start_hour: int | None = Field(default=None, ge=0, le=23)
    typical_end_hour: int | None = Field(default=None, ge=0, le=23)


class RiskZoneUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=80)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    radius_meters: float | None = Field(default=None, gt=20, le=5000)
    is_active: bool | None = None
    typical_start_hour: int | None = Field(default=None, ge=0, le=23)
    typical_end_hour: int | None = Field(default=None, ge=0, le=23)


class IncidentCreate(BaseModel):
    title: str = Field(min_length=2, max_length=160)
    description: str | None = None
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    occurred_at: datetime | None = None
    source: str | None = Field(default=None, max_length=80)
    count: int = Field(default=1, ge=1, le=100)
