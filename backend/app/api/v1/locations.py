from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.entities import TrackerLocationRead, TrajectoryRead
from app.schemas.location import LocationCreate, LocationWatch
from app.services.family_service import FamilyError
from app.services.location_service import (
    LocationError,
    history_for_child,
    history_own,
    latest_for_child,
    latest_own,
    record_phone_location,
    watch_child,
    watch_own,
)
from app.services.trajectory_service import child_trajectory, own_trajectory

router = APIRouter(prefix="/locations", tags=["locations"])


def _http(exc: FamilyError | LocationError) -> None:
    raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc


@router.post("", response_model=TrackerLocationRead)
def post_location(
    payload: LocationCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> TrackerLocationRead:
    try:
        return record_phone_location(db, user, payload)
    except (LocationError, FamilyError) as exc:
        _http(exc)


@router.get("/me/latest", response_model=TrackerLocationRead)
def get_my_latest(db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> TrackerLocationRead:
    try:
        return latest_own(db, user)
    except (LocationError, FamilyError) as exc:
        _http(exc)


@router.get("/me/history", response_model=list[TrackerLocationRead])
def get_my_history(
    limit: int = Query(default=20, ge=1, le=100),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[TrackerLocationRead]:
    try:
        return history_own(db, user, limit)
    except (LocationError, FamilyError) as exc:
        _http(exc)


@router.get("/me/watch", response_model=LocationWatch)
def get_my_watch(db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> LocationWatch:
    try:
        return watch_own(db, user)
    except (LocationError, FamilyError) as exc:
        _http(exc)


@router.get("/me/trajectory", response_model=TrajectoryRead)
def get_my_trajectory(
    hours: int = Query(default=4, ge=1, le=24),
    limit: int = Query(default=100, ge=1, le=200),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> TrajectoryRead:
    try:
        return own_trajectory(db, user, hours=hours, limit=limit)
    except (LocationError, FamilyError) as exc:
        _http(exc)


@router.get("/children/{young_person_id}/latest", response_model=TrackerLocationRead)
def get_child_latest(
    young_person_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> TrackerLocationRead:
    try:
        return latest_for_child(db, user, young_person_id)
    except (LocationError, FamilyError) as exc:
        _http(exc)


@router.get("/children/{young_person_id}/history", response_model=list[TrackerLocationRead])
def get_child_history(
    young_person_id: UUID,
    limit: int = Query(default=20, ge=1, le=100),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[TrackerLocationRead]:
    try:
        return history_for_child(db, user, young_person_id, limit)
    except (LocationError, FamilyError) as exc:
        _http(exc)


@router.get("/children/{young_person_id}/watch", response_model=LocationWatch)
def get_child_watch(
    young_person_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> LocationWatch:
    try:
        return watch_child(db, user, young_person_id)
    except (LocationError, FamilyError) as exc:
        _http(exc)


@router.get("/children/{young_person_id}/trajectory", response_model=TrajectoryRead)
def get_child_trajectory(
    young_person_id: UUID,
    hours: int = Query(default=4, ge=1, le=24),
    limit: int = Query(default=100, ge=1, le=200),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> TrajectoryRead:
    try:
        return child_trajectory(db, user, young_person_id, hours=hours, limit=limit)
    except (LocationError, FamilyError) as exc:
        _http(exc)
