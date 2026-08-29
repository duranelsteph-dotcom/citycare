from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.entities import NotificationRead
from app.services.fcm_service import is_configured as fcm_configured
from app.services.notification_service import (
    DISCLAIMER,
    NotificationError,
    list_mine,
    mark_all_read,
    mark_read,
    unread_count,
)

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("/me", response_model=list[NotificationRead])
def get_notifications(
    limit: int = Query(default=50, ge=1, le=100),
    unread_only: bool = Query(default=False),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[NotificationRead]:
    return list_mine(db, user, limit, unread_only=unread_only)


@router.get("/unread-count")
def get_unread_count(db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> dict:
    return {
        "unread": unread_count(db, user),
        "channel": "IN_APP",
        "push": "FCM" if fcm_configured() else "DISABLED",
        "disclaimer": DISCLAIMER,
    }


@router.post("/read-all")
def post_read_all(db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> dict:
    return {
        "updated": mark_all_read(db, user),
        "channel": "IN_APP",
        "push": "FCM" if fcm_configured() else "DISABLED",
        "disclaimer": DISCLAIMER,
    }


@router.post("/{notification_id}/read", response_model=NotificationRead)
def post_read(
    notification_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> NotificationRead:
    try:
        return mark_read(db, user, notification_id)
    except NotificationError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc
