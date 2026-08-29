from datetime import datetime, time
from uuid import UUID

from sqlalchemy.orm import Session, selectinload

from app.core.enums import GuardianLinkStatus, UserRole
from app.models.people import GuardianLink
from app.models.user import User
from app.models.zones import GeofenceOccupancy, SafetyZone, SafetyZoneSchedule
from app.schemas.entities import SafetyZoneRead
from app.schemas.zones import SafetyZoneCreate, SafetyZoneUpdate, ScheduleInput
from app.services.family_service import FamilyError, require_young


class ZoneError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


def is_window_active(weekday: int, start: time, end: time, at: datetime) -> bool:
    """True si `at` (heure locale du serveur) tombe dans la plage.

    Si end <= start, la fenêtre traverse minuit : weekday 18:00 → lendemain 07:00.
    Si start == end, la journée entière de `weekday` est couverte.
    """
    local = at.astimezone().replace(tzinfo=None) if at.tzinfo else at
    current_wd = local.weekday()
    current_t = local.time().replace(microsecond=0)
    start = start.replace(microsecond=0)
    end = end.replace(microsecond=0)
    if start == end:
        return current_wd == weekday
    if end <= start:
        if current_wd == weekday and current_t >= start:
            return True
        return current_wd == (weekday + 1) % 7 and current_t < end
    return current_wd == weekday and start <= current_t < end


def schedule_active_now(schedules: list[SafetyZoneSchedule], at: datetime | None = None) -> bool:
    moment = at or datetime.now().astimezone()
    return any(is_window_active(row.weekday, row.start_time, row.end_time, moment) for row in schedules)


def to_read(zone: SafetyZone, db: Session | None = None, at: datetime | None = None) -> SafetyZoneRead:
    payload = SafetyZoneRead.model_validate(zone)
    inside = False
    if db is not None:
        occupancy = (
            db.query(GeofenceOccupancy)
            .filter(
                GeofenceOccupancy.zone_id == zone.id,
                GeofenceOccupancy.young_person_id == zone.young_person_id,
            )
            .one_or_none()
        )
        inside = bool(occupancy is not None and occupancy.is_inside)
    return payload.model_copy(
        update={
            "schedule_active_now": schedule_active_now(zone.schedules, at),
            "inside_on_last_fix": inside,
        }
    )


def _zone_query(db: Session):
    return db.query(SafetyZone).options(selectinload(SafetyZone.schedules))


def _active_link(db: Session, guardian: User, young_person_id: UUID) -> GuardianLink:
    if guardian.role not in {UserRole.PARENT, UserRole.RELATIVE}:
        raise ZoneError("Réservé au parent ou au proche autorisé", 403)
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
        raise ZoneError("Pas de rattachement actif avec ce jeune", 403)
    return link


def _require_manage(db: Session, guardian: User, young_person_id: UUID) -> GuardianLink:
    link = _active_link(db, guardian, young_person_id)
    if not link.can_manage_zones:
        raise ZoneError("Le jeune n'a pas autorisé la gestion de ses zones", 403)
    return link


def _schedules_from(inputs: list[ScheduleInput]) -> list[SafetyZoneSchedule]:
    return [
        SafetyZoneSchedule(weekday=item.weekday, start_time=item.start_time, end_time=item.end_time)
        for item in inputs
    ]


def list_own(db: Session, user: User) -> list[SafetyZoneRead]:
    young = require_young(user)
    zones = _zone_query(db).filter(SafetyZone.young_person_id == young.id).order_by(SafetyZone.name).all()
    return [to_read(zone, db) for zone in zones]


def list_for_child(db: Session, guardian: User, young_person_id: UUID) -> list[SafetyZoneRead]:
    _active_link(db, guardian, young_person_id)
    zones = _zone_query(db).filter(SafetyZone.young_person_id == young_person_id).order_by(SafetyZone.name).all()
    return [to_read(zone, db) for zone in zones]


def create_zone(db: Session, user: User, payload: SafetyZoneCreate) -> SafetyZoneRead:
    if user.role == UserRole.YOUNG:
        raise ZoneError("Le jeune consulte ses zones ; seul un parent autorisé peut les définir", 403)
    if payload.young_person_id is None:
        raise ZoneError("Indiquez le jeune concerné", 422)
    _require_manage(db, user, payload.young_person_id)
    zone = SafetyZone(
        young_person_id=payload.young_person_id,
        name=payload.name.strip(),
        latitude=payload.latitude,
        longitude=payload.longitude,
        radius_meters=payload.radius_meters,
        is_active=payload.is_active,
        accuracy_tolerance_meters=payload.accuracy_tolerance_meters if payload.accuracy_tolerance_meters is not None else 40.0,
        min_exit_duration_seconds=payload.min_exit_duration_seconds if payload.min_exit_duration_seconds is not None else 90,
        schedules=_schedules_from(payload.schedules),
    )
    db.add(zone)
    db.commit()
    db.refresh(zone)
    loaded = _zone_query(db).filter(SafetyZone.id == zone.id).one()
    return to_read(loaded, db)


def _owned_zone(db: Session, user: User, zone_id: UUID, *, manage: bool) -> SafetyZone:
    zone = _zone_query(db).filter(SafetyZone.id == zone_id).one_or_none()
    if zone is None:
        raise ZoneError("Zone introuvable", 404)
    if user.role == UserRole.YOUNG:
        young = require_young(user)
        if zone.young_person_id != young.id:
            raise ZoneError("Zone introuvable", 404)
        if manage:
            raise ZoneError("Le jeune consulte ses zones ; seul un parent autorisé peut les modifier", 403)
        return zone
    if manage:
        _require_manage(db, user, zone.young_person_id)
    else:
        _active_link(db, user, zone.young_person_id)
    return zone


def update_zone(db: Session, user: User, zone_id: UUID, payload: SafetyZoneUpdate) -> SafetyZoneRead:
    zone = _owned_zone(db, user, zone_id, manage=True)
    if payload.name is not None:
        zone.name = payload.name.strip()
    if payload.latitude is not None:
        zone.latitude = payload.latitude
    if payload.longitude is not None:
        zone.longitude = payload.longitude
    if payload.radius_meters is not None:
        zone.radius_meters = payload.radius_meters
    if payload.is_active is not None:
        zone.is_active = payload.is_active
    if payload.schedules is not None:
        zone.schedules.clear()
        db.flush()
        for row in _schedules_from(payload.schedules):
            zone.schedules.append(row)
    db.commit()
    loaded = _zone_query(db).filter(SafetyZone.id == zone.id).one()
    return to_read(loaded, db)


def delete_zone(db: Session, user: User, zone_id: UUID) -> None:
    zone = _owned_zone(db, user, zone_id, manage=True)
    db.delete(zone)
    db.commit()
