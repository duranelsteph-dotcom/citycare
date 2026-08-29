from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.entities import IncidentRead, RiskZoneRead
from app.schemas.risk import IncidentCreate, RiskZoneCreate, RiskZoneUpdate
from app.services.risk_zone_service import (
    RiskZoneError,
    add_incident,
    create_zone,
    delete_zone,
    list_incidents,
    list_zones,
    update_zone,
)

router = APIRouter(prefix="/risk-zones", tags=["risk-zones"])


def _http(exc: RiskZoneError) -> None:
    raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc


@router.get("/list", response_model=list[RiskZoneRead])
def get_risk_zones(db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> list[RiskZoneRead]:
    return list_zones(db, user)


@router.post("", response_model=RiskZoneRead)
def post_risk_zone(
    payload: RiskZoneCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> RiskZoneRead:
    try:
        return create_zone(db, user, payload)
    except RiskZoneError as exc:
        _http(exc)


@router.patch("/{zone_id}", response_model=RiskZoneRead)
def patch_risk_zone(
    zone_id: UUID,
    payload: RiskZoneUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> RiskZoneRead:
    try:
        return update_zone(db, user, zone_id, payload)
    except RiskZoneError as exc:
        _http(exc)


@router.delete("/{zone_id}", status_code=204)
def remove_risk_zone(
    zone_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> None:
    try:
        delete_zone(db, user, zone_id)
    except RiskZoneError as exc:
        _http(exc)


@router.get("/{zone_id}/incidents", response_model=list[IncidentRead])
def get_incidents(
    zone_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[IncidentRead]:
    try:
        return list_incidents(db, zone_id)
    except RiskZoneError as exc:
        _http(exc)


@router.post("/{zone_id}/incidents", response_model=IncidentRead)
def post_incident(
    zone_id: UUID,
    payload: IncidentCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> IncidentRead:
    try:
        return add_incident(db, user, zone_id, payload)
    except RiskZoneError as exc:
        _http(exc)
