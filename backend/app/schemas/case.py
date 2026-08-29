from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

from app.core.enums import CaseStatus


class CaseCreate(BaseModel):
    young_person_id: UUID
    occurred_at: datetime | None = None
    description: str | None = Field(default=None, max_length=1000)
    clothing: str | None = Field(default=None, max_length=500)
    circumstances: str | None = Field(default=None, max_length=1000)
    last_seen_by: str | None = Field(default=None, max_length=160)


class CaseStatusUpdate(BaseModel):
    status: CaseStatus
