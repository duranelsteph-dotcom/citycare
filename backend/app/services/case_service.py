import json
from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy.orm import Session, joinedload

from app.core.enums import (
    AlertStatus,
    CasePriority,
    CaseStatus,
    GuardianLinkStatus,
    NotificationType,
    TrackerEventType,
    UserRole,
)
from app.models.alert import Alert, AppNotification
from app.models.people import GuardianLink, YoungPerson
from app.models.search import MissingPersonCase
from app.models.tracker import GPSTracker, TrackerEvent, TrackerLocation
from app.models.user import User
from app.schemas.case import CaseCreate
from app.schemas.entities import MissingPersonCaseRead
from app.services.family_service import require_young
from app.services.location_service import STALE_AFTER, _aware

OPEN_CASE = {CaseStatus.OPEN, CaseStatus.SEARCHING}
OPEN_SOS = {
    AlertStatus.CREATED,
    AlertStatus.ACTIVE,
    AlertStatus.ACKNOWLEDGED,
    AlertStatus.IN_PROGRESS,
}
TERMINAL_CASE = {CaseStatus.FOUND, CaseStatus.CLOSED}


class CaseError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _iso(value: datetime | None) -> str | None:
    if value is None:
        return None
    return _aware(value).isoformat()


def to_read(row: MissingPersonCase) -> MissingPersonCaseRead:
    snapshot = None
    if row.snapshot_json:
        try:
            snapshot = json.loads(row.snapshot_json)
        except json.JSONDecodeError:
            snapshot = None
    payload = MissingPersonCaseRead.model_validate(row)
    young = row.young_person
    reporter = row.reported_by
    return payload.model_copy(
        update={
            "snapshot": snapshot,
            "young_display_name": young.display_name if young else None,
            "reporter_name": reporter.full_name if reporter else None,
        }
    )


def _query(db: Session):
    return db.query(MissingPersonCase).options(
        joinedload(MissingPersonCase.young_person),
        joinedload(MissingPersonCase.reported_by),
    )


def _active_link(db: Session, user: User, young_person_id: UUID) -> GuardianLink:
    if user.role not in {UserRole.PARENT, UserRole.RELATIVE}:
        raise CaseError("Réservé au parent ou au proche autorisé", 403)
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
        raise CaseError("Pas de rattachement actif avec ce jeune", 403)
    return link


def _can_view(db: Session, user: User, young_person_id: UUID) -> None:
    if user.role == UserRole.AUTHORITY:
        return
    if user.role == UserRole.YOUNG:
        young = require_young(user)
        if young.id != young_person_id:
            raise CaseError("Vous ne pouvez consulter que votre propre dossier", 403)
        return
    _active_link(db, user, young_person_id)


def _can_report(db: Session, user: User, young_person_id: UUID) -> GuardianLink:
    link = _active_link(db, user, young_person_id)
    if not link.can_report_missing:
        raise CaseError("Le jeune n'a pas autorisé la déclaration d'une disparition", 403)
    return link


def _open_case(db: Session, young_person_id: UUID) -> MissingPersonCase | None:
    return (
        _query(db)
        .filter(MissingPersonCase.young_person_id == young_person_id, MissingPersonCase.status.in_(OPEN_CASE))
        .order_by(MissingPersonCase.created_at.desc())
        .first()
    )


def _build_snapshot(db: Session, young: YoungPerson) -> dict:
    latest = (
        db.query(TrackerLocation)
        .filter(TrackerLocation.young_person_id == young.id)
        .order_by(TrackerLocation.recorded_at.desc())
        .first()
    )
    recent = (
        db.query(TrackerLocation)
        .filter(TrackerLocation.young_person_id == young.id)
        .order_by(TrackerLocation.recorded_at.desc())
        .limit(10)
        .all()
    )
    kits = db.query(GPSTracker).filter(GPSTracker.young_person_id == young.id).all()
    exits = (
        db.query(TrackerEvent)
        .filter(
            TrackerEvent.young_person_id == young.id,
            TrackerEvent.event_type == TrackerEventType.GEOFENCE_EXIT,
        )
        .order_by(TrackerEvent.recorded_at.desc())
        .limit(5)
        .all()
    )
    kit_events = (
        db.query(TrackerEvent)
        .filter(
            TrackerEvent.young_person_id == young.id,
            TrackerEvent.event_type.in_(
                {TrackerEventType.SIGNAL_LOST, TrackerEventType.DEVICE_REMOVED, TrackerEventType.LOW_BATTERY}
            ),
        )
        .order_by(TrackerEvent.recorded_at.desc())
        .limit(5)
        .all()
    )
    sos = (
        db.query(Alert)
        .filter(Alert.young_person_id == young.id, Alert.status.in_(OPEN_SOS))
        .order_by(Alert.triggered_at.desc())
        .first()
    )
    last_known = None
    if latest is not None:
        last_known = {
            "latitude": latest.latitude,
            "longitude": latest.longitude,
            "recorded_at": _iso(latest.recorded_at),
            "source": latest.source.value,
            "is_stale": (_utcnow() - _aware(latest.recorded_at)) > STALE_AFTER,
        }
    return {
        "disclaimer": (
            "Instantané au moment de la déclaration. Ce n'est pas un kidnapping confirmé. "
            "Les positions sont des dernières valeurs connues, pas un suivi en direct, "
            "pas une trajectoire analysée ni une zone de recherche."
        ),
        "last_known": last_known,
        "recent_points": [
            {
                "latitude": point.latitude,
                "longitude": point.longitude,
                "recorded_at": _iso(point.recorded_at),
                "source": point.source.value,
            }
            for point in recent
        ],
        "kits": [
            {
                "label": kit.label,
                "device_uid": kit.device_uid,
                "status": kit.status.value,
                "battery_level": kit.battery_level,
                "last_seen_at": _iso(kit.last_seen_at),
                "last_latitude": kit.last_latitude,
                "last_longitude": kit.last_longitude,
            }
            for kit in kits
        ],
        "geofence_exits": [
            {
                "recorded_at": _iso(event.recorded_at),
                "latitude": event.latitude,
                "longitude": event.longitude,
                "payload": event.payload,
            }
            for event in exits
        ],
        "kit_events": [
            {
                "event_type": event.event_type.value,
                "recorded_at": _iso(event.recorded_at),
            }
            for event in kit_events
        ],
        "open_sos": None
        if sos is None
        else {
            "id": str(sos.id),
            "source": sos.source.value,
            "triggered_at": _iso(sos.triggered_at),
            "status": sos.status.value,
        },
    }


def _notify_case(db: Session, case: MissingPersonCase, young: YoungPerson, *, opened: bool) -> None:
    title = "Dossier de disparition" if opened else "Dossier mis à jour"
    note_type = NotificationType.MISSING_CASE
    if opened:
        body = (
            f"Un dossier de disparition a été ouvert concernant {young.display_name}. "
            "C'est une déclaration, pas un kidnapping confirmé. Un push FCM est tenté si un jeton appareil est enregistré."
        )
    elif case.status == CaseStatus.SEARCHING:
        title = "Recherche lancée"
        note_type = NotificationType.SEARCH_UPDATE
        body = (
            f"Une recherche a été lancée concernant {young.display_name}. "
            "Aide à la décision, pas un kidnapping confirmé. Un push FCM est tenté si un jeton appareil est enregistré."
        )
    elif case.status == CaseStatus.FOUND:
        body = f"{young.display_name} a été marqué comme retrouvé. Ce n'était pas un kidnapping confirmé."
    else:
        body = f"Le dossier concernant {young.display_name} est clôturé."
    payload = json.dumps(
        {
            "young_person_id": str(young.id),
            "young_display_name": young.display_name,
            "case_id": str(case.id),
            "status": case.status.value,
        },
        ensure_ascii=False,
    )
    recipients = [young.user_id]
    links = (
        db.query(GuardianLink)
        .filter(
            GuardianLink.young_person_id == young.id,
            GuardianLink.status == GuardianLinkStatus.ACTIVE,
            GuardianLink.can_receive_alerts.is_(True),
        )
        .all()
    )
    recipients.extend(link.guardian_user_id for link in links)
    seen: set[UUID] = set()
    for recipient_id in recipients:
        if recipient_id in seen:
            continue
        seen.add(recipient_id)
        db.add(
            AppNotification(
                recipient_user_id=recipient_id,
                notification_type=note_type,
                title=title,
                body=body,
                case_id=case.id,
                payload=payload,
            )
        )


def create_case(db: Session, user: User, payload: CaseCreate) -> MissingPersonCaseRead:
    _can_report(db, user, payload.young_person_id)
    existing = _open_case(db, payload.young_person_id)
    if existing is not None:
        return to_read(existing)
    young = db.query(YoungPerson).filter(YoungPerson.id == payload.young_person_id).one_or_none()
    if young is None:
        raise CaseError("Jeune introuvable", 404)
    snapshot = _build_snapshot(db, young)
    last = snapshot.get("last_known") or {}
    occurred = payload.occurred_at or _utcnow()
    occurred = _aware(occurred)
    case = MissingPersonCase(
        young_person_id=young.id,
        reported_by_user_id=user.id,
        occurred_at=occurred,
        last_known_latitude=last.get("latitude"),
        last_known_longitude=last.get("longitude"),
        last_known_at=_aware(datetime.fromisoformat(last["recorded_at"])) if last.get("recorded_at") else None,
        description=payload.description,
        clothing=payload.clothing,
        circumstances=payload.circumstances,
        last_seen_by=payload.last_seen_by,
        snapshot_json=json.dumps(snapshot, ensure_ascii=False),
        status=CaseStatus.OPEN,
        priority=CasePriority.HIGH,
    )
    db.add(case)
    db.flush()
    _notify_case(db, case, young, opened=True)
    from app.services.intelligence_service import attach_analysis

    attach_analysis(db, case, young, notify=True)
    db.commit()
    return to_read(_query(db).filter(MissingPersonCase.id == case.id).one())


def list_own(db: Session, user: User) -> list[MissingPersonCaseRead]:
    young = require_young(user)
    rows = (
        _query(db)
        .filter(MissingPersonCase.young_person_id == young.id)
        .order_by(MissingPersonCase.created_at.desc())
        .all()
    )
    return [to_read(row) for row in rows]


def list_for_authority(db: Session, user: User) -> list[MissingPersonCaseRead]:
    if user.role != UserRole.AUTHORITY:
        raise CaseError("Réservé à l’autorité", 403)
    rows = _query(db).order_by(MissingPersonCase.created_at.desc()).limit(100).all()
    return [to_read(row) for row in rows]


def list_for_guardian(db: Session, user: User) -> list[MissingPersonCaseRead]:
    if user.role == UserRole.AUTHORITY:
        return list_for_authority(db, user)
    if user.role not in {UserRole.PARENT, UserRole.RELATIVE}:
        raise CaseError("Réservé au parent, au proche ou à l’autorité", 403)
    young_ids = [
        link.young_person_id
        for link in db.query(GuardianLink)
        .filter(GuardianLink.guardian_user_id == user.id, GuardianLink.status == GuardianLinkStatus.ACTIVE)
        .all()
    ]
    if not young_ids:
        return []
    rows = (
        _query(db)
        .filter(MissingPersonCase.young_person_id.in_(young_ids))
        .order_by(MissingPersonCase.created_at.desc())
        .all()
    )
    return [to_read(row) for row in rows]


def get_case(db: Session, user: User, case_id: UUID) -> MissingPersonCaseRead:
    row = _query(db).filter(MissingPersonCase.id == case_id).one_or_none()
    if row is None:
        raise CaseError("Dossier introuvable", 404)
    _can_view(db, user, row.young_person_id)
    return to_read(row)


def set_status(db: Session, user: User, case_id: UUID, status: CaseStatus) -> MissingPersonCaseRead:
    if status not in {CaseStatus.SEARCHING, CaseStatus.FOUND, CaseStatus.CLOSED}:
        raise CaseError("Statut non autorisé", 422)
    row = _query(db).filter(MissingPersonCase.id == case_id).one_or_none()
    if row is None:
        raise CaseError("Dossier introuvable", 404)
    if user.role == UserRole.YOUNG:
        young = require_young(user)
        if young.id != row.young_person_id:
            raise CaseError("Vous ne pouvez modifier que votre propre dossier", 403)
        if status != CaseStatus.FOUND:
            raise CaseError("Le jeune peut indiquer qu'il est en sécurité", 403)
    elif user.role != UserRole.AUTHORITY:
        _can_report(db, user, row.young_person_id)
    if row.status in TERMINAL_CASE and status != row.status:
        raise CaseError("Ce dossier est déjà clos", 409)
    if row.status == status:
        return to_read(row)
    if status == CaseStatus.SEARCHING and row.status != CaseStatus.OPEN:
        raise CaseError("La recherche se lance depuis un dossier ouvert", 409)
    row.status = status
    db.flush()
    if status in TERMINAL_CASE or status == CaseStatus.SEARCHING:
        _notify_case(db, row, row.young_person, opened=False)
    db.commit()
    return to_read(_query(db).filter(MissingPersonCase.id == case_id).one())
