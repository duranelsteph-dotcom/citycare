from datetime import datetime

from pydantic import BaseModel, Field


class TestimonyCreate(BaseModel):
    description: str = Field(min_length=8, max_length=2000)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    observed_at: datetime | None = None
    photo_url: str | None = Field(default=None, max_length=512)
