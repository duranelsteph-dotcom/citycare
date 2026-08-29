from __future__ import annotations

import json
from datetime import datetime, timezone
from math import atan2, cos, radians, sin, sqrt
from uuid import UUID

from sqlalchemy.orm import Session, selectinload

from app.core.enums import GuardianLinkStatus, NotificationType, TrackerEventType
from app.models.alert import AppNotification
from app.models.people import GuardianLink, YoungPerson
from app.models.tracker import TrackerEvent, TrackerLocation
from app.models.zones import GeofenceOccupancy, SafetyZone
from app.services.zone_service import schedule_active_now

EARTH_RADIUS_M = 6_371_000
# ~250 km/h : un saut GPS aberrant n'est pas une sortie de zone.
MAX_PLAUSIBLE_SPEED_M_S = 70.0


def haversine_meters(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    phi1, phi2 = radians(lat1), radians(lat2)
    d_phi = radians(lat2 - lat1)
    d_lambda = radians(lon2 - lon1)
    a = sin(d_phi / 2) ** 2 + cos(phi1) * cos(phi2) * sin(d_lambda / 2) ** 2
    return 2 * EARTH_RADIUS_M * atan2(sqrt(a), sqrt(max(0.0, 1 - a)))


def _aware(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value


def _membership(distance: float, accuracy: float | None, radius: float, tolerance: float) -> str:
    """inside | outside | unknown — l'incertitude GPS ne doit pas décider seule."""
    blob = accuracy if accuracy is not None and accuracy >= 0 else 0.0
    limit = radius + tolerance
    if blob > limit:
        return "unknown"
    if distance + blob / 2 <= limit:
        return "inside"
    if distance - blob / 2 > limit:
        return "outside"
    return "unknown"


def _implausible_jump(previous: TrackerLocation | None, current: TrackerLocation) -> bool:
    if previous is None:
        return False
    dt = (_aware(current.recorded_at) - _aware(previous.recorded_at)).total_seconds()
    if dt <= 0 or dt > 3600:
        return False
    distance = haversine_meters(previous.latitude, previous.longitude, current.latitude, current.longitude)
    return distance / dt > MAX_PLAUSIBLE_SPEED_M_S


def _occupancy(db: Session, young_id: UUID, zone_id: UUID) -> GeofenceOccupancy:
    row = (
        db.query(GeofenceOccupancy)
        .filter(GeofenceOccupancy.young_person_id == young_id, GeofenceOccupancy.zone_id == zone_id)
        .one_or_none()
    )
    if row is None:
        row = GeofenceOccupancy(young_person_id=young_id, zone_id=zone_id)
        db.add(row)
        db.flush()
    return row


def _notify_exit(db: Session, young: YoungPerson, zone: SafetyZone, point: TrackerLocation) -> None:
    local = _aware(point.recorded_at).astimezone()
    clock = local.strftime("%H:%M")
    payload = json.dumps(
        {
            "young_person_id": str(young.id),
            "young_display_name": young.display_name,
            "zone_id": str(zone.id),
            "zone_name": zone.name,
            "event_type": TrackerEventType.GEOFENCE_EXIT.value,
            "latitude": point.latitude,
            "longitude": point.longitude,
        },
        ensure_ascii=False,
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
        db.add(
            AppNotification(
                recipient_user_id=link.guardian_user_id,
                notification_type=NotificationType.GEOFENCE_EXIT,
                title="Sortie de zone",
                body=(
                    f"⚠️ {young.display_name} a quitté la zone « {zone.name} » à {clock}. "
                    "Ceci n'est pas un kidnapping."
                ),
                payload=payload,
            )
        )


def evaluate_geofences(
    db: Session,
    young: YoungPerson,
    point: TrackerLocation,
    previous: TrackerLocation | None,
) -> None:
    """Évalue les zones actives. Produit GEOFENCE_EXIT, jamais une alerte kidnapping."""
    if _implausible_jump(previous, point):
        _notify_anomaly(db, young, point, previous)
        return
    recorded = _aware(point.recorded_at)
    zones = (
        db.query(SafetyZone)
        .options(selectinload(SafetyZone.schedules))
        .filter(SafetyZone.young_person_id == young.id, SafetyZone.is_active.is_(True))
        .all()
    )
    for zone in zones:
        if not schedule_active_now(zone.schedules, recorded):
            continue
        distance = haversine_meters(point.latitude, point.longitude, zone.latitude, zone.longitude)
        state = _membership(distance, point.accuracy, zone.radius_meters, zone.accuracy_tolerance_meters)
        if state == "unknown":
            continue
        occupancy = _occupancy(db, young.id, zone.id)
        if state == "inside":
            was_outside = occupancy.observed_inside and not occupancy.is_inside
            occupancy.observed_inside = True
            occupancy.is_inside = True
            occupancy.candidate_exit_at = None
            if was_outside:
                db.add(
                    TrackerEvent(
                        tracker_id=point.tracker_id,
                        young_person_id=young.id,
                        event_type=TrackerEventType.GEOFENCE_ENTER,
                        recorded_at=recorded,
                        latitude=point.latitude,
                        longitude=point.longitude,
                        payload=json.dumps({"zone_id": str(zone.id), "zone_name": zone.name}, ensure_ascii=False),
                    )
                )
            continue
        if not occupancy.observed_inside:
            occupancy.is_inside = False
            continue
        if not occupancy.is_inside:
            continue
        if occupancy.candidate_exit_at is None:
            occupancy.candidate_exit_at = recorded
        started = _aware(occupancy.candidate_exit_at)
        elapsed = (recorded - started).total_seconds()
        if elapsed < zone.min_exit_duration_seconds:
            continue
        occupancy.is_inside = False
        occupancy.candidate_exit_at = None
        db.add(
            TrackerEvent(
                tracker_id=point.tracker_id,
                young_person_id=young.id,
                event_type=TrackerEventType.GEOFENCE_EXIT,
                recorded_at=recorded,
                latitude=point.latitude,
                longitude=point.longitude,
                payload=json.dumps(
                    {
                        "zone_id": str(zone.id),
                        "zone_name": zone.name,
                        "distance_meters": round(distance, 1),
                    },
                    ensure_ascii=False,
                ),
            )
        )
        _notify_exit(db, young, zone, point)


def _notify_anomaly(
    db: Session,
    young: YoungPerson,
    point: TrackerLocation,
    previous: TrackerLocation | None,
) -> None:
    """Saut GPS trop rapide : ce n'est pas une sortie de zone, pas un kidnapping."""
    payload = json.dumps(
        {
            "young_person_id": str(young.id),
            "young_display_name": young.display_name,
            "event_type": "GPS_JUMP",
            "latitude": point.latitude,
            "longitude": point.longitude,
            "previous_latitude": previous.latitude if previous is not None else None,
            "previous_longitude": previous.longitude if previous is not None else None,
        },
        ensure_ascii=False,
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
        db.add(
            AppNotification(
                recipient_user_id=link.guardian_user_id,
                notification_type=NotificationType.ANOMALY,
                title="Position GPS incohérente",
                body=(
                    f"Une position transmise pour {young.display_name} a été ignorée "
                    "(saut trop rapide pour être crédible). "
                    "Ce n'est pas une sortie de zone, pas un kidnapping."
                ),
                payload=payload,
            )
        )

