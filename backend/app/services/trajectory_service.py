from datetime import datetime, timedelta, timezone
from math import atan2, cos, radians, sin, sqrt
from uuid import UUID

from sqlalchemy.orm import Session

from app.core.enums import CaseStatus, GuardianLinkStatus, UserRole
from app.models.people import GuardianLink
from app.models.search import MissingPersonCase
from app.models.tracker import TrackerLocation
from app.models.user import User
from app.schemas.entities import TrajectoryPointRead, TrajectoryRead
from app.services.family_service import require_young
from app.services.location_service import LocationError, _aware, _view_access

GAP_AFTER = timedelta(minutes=10)
EARTH_RADIUS_M = 6_371_000
DISCLAIMER = (
    "Trajectoire reconstruite à partir des positions enregistrées. "
    "Ce n'est pas un suivi en direct, pas la position actuelle, "
    "pas une trajectoire analysée ni une zone de recherche. "
    "Les coupures correspondent à des trous de communication."
)
OPEN_CASE = {CaseStatus.OPEN, CaseStatus.SEARCHING}


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    phi1, phi2 = radians(lat1), radians(lat2)
    dphi = radians(lat2 - lat1)
    dlambda = radians(lon2 - lon1)
    a = sin(dphi / 2) ** 2 + cos(phi1) * cos(phi2) * sin(dlambda / 2) ** 2
    return 2 * EARTH_RADIUS_M * atan2(sqrt(a), sqrt(1 - a))


def _open_case(db: Session, young_person_id: UUID) -> MissingPersonCase | None:
    return (
        db.query(MissingPersonCase)
        .filter(MissingPersonCase.young_person_id == young_person_id, MissingPersonCase.status.in_(OPEN_CASE))
        .order_by(MissingPersonCase.created_at.desc())
        .first()
    )


def _active_guardian(db: Session, user: User, young_person_id: UUID) -> bool:
    if user.role not in {UserRole.PARENT, UserRole.RELATIVE}:
        return False
    link = (
        db.query(GuardianLink.id)
        .filter(
            GuardianLink.guardian_user_id == user.id,
            GuardianLink.young_person_id == young_person_id,
            GuardianLink.status == GuardianLinkStatus.ACTIVE,
        )
        .first()
    )
    return link is not None


def _child_access(db: Session, user: User, young_person_id: UUID) -> str:
    try:
        return _view_access(db, user, young_person_id)
    except LocationError:
        if _active_guardian(db, user, young_person_id) and _open_case(db, young_person_id) is not None:
            return "CASE"
        raise


def _reconstruct(
    db: Session,
    young_person_id: UUID,
    *,
    since: datetime,
    until: datetime,
    limit: int,
    access: str,
) -> TrajectoryRead:
    cap = min(max(limit, 1), 200)
    since = _aware(since)
    until = _aware(until)
    rows = (
        db.query(TrackerLocation)
        .filter(
            TrackerLocation.young_person_id == young_person_id,
            TrackerLocation.recorded_at >= since,
            TrackerLocation.recorded_at <= until,
        )
        .order_by(TrackerLocation.recorded_at.asc())
        .limit(cap)
        .all()
    )
    points: list[TrajectoryPointRead] = []
    gap_count = 0
    distance = 0.0
    gap_seconds = int(GAP_AFTER.total_seconds())
    for index, row in enumerate(rows):
        gap_after = False
        if index + 1 < len(rows):
            nxt = rows[index + 1]
            delta = _aware(nxt.recorded_at) - _aware(row.recorded_at)
            if delta > GAP_AFTER:
                gap_after = True
                gap_count += 1
            else:
                distance += _haversine(row.latitude, row.longitude, nxt.latitude, nxt.longitude)
        points.append(
            TrajectoryPointRead(
                location_id=row.id,
                latitude=row.latitude,
                longitude=row.longitude,
                recorded_at=_aware(row.recorded_at),
                speed=row.speed,
                heading=row.heading,
                source=row.source,
                gap_after=gap_after,
            )
        )
    return TrajectoryRead(
        young_person_id=young_person_id,
        points=points,
        access=access,
        point_count=len(points),
        gap_count=gap_count,
        distance_meters=round(distance, 1),
        started_at=points[0].recorded_at if points else None,
        ended_at=points[-1].recorded_at if points else None,
        gap_threshold_seconds=gap_seconds,
        disclaimer=DISCLAIMER,
    )


def reconstruct_window(
    db: Session,
    young_person_id: UUID,
    *,
    since: datetime,
    until: datetime,
    limit: int = 200,
    access: str = "CASE",
) -> TrajectoryRead:
    return _reconstruct(db, young_person_id, since=since, until=until, limit=limit, access=access)


def own_trajectory(db: Session, user: User, *, hours: int = 4, limit: int = 100) -> TrajectoryRead:
    young = require_young(user)
    until = _utcnow()
    since = until - timedelta(hours=hours)
    return _reconstruct(db, young.id, since=since, until=until, limit=limit, access="SELF")


def child_trajectory(
    db: Session,
    user: User,
    young_person_id: UUID,
    *,
    hours: int = 4,
    limit: int = 100,
) -> TrajectoryRead:
    access = _child_access(db, user, young_person_id)
    until = _utcnow()
    since = until - timedelta(hours=hours)
    return _reconstruct(db, young_person_id, since=since, until=until, limit=limit, access=access)


def case_trajectory(
    db: Session,
    user: User,
    case_id: UUID,
    *,
    hours: int = 6,
    limit: int = 200,
) -> TrajectoryRead:
    from app.services.case_service import get_case

    row = get_case(db, user, case_id)
    occurred = _aware(row.occurred_at)
    until = _utcnow() if row.status in OPEN_CASE else _aware(row.updated_at)
    since = occurred - timedelta(hours=hours)
    if user.role == UserRole.YOUNG:
        access = "SELF"
    else:
        try:
            access = _view_access(db, user, row.young_person_id)
        except LocationError:
            access = "CASE"
    return _reconstruct(db, row.young_person_id, since=since, until=until, limit=limit, access=access)
