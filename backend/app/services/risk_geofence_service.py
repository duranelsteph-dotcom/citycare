from __future__ import annotations

import json
from uuid import UUID

from sqlalchemy.orm import Session

from app.core.enums import GuardianLinkStatus, NotificationType, TrackerEventType
from app.models.alert import AppNotification
from app.models.people import GuardianLink, YoungPerson
from app.models.tracker import TrackerEvent, TrackerLocation
from app.models.zones import RiskZone, RiskZoneOccupancy
from app.services.geofence_service import _aware, _implausible_jump, _membership, haversine_meters
from app.services.risk_zone_service import hour_window_active

RISK_GPS_TOLERANCE_M = 40.0


def _occupancy(db: Session, young_id: UUID, zone_id: UUID) -> RiskZoneOccupancy:
    row = (
        db.query(RiskZoneOccupancy)
        .filter(RiskZoneOccupancy.young_person_id == young_id, RiskZoneOccupancy.risk_zone_id == zone_id)
        .one_or_none()
    )
    if row is None:
        row = RiskZoneOccupancy(young_person_id=young_id, risk_zone_id=zone_id)
        db.add(row)
        db.flush()
    return row


def _notify_enter(db: Session, young: YoungPerson, zone: RiskZone, point: TrackerLocation) -> None:
    local = _aware(point.recorded_at).astimezone()
    clock = local.strftime("%H:%M")
    payload = json.dumps(
        {
            "young_person_id": str(young.id),
            "young_display_name": young.display_name,
            "zone_id": str(zone.id),
            "zone_name": zone.name,
            "event_type": TrackerEventType.RISK_ZONE_ENTER.value,
            "latitude": point.latitude,
            "longitude": point.longitude,
        },
        ensure_ascii=False,
    )
    db.add(
        AppNotification(
            recipient_user_id=young.user_id,
            notification_type=NotificationType.RISK_ZONE_ENTER,
            title="Zone à risque",
            body=(
                f"⚠️ Vous entrez dans une zone à risque « {zone.name} » à {clock}. "
                "Restez vigilant. Ceci n'est pas un kidnapping."
            ),
            payload=payload,
        )
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
                notification_type=NotificationType.RISK_ZONE_ENTER,
                title="Zone à risque",
                body=(
                    f"⚠️ {young.display_name} se trouve dans la zone à risque « {zone.name} » à {clock}. "
                    "Ceci n'est pas un kidnapping."
                ),
                payload=payload,
            )
        )


def evaluate_risk_zones(
    db: Session,
    young: YoungPerson,
    point: TrackerLocation,
    previous: TrackerLocation | None,
) -> None:
    """Prévention : entrée dans une zone à risque. Pas un SOS, pas un kidnapping."""
    if _implausible_jump(previous, point):
        return
    recorded = _aware(point.recorded_at)
    zones = db.query(RiskZone).filter(RiskZone.is_active.is_(True)).all()
    for zone in zones:
        distance = haversine_meters(point.latitude, point.longitude, zone.latitude, zone.longitude)
        state = _membership(distance, point.accuracy, zone.radius_meters, RISK_GPS_TOLERANCE_M)
        if state == "unknown":
            continue
        occupancy = _occupancy(db, young.id, zone.id)
        in_hours = hour_window_active(zone.typical_start_hour, zone.typical_end_hour, recorded)
        if state == "outside":
            occupancy.is_inside = False
            continue
        was_inside = occupancy.is_inside
        occupancy.is_inside = True
        if was_inside or not in_hours:
            continue
        db.add(
            TrackerEvent(
                tracker_id=point.tracker_id,
                young_person_id=young.id,
                event_type=TrackerEventType.RISK_ZONE_ENTER,
                recorded_at=recorded,
                latitude=point.latitude,
                longitude=point.longitude,
                payload=json.dumps(
                    {
                        "zone_id": str(zone.id),
                        "zone_name": zone.name,
                        "incident_count": zone.incident_count,
                        "distance_meters": round(distance, 1),
                    },
                    ensure_ascii=False,
                ),
            )
        )
        _notify_enter(db, young, zone, point)
