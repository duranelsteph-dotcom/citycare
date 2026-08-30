from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.auth import (
    AuthUserRead,
    DeleteAccountRequest,
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
from app.services.auth_service import (
    AuthError,
    auth_user_from_model,
    delete_account,
    login_user,
    register_user,
    request_password_reset,
    resend_otp,
    reset_password,
    verify_otp,
)
from app.services.photo_service import PhotoError, save_profile_photo

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=TokenResponse)
def register(payload: RegisterRequest, db: Session = Depends(get_db)) -> TokenResponse:
    try:
        return register_user(db, payload)
    except AuthError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/login", response_model=LoginChallengeResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)) -> LoginChallengeResponse:
    try:
        return login_user(db, payload)
    except AuthError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc


@router.post("/verify-otp", response_model=TokenResponse)
def verify_login_otp(payload: VerifyOtpRequest, db: Session = Depends(get_db)) -> TokenResponse:
    try:
        return verify_otp(db, payload)
    except AuthError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc


@router.post("/resend-otp", response_model=LoginChallengeResponse)
def resend_login_otp(payload: ResendOtpRequest, db: Session = Depends(get_db)) -> LoginChallengeResponse:
    try:
        return resend_otp(db, payload)
    except AuthError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc


@router.post("/forgot-password", response_model=ForgotPasswordResponse)
def forgot_password(payload: ForgotPasswordRequest, db: Session = Depends(get_db)) -> ForgotPasswordResponse:
    try:
        return request_password_reset(db, payload)
    except AuthError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc


@router.post("/reset-password", response_model=ResetPasswordResponse)
def reset_user_password(payload: ResetPasswordRequest, db: Session = Depends(get_db)) -> ResetPasswordResponse:
    try:
        return reset_password(db, payload)
    except AuthError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/me", response_model=AuthUserRead)
def me(user: User = Depends(get_current_user)) -> AuthUserRead:
    return auth_user_from_model(user)


@router.delete("/me", response_model=DeleteAccountResponse)
def delete_me(
    payload: DeleteAccountRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> DeleteAccountResponse:
    """RGPD : mot de passe obligatoire. Anonymise, invalide le JWT."""
    try:
        return delete_account(db, user, payload.password)
    except AuthError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc


@router.post("/me/photo", response_model=AuthUserRead)
def upload_my_photo(
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> AuthUserRead:
    """JPEG/PNG, ~2 Mo. Stockage disque local. JWT obligatoire."""
    try:
        return save_profile_photo(db, user, file)
    except PhotoError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc
