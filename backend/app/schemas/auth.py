from uuid import UUID

from pydantic import BaseModel, Field, field_validator

from app.core.enums import UserRole
from app.core.password_rules import require_strong_password
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

    @field_validator("password")
    @classmethod
    def password_strong(cls, value: str) -> str:
        return require_strong_password(value)


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


class LoginChallengeResponse(BaseModel):
    """Réponse du login : pas de JWT tant que le code OTP n'est pas validé."""

    challenge_id: UUID
    expires_in: int
    message: str = (
        "Un code à 6 chiffres a été généré. "
        "Aucun SMS n'est envoyé : en développement, le code est dans otp_dev."
    )
    otp_dev: str | None = None


class VerifyOtpRequest(BaseModel):
    challenge_id: UUID
    code: str = Field(min_length=6, max_length=16)

    @field_validator("code")
    @classmethod
    def code_six_digits(cls, value: str) -> str:
        digits = "".join(ch for ch in value if ch.isdigit())
        if len(digits) != 6:
            raise ValueError("Le code OTP doit contenir 6 chiffres")
        return digits


class ResendOtpRequest(BaseModel):
    challenge_id: UUID


class ForgotPasswordRequest(BaseModel):
    phone: str

    @field_validator("phone")
    @classmethod
    def phone_ok(cls, value: str) -> str:
        return _normalize_phone(value)


class ForgotPasswordResponse(BaseModel):
    """Même forme que le numéro existe ou non (anti-énumération). Aucun SMS."""

    expires_in: int
    message: str = (
        "Si ce numéro est associé à un compte, un code a été généré. "
        "Aucun SMS n'est envoyé : en développement, le code est dans reset_code_dev."
    )
    reset_code_dev: str | None = None


class ResetPasswordRequest(BaseModel):
    phone: str
    code: str = Field(min_length=6, max_length=16)
    new_password: str = Field(min_length=8, max_length=72)

    @field_validator("phone")
    @classmethod
    def phone_ok(cls, value: str) -> str:
        return _normalize_phone(value)

    @field_validator("code")
    @classmethod
    def code_six_digits(cls, value: str) -> str:
        digits = "".join(ch for ch in value if ch.isdigit())
        if len(digits) != 6:
            raise ValueError("Le code OTP doit contenir 6 chiffres")
        return digits

    @field_validator("new_password")
    @classmethod
    def password_strong(cls, value: str) -> str:
        return require_strong_password(value)


class ResetPasswordResponse(BaseModel):
    message: str = "Mot de passe mis à jour. Reconnectez-vous avec le nouveau mot de passe."


class DeleteAccountRequest(BaseModel):
    """Confirmation par mot de passe avant suppression RGPD."""

    password: str = Field(min_length=1, max_length=72)


class DeleteAccountResponse(BaseModel):
    message: str = (
        "Votre compte a été supprimé. Les données personnelles ont été effacées."
    )
