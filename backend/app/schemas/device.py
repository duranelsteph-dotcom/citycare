from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

from app.schemas.entities import OrmModel


class DeviceTokenUpsert(BaseModel):
    token: str = Field(min_length=8, max_length=512)
    platform: str = Field(min_length=2, max_length=16)


class DeviceTokenRead(OrmModel):
    id: UUID
    user_id: UUID
    platform: str
    is_active: bool
    created_at: datetime
    updated_at: datetime
