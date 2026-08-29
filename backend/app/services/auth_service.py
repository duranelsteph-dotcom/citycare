from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.enums import UserRole
from app.core.rate_limit import auth_limiter
from app.core.security import create_access_token, hash_password, verify_password
from app.models.people import YoungPerson
from app.models.user import User
from app.schemas.auth import AuthUserRead, LoginRequest, RegisterRequest, TokenResponse


class AuthError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


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
    token = create_access_token(user_id=user.id, role=user.role.value)
    return TokenResponse(access_token=token, user=auth_user_from_model(user))


def login_user(db: Session, payload: LoginRequest) -> TokenResponse:
    key = f"login:{payload.phone}"
    if auth_limiter.blocked(key):
        raise AuthError("Trop de tentatives. Réessayez plus tard.", 429)
    user = db.query(User).filter(User.phone == payload.phone).one_or_none()
    if user is None or not user.is_active or not verify_password(payload.password, user.password_hash):
        auth_limiter.hit(key)
        raise AuthError("Identifiants incorrects", 401)
    auth_limiter.clear(key)
    token = create_access_token(user_id=user.id, role=user.role.value)
    return TokenResponse(access_token=token, user=auth_user_from_model(user))
