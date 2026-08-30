import json
from datetime import datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy.orm import Session, joinedload

from app.core.enums import (
    AlertSeverity,
    AlertSource,
    AlertStatus,
    GuardianLinkStatus,
    LocationSource,
    NotificationType,
    TrackerEventType,
    TrackerStatus,
    UserRole,
)
from app.models.alert import Alert, AppNotification
from app.models.people import GuardianLink, YoungPerson
from app.models.tracker import GPSTracker, TrackerEvent, TrackerLocation
from app.models.user import User
from app.schemas.alert import SosCreate
from app.schemas.entities import AlertRead
from app.core.rate_limit import kit_limiter
from app.core.security import verify_password
from app.services.family_service import require_young
from app.services.geofence_service import evaluate_geofences
from app.services.risk_geofence_service import evaluate_risk_zones

OPEN_STATUSES = {
    AlertStatus.CREATED,
    AlertStatus.ACTIVE,
    AlertStatus.ACKNOWLEDGED,
    AlertStatus.IN_PROGRESS,
}


class AlertError(Exception):
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


def to_read(alert: Alert) -> AlertRead:
    payload = AlertRead.model_validate(alert)
    young = alert.young_person
    return payload.model_copy(update={"young_display_name": young.display_name if young else None})


def _latest_point(db: Session, young_id: UUID) -> TrackerLocation | None:
    return (
        db.query(TrackerLocation)
        .filter(TrackerLocation.young_person_id == young_id)
        .order_by(TrackerLocation.recorded_at.desc())
        .first()
    )


def _open_query(db: Session, young_id: UUID):
    return (
        db.query(Alert)
        .options(joinedload(Alert.young_person))
        .filter(Alert.young_person_id == young_id, Alert.status.in_(OPEN_STATUSES))
        .order_by(Alert.triggered_at.desc())
    )


def _require_owner(user: User, alert: Alert) -> YoungPerson:
    young = require_young(user)
    if alert.young_person_id != young.id:
        raise AlertError("Cette alerte ne vous appartient pas", 403)
    return young


def _guardian_link(db: Session, user: User, young_id: UUID) -> GuardianLink:
    if user.role not in {UserRole.PARENT, UserRole.RELATIVE}:
        raise AlertError("Réservé au parent ou au proche autorisé", 403)
    link = (
        db.query(GuardianLink)
        .filter(
            GuardianLink.guardian_user_id == user.id,
            GuardianLink.young_person_id == young_id,
            GuardianLink.status == GuardianLinkStatus.ACTIVE,
        )
        .one_or_none()
    )
    if link is None:
        raise AlertError("Pas de rattachement actif avec ce jeune", 403)
    return link


def _load_alert(db: Session, alert_id: UUID) -> Alert:
    alert = db.query(Alert).options(joinedload(Alert.young_person)).filter(Alert.id == alert_id).one_or_none()
    if alert is None:
        raise AlertError("Alerte introuvable", 404)
    return alert


def _assert_can_view(db: Session, user: User, alert: Alert) -> None:
    if user.role == UserRole.AUTHORITY:
        return
    if user.role == UserRole.YOUNG:
        _require_owner(user, alert)
        return
    _guardian_link(db, user, alert.young_person_id)


def _notify(
    db: Session,
    *,
    recipient_id: UUID,
    alert: Alert,
    young: YoungPerson,
    title: str,
    body: str,
) -> None:
    payload = json.dumps(
        {
            "young_person_id": str(young.id),
            "young_display_name": young.display_name,
            "alert_id": str(alert.id),
            "event_type": TrackerEventType.SOS.value,
            "latitude": alert.latitude,
            "longitude": alert.longitude,
        },
        ensure_ascii=False,
    )
    db.add(
        AppNotification(
            recipient_user_id=recipient_id,
            notification_type=NotificationType.SOS,
            title=title,
            body=body,
            alert_id=alert.id,
            payload=payload,
        )
    )


def authenticate_kit(db: Session, device_uid: str, device_secret: str) -> GPSTracker:
    key = f"kit:{device_uid}"
    if kit_limiter.blocked(key):
        raise AlertError("Trop de tentatives. Réessayez plus tard.", 429)
    tracker = (
        db.query(GPSTracker)
        .options(joinedload(GPSTracker.young_person))
        .filter(GPSTracker.device_uid == device_uid)
        .one_or_none()
    )
    if tracker is None or not tracker.device_secret_hash or not verify_password(device_secret, tracker.device_secret_hash):
        kit_limiter.hit(key)
        raise AlertError("Identifiants du kit invalides", 401)
    if tracker.status == TrackerStatus.INACTIVE:
        raise AlertError("Ce kit est désactivé", 403)
    kit_limiter.clear(key)
    return tracker


def _create_sos(
    db: Session,
    young: YoungPerson,
    payload: SosCreate,
    *,
    source: AlertSource,
    tracker: GPSTracker | None = None,
    triggered_by_user_id: UUID | None = None,
) -> Alert:
    existing = _open_query(db, young.id).first()
    if existing is not None:
        if tracker is not None:
            tracker.last_seen_at = _utcnow()
            if payload.battery_level is not None:
                tracker.battery_level = payload.battery_level
        return existing

    recorded = payload.recorded_at or _utcnow()
    recorded = _aware(recorded)
    if recorded > _utcnow() + timedelta(minutes=2):
        recorded = _utcnow()

    latitude = payload.latitude
    longitude = payload.longitude
    accuracy = payload.accuracy
    last_known_latitude = None
    last_known_longitude = None
    last_known_at = None
    previous = _latest_point(db, young.id)
    location_source = LocationSource.IOT if source == AlertSource.IOT else LocationSource.PHONE

    if latitude is not None and longitude is not None:
        point = TrackerLocation(
            tracker_id=tracker.id if tracker is not None else None,
            young_person_id=young.id,
            source=location_source,
            latitude=latitude,
            longitude=longitude,
            accuracy=accuracy,
            recorded_at=recorded,
            battery_level=payload.battery_level,
        )
        db.add(point)
        db.flush()
        evaluate_geofences(db, young, point, previous)
        evaluate_risk_zones(db, young, point, previous)
        last_known_latitude = latitude
        last_known_longitude = longitude
        last_known_at = recorded
    elif previous is not None:
        latitude = previous.latitude
        longitude = previous.longitude
        accuracy = previous.accuracy
        last_known_latitude = previous.latitude
        last_known_longitude = previous.longitude
        last_known_at = previous.recorded_at

    if tracker is not None:
        tracker.last_seen_at = _utcnow()
        tracker.status = TrackerStatus.ACTIVE
        if payload.battery_level is not None:
            tracker.battery_level = payload.battery_level
        if latitude is not None and longitude is not None:
            tracker.last_latitude = latitude
            tracker.last_longitude = longitude

    alert = Alert(
        young_person_id=young.id,
        triggered_by_user_id=triggered_by_user_id,
        source=source,
        status=AlertStatus.ACTIVE,
        severity=AlertSeverity.CRITICAL,
        latitude=latitude,
        longitude=longitude,
        accuracy=accuracy,
        triggered_at=_utcnow(),
        battery_level=payload.battery_level,
        tracker_status=tracker.status.value if tracker is not None else None,
        description=payload.description,
        last_known_latitude=last_known_latitude,
        last_known_longitude=last_known_longitude,
        last_known_at=last_known_at,
    )
    db.add(alert)
    db.flush()
    db.add(
        TrackerEvent(
            tracker_id=tracker.id if tracker is not None else None,
            young_person_id=young.id,
            event_type=TrackerEventType.SOS,
            recorded_at=alert.triggered_at,
            latitude=alert.latitude,
            longitude=alert.longitude,
            payload=json.dumps(
                {"alert_id": str(alert.id), "source": source.value},
                ensure_ascii=False,
            ),
        )
    )
    from_kit = source == AlertSource.IOT
    from_voice = source == AlertSource.VOICE
    if from_kit:
        young_title = "SOS kit IoT"
        young_body = (
            "Un SOS a été envoyé depuis votre kit IoT aux contacts qui reçoivent les alertes. "
            "Ce n'est pas un kidnapping confirmé. Un push FCM est tenté si un jeton appareil est enregistré."
        )
    elif from_voice:
        young_title = "SOS vocal"
        young_body = (
            "Un SOS a été déclenché par la reconnaissance vocale de ce téléphone. "
            "Ce n'est pas un kidnapping confirmé. Un push FCM est tenté si un jeton appareil est enregistré."
        )
    else:
        young_title = "SOS envoyé"
        young_body = (
            "Votre demande d'aide a été transmise aux contacts qui reçoivent les alertes. "
            "Ce n'est pas un kidnapping confirmé. Un push FCM est tenté si un jeton appareil est enregistré."
        )
    _notify(
        db,
        recipient_id=young.user_id,
        alert=alert,
        young=young,
        title=young_title,
        body=young_body,
    )
    recipients = (
        db.query(GuardianLink)
        .filter(
            GuardianLink.young_person_id == young.id,
            GuardianLink.status == GuardianLinkStatus.ACTIVE,
            GuardianLink.can_receive_alerts.is_(True),
        )
        .all()
    )
    if from_kit:
        origin = "depuis le kit IoT "
    elif from_voice:
        origin = "vocal "
    elif source == AlertSource.RELATIVE:
        origin = "d'un proche "
    else:
        origin = ""
    for link in recipients:
        _notify(
            db,
            recipient_id=link.guardian_user_id,
            alert=alert,
            young=young,
            title="SOS",
            body=(
                f"SOS {origin}: {young.display_name} — demande d'aide. "
                if origin
                else f"SOS : {young.display_name} demande de l'aide. "
            )
            + "Ouvrez la fiche. Ce n'est pas un kidnapping confirmé.",
        )
    return alert


def trigger_sos(db: Session, user: User, payload: SosCreate) -> AlertRead:
    if user.role == UserRole.YOUNG:
        young = require_young(user)
        source = AlertSource.VOICE if payload.source == AlertSource.VOICE else AlertSource.MOBILE
    elif user.role in {UserRole.PARENT, UserRole.RELATIVE}:
        if payload.young_person_id is None:
            raise AlertError("Indiquez le jeune concerné", 403)
        link = _guardian_link(db, user, payload.young_person_id)
        if not link.can_trigger_alert:
            raise AlertError("Le jeune ne vous a pas autorisé à déclencher une alerte", 403)
        young = db.query(YoungPerson).filter(YoungPerson.id == payload.young_person_id).one()
        source = AlertSource.RELATIVE
    else:
        raise AlertError("Vous ne pouvez pas déclencher un SOS", 403)
    alert = _create_sos(db, young, payload, source=source, triggered_by_user_id=user.id)
    db.commit()
    alert = _load_alert(db, alert.id)
    return to_read(alert)


def trigger_iot_sos(db: Session, device_uid: str, device_secret: str, payload: SosCreate) -> AlertRead:
    tracker = authenticate_kit(db, device_uid, device_secret)
    young = tracker.young_person
    alert = _create_sos(
        db,
        young,
        payload,
        source=AlertSource.IOT,
        tracker=tracker,
        triggered_by_user_id=None,
    )
    db.commit()
    alert = _load_alert(db, alert.id)
    return to_read(alert)


def list_own(db: Session, user: User) -> list[AlertRead]:
    young = require_young(user)
    rows = (
        db.query(Alert)
        .options(joinedload(Alert.young_person))
        .filter(Alert.young_person_id == young.id)
        .order_by(Alert.triggered_at.desc())
        .limit(50)
        .all()
    )
    return [to_read(row) for row in rows]


def list_for_authority(db: Session, user: User) -> list[AlertRead]:
    if user.role != UserRole.AUTHORITY:
        raise AlertError("Réservé à l’autorité", 403)
    rows = (
        db.query(Alert)
        .options(joinedload(Alert.young_person))
        .order_by(Alert.triggered_at.desc())
        .limit(100)
        .all()
    )
    return [to_read(row) for row in rows]


def list_for_guardian(db: Session, user: User) -> list[AlertRead]:
    if user.role == UserRole.AUTHORITY:
        return list_for_authority(db, user)
    if user.role not in {UserRole.PARENT, UserRole.RELATIVE}:
        raise AlertError("Réservé au parent, au proche ou à l’autorité", 403)
    young_ids = [
        row[0]
        for row in (
            db.query(GuardianLink.young_person_id)
            .filter(GuardianLink.guardian_user_id == user.id, GuardianLink.status == GuardianLinkStatus.ACTIVE)
            .all()
        )
    ]
    if not young_ids:
        return []
    rows = (
        db.query(Alert)
        .options(joinedload(Alert.young_person))
        .filter(Alert.young_person_id.in_(young_ids))
        .order_by(Alert.triggered_at.desc())
        .limit(50)
        .all()
    )
    return [to_read(row) for row in rows]


def get_alert(db: Session, user: User, alert_id: UUID) -> AlertRead:
    alert = _load_alert(db, alert_id)
    _assert_can_view(db, user, alert)
    return to_read(alert)


def cancel_sos(db: Session, user: User, alert_id: UUID) -> AlertRead:
    alert = _load_alert(db, alert_id)
    young = _require_owner(user, alert)
    if alert.status not in OPEN_STATUSES:
        return to_read(alert)
    alert.status = AlertStatus.CANCELLED
    recipients = (
        db.query(GuardianLink)
        .filter(
            GuardianLink.young_person_id == young.id,
            GuardianLink.status == GuardianLinkStatus.ACTIVE,
            GuardianLink.can_receive_alerts.is_(True),
        )
        .all()
    )
    for link in recipients:
        _notify(
            db,
            recipient_id=link.guardian_user_id,
            alert=alert,
            young=young,
            title="SOS annulé",
            body=f"{young.display_name} a annulé le SOS. Ce n'était pas un kidnapping confirmé.",
        )
    db.commit()
    db.refresh(alert)
    return to_read(alert)


def acknowledge_sos(db: Session, user: User, alert_id: UUID) -> AlertRead:
    alert = _load_alert(db, alert_id)
    if user.role != UserRole.AUTHORITY:
        _guardian_link(db, user, alert.young_person_id)
    if alert.status not in OPEN_STATUSES:
        raise AlertError("Cette alerte n'est plus ouverte", 409)
    if alert.status == AlertStatus.ACKNOWLEDGED:
        return to_read(alert)
    alert.status = AlertStatus.ACKNOWLEDGED
    young = alert.young_person
    _notify(
        db,
        recipient_id=young.user_id,
        alert=alert,
        young=young,
        title="SOS pris en compte",
        body="Un contact de confiance a pris en compte votre SOS. Ce n'est pas un kidnapping confirmé.",
    )
    db.commit()
    db.refresh(alert)
    return to_read(alert)


def resolve_sos(db: Session, user: User, alert_id: UUID) -> AlertRead:
    alert = _load_alert(db, alert_id)
    if user.role == UserRole.YOUNG:
        young = _require_owner(user, alert)
    elif user.role in {UserRole.PARENT, UserRole.RELATIVE, UserRole.AUTHORITY}:
        if user.role != UserRole.AUTHORITY:
            _guardian_link(db, user, alert.young_person_id)
        young = alert.young_person
    else:
        raise AlertError("Réservé au jeune, au parent, au proche ou à l’autorité", 403)
    if alert.status == AlertStatus.RESOLVED:
        return to_read(alert)
    if alert.status not in OPEN_STATUSES:
        raise AlertError("Cette alerte n'est plus ouverte", 409)
    alert.status = AlertStatus.RESOLVED
    body = (
        f"Le SOS concernant {young.display_name} a été clos. "
        "Ce n'était pas un kidnapping confirmé. Un push FCM est tenté si un jeton appareil est enregistré."
    )
    _notify(
        db,
        recipient_id=young.user_id,
        alert=alert,
        young=young,
        title="SOS clos",
        body=body,
    )
    recipients = (
        db.query(GuardianLink)
        .filter(
            GuardianLink.young_person_id == young.id,
            GuardianLink.status == GuardianLinkStatus.ACTIVE,
            GuardianLink.can_receive_alerts.is_(True),
        )
        .all()
    )
    for link in recipients:
        _notify(
            db,
            recipient_id=link.guardian_user_id,
            alert=alert,
            young=young,
            title="SOS clos",
            body=body,
        )
    db.commit()
    db.refresh(alert)
    return to_read(alert)
