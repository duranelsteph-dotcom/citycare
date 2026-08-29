from uuid import UUID

from pydantic import BaseModel, Field, field_validator

from app.core.enums import UserRole
from app.schemas.entities import UserRead


def _normalize_phone(value: str) -> str:
    compact = "".join(value.split())
    if len(compact) < 8:
        raise ValueError("Le numéro de téléphone est trop court")
    return compact


class RegisterRequest(BaseModel):
    full_name: str = Field(min_length=2, max_length=120)
    phone: str = Field(min_length=8, max_length=32)
    password: str = Field(min_length=8, max_length=72)
    role: UserRole
    email: str | None = None

    @field_validator("phone")
    @classmethod
    def phone_ok(cls, value: str) -> str:
        return _normalize_phone(value)

    @field_validator("email")
    @classmethod
    def empty_email_to_none(cls, value: str | None) -> str | None:
        if value is None:
            return None
        stripped = value.strip()
        return stripped or None

    @field_validator("full_name")
    @classmethod
    def name_ok(cls, value: str) -> str:
        return value.strip()


class LoginRequest(BaseModel):
    phone: str
    password: str

    @field_validator("phone")
    @classmethod
    def phone_ok(cls, value: str) -> str:
        return _normalize_phone(value)


class AuthUserRead(UserRead):
    young_person_id: UUID | None = None


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: AuthUserRead
