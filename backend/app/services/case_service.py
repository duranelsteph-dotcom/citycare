import json
from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy.orm import Session, joinedload

from app.core.enums import (
    AlertStatus,
    CasePriority,
    CaseStatus,
    GuardianLinkStatus,
    GuardianRelation,
    NotificationType,
    TrackerEventType,
    UserRole,
)
from app.models.alert import Alert, AppNotification
from app.models.people import GuardianLink, YoungPerson
from app.models.search import CaseEvent, MissingPersonCase
from app.models.tracker import GPSTracker, TrackerEvent, TrackerLocation
from app.models.user import User
from app.schemas.case import CaseCreate
from app.schemas.entities import CaseEventRead, MissingPersonCaseRead
from app.services.audience import active_authority_ids
from app.services.family_service import require_young
from app.services.location_service import STALE_AFTER, _aware

OPEN_CASE = {CaseStatus.OPEN, CaseStatus.ACKNOWLEDGED, CaseStatus.SEARCHING, CaseStatus.INFO}
OPEN_SOS = {
    AlertStatus.CREATED,
    AlertStatus.ACTIVE,
    AlertStatus.ACKNOWLEDGED,
    AlertStatus.IN_PROGRESS,
}
TERMINAL_CASE = {CaseStatus.FOUND, CaseStatus.CLOSED}
STATUS_LABELS = {
    CaseStatus.OPEN: "Déposé",
    CaseStatus.ACKNOWLEDGED: "Pris en charge",
    CaseStatus.SEARCHING: "Recherches",
    CaseStatus.INFO: "Infos",
    CaseStatus.FOUND: "Retrouvé",
    CaseStatus.CLOSED: "Clos",
}


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
    display = None
    if young is not None:
        display = young.display_name
    if not display and row.subject_name:
        display = row.subject_name
    return payload.model_copy(
        update={
            "snapshot": snapshot,
            "young_display_name": display,
            "reporter_name": reporter.full_name if reporter else None,
        }
    )


def _query(db: Session):
    return db.query(MissingPersonCase).options(
        joinedload(MissingPersonCase.young_person).joinedload(YoungPerson.user),
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


def _can_view_case(db: Session, user: User, row: MissingPersonCase) -> None:
    if user.role == UserRole.AUTHORITY:
        return
    if user.id == row.reported_by_user_id:
        return
    _can_view(db, user, row.young_person_id)


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


def _subject_label(case: MissingPersonCase, young: YoungPerson | None) -> str:
    if case.subject_name:
        return case.subject_name
    if young is not None:
        return young.display_name
    return "une personne disparue"


def append_case_event(
    db: Session,
    case: MissingPersonCase,
    status: CaseStatus,
    *,
    actor_id: UUID | None,
) -> CaseEvent:
    event = CaseEvent(
        case_id=case.id,
        status=status,
        label=STATUS_LABELS.get(status, status.value),
        actor_user_id=actor_id,
    )
    db.add(event)
    db.flush()
    return event


def _notify_recipients(db: Session, case: MissingPersonCase, recipient_ids: list[UUID], *, title: str, body: str, note_type: NotificationType) -> None:
    young = case.young_person
    payload = json.dumps(
        {
            "young_person_id": str(case.young_person_id),
            "young_display_name": _subject_label(case, young),
            "case_id": str(case.id),
            "status": case.status.value,
        },
        ensure_ascii=False,
    )
    seen: set[UUID] = set()
    for recipient_id in recipient_ids:
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


def _circle_recipients(db: Session, case: MissingPersonCase, young: YoungPerson) -> list[UUID]:
    ids: list[UUID] = []
    if young.user is not None and young.user.is_active:
        ids.append(young.user_id)
    links = (
        db.query(GuardianLink)
        .filter(
            GuardianLink.young_person_id == young.id,
            GuardianLink.status == GuardianLinkStatus.ACTIVE,
            GuardianLink.can_receive_alerts.is_(True),
        )
        .all()
    )
    ids.extend(link.guardian_user_id for link in links)
    ids.append(case.reported_by_user_id)
    return ids


def _notify_case(db: Session, case: MissingPersonCase, young: YoungPerson, *, opened: bool) -> None:
    name = _subject_label(case, young)
    title = "Nouveau avis de recherche" if opened else "Dossier mis à jour"
    note_type = NotificationType.MISSING_CASE
    if opened:
        body = (
            f"Avis de recherche déposé concernant {name}. "
            "C'est une déclaration, pas un kidnapping confirmé. Un push FCM est tenté si un jeton appareil est enregistré."
        )
    elif case.status == CaseStatus.ACKNOWLEDGED:
        title = "Avis pris en charge"
        note_type = NotificationType.SEARCH_UPDATE
        body = (
            "L'avis est pris en charge. "
            "Ce n'est pas un kidnapping confirmé. Un push FCM est tenté si un jeton appareil est enregistré."
        )
    elif case.status == CaseStatus.SEARCHING:
        title = "Recherche lancée"
        note_type = NotificationType.SEARCH_UPDATE
        body = (
            f"Une recherche a été lancée concernant {name}. "
            "Aide à la décision, pas un kidnapping confirmé. Un push FCM est tenté si un jeton appareil est enregistré."
        )
    elif case.status == CaseStatus.INFO:
        title = "Nouvelles informations"
        note_type = NotificationType.SEARCH_UPDATE
        body = (
            f"Des informations ont été ajoutées au dossier concernant {name}. "
            "Ce n'est pas un kidnapping confirmé."
        )
    elif case.status == CaseStatus.FOUND:
        body = f"{name} a été marqué comme retrouvé. Ce n'était pas un kidnapping confirmé."
    else:
        body = f"Le dossier concernant {name} est clôturé."
    recipients = _circle_recipients(db, case, young)
    if opened:
        recipients.extend(active_authority_ids(db))
    _notify_recipients(db, case, recipients, title=title, body=body, note_type=note_type)


def _create_subject_young(db: Session, reporter: User, payload: CaseCreate) -> YoungPerson:
    """Fiche sujet sans compte login : jeune inactif, rattachement au déclarant. Pas Firestore."""
    from uuid import uuid4

    from app.core.security import hash_password

    name = (payload.subject_name or "").strip()
    if len(name) < 2:
        raise CaseError("Indiquez le nom de la personne disparue", 422)
    subject_user = User(
        full_name=name[:120],
        phone=f"+2370{uuid4().hex[:8]}",
        password_hash=hash_password(uuid4().hex + "Aa1!"),
        role=UserRole.YOUNG,
        is_active=False,
    )
    db.add(subject_user)
    db.flush()
    notes_parts = []
    if payload.subject_age_approx:
        notes_parts.append(f"Âge : {payload.subject_age_approx}")
    if payload.subject_sex:
        notes_parts.append(f"Sexe : {payload.subject_sex}")
    if payload.distinctive_signs:
        notes_parts.append(payload.distinctive_signs)
    young = YoungPerson(
        user_id=subject_user.id,
        display_name=name[:120],
        notes=" · ".join(notes_parts) or None,
        photo_url=payload.photo_url,
    )
    db.add(young)
    db.flush()
    relation = GuardianRelation.PARENT if reporter.role == UserRole.PARENT else GuardianRelation.RELATIVE
    db.add(
        GuardianLink(
            guardian_user_id=reporter.id,
            young_person_id=young.id,
            relation=relation,
            status=GuardianLinkStatus.ACTIVE,
            can_view_location=False,
            can_receive_alerts=True,
            can_trigger_alert=False,
            can_report_missing=True,
            can_manage_zones=False,
            can_manage_tracker=False,
        )
    )
    db.flush()
    return young


def create_case(db: Session, user: User, payload: CaseCreate) -> MissingPersonCaseRead:
    if user.role not in {UserRole.PARENT, UserRole.RELATIVE}:
        raise CaseError("Réservé au parent ou au proche autorisé", 403)
    linked_id = payload.young_person_id
    if linked_id is not None:
        _can_report(db, user, linked_id)
        existing = _open_case(db, linked_id)
        if existing is not None:
            return to_read(existing)
        young = db.query(YoungPerson).filter(YoungPerson.id == linked_id).one_or_none()
        if young is None:
            raise CaseError("Jeune introuvable", 404)
    else:
        young = _create_subject_young(db, user, payload)
    snapshot = _build_snapshot(db, young)
    last = snapshot.get("last_known") or {}
    occurred = payload.occurred_at or _utcnow()
    occurred = _aware(occurred)
    form_lat = payload.last_known_latitude
    form_lng = payload.last_known_longitude
    last_lat = form_lat if form_lat is not None else last.get("latitude")
    last_lng = form_lng if form_lng is not None else last.get("longitude")
    last_at = None
    if form_lat is not None and form_lng is not None:
        last_at = occurred
        snapshot["last_known"] = {
            "latitude": form_lat,
            "longitude": form_lng,
            "recorded_at": _iso(occurred),
            "source": "NOTICE",
            "address": payload.last_known_address,
            "is_stale": True,
        }
    elif last.get("recorded_at"):
        last_at = _aware(datetime.fromisoformat(last["recorded_at"]))
    subject_name = (payload.subject_name or "").strip() or young.display_name
    case = MissingPersonCase(
        young_person_id=young.id,
        reported_by_user_id=user.id,
        occurred_at=occurred,
        last_known_latitude=last_lat,
        last_known_longitude=last_lng,
        last_known_at=last_at,
        description=payload.description,
        clothing=payload.clothing or payload.distinctive_signs,
        circumstances=payload.circumstances,
        last_seen_by=payload.last_seen_by,
        photo_url=payload.photo_url,
        subject_name=subject_name,
        subject_age_approx=payload.subject_age_approx,
        subject_sex=payload.subject_sex,
        distinctive_signs=payload.distinctive_signs,
        last_known_address=payload.last_known_address,
        snapshot_json=json.dumps(snapshot, ensure_ascii=False),
        status=CaseStatus.OPEN,
        priority=CasePriority.HIGH,
    )
    db.add(case)
    db.flush()
    append_case_event(db, case, CaseStatus.OPEN, actor_id=user.id)
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
    query = _query(db)
    if young_ids:
        from sqlalchemy import or_

        query = query.filter(
            or_(
                MissingPersonCase.young_person_id.in_(young_ids),
                MissingPersonCase.reported_by_user_id == user.id,
            )
        )
    else:
        query = query.filter(MissingPersonCase.reported_by_user_id == user.id)
    rows = query.order_by(MissingPersonCase.created_at.desc()).all()
    return [to_read(row) for row in rows]


def get_case(db: Session, user: User, case_id: UUID) -> MissingPersonCaseRead:
    row = _query(db).filter(MissingPersonCase.id == case_id).one_or_none()
    if row is None:
        raise CaseError("Dossier introuvable", 404)
    _can_view_case(db, user, row)
    return to_read(row)


def list_events(db: Session, user: User, case_id: UUID) -> list[CaseEventRead]:
    get_case(db, user, case_id)
    rows = (
        db.query(CaseEvent)
        .filter(CaseEvent.case_id == case_id)
        .order_by(CaseEvent.created_at.asc())
        .all()
    )
    out: list[CaseEventRead] = []
    for row in rows:
        actor_name = None
        if row.actor_user_id is not None:
            actor = db.query(User).filter(User.id == row.actor_user_id).one_or_none()
            actor_name = actor.full_name if actor is not None else None
        payload = CaseEventRead.model_validate(row)
        out.append(payload.model_copy(update={"actor_name": actor_name}))
    return out


def attach_photo(db: Session, user: User, case_id: UUID, upload) -> MissingPersonCaseRead:
    from app.services.photo_service import PhotoError, delete_profile_photo_file, store_upload

    row = _query(db).filter(MissingPersonCase.id == case_id).one_or_none()
    if row is None:
        raise CaseError("Dossier introuvable", 404)
    if user.role == UserRole.AUTHORITY:
        pass
    elif user.id == row.reported_by_user_id:
        pass
    else:
        _can_report(db, user, row.young_person_id)
    try:
        public = store_upload(upload, prefix=f"case_{case_id}")
    except PhotoError as exc:
        raise CaseError(exc.message, exc.status_code) from exc
    previous = row.photo_url
    row.photo_url = public
    if row.young_person is not None:
        row.young_person.photo_url = public
    db.commit()
    delete_profile_photo_file(previous if previous != public else None)
    return to_read(_query(db).filter(MissingPersonCase.id == case_id).one())


def set_status(db: Session, user: User, case_id: UUID, status: CaseStatus) -> MissingPersonCaseRead:
    allowed = {
        CaseStatus.ACKNOWLEDGED,
        CaseStatus.SEARCHING,
        CaseStatus.INFO,
        CaseStatus.FOUND,
        CaseStatus.CLOSED,
    }
    if status not in allowed:
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
    elif user.role == UserRole.AUTHORITY:
        pass
    elif status == CaseStatus.ACKNOWLEDGED:
        raise CaseError("Seul l’autorité peut prendre en charge un avis", 403)
    else:
        _can_report(db, user, row.young_person_id)
    if row.status in TERMINAL_CASE and status != row.status:
        raise CaseError("Ce dossier est déjà clos", 409)
    if row.status == status:
        return to_read(row)
    if status == CaseStatus.ACKNOWLEDGED and row.status != CaseStatus.OPEN:
        raise CaseError("La prise en charge part d’un avis déposé", 409)
    if status == CaseStatus.SEARCHING and row.status not in {
        CaseStatus.OPEN,
        CaseStatus.ACKNOWLEDGED,
        CaseStatus.INFO,
    }:
        raise CaseError("La recherche se lance depuis un dossier ouvert", 409)
    if status == CaseStatus.INFO and row.status not in OPEN_CASE:
        raise CaseError("Impossible d’ajouter des infos sur un dossier clos", 409)
    row.status = status
    db.flush()
    append_case_event(db, row, status, actor_id=user.id)
    if status in TERMINAL_CASE or status in {CaseStatus.SEARCHING, CaseStatus.ACKNOWLEDGED, CaseStatus.INFO}:
        _notify_case(db, row, row.young_person, opened=False)
    db.commit()
    return to_read(_query(db).filter(MissingPersonCase.id == case_id).one())
