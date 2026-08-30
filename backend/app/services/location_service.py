from datetime import datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy.orm import Session

from app.core.enums import GuardianLinkStatus, LocationSource, UserRole
from app.models.people import GuardianLink, YoungPerson
from app.models.tracker import GPSTracker, TrackerLocation
from app.models.user import User
from app.schemas.entities import TrackerLocationRead
from app.schemas.location import LocationCreate, LocationWatch
from app.services.anomaly_service import evaluate_anomalies
from app.services.family_service import require_young
from app.services.geofence_service import evaluate_geofences
from app.services.risk_geofence_service import evaluate_risk_zones
from app.services.share_service import active_share
from app.services.tracking_mode import effective_mode, interval_for

STALE_AFTER = timedelta(minutes=5)


class LocationError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _aware(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value


def to_read(point: TrackerLocation) -> TrackerLocationRead:
    recorded = _aware(point.recorded_at)
    age = max(0, int((_utcnow() - recorded).total_seconds()))
    payload = TrackerLocationRead.model_validate(point)
    return payload.model_copy(update={"is_stale": age > int(STALE_AFTER.total_seconds()), "age_seconds": age})


def ingest_point(
    db: Session,
    young: YoungPerson,
    payload: LocationCreate,
    *,
    source: LocationSource,
    tracker: GPSTracker | None = None,
    signal_strength: int | None = None,
) -> TrackerLocation:
    recorded = payload.recorded_at or _utcnow()
    if recorded.tzinfo is None:
        recorded = recorded.replace(tzinfo=timezone.utc)
    else:
        recorded = recorded.astimezone(timezone.utc)
    if recorded > _utcnow() + timedelta(minutes=2):
        recorded = _utcnow()
    previous = _latest(db, young.id)
    point = TrackerLocation(
        tracker_id=tracker.id if tracker is not None else None,
        young_person_id=young.id,
        source=source,
        latitude=payload.latitude,
        longitude=payload.longitude,
        accuracy=payload.accuracy,
        altitude=payload.altitude,
        speed=payload.speed,
        heading=payload.heading,
        recorded_at=recorded,
        battery_level=payload.battery_level,
        signal_strength=signal_strength,
    )
    db.add(point)
    db.flush()
    evaluate_geofences(db, young, point, previous)
    evaluate_risk_zones(db, young, point, previous)
    evaluate_anomalies(db, young, point, previous)
    return point


def record_phone_location(db: Session, user: User, payload: LocationCreate) -> TrackerLocationRead:
    young = require_young(user)
    point = ingest_point(db, young, payload, source=LocationSource.PHONE)
    db.commit()
    db.refresh(point)
    return to_read(point)


def latest_own(db: Session, user: User) -> TrackerLocationRead:
    young = require_young(user)
    point = _latest(db, young.id)
    if point is None:
        raise LocationError("Aucune position enregistrée", 404)
    return to_read(point)


def history_own(db: Session, user: User, limit: int = 20) -> list[TrackerLocationRead]:
    young = require_young(user)
    return _history(db, young.id, limit)


def _history(db: Session, young_id: UUID, limit: int) -> list[TrackerLocationRead]:
    cap = min(max(limit, 1), 100)
    rows = (
        db.query(TrackerLocation)
        .filter(TrackerLocation.young_person_id == young_id)
        .order_by(TrackerLocation.recorded_at.desc())
        .limit(cap)
        .all()
    )
    return [to_read(row) for row in rows]


def _latest(db: Session, young_id: UUID) -> TrackerLocation | None:
    return (
        db.query(TrackerLocation)
        .filter(TrackerLocation.young_person_id == young_id)
        .order_by(TrackerLocation.recorded_at.desc())
        .first()
    )


def _view_access(db: Session, guardian: User, young_person_id: UUID) -> str:
    if guardian.role not in {UserRole.PARENT, UserRole.RELATIVE}:
        raise LocationError("Réservé au parent ou au proche autorisé", 403)
    link = (
        db.query(GuardianLink)
        .filter(
            GuardianLink.guardian_user_id == guardian.id,
            GuardianLink.young_person_id == young_person_id,
            GuardianLink.status == GuardianLinkStatus.ACTIVE,
        )
        .one_or_none()
    )
    if link is None:
        raise LocationError("Pas de rattachement actif avec ce jeune", 403)
    if link.can_view_location:
        return "PERMISSION"
    if active_share(db, young_person_id, guardian.id) is not None:
        return "SHARE"
    raise LocationError("Le jeune n'a pas autorisé le partage de sa position", 403)


def _watch(db: Session, young_person_id: UUID, access: str) -> LocationWatch:
    mode = effective_mode(db, young_person_id)
    point = _latest(db, young_person_id)
    return LocationWatch(
        latest=to_read(point) if point is not None else None,
        poll_after_seconds=interval_for(mode),
        effective_mode=mode,
        access=access,
    )


def watch_own(db: Session, user: User) -> LocationWatch:
    young = require_young(user)
    return _watch(db, young.id, "SELF")


def watch_child(db: Session, guardian: User, young_person_id: UUID) -> LocationWatch:
    access = _view_access(db, guardian, young_person_id)
    return _watch(db, young_person_id, access)


def latest_for_child(db: Session, guardian: User, young_person_id: UUID) -> TrackerLocationRead:
    _view_access(db, guardian, young_person_id)
    point = _latest(db, young_person_id)
    if point is None:
        raise LocationError("Aucune position enregistrée pour ce jeune", 404)
    return to_read(point)


def history_for_child(db: Session, guardian: User, young_person_id: UUID, limit: int = 20) -> list[TrackerLocationRead]:
    _view_access(db, guardian, young_person_id)
    return _history(db, young_person_id, limit)
