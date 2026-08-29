from datetime import datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy.orm import Session, joinedload

from app.core.enums import GuardianLinkStatus, TrackerStatus, UserRole
from app.models.alert import Alert
from app.models.people import GuardianLink, YoungPerson
from app.models.search import MissingPersonCase
from app.models.tracker import GPSTracker, TrackerEvent, TrackerLocation
from app.models.user import User
from app.schemas.entities import (
    AlertRead,
    EmergencySnapshot,
    SearchZoneRead,
    TrackerEventRead,
    TrackerLocationRead,
    TrajectoryRead,
)
from app.services.alert_service import OPEN_STATUSES, to_read as alert_to_read
from app.services.case_service import OPEN_CASE
from app.services.location_service import to_read as location_to_read
from app.services.tracking_mode import effective_mode
from app.services.trajectory_service import reconstruct_window

DISCLAIMER = (
    "MODE URGENCE : dernière position connue, dernière communication, batterie et kit. "
    "Ce n'est pas un suivi en direct, pas la position actuelle, pas un kidnapping confirmé."
)


class EmergencyError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _can_view(db: Session, user: User, young: YoungPerson) -> str:
    if user.role == UserRole.YOUNG:
        if user.young_profile is None or user.young_profile.id != young.id:
            raise EmergencyError("Vous ne pouvez consulter que votre propre mode urgence", 403)
        return "SELF"
    if user.role not in {UserRole.PARENT, UserRole.RELATIVE}:
        raise EmergencyError("Réservé au jeune, au parent ou au proche autorisé", 403)
    link = (
        db.query(GuardianLink)
        .filter(
            GuardianLink.guardian_user_id == user.id,
            GuardianLink.young_person_id == young.id,
            GuardianLink.status == GuardianLinkStatus.ACTIVE,
        )
        .one_or_none()
    )
    if link is None:
        raise EmergencyError("Pas de rattachement actif avec ce jeune", 403)
    open_sos = (
        db.query(Alert.id)
        .filter(Alert.young_person_id == young.id, Alert.status.in_(OPEN_STATUSES))
        .first()
    )
    open_case = (
        db.query(MissingPersonCase.id)
        .filter(MissingPersonCase.young_person_id == young.id, MissingPersonCase.status.in_(OPEN_CASE))
        .first()
    )
    if open_sos or open_case:
        if link.can_receive_alerts or link.can_report_missing or link.can_view_location or link.can_trigger_alert:
            return "EMERGENCY"
        raise EmergencyError("Pas d'autorisation pour le mode urgence", 403)
    if link.can_view_location:
        return "PERMISSION"
    raise EmergencyError(
        "Le mode urgence s'ouvre s'il y a un SOS ou un dossier, ou si le jeune a autorisé la localisation.",
        403,
    )


def snapshot(db: Session, user: User, young_person_id: UUID) -> EmergencySnapshot:
    young = (
        db.query(YoungPerson)
        .options(joinedload(YoungPerson.user))
        .filter(YoungPerson.id == young_person_id)
        .one_or_none()
    )
    if young is None:
        raise EmergencyError("Jeune introuvable", 404)
    access = _can_view(db, user, young)
    point = (
        db.query(TrackerLocation)
        .filter(TrackerLocation.young_person_id == young.id)
        .order_by(TrackerLocation.recorded_at.desc())
        .first()
    )
    kits = (
        db.query(GPSTracker)
        .filter(GPSTracker.young_person_id == young.id, GPSTracker.status != TrackerStatus.INACTIVE)
        .order_by(GPSTracker.last_seen_at.desc())
        .all()
    )
    kit = kits[0] if kits else None
    kit_events: list[TrackerEventRead] = []
    if kit is not None:
        rows = (
            db.query(TrackerEvent)
            .filter(TrackerEvent.tracker_id == kit.id)
            .order_by(TrackerEvent.recorded_at.desc())
            .limit(8)
            .all()
        )
        kit_events = [TrackerEventRead.model_validate(row) for row in rows]
    sos = (
        db.query(Alert)
        .options(joinedload(Alert.young_person))
        .filter(Alert.young_person_id == young.id, Alert.status.in_(OPEN_STATUSES))
        .order_by(Alert.triggered_at.desc())
        .first()
    )
    case = (
        db.query(MissingPersonCase)
        .filter(MissingPersonCase.young_person_id == young.id, MissingPersonCase.status.in_(OPEN_CASE))
        .order_by(MissingPersonCase.created_at.desc())
        .first()
    )
    last_comm = None
    if kit is not None and kit.last_seen_at is not None:
        last_comm = kit.last_seen_at
    if point is not None:
        recorded = point.recorded_at
        if last_comm is None or recorded > last_comm:
            last_comm = recorded
    zones: list[SearchZoneRead] = []
    testimony_count = 0
    if case is not None:
        from app.services.search_zone_service import list_search_zones
        from app.services.testimony_service import list_testimonies

        zones = list_search_zones(db, user, case.id)
        testimony_count = len(list_testimonies(db, user, case.id))
    trajectory: TrajectoryRead | None = None
    try:
        until = _utcnow()
        trajectory = reconstruct_window(
            db,
            young.id,
            since=until - timedelta(hours=6),
            until=until,
            limit=100,
            access="EMERGENCY",
        )
    except Exception:
        trajectory = None
    last_known: TrackerLocationRead | None = location_to_read(point) if point is not None else None
    return EmergencySnapshot(
        young_person_id=young.id,
        display_name=young.display_name,
        effective_mode=effective_mode(db, young.id, kit),
        last_known=last_known,
        last_communication_at=last_comm,
        battery_level=kit.battery_level if kit is not None else None,
        kit_status=kit.status.value if kit is not None else None,
        kit_label=kit.label if kit is not None else None,
        open_sos=alert_to_read(sos) if sos is not None else None,
        open_case_id=case.id if case is not None else None,
        trajectory=trajectory,
        search_zones=zones,
        kit_events=kit_events,
        testimony_count=testimony_count,
        is_live=False,
        access=access,
        disclaimer=DISCLAIMER,
    )
