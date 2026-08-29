from datetime import time
from uuid import UUID

from pydantic import BaseModel, Field


class ScheduleInput(BaseModel):
    weekday: int = Field(ge=0, le=6, description="0 = lundi … 6 = dimanche")
    start_time: time
    end_time: time


class SafetyZoneCreate(BaseModel):
    young_person_id: UUID | None = None
    name: str = Field(min_length=1, max_length=80)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    radius_meters: float = Field(gt=20, le=5000)
    is_active: bool = True
    accuracy_tolerance_meters: float | None = Field(default=None, ge=0, le=500)
    min_exit_duration_seconds: int | None = Field(default=None, ge=0, le=3600)
    schedules: list[ScheduleInput] = Field(min_length=1)


class SafetyZoneUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=80)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    radius_meters: float | None = Field(default=None, gt=20, le=5000)
    is_active: bool | None = None
    schedules: list[ScheduleInput] | None = Field(default=None, min_length=1)
