from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.entities import PositionShareRead
from app.schemas.location import ShareCreate
from app.services.family_service import FamilyError
from app.services.share_service import ShareError, create_share, list_own, list_received, revoke_share

router = APIRouter(prefix="/shares", tags=["shares"])


def _http(exc: ShareError | FamilyError) -> None:
    raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc


@router.get("/me", response_model=list[PositionShareRead])
def get_my_shares(db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> list[PositionShareRead]:
    try:
        return list_own(db, user)
    except (ShareError, FamilyError) as exc:
        _http(exc)


@router.get("/received", response_model=list[PositionShareRead])
def get_received_shares(
    db: Session = Depends(get_db), user: User = Depends(get_current_user)
) -> list[PositionShareRead]:
    try:
        return list_received(db, user)
    except (ShareError, FamilyError) as exc:
        _http(exc)


@router.post("", response_model=PositionShareRead)
def post_share(
    payload: ShareCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> PositionShareRead:
    try:
        return create_share(db, user, payload)
    except (ShareError, FamilyError) as exc:
        _http(exc)


@router.post("/{share_id}/revoke", response_model=PositionShareRead)
def post_revoke_share(
    share_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> PositionShareRead:
    try:
        return revoke_share(db, user, share_id)
    except (ShareError, FamilyError) as exc:
        _http(exc)
