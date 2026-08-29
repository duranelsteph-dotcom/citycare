from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.entities import GPSTrackerRead, TrackerEventRead
from app.schemas.tracker import TrackerCreate, TrackerCreated, TrackerUpdate
from app.services.family_service import FamilyError
from app.services.tracker_service import (
    TrackerError,
    delete_tracker,
    get_tracker,
    list_events,
    list_for_child,
    list_own,
    register_tracker,
    rotate_secret,
    update_tracker,
)

router = APIRouter(prefix="/trackers", tags=["trackers"])


def _http(exc: TrackerError | FamilyError) -> None:
    raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc


@router.get("/me", response_model=list[GPSTrackerRead])
def get_my_trackers(db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> list[GPSTrackerRead]:
    try:
        return list_own(db, user)
    except (TrackerError, FamilyError) as exc:
        _http(exc)


@router.get("/children/{young_person_id}", response_model=list[GPSTrackerRead])
def get_child_trackers(
    young_person_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[GPSTrackerRead]:
    try:
        return list_for_child(db, user, young_person_id)
    except (TrackerError, FamilyError) as exc:
        _http(exc)


@router.get("/{tracker_id}", response_model=GPSTrackerRead)
def get_one_tracker(
    tracker_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> GPSTrackerRead:
    try:
        return get_tracker(db, user, tracker_id)
    except (TrackerError, FamilyError) as exc:
        _http(exc)


@router.get("/{tracker_id}/events", response_model=list[TrackerEventRead])
def get_tracker_events(
    tracker_id: UUID,
    limit: int = Query(default=30, ge=1, le=100),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[TrackerEventRead]:
    try:
        return list_events(db, user, tracker_id, limit)
    except (TrackerError, FamilyError) as exc:
        _http(exc)


@router.post("", response_model=TrackerCreated)
def post_tracker(
    payload: TrackerCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> TrackerCreated:
    try:
        return register_tracker(db, user, payload)
    except (TrackerError, FamilyError) as exc:
        _http(exc)


@router.patch("/{tracker_id}", response_model=GPSTrackerRead)
def patch_tracker(
    tracker_id: UUID,
    payload: TrackerUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> GPSTrackerRead:
    try:
        return update_tracker(db, user, tracker_id, payload)
    except (TrackerError, FamilyError) as exc:
        _http(exc)


@router.post("/{tracker_id}/secret", response_model=TrackerCreated)
def post_rotate_secret(
    tracker_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> TrackerCreated:
    try:
        return rotate_secret(db, user, tracker_id)
    except (TrackerError, FamilyError) as exc:
        _http(exc)


@router.delete("/{tracker_id}", status_code=204)
def remove_tracker(
    tracker_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> None:
    try:
        delete_tracker(db, user, tracker_id)
    except (TrackerError, FamilyError) as exc:
        _http(exc)
