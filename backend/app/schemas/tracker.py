from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

from app.core.enums import TrackerEventType, TrackerStatus, TrackingMode, TrackerStatus
from app.schemas.alert import SosCreate
from app.schemas.entities import GPSTrackerRead, TrackerEventRead
from app.schemas.location import LocationCreate


class TrackerCreate(BaseModel):
    young_person_id: UUID | None = None
    label: str = Field(default="Kit CityCare", min_length=2, max_length=80)


class TrackerCreated(GPSTrackerRead):
    device_secret: str


class TrackerUpdate(BaseModel):
    label: str | None = Field(default=None, min_length=2, max_length=80)
    tracking_mode: TrackingMode | None = None
    enabled: bool | None = None


class IotSosRequest(SosCreate):
    device_uid: str = Field(min_length=6, max_length=64)
    device_secret: str = Field(min_length=8, max_length=128)


class IotLocationRequest(LocationCreate):
    device_uid: str = Field(min_length=6, max_length=64)
    device_secret: str = Field(min_length=8, max_length=128)
    signal_strength: int | None = Field(default=None, ge=0, le=100)


class IotEventRequest(BaseModel):
    device_uid: str = Field(min_length=6, max_length=64)
    device_secret: str = Field(min_length=8, max_length=128)
    event_type: TrackerEventType
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    battery_level: int | None = Field(default=None, ge=0, le=100)
    recorded_at: datetime | None = None


class IotEventResult(BaseModel):
    tracker: GPSTrackerRead
    event: TrackerEventRead


class IotConfigRequest(BaseModel):
    device_uid: str = Field(min_length=6, max_length=64)
    device_secret: str = Field(min_length=8, max_length=128)


class IotConfigRead(BaseModel):
    tracking_mode: TrackingMode
    effective_mode: TrackingMode
    suggested_interval_seconds: int
    status: TrackerStatus
    open_sos: bool
    message: str
