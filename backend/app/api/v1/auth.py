from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.auth import AuthUserRead, LoginRequest, RegisterRequest, TokenResponse
from app.services.auth_service import AuthError, auth_user_from_model, login_user, register_user

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=TokenResponse)
def register(payload: RegisterRequest, db: Session = Depends(get_db)) -> TokenResponse:
    try:
        return register_user(db, payload)
    except AuthError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)) -> TokenResponse:
    try:
        return login_user(db, payload)
    except AuthError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc


@router.get("/me", response_model=AuthUserRead)
def me(user: User = Depends(get_current_user)) -> AuthUserRead:
    return auth_user_from_model(user)
