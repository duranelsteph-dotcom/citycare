from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

from app.core.enums import CaseStatus


class CaseCreate(BaseModel):
    young_person_id: UUID | None = None
    occurred_at: datetime | None = None
    description: str | None = Field(default=None, max_length=1000)
    clothing: str | None = Field(default=None, max_length=500)
    circumstances: str | None = Field(default=None, max_length=1000)
    last_seen_by: str | None = Field(default=None, max_length=160)
    subject_name: str | None = Field(default=None, max_length=120)
    subject_age_approx: str | None = Field(default=None, max_length=40)
    subject_sex: str | None = Field(default=None, max_length=32)
    distinctive_signs: str | None = Field(default=None, max_length=1000)
    last_known_latitude: float | None = Field(default=None, ge=-90, le=90)
    last_known_longitude: float | None = Field(default=None, ge=-180, le=180)
    last_known_address: str | None = Field(default=None, max_length=255)
    photo_url: str | None = Field(default=None, max_length=512)


class CaseStatusUpdate(BaseModel):
    status: CaseStatus
