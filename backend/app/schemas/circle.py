from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field, field_validator

from app.core.enums import CircleRole, UserRole
from app.schemas.entities import OrmModel


class CircleCreate(BaseModel):
    name: str = Field(min_length=2, max_length=80)

    @field_validator("name")
    @classmethod
    def strip_name(cls, value: str) -> str:
        cleaned = value.strip()
        if len(cleaned) < 2:
            raise ValueError("Le nom du cercle est trop court")
        return cleaned


class CircleUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=80)

    @field_validator("name")
    @classmethod
    def strip_name(cls, value: str | None) -> str | None:
        if value is None:
            return None
        cleaned = value.strip()
        if len(cleaned) < 2:
            raise ValueError("Le nom du cercle est trop court")
        return cleaned


class CircleJoinRequest(BaseModel):
    code: str = Field(min_length=6, max_length=6)

    @field_validator("code")
    @classmethod
    def normalize_code(cls, value: str) -> str:
        cleaned = "".join(value.split()).upper()
        if len(cleaned) != 6 or not cleaned.isalnum():
            raise ValueError("Le code d'invitation doit contenir 6 caractères")
        return cleaned


class CircleRead(OrmModel):
    id: UUID
    name: str
    invite_code: str
    created_by_user_id: UUID
    my_role: CircleRole
    member_count: int
    created_at: datetime
    updated_at: datetime


class CircleMemberRead(OrmModel):
    user_id: UUID
    full_name: str
    user_role: UserRole
    circle_role: CircleRole
    joined_at: datetime
    young_person_id: UUID | None = None
    photo_url: str | None = None
    # Permission dyadique déjà existante — le cercle ne l'accorde pas.
    can_view_location: bool = False
    guardian_link_id: UUID | None = None


class CircleInviteCodeRead(BaseModel):
    invite_code: str
