import json
from datetime import datetime, timedelta, timezone

from sqlalchemy.orm import Session, joinedload

from app.core.enums import (
    GuardianLinkStatus,
    LocationSource,
    NotificationType,
    TrackerEventType,
    TrackerStatus,
)
from app.models.alert import AppNotification
from app.models.people import GuardianLink, YoungPerson
from app.models.tracker import GPSTracker, TrackerEvent
from app.schemas.entities import TrackerEventRead
from app.schemas.tracker import IotEventRequest, IotEventResult, IotLocationRequest
from app.services.alert_service import AlertError, authenticate_kit
from app.services.location_service import ingest_point, to_read as location_to_read
from app.services.tracker_service import to_read as tracker_to_read

LOW_BATTERY_THRESHOLD = 15

REPORTABLE_EVENTS = {
    TrackerEventType.SIGNAL_LOST,
    TrackerEventType.DEVICE_REMOVED,
    TrackerEventType.LOW_BATTERY,
    TrackerEventType.SIGNAL_RESTORED,
}

EVENT_STATUS = {
    TrackerEventType.SIGNAL_LOST: TrackerStatus.SIGNAL_LOST,
    TrackerEventType.DEVICE_REMOVED: TrackerStatus.REMOVED,
    TrackerEventType.LOW_BATTERY: TrackerStatus.LOW_BATTERY,
    TrackerEventType.SIGNAL_RESTORED: TrackerStatus.ACTIVE,
}

EVENT_TITLES = {
    TrackerEventType.SIGNAL_LOST: "Connexion kit perdue",
    TrackerEventType.DEVICE_REMOVED: "Kit retiré",
    TrackerEventType.LOW_BATTERY: "Batterie kit faible",
    TrackerEventType.SIGNAL_RESTORED: "Connexion kit rétablie",
}

EVENT_NOTIFY_TYPE = {
    TrackerEventType.SIGNAL_LOST: NotificationType.SIGNAL_LOST,
    TrackerEventType.DEVICE_REMOVED: NotificationType.DEVICE_REMOVED,
    TrackerEventType.LOW_BATTERY: NotificationType.LOW_BATTERY,
    TrackerEventType.SIGNAL_RESTORED: NotificationType.SIGNAL_LOST,
}


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _aware(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value


def _known_clock(value: datetime | None) -> str:
    if value is None:
        return "inconnue"
    local = _aware(value).astimezone()
    return local.strftime("%H:%M")


def _event_body(event_type: TrackerEventType, tracker: GPSTracker) -> str:
    clock = _known_clock(tracker.last_seen_at)
    battery = "inconnue" if tracker.battery_level is None else f"{tracker.battery_level} %"
    if event_type == TrackerEventType.SIGNAL_LOST:
        return (
            f"Connexion avec le kit perdue. Dernière position connue : {clock}. "
            "Dernière communication connue — pas la position actuelle, pas un suivi en direct. "
            "Ce n'est pas un kidnapping confirmé."
        )
    if event_type == TrackerEventType.DEVICE_REMOVED:
        return (
            f"Le kit a signalé un retrait. Dernière communication : {clock}. "
            "Position et heure enregistrées — pas un suivi en direct. "
            "Ce n'est pas un kidnapping confirmé."
        )
    if event_type == TrackerEventType.LOW_BATTERY:
        return (
            f"Dernière batterie connue du kit : {battery} — pas la batterie actuelle. "
            f"Dernière communication : {clock}. Ce n'est pas un kidnapping confirmé."
        )
    return (
        f"Le kit a de nouveau communiqué à {clock}. Dernière communication connue — "
        "pas un suivi en direct. Ce n'est pas un kidnapping confirmé."
    )


def _apply_tracker_fix(
    tracker: GPSTracker,
    *,
    recorded: datetime,
    latitude: float | None,
    longitude: float | None,
    battery_level: int | None,
    signal_strength: int | None,
) -> None:
    tracker.last_seen_at = recorded
    if latitude is not None and longitude is not None:
        tracker.last_latitude = latitude
        tracker.last_longitude = longitude
    if battery_level is not None:
        tracker.battery_level = battery_level
    if signal_strength is not None:
        tracker.signal_strength = signal_strength


def _notify_kit(
    db: Session,
    young: YoungPerson,
    tracker: GPSTracker,
    *,
    notification_type: NotificationType,
    title: str,
    body: str,
    event_type: TrackerEventType,
    latitude: float | None,
    longitude: float | None,
) -> None:
    payload = json.dumps(
        {
            "young_person_id": str(young.id),
            "young_display_name": young.display_name,
            "tracker_id": str(tracker.id),
            "event_type": event_type.value,
            "latitude": latitude,
            "longitude": longitude,
            "last_seen_at": tracker.last_seen_at.isoformat() if tracker.last_seen_at else None,
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
    for recipient_id in recipients:
        prefix = "" if recipient_id == young.user_id else f"{young.display_name} : "
        db.add(
            AppNotification(
                recipient_user_id=recipient_id,
                notification_type=notification_type,
                title=title,
                body=prefix + body,
                payload=payload,
            )
        )


def _maybe_low_battery(db: Session, young: YoungPerson, tracker: GPSTracker, battery: int | None) -> None:
    if battery is None:
        return
    if battery > LOW_BATTERY_THRESHOLD:
        if tracker.status == TrackerStatus.LOW_BATTERY:
            tracker.status = TrackerStatus.ACTIVE
        return
    if tracker.status == TrackerStatus.LOW_BATTERY:
        return
    tracker.status = TrackerStatus.LOW_BATTERY
    db.add(
        TrackerEvent(
            tracker_id=tracker.id,
            young_person_id=young.id,
            event_type=TrackerEventType.LOW_BATTERY,
            recorded_at=tracker.last_seen_at or _utcnow(),
            latitude=tracker.last_latitude,
            longitude=tracker.last_longitude,
            payload=json.dumps({"battery_level": battery}, ensure_ascii=False),
        )
    )
    kind, title, body = (
        EVENT_NOTIFY_TYPE[TrackerEventType.LOW_BATTERY],
        EVENT_TITLES[TrackerEventType.LOW_BATTERY],
        _event_body(TrackerEventType.LOW_BATTERY, tracker),
    )
    _notify_kit(
        db,
        young,
        tracker,
        notification_type=kind,
        title=title,
        body=body,
        event_type=TrackerEventType.LOW_BATTERY,
        latitude=tracker.last_latitude,
        longitude=tracker.last_longitude,
    )


def record_kit_location(db: Session, payload: IotLocationRequest):
    tracker = authenticate_kit(db, payload.device_uid, payload.device_secret)
    young = tracker.young_person
    was_lost = tracker.status == TrackerStatus.SIGNAL_LOST
    point = ingest_point(
        db,
        young,
        payload,
        source=LocationSource.IOT,
        tracker=tracker,
        signal_strength=payload.signal_strength,
    )
    _apply_tracker_fix(
        tracker,
        recorded=point.recorded_at,
        latitude=point.latitude,
        longitude=point.longitude,
        battery_level=payload.battery_level,
        signal_strength=payload.signal_strength,
    )
    if was_lost:
        tracker.status = TrackerStatus.ACTIVE
        db.add(
            TrackerEvent(
                tracker_id=tracker.id,
                young_person_id=young.id,
                event_type=TrackerEventType.SIGNAL_RESTORED,
                recorded_at=point.recorded_at,
                latitude=point.latitude,
                longitude=point.longitude,
                payload=json.dumps({"via": "location"}, ensure_ascii=False),
            )
        )
        kind, title, body = (
            EVENT_NOTIFY_TYPE[TrackerEventType.SIGNAL_RESTORED],
            EVENT_TITLES[TrackerEventType.SIGNAL_RESTORED],
            _event_body(TrackerEventType.SIGNAL_RESTORED, tracker),
        )
        _notify_kit(
            db,
            young,
            tracker,
            notification_type=kind,
            title=title,
            body=body,
            event_type=TrackerEventType.SIGNAL_RESTORED,
            latitude=point.latitude,
            longitude=point.longitude,
        )
    elif tracker.status == TrackerStatus.REMOVED:
        tracker.status = TrackerStatus.ACTIVE
    _maybe_low_battery(db, young, tracker, payload.battery_level)
    db.commit()
    db.refresh(point)
    return location_to_read(point)


def report_kit_event(db: Session, payload: IotEventRequest) -> IotEventResult:
    if payload.event_type not in REPORTABLE_EVENTS:
        raise AlertError("Événement kit non pris en charge", 422)
    if (payload.latitude is None) != (payload.longitude is None):
        raise AlertError("latitude et longitude vont ensemble", 422)
    tracker = authenticate_kit(db, payload.device_uid, payload.device_secret)
    young = tracker.young_person
    recorded = _aware(payload.recorded_at or _utcnow())
    if recorded > _utcnow() + timedelta(minutes=2):
        recorded = _utcnow()
    target_status = EVENT_STATUS[payload.event_type]
    already = tracker.status == target_status
    _apply_tracker_fix(
        tracker,
        recorded=recorded,
        latitude=payload.latitude,
        longitude=payload.longitude,
        battery_level=payload.battery_level,
        signal_strength=None,
    )
    event = TrackerEvent(
        tracker_id=tracker.id,
        young_person_id=young.id,
        event_type=payload.event_type,
        recorded_at=recorded,
        latitude=payload.latitude if payload.latitude is not None else tracker.last_latitude,
        longitude=payload.longitude if payload.longitude is not None else tracker.last_longitude,
        payload=json.dumps({"duplicate": already}, ensure_ascii=False),
    )
    db.add(event)
    if not already:
        tracker.status = target_status
        kind = EVENT_NOTIFY_TYPE[payload.event_type]
        title = EVENT_TITLES[payload.event_type]
        body = _event_body(payload.event_type, tracker)
        _notify_kit(
            db,
            young,
            tracker,
            notification_type=kind,
            title=title,
            body=body,
            event_type=payload.event_type,
            latitude=event.latitude,
            longitude=event.longitude,
        )
    db.commit()
    db.refresh(event)
    tracker = (
        db.query(GPSTracker)
        .options(joinedload(GPSTracker.young_person))
        .filter(GPSTracker.id == tracker.id)
        .one()
    )
    return IotEventResult(tracker=tracker_to_read(tracker), event=TrackerEventRead.model_validate(event))


def kit_config(db: Session, device_uid: str, device_secret: str):
    from app.schemas.tracker import IotConfigRead
    from app.services.tracking_mode import effective_mode, has_open_sos, interval_for

    tracker = authenticate_kit(db, device_uid, device_secret)
    young_id = tracker.young_person_id
    mode = effective_mode(db, young_id, tracker)
    return IotConfigRead(
        tracking_mode=tracker.tracking_mode,
        effective_mode=mode,
        suggested_interval_seconds=interval_for(mode),
        status=tracker.status,
        open_sos=has_open_sos(db, young_id),
        message=(
            "Intervalle conseillé pour le prochain envoi. "
            "Ce n'est pas un GPS continu. Une position ancienne n'est pas actuelle."
        ),
    )
