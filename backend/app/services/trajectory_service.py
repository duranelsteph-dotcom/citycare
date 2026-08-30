from datetime import datetime, timedelta, timezone
from math import atan2, cos, radians, sin, sqrt
from uuid import UUID

from sqlalchemy.orm import Session

from app.core.enums import CaseStatus, GuardianLinkStatus, UserRole
from app.models.people import GuardianLink
from app.models.search import MissingPersonCase
from app.models.tracker import TrackerLocation
from app.models.user import User
from app.schemas.entities import TrajectoryPointRead, TrajectoryRead, TripHistoryRead, TripRead
from app.services.family_service import require_young
from app.services.location_service import LocationError, _aware, _view_access

GAP_AFTER = timedelta(minutes=10)
# Un trou de 15–20 min ouvre un nouveau trajet (liste type Life360).
TRIP_GAP = timedelta(minutes=18)
EARTH_RADIUS_M = 6_371_000
HISTORY_LIMIT = 2000
DISCLAIMER = (
    "Trajectoire reconstruite à partir des positions enregistrées. "
    "Ce n'est pas un suivi en direct, pas la position actuelle, "
    "pas une trajectoire analysée ni une zone de recherche. "
    "Les coupures correspondent à des trous de communication."
)
TRIPS_DISCLAIMER = (
    "Historique de déplacements reconstruit à partir des positions enregistrées. "
    "Ce n'est pas un suivi en direct, pas la position actuelle, "
    "pas un rapport de conduite (vitesse max, distraction), "
    "pas une trajectoire analysée ni une zone de recherche."
)
OPEN_CASE = {CaseStatus.OPEN, CaseStatus.SEARCHING}
VALID_PERIODS = {"today", "yesterday", "last_7_days"}


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    phi1, phi2 = radians(lat1), radians(lat2)
    dphi = radians(lat2 - lat1)
    dlambda = radians(lon2 - lon1)
    a = sin(dphi / 2) ** 2 + cos(phi1) * cos(phi2) * sin(dlambda / 2) ** 2
    return 2 * EARTH_RADIUS_M * atan2(sqrt(a), sqrt(1 - a))


def resolve_history_window(
    *,
    period: str | None = None,
    start: datetime | None = None,
    end: datetime | None = None,
    hours: int | None = None,
) -> tuple[datetime, datetime, str]:
    """Calcule [since, until] : période nommée, from/to ISO, ou fenêtre hours."""
    until = _utcnow()
    if start is not None or end is not None:
        if start is None or end is None:
            raise LocationError("from et to sont requis ensemble", 422)
        since = _aware(start)
        until = _aware(end)
        if until <= since:
            raise LocationError("to doit être après from", 422)
        if until - since > timedelta(days=31):
            raise LocationError("Période trop longue (31 jours max)", 422)
        return since, until, "custom"
    if period is not None:
        if period not in VALID_PERIODS:
            raise LocationError("Période inconnue. Utilisez today, yesterday ou last_7_days.", 422)
        if period == "today":
            since = until.replace(hour=0, minute=0, second=0, microsecond=0)
            return since, until, "today"
        if period == "yesterday":
            today = until.replace(hour=0, minute=0, second=0, microsecond=0)
            return today - timedelta(days=1), today, "yesterday"
        return until - timedelta(days=7), until, "last_7_days"
    window = hours if hours is not None else 4
    return until - timedelta(hours=window), until, "hours"


def _trip_from_points(points: list[TrajectoryPointRead]) -> TripRead:
    # Distance intra-trajet : somme des segments GPS. Pas de vitesse max.
    distance = 0.0
    for prev, nxt in zip(points, points[1:]):
        distance += _haversine(prev.latitude, prev.longitude, nxt.latitude, nxt.longitude)
    return TripRead(
        id=f"{points[0].location_id}:{points[-1].location_id}",
        started_at=points[0].recorded_at,
        ended_at=points[-1].recorded_at,
        distance_meters=round(distance, 1),
        point_count=len(points),
        points=points,
    )


def _group_trips(points: list[TrajectoryPointRead]) -> list[TripRead]:
    """Regroupe les points : écart > 18 min = nouveau trajet. Pas de conduite."""
    if not points:
        return []
    trips: list[TripRead] = []
    current = [points[0]]
    for prev, nxt in zip(points, points[1:]):
        delta = _aware(nxt.recorded_at) - _aware(prev.recorded_at)
        if delta > TRIP_GAP:
            trips.append(_trip_from_points(current))
            current = [nxt]
        else:
            current.append(nxt)
    trips.append(_trip_from_points(current))
    return trips


def _trip_history(
    db: Session,
    young_person_id: UUID,
    *,
    since: datetime,
    until: datetime,
    limit: int,
    access: str,
    period: str,
) -> TripHistoryRead:
    # Plafond plus haut que la fenêtre courte (4 h) pour 7 jours.
    cap = min(max(limit, 1), HISTORY_LIMIT)
    traj = _reconstruct(db, young_person_id, since=since, until=until, limit=cap, access=access)
    trips = _group_trips(traj.points)
    return TripHistoryRead(
        young_person_id=young_person_id,
        access=access,
        period=period,
        since=_aware(since),
        until=_aware(until),
        trips=trips,
        trip_count=len(trips),
        point_count=traj.point_count,
        gap_threshold_seconds=int(TRIP_GAP.total_seconds()),
        disclaimer=TRIPS_DISCLAIMER,
    )


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
    cap = min(max(limit, 1), HISTORY_LIMIT)
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
    trips = _group_trips(points)
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
        period=None,
        trips=trips,
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


def own_trajectory(
    db: Session,
    user: User,
    *,
    hours: int = 4,
    limit: int = 100,
    period: str | None = None,
    start: datetime | None = None,
    end: datetime | None = None,
) -> TrajectoryRead:
    young = require_young(user)
    since, until, label = resolve_history_window(period=period, start=start, end=end, hours=hours)
    traj = _reconstruct(db, young.id, since=since, until=until, limit=limit, access="SELF")
    return traj.model_copy(update={"period": label})


def child_trajectory(
    db: Session,
    user: User,
    young_person_id: UUID,
    *,
    hours: int = 4,
    limit: int = 100,
    period: str | None = None,
    start: datetime | None = None,
    end: datetime | None = None,
) -> TrajectoryRead:
    access = _child_access(db, user, young_person_id)
    since, until, label = resolve_history_window(period=period, start=start, end=end, hours=hours)
    traj = _reconstruct(db, young_person_id, since=since, until=until, limit=limit, access=access)
    return traj.model_copy(update={"period": label})


def own_trips(
    db: Session,
    user: User,
    *,
    period: str | None = "today",
    start: datetime | None = None,
    end: datetime | None = None,
    limit: int = 1000,
) -> TripHistoryRead:
    young = require_young(user)
    since, until, label = resolve_history_window(period=period, start=start, end=end)
    return _trip_history(db, young.id, since=since, until=until, limit=limit, access="SELF", period=label)


def child_trips(
    db: Session,
    user: User,
    young_person_id: UUID,
    *,
    period: str | None = "today",
    start: datetime | None = None,
    end: datetime | None = None,
    limit: int = 1000,
) -> TripHistoryRead:
    # Mêmes règles que watch : GuardianLink + can_view_location ou partage. Pas CASE.
    access = _view_access(db, user, young_person_id)
    since, until, label = resolve_history_window(period=period, start=start, end=end)
    return _trip_history(
        db, young_person_id, since=since, until=until, limit=limit, access=access, period=label
    )


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
