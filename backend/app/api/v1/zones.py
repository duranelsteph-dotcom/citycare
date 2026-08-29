from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.entities import SafetyZoneRead
from app.schemas.zones import SafetyZoneCreate, SafetyZoneUpdate
from app.services.family_service import FamilyError
from app.services.zone_service import (
    ZoneError,
    create_zone,
    delete_zone,
    list_for_child,
    list_own,
    update_zone,
)

router = APIRouter(prefix="/zones", tags=["zones"])


def _http(exc: FamilyError | ZoneError) -> None:
    raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc


@router.get("/me", response_model=list[SafetyZoneRead])
def get_my_zones(db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> list[SafetyZoneRead]:
    try:
        return list_own(db, user)
    except (ZoneError, FamilyError) as exc:
        _http(exc)


@router.get("/children/{young_person_id}", response_model=list[SafetyZoneRead])
def get_child_zones(
    young_person_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[SafetyZoneRead]:
    try:
        return list_for_child(db, user, young_person_id)
    except (ZoneError, FamilyError) as exc:
        _http(exc)


@router.post("", response_model=SafetyZoneRead)
def post_zone(
    payload: SafetyZoneCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> SafetyZoneRead:
    try:
        return create_zone(db, user, payload)
    except (ZoneError, FamilyError) as exc:
        _http(exc)


@router.patch("/{zone_id}", response_model=SafetyZoneRead)
def patch_zone(
    zone_id: UUID,
    payload: SafetyZoneUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> SafetyZoneRead:
    try:
        return update_zone(db, user, zone_id, payload)
    except (ZoneError, FamilyError) as exc:
        _http(exc)


@router.delete("/{zone_id}", status_code=204)
def remove_zone(
    zone_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> None:
    try:
        delete_zone(db, user, zone_id)
    except (ZoneError, FamilyError) as exc:
        _http(exc)
