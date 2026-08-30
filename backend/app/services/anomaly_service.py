"""Alertes automatiques d'anomalie : règles métier explicables, pas de ML."""

from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from math import atan2, cos, degrees, radians, sin
from uuid import UUID

from sqlalchemy.orm import Session, selectinload

from app.core.enums import (
    AlertSeverity,
    GuardianLinkStatus,
    NotificationType,
    TrackerEventType,
)
from app.models.alert import AppNotification
from app.models.people import GuardianLink, YoungPerson
from app.models.tracker import TrackerEvent, TrackerLocation
from app.models.zones import SafetyZone
from app.services.geofence_service import (
    _aware,
    _implausible_jump,
    _membership,
    haversine_meters,
)
from app.services.zone_service import schedule_active_now

LOOKBACK = timedelta(hours=2)
COOLDOWN = timedelta(minutes=15)
STILL_RADIUS_M = 70.0
STOP_MIN_SECONDS = 20 * 60
STOP_LONG_SECONDS = 40 * 60
MOVE_BEFORE_M = 150.0
SIGNAL_GAP_SECONDS = 20 * 60
# Au-delà, c'est une donnée clairsemée (ex. deux points dans la journée), pas une perte.
SIGNAL_GAP_MAX_SECONDS = 90 * 60
HIGH_SPEED_M_S = 15.0
HEADING_TURN_DEG = 90.0
GEOFENCE_LINK_WINDOW = timedelta(minutes=10)
DISCLAIMER = (
    "Règles métier, pas de machine learning. Ce n'est pas un kidnapping confirmé."
)


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _iso(value: datetime | None) -> str | None:
    if value is None:
        return None
    return _aware(value).isoformat()


def _bearing(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    phi1, phi2 = radians(lat1), radians(lat2)
    d_lambda = radians(lon2 - lon1)
    x = sin(d_lambda) * cos(phi2)
    y = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(d_lambda)
    return (degrees(atan2(x, y)) + 360) % 360


def _heading_delta(a: float, b: float) -> float:
    delta = abs(a - b) % 360
    return min(delta, 360 - delta)


def _level_for(score: int) -> AlertSeverity:
    if score >= 8:
        return AlertSeverity.CRITICAL
    if score >= 5:
        return AlertSeverity.HIGH
    if score >= 3:
        return AlertSeverity.MEDIUM
    return AlertSeverity.LOW


def _recent_points(db: Session, young_id: UUID, since: datetime, until: datetime) -> list[TrackerLocation]:
    return (
        db.query(TrackerLocation)
        .filter(
            TrackerLocation.young_person_id == young_id,
            TrackerLocation.recorded_at >= since,
            TrackerLocation.recorded_at <= until,
        )
        .order_by(TrackerLocation.recorded_at.asc())
        .all()
    )


def _inside_active_safety(db: Session, young_id: UUID, point: TrackerLocation) -> str | None:
    """Nom de la zone de sécurité active qui contient le point, sinon None."""
    recorded = _aware(point.recorded_at)
    zones = (
        db.query(SafetyZone)
        .options(selectinload(SafetyZone.schedules))
        .filter(SafetyZone.young_person_id == young_id, SafetyZone.is_active.is_(True))
        .all()
    )
    for zone in zones:
        if zone.schedules and not schedule_active_now(zone.schedules, recorded):
            continue
        distance = haversine_meters(point.latitude, point.longitude, zone.latitude, zone.longitude)
        if _membership(distance, point.accuracy, zone.radius_meters, zone.accuracy_tolerance_meters) == "inside":
            return zone.name
    return None


def _recent_event(db: Session, young_id: UUID, event_type: TrackerEventType, since: datetime) -> TrackerEvent | None:
    return (
        db.query(TrackerEvent)
        .filter(
            TrackerEvent.young_person_id == young_id,
            TrackerEvent.event_type == event_type,
            TrackerEvent.recorded_at >= since,
        )
        .order_by(TrackerEvent.recorded_at.desc())
        .first()
    )


def _payload_dict(row: AppNotification) -> dict:
    if not row.payload:
        return {}
    try:
        data = json.loads(row.payload)
    except json.JSONDecodeError:
        return {}
    return data if isinstance(data, dict) else {}


def _in_cooldown(db: Session, young_id: UUID) -> bool:
    """Anti-spam horloge serveur. Ignore le saut GPS (source différente)."""
    since = _utcnow() - COOLDOWN
    rows = (
        db.query(AppNotification)
        .filter(
            AppNotification.notification_type == NotificationType.ANOMALY,
            AppNotification.created_at >= since,
        )
        .order_by(AppNotification.created_at.desc())
        .limit(40)
        .all()
    )
    for row in rows:
        data = _payload_dict(row)
        if data.get("source") != "anomaly_rules":
            continue
        if data.get("young_person_id") == str(young_id):
            return True
    return False


def _still_cluster(points: list[TrackerLocation]) -> list[TrackerLocation]:
    if not points:
        return []
    latest = points[-1]
    cluster = [latest]
    for older in reversed(points[:-1]):
        dist = haversine_meters(older.latitude, older.longitude, latest.latitude, latest.longitude)
        if dist <= STILL_RADIUS_M:
            cluster.append(older)
        else:
            break
    cluster.reverse()
    return cluster


def _append_stop_factors(factors: list[dict], points: list[TrackerLocation], safety_name: str | None) -> None:
    cluster = _still_cluster(points)
    if len(cluster) < 2:
        return
    dwell = (_aware(cluster[-1].recorded_at) - _aware(cluster[0].recorded_at)).total_seconds()
    moved_before = False
    if len(points) > len(cluster):
        first = points[0]
        moved_before = (
            haversine_meters(first.latitude, first.longitude, cluster[0].latitude, cluster[0].longitude)
            >= MOVE_BEFORE_M
        )
    if safety_name is not None or dwell < STOP_MIN_SECONDS:
        return
    minutes = int(dwell // 60)
    points_given = 4 if dwell >= STOP_LONG_SECONDS else 3
    factors.append(
        {
            "code": "ARRET_PROLONGE",
            "points": points_given,
            "label": (
                f"Arrêt prolongé inhabituel (~{minutes} min) hors zone de sécurité. "
                "Ce n'est pas un kidnapping."
            ),
            "dwell_seconds": int(dwell),
        }
    )
    if moved_before and dwell >= 15 * 60:
        factors.append(
            {
                "code": "PERTE_MOUVEMENT",
                "points": 2,
                "label": (
                    "Perte de mouvement après un déplacement enregistré. "
                    "Règle de distance, pas une preuve."
                ),
            }
        )


def _collect_factors(
    db: Session,
    young: YoungPerson,
    point: TrackerLocation,
    previous: TrackerLocation | None,
) -> list[dict]:
    """Indicateurs explicables. Pas un score ML, pas un kidnapping."""
    now = _aware(point.recorded_at)
    since = now - LOOKBACK
    points = _recent_points(db, young.id, since, now)
    factors: list[dict] = []
    safety_name = _inside_active_safety(db, young.id, point)
    _append_stop_factors(factors, points, safety_name)

    if previous is not None:
        gap = (_aware(point.recorded_at) - _aware(previous.recorded_at)).total_seconds()
        if SIGNAL_GAP_SECONDS <= gap <= SIGNAL_GAP_MAX_SECONDS:
            factors.append(
                {
                    "code": "PERTE_SIGNAL",
                    "points": 3,
                    "label": (
                        f"Trou de communication de {int(gap // 60)} min entre deux positions. "
                        "Pas la position actuelle."
                    ),
                    "gap_seconds": int(gap),
                }
            )

    if len(points) >= 3:
        a, b, c = points[-3], points[-2], points[-1]
        dt1 = (_aware(b.recorded_at) - _aware(a.recorded_at)).total_seconds()
        dt2 = (_aware(c.recorded_at) - _aware(b.recorded_at)).total_seconds()
        if 1 <= dt1 <= 600 and 1 <= dt2 <= 600:
            heading1 = _bearing(a.latitude, a.longitude, b.latitude, b.longitude)
            heading2 = _bearing(b.latitude, b.longitude, c.latitude, c.longitude)
            turn = _heading_delta(heading1, heading2)
            if turn > HEADING_TURN_DEG:
                factors.append(
                    {
                        "code": "TRAJET_INHABITUEL",
                        "points": 3,
                        "label": (
                            f"Changement de cap enregistré de {turn:.0f}° sur les derniers points "
                            "(règle trajectoire, pas une destination prédite)."
                        ),
                        "heading_delta_degrees": round(turn, 1),
                    }
                )

    if previous is not None:
        dt = (_aware(point.recorded_at) - _aware(previous.recorded_at)).total_seconds()
        if dt >= 1:
            dist = haversine_meters(previous.latitude, previous.longitude, point.latitude, point.longitude)
            speed = point.speed if point.speed is not None else dist / dt
            if HIGH_SPEED_M_S <= speed < 70.0:
                factors.append(
                    {
                        "code": "HIGH_SPEED",
                        "points": 3,
                        "label": (
                            "Dernier déplacement enregistré à vitesse élevée "
                            "(ordre de grandeur, pas une preuve de véhicule)."
                        ),
                        "speed_mps": round(float(speed), 2),
                    }
                )

    exit_event = _recent_event(db, young.id, TrackerEventType.GEOFENCE_EXIT, now - GEOFENCE_LINK_WINDOW)
    if exit_event is not None:
        zone_name = None
        if exit_event.payload:
            try:
                extra = json.loads(exit_event.payload)
                if isinstance(extra, dict):
                    zone_name = extra.get("zone_name")
            except json.JSONDecodeError:
                zone_name = None
        where = f" « {zone_name} »" if zone_name else ""
        factors.append(
            {
                "code": "GEOFENCE_EXIT",
                "points": 2,
                "label": (
                    f"Une sortie de zone de sécurité{where} a déjà été signalée. "
                    "Pas une deuxième alerte de zone, pas un kidnapping."
                ),
                "linked": True,
            }
        )

    lost = _recent_event(db, young.id, TrackerEventType.SIGNAL_LOST, now - LOOKBACK)
    if lost is not None and not any(item["code"] == "PERTE_SIGNAL" for item in factors):
        factors.append(
            {
                "code": "SIGNAL_LOST_EVENT",
                "points": 2,
                "label": "Le kit a signalé une perte de connexion récemment. Pas la position actuelle.",
                "linked": True,
            }
        )
    return factors


def _notify_anomaly(
    db: Session,
    young: YoungPerson,
    point: TrackerLocation,
    *,
    level: AlertSeverity,
    factors: list[dict],
    score: int,
) -> None:
    lines = [item["label"] for item in factors]
    body = (
        f"Anomalie détectée ({level.value}) concernant {young.display_name}.\n"
        + "\n".join(f"- {line}" for line in lines)
        + f"\n{DISCLAIMER}"
    )
    payload = json.dumps(
        {
            "young_person_id": str(young.id),
            "young_display_name": young.display_name,
            "event_type": TrackerEventType.ANOMALY.value,
            "source": "anomaly_rules",
            "method": "rules",
            "trained_model": False,
            "severity": level.value,
            "score": score,
            "latitude": point.latitude,
            "longitude": point.longitude,
            "recorded_at": _iso(point.recorded_at),
            "factors": factors,
            "disclaimer": DISCLAIMER,
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
                title="Anomalie détectée",
                body=body,
                payload=payload,
            )
        )


def evaluate_anomalies(
    db: Session,
    young: YoungPerson,
    point: TrackerLocation,
    previous: TrackerLocation | None,
) -> None:
    """Évalue le point GPS fraîchement ingéré. Règles, pas un Random Forest."""
    if previous is None:
        return
    if _implausible_jump(previous, point):
        return
    factors = _collect_factors(db, young, point, previous)
    own = [item for item in factors if not item.get("linked")]
    if not own:
        return
    score = sum(int(item["points"]) for item in factors)
    level = _level_for(score)
    if level == AlertSeverity.LOW:
        return
    if _in_cooldown(db, young.id):
        return
    db.add(
        TrackerEvent(
            tracker_id=point.tracker_id,
            young_person_id=young.id,
            event_type=TrackerEventType.ANOMALY,
            recorded_at=_aware(point.recorded_at),
            latitude=point.latitude,
            longitude=point.longitude,
            payload=json.dumps(
                {
                    "source": "anomaly_rules",
                    "method": "rules",
                    "severity": level.value,
                    "score": score,
                    "codes": [item["code"] for item in factors],
                },
                ensure_ascii=False,
            ),
        )
    )
    _notify_anomaly(db, young, point, level=level, factors=factors, score=score)



