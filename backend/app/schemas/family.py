from datetime import date, datetime

from pydantic import BaseModel, Field, field_validator

from app.core.enums import GuardianRelation


class UserProfileUpdate(BaseModel):
    full_name: str | None = Field(default=None, min_length=2, max_length=120)

    @field_validator("full_name")
    @classmethod
    def strip_name(cls, value: str | None) -> str | None:
        return value.strip() if value else value


class YoungProfileUpdate(BaseModel):
    display_name: str | None = Field(default=None, min_length=2, max_length=120)
    birth_date: date | None = None
    notes: str | None = None

    @field_validator("display_name")
    @classmethod
    def strip_name(cls, value: str | None) -> str | None:
        return value.strip() if value else value


class LinkByCodeRequest(BaseModel):
    code: str = Field(min_length=6, max_length=8)

    @field_validator("code")
    @classmethod
    def normalize_code(cls, value: str) -> str:
        return value.strip()


class InviteByPhoneRequest(BaseModel):
    phone: str
    relation: GuardianRelation = GuardianRelation.PARENT

    @field_validator("phone")
    @classmethod
    def normalize_phone(cls, value: str) -> str:
        compact = "".join(value.split())
        if len(compact) < 8:
            raise ValueError("Le numéro de téléphone est trop court")
        return compact


class PermissionsUpdate(BaseModel):
    can_view_location: bool | None = None
    can_receive_alerts: bool | None = None
    can_trigger_alert: bool | None = None
    can_report_missing: bool | None = None
    can_manage_zones: bool | None = None
    can_manage_tracker: bool | None = None


class EmergencyContactCreate(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    phone: str

    @field_validator("phone")
    @classmethod
    def normalize_phone(cls, value: str) -> str:
        compact = "".join(value.split())
        if len(compact) < 8:
            raise ValueError("Le numéro de téléphone est trop court")
        return compact


class PairingCodeRead(BaseModel):
    code: str
    expires_at: datetime
