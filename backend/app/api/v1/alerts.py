from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.alert import SosCreate
from app.schemas.entities import AlertRead
from app.services.alert_service import (
    AlertError,
    acknowledge_sos,
    cancel_sos,
    get_alert,
    list_for_guardian,
    list_own,
    resolve_sos,
    trigger_sos,
)
from app.services.family_service import FamilyError

router = APIRouter(prefix="/alerts", tags=["alerts"])


def _http(exc: AlertError | FamilyError) -> None:
    raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc


@router.post("/sos", response_model=AlertRead)
def post_sos(
    payload: SosCreate | None = None,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> AlertRead:
    try:
        return trigger_sos(db, user, payload or SosCreate())
    except (AlertError, FamilyError) as exc:
        _http(exc)


@router.get("/me", response_model=list[AlertRead])
def get_my_alerts(db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> list[AlertRead]:
    try:
        return list_own(db, user)
    except (AlertError, FamilyError) as exc:
        _http(exc)


@router.get("/mine", response_model=list[AlertRead])
def get_guardian_alerts(db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> list[AlertRead]:
    try:
        return list_for_guardian(db, user)
    except (AlertError, FamilyError) as exc:
        _http(exc)


@router.get("/{alert_id}", response_model=AlertRead)
def get_one(
    alert_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> AlertRead:
    try:
        return get_alert(db, user, alert_id)
    except (AlertError, FamilyError) as exc:
        _http(exc)


@router.post("/{alert_id}/cancel", response_model=AlertRead)
def post_cancel(
    alert_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> AlertRead:
    try:
        return cancel_sos(db, user, alert_id)
    except (AlertError, FamilyError) as exc:
        _http(exc)


@router.post("/{alert_id}/acknowledge", response_model=AlertRead)
def post_acknowledge(
    alert_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> AlertRead:
    try:
        return acknowledge_sos(db, user, alert_id)
    except (AlertError, FamilyError) as exc:
        _http(exc)


@router.post("/{alert_id}/resolve", response_model=AlertRead)
def post_resolve(
    alert_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> AlertRead:
    try:
        return resolve_sos(db, user, alert_id)
    except (AlertError, FamilyError) as exc:
        _http(exc)
