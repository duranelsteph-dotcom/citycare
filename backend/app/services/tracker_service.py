import secrets
from uuid import UUID

from sqlalchemy.orm import Session, joinedload

from app.core.enums import GuardianLinkStatus, TrackerStatus, TrackingMode, UserRole
from app.core.security import hash_password
from app.models.people import GuardianLink, YoungPerson
from app.models.tracker import GPSTracker, TrackerEvent
from app.models.user import User
from app.schemas.entities import GPSTrackerRead, TrackerEventRead
from app.schemas.tracker import TrackerCreate, TrackerCreated, TrackerUpdate
from app.services.family_service import require_young


class TrackerError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


def to_read(tracker: GPSTracker) -> GPSTrackerRead:
    payload = GPSTrackerRead.model_validate(tracker)
    young = tracker.young_person
    return payload.model_copy(update={"young_display_name": young.display_name if young else None})


def _require_target(db: Session, user: User, young_person_id: UUID | None, *, manage: bool) -> YoungPerson:
    if user.role == UserRole.YOUNG:
        young = require_young(user)
        if young_person_id is not None and young_person_id != young.id:
            raise TrackerError("Vous ne pouvez consulter que votre propre kit", 403)
        return young
    if user.role not in {UserRole.PARENT, UserRole.RELATIVE}:
        raise TrackerError("Réservé au jeune, au parent ou au proche autorisé", 403)
    if young_person_id is None:
        raise TrackerError("Indiquez le jeune concerné", 400)
    link = (
        db.query(GuardianLink)
        .filter(
            GuardianLink.guardian_user_id == user.id,
            GuardianLink.young_person_id == young_person_id,
            GuardianLink.status == GuardianLinkStatus.ACTIVE,
        )
        .one_or_none()
    )
    if link is None:
        raise TrackerError("Pas de rattachement actif avec ce jeune", 403)
    if manage and not link.can_manage_tracker:
        raise TrackerError("Le jeune n'a pas autorisé la gestion du kit", 403)
    young = db.query(YoungPerson).filter(YoungPerson.id == young_person_id).one_or_none()
    if young is None:
        raise TrackerError("Jeune introuvable", 404)
    return young


def _query(db: Session):
    return db.query(GPSTracker).options(joinedload(GPSTracker.young_person))


def list_own(db: Session, user: User) -> list[GPSTrackerRead]:
    young = require_young(user)
    rows = _query(db).filter(GPSTracker.young_person_id == young.id).order_by(GPSTracker.created_at.desc()).all()
    return [to_read(row) for row in rows]


def list_for_child(db: Session, user: User, young_person_id: UUID) -> list[GPSTrackerRead]:
    _require_target(db, user, young_person_id, manage=False)
    rows = _query(db).filter(GPSTracker.young_person_id == young_person_id).order_by(GPSTracker.created_at.desc()).all()
    return [to_read(row) for row in rows]


def _owned(db: Session, user: User, tracker_id: UUID, *, manage: bool) -> GPSTracker:
    tracker = _query(db).filter(GPSTracker.id == tracker_id).one_or_none()
    if tracker is None:
        raise TrackerError("Kit introuvable", 404)
    _require_target(db, user, tracker.young_person_id, manage=manage)
    return tracker


def get_tracker(db: Session, user: User, tracker_id: UUID) -> GPSTrackerRead:
    return to_read(_owned(db, user, tracker_id, manage=False))


def update_tracker(db: Session, user: User, tracker_id: UUID, payload: TrackerUpdate) -> GPSTrackerRead:
    tracker = _owned(db, user, tracker_id, manage=True)
    if payload.label is not None:
        tracker.label = payload.label.strip()
    if payload.tracking_mode is not None:
        tracker.tracking_mode = payload.tracking_mode
    if payload.enabled is not None:
        tracker.status = TrackerStatus.ACTIVE if payload.enabled else TrackerStatus.INACTIVE
    db.commit()
    return to_read(_query(db).filter(GPSTracker.id == tracker_id).one())


def rotate_secret(db: Session, user: User, tracker_id: UUID) -> TrackerCreated:
    tracker = _owned(db, user, tracker_id, manage=True)
    secret = secrets.token_urlsafe(24)
    tracker.device_secret_hash = hash_password(secret)
    db.commit()
    tracker = _query(db).filter(GPSTracker.id == tracker_id).one()
    return TrackerCreated.model_validate({**to_read(tracker).model_dump(), "device_secret": secret})


def delete_tracker(db: Session, user: User, tracker_id: UUID) -> None:
    tracker = _owned(db, user, tracker_id, manage=True)
    db.delete(tracker)
    db.commit()


def register_tracker(db: Session, user: User, payload: TrackerCreate) -> TrackerCreated:
    young = _require_target(db, user, payload.young_person_id, manage=True)
    secret = secrets.token_urlsafe(24)
    tracker = GPSTracker(
        young_person_id=young.id,
        device_uid=f"CCKIT-{secrets.token_hex(6).upper()}",
        label=payload.label.strip(),
        status=TrackerStatus.ACTIVE,
        tracking_mode=TrackingMode.NORMAL,
        device_secret_hash=hash_password(secret),
    )
    db.add(tracker)
    db.commit()
    db.refresh(tracker)
    tracker = _query(db).filter(GPSTracker.id == tracker.id).one()
    return TrackerCreated.model_validate({**to_read(tracker).model_dump(), "device_secret": secret})


def list_events(db: Session, user: User, tracker_id: UUID, limit: int = 30) -> list[TrackerEventRead]:
    tracker = _owned(db, user, tracker_id, manage=False)
    cap = max(1, min(limit, 100))
    rows = (
        db.query(TrackerEvent)
        .filter(TrackerEvent.tracker_id == tracker.id)
        .order_by(TrackerEvent.recorded_at.desc())
        .limit(cap)
        .all()
    )
    return [TrackerEventRead.model_validate(row) for row in rows]
