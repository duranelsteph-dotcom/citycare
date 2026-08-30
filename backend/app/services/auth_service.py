import hashlib
import hmac
import logging
import secrets
from datetime import datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, joinedload

from app.core.config import settings
from app.core.enums import UserRole
from app.core.rate_limit import auth_limiter
from app.core.security import create_access_token, hash_password, verify_password
from app.models.alert import AppNotification
from app.models.circle import CircleMembership
from app.models.device import DevicePushToken
from app.models.otp import OtpChallenge
from app.models.password_reset import PasswordResetChallenge
from app.models.people import EmergencyContact, GuardianLink, YoungPerson
from app.models.tracker import PositionShare
from app.models.user import User
from app.schemas.auth import (
    AuthUserRead,
    DeleteAccountResponse,
    ForgotPasswordRequest,
    ForgotPasswordResponse,
    LoginChallengeResponse,
    LoginRequest,
    RegisterRequest,
    ResendOtpRequest,
    ResetPasswordRequest,
    ResetPasswordResponse,
    TokenResponse,
    VerifyOtpRequest,
)

logger = logging.getLogger(__name__)


class AuthError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


def _aware(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value


def _hash_otp(challenge_id: UUID, code: str) -> str:
    return hmac.new(
        settings.secret_key.encode("utf-8"),
        f"{challenge_id}:{code}".encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()


def _new_otp_code() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def _dev_otp_enabled() -> bool:
    return not settings.is_production


def auth_user_from_model(user: User) -> AuthUserRead:
    young_id = user.young_profile.id if user.young_profile is not None else None
    return AuthUserRead.model_validate(user).model_copy(update={"young_person_id": young_id})


def register_user(db: Session, payload: RegisterRequest) -> TokenResponse:
    user = User(
        full_name=payload.full_name,
        phone=payload.phone,
        email=payload.email,
        password_hash=hash_password(payload.password),
        role=payload.role,
        is_active=True,
    )
    db.add(user)
    db.flush()
    if payload.role == UserRole.YOUNG:
        db.add(YoungPerson(user_id=user.id, display_name=payload.full_name))
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise AuthError("Ce numéro de téléphone ou cet e-mail est déjà utilisé", 409)
    db.refresh(user)
    if payload.role == UserRole.YOUNG:
        db.refresh(user, attribute_names=["young_profile"])
    token = create_access_token(
        user_id=user.id, role=user.role.value, token_version=user.token_version
    )
    return TokenResponse(access_token=token, user=auth_user_from_model(user))


def login_user(db: Session, payload: LoginRequest) -> LoginChallengeResponse:
    key = f"login:{payload.phone}"
    if auth_limiter.blocked(key):
        raise AuthError("Trop de tentatives. Réessayez plus tard.", 429)
    user = db.query(User).filter(User.phone == payload.phone).one_or_none()
    if user is None or not user.is_active or not verify_password(payload.password, user.password_hash):
        auth_limiter.hit(key)
        raise AuthError("Identifiants incorrects", 401)
    auth_limiter.clear(key)
    return _issue_otp_challenge(db, user)


def verify_otp(db: Session, payload: VerifyOtpRequest) -> TokenResponse:
    challenge = db.query(OtpChallenge).filter(OtpChallenge.id == payload.challenge_id).one_or_none()
    now = datetime.now(timezone.utc)
    if challenge is None or challenge.consumed_at is not None:
        raise AuthError("Code invalide ou expiré", 401)
    if _aware(challenge.expires_at) < now:
        raise AuthError("Code invalide ou expiré", 401)
    if challenge.attempts >= settings.otp_max_attempts:
        raise AuthError("Trop de tentatives. Redemandez un code.", 429)
    code = "".join(ch for ch in payload.code if ch.isdigit())
    if len(code) != 6:
        raise AuthError("Le code OTP doit contenir 6 chiffres", 400)
    expected = _hash_otp(challenge.id, code)
    if not hmac.compare_digest(expected, challenge.code_hash):
        challenge.attempts += 1
        db.commit()
        raise AuthError("Code incorrect", 401)
    challenge.consumed_at = now
    db.commit()
    user = (
        db.query(User)
        .options(joinedload(User.young_profile))
        .filter(User.id == challenge.user_id)
        .one()
    )
    if not user.is_active:
        raise AuthError("Compte introuvable ou inactif", 401)
    token = create_access_token(
        user_id=user.id, role=user.role.value, token_version=user.token_version
    )
    return TokenResponse(access_token=token, user=auth_user_from_model(user))


def resend_otp(db: Session, payload: ResendOtpRequest) -> LoginChallengeResponse:
    challenge = db.query(OtpChallenge).filter(OtpChallenge.id == payload.challenge_id).one_or_none()
    now = datetime.now(timezone.utc)
    if challenge is None or challenge.consumed_at is not None:
        raise AuthError("Session de vérification introuvable", 404)
    if _aware(challenge.expires_at) < now:
        raise AuthError("Le code a expiré. Reconnectez-vous.", 401)
    elapsed = (now - _aware(challenge.last_sent_at)).total_seconds()
    if elapsed < settings.otp_resend_seconds:
        raise AuthError("Patientez avant de renvoyer le code.", 429)
    return _refresh_otp_challenge(db, challenge)


def _issue_otp_challenge(db: Session, user: User) -> LoginChallengeResponse:
    now = datetime.now(timezone.utc)
    challenge = OtpChallenge(
        user_id=user.id,
        code_hash="pending",
        expires_at=now + timedelta(seconds=settings.otp_ttl_seconds),
        last_sent_at=now,
        attempts=0,
    )
    db.add(challenge)
    db.flush()
    return _refresh_otp_challenge(db, challenge, reset_expiry=False)


def _refresh_otp_challenge(
    db: Session, challenge: OtpChallenge, *, reset_expiry: bool = False
) -> LoginChallengeResponse:
    code = _new_otp_code()
    now = datetime.now(timezone.utc)
    challenge.code_hash = _hash_otp(challenge.id, code)
    challenge.last_sent_at = now
    challenge.attempts = 0
    if reset_expiry:
        challenge.expires_at = now + timedelta(seconds=settings.otp_ttl_seconds)
    db.commit()
    remaining = max(0, int((_aware(challenge.expires_at) - now).total_seconds()))
    otp_dev = code if _dev_otp_enabled() else None
    if otp_dev is not None:
        logger.warning(
            "OTP démo (aucun SMS n'est envoyé) challenge_id=%s code=%s",
            challenge.id,
            otp_dev,
        )
    return LoginChallengeResponse(
        challenge_id=challenge.id,
        expires_in=remaining,
        otp_dev=otp_dev,
    )


def request_password_reset(db: Session, payload: ForgotPasswordRequest) -> ForgotPasswordResponse:
    """Crée un challenge reset si le compte existe. Réponse identique sinon."""
    key = f"forgot:{payload.phone}"
    if auth_limiter.blocked(key):
        raise AuthError("Trop de tentatives. Réessayez plus tard.", 429)
    auth_limiter.hit(key)

    user = db.query(User).filter(User.phone == payload.phone).one_or_none()
    code = _new_otp_code()
    now = datetime.now(timezone.utc)
    expires_in = settings.reset_ttl_seconds

    if user is not None and user.is_active:
        for old in (
            db.query(PasswordResetChallenge)
            .filter(
                PasswordResetChallenge.user_id == user.id,
                PasswordResetChallenge.consumed_at.is_(None),
            )
            .all()
        ):
            old.consumed_at = now
        challenge = PasswordResetChallenge(
            user_id=user.id,
            code_hash="pending",
            expires_at=now + timedelta(seconds=settings.reset_ttl_seconds),
            last_sent_at=now,
            attempts=0,
        )
        db.add(challenge)
        db.flush()
        challenge.code_hash = _hash_otp(challenge.id, code)
        db.commit()
        remaining = max(0, int((_aware(challenge.expires_at) - now).total_seconds()))
        expires_in = remaining

    reset_code_dev = code if _dev_otp_enabled() else None
    if reset_code_dev is not None:
        logger.warning(
            "Reset démo (aucun SMS n'est envoyé) phone=%s code=%s persisted=%s",
            payload.phone,
            reset_code_dev,
            user is not None and user.is_active,
        )
    return ForgotPasswordResponse(expires_in=expires_in, reset_code_dev=reset_code_dev)


def reset_password(db: Session, payload: ResetPasswordRequest) -> ResetPasswordResponse:
    """Change le hash si le code est valide. Invalide JWT et OTP en cours."""
    key = f"reset:{payload.phone}"
    if auth_limiter.blocked(key):
        raise AuthError("Trop de tentatives. Réessayez plus tard.", 429)

    user = db.query(User).filter(User.phone == payload.phone).one_or_none()
    now = datetime.now(timezone.utc)
    challenge: PasswordResetChallenge | None = None
    if user is not None and user.is_active:
        challenge = (
            db.query(PasswordResetChallenge)
            .filter(
                PasswordResetChallenge.user_id == user.id,
                PasswordResetChallenge.consumed_at.is_(None),
            )
            .order_by(PasswordResetChallenge.created_at.desc())
            .first()
        )

    if challenge is None or _aware(challenge.expires_at) < now:
        auth_limiter.hit(key)
        raise AuthError("Code invalide ou expiré", 400)
    if challenge.attempts >= settings.reset_max_attempts:
        auth_limiter.hit(key)
        raise AuthError("Trop de tentatives. Redemandez un code.", 429)

    expected = _hash_otp(challenge.id, payload.code)
    if not hmac.compare_digest(expected, challenge.code_hash):
        challenge.attempts += 1
        db.commit()
        auth_limiter.hit(key)
        raise AuthError("Code invalide ou expiré", 400)

    user.password_hash = hash_password(payload.new_password)
    user.password_changed_at = now
    user.token_version = (user.token_version or 0) + 1
    challenge.consumed_at = now
    for otp in (
        db.query(OtpChallenge)
        .filter(OtpChallenge.user_id == user.id, OtpChallenge.consumed_at.is_(None))
        .all()
    ):
        otp.consumed_at = now
    auth_limiter.clear(key)
    db.commit()
    return ResetPasswordResponse()


def delete_account(db: Session, user: User, password: str) -> DeleteAccountResponse:
    """Suppression RGPD : anonymisation + is_active=false (pas de hard-delete).

    Hard-delete refusé : MissingPersonCase.reported_by_user_id est RESTRICT NOT
    NULL ; YoungPerson CASCADE effacerait dossiers, alertes et positions ;
    Circle.created_by CASCADE supprimerait des cercles encore habités.
    OTP / reset n'ont pas ondelete=CASCADE.

    On libère le téléphone, on efface photo, jetons FCM, OTP, memberships et
    notifications. Le JWT est invalidé via token_version + is_active=false.
    """
    if not verify_password(password, user.password_hash):
        raise AuthError("Mot de passe incorrect", 403)

    from app.services.photo_service import delete_profile_photo_file

    photo_urls = [user.photo_url]
    young = user.young_profile
    if young is not None:
        photo_urls.append(young.photo_url)
    for url in photo_urls:
        delete_profile_photo_file(url)

    uid = user.id
    db.query(DevicePushToken).filter(DevicePushToken.user_id == uid).delete(synchronize_session=False)
    db.query(OtpChallenge).filter(OtpChallenge.user_id == uid).delete(synchronize_session=False)
    db.query(PasswordResetChallenge).filter(PasswordResetChallenge.user_id == uid).delete(
        synchronize_session=False
    )
    db.query(CircleMembership).filter(CircleMembership.user_id == uid).delete(synchronize_session=False)
    db.query(AppNotification).filter(AppNotification.recipient_user_id == uid).delete(
        synchronize_session=False
    )
    db.query(GuardianLink).filter(GuardianLink.guardian_user_id == uid).delete(synchronize_session=False)
    db.query(PositionShare).filter(PositionShare.target_user_id == uid).delete(synchronize_session=False)
    db.query(EmergencyContact).filter(EmergencyContact.user_id == uid).update(
        {EmergencyContact.user_id: None},
        synchronize_session=False,
    )

    if young is not None:
        db.query(GuardianLink).filter(GuardianLink.young_person_id == young.id).delete(
            synchronize_session=False
        )
        db.query(PositionShare).filter(PositionShare.young_person_id == young.id).delete(
            synchronize_session=False
        )
        young.display_name = "Compte supprimé"
        young.photo_url = None
        young.notes = None
        young.birth_date = None
        young.pairing_code = None
        young.pairing_code_expires_at = None

    digest = hashlib.sha256(f"{uid}:{user.phone}".encode("utf-8")).hexdigest()[:30]
    user.phone = f"d:{digest}"
    user.email = None
    user.full_name = "Compte supprimé"
    user.photo_url = None
    user.password_hash = hash_password(secrets.token_urlsafe(32))
    user.token_version = (user.token_version or 0) + 1
    user.is_active = False
    db.commit()
    return DeleteAccountResponse()
