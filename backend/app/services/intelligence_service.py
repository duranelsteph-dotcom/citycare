from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from math import atan2, cos, degrees, radians, sin
from uuid import UUID

from sqlalchemy.orm import Session, selectinload

from app.core.enums import (
    AlertStatus,
    CaseStatus,
    GuardianLinkStatus,
    NotificationType,
    RiskLevel,
    TrackerEventType,
    TrackerStatus,
)
from app.models.alert import Alert, AppNotification
from app.models.people import GuardianLink, YoungPerson
from app.models.search import MissingPersonCase, RiskAnalysis
from app.models.tracker import GPSTracker, TrackerEvent, TrackerLocation
from app.models.user import User
from app.models.zones import RiskZone, SafetyZone
from app.schemas.entities import SearchIntelligenceRead
from app.services.consistency_service import refresh_case_consistencies
from app.services.geofence_service import _aware, _membership, haversine_meters
from app.services.risk_zone_service import hour_window_active
from app.services.search_zone_service import replace_priority_zones, upsert_probable_zone
from app.services.trajectory_service import reconstruct_window
from app.services.zone_service import schedule_active_now

DISCLAIMER = (
    "Aide à la décision par règles métier. Aucun modèle de machine learning n'a été entraîné. "
    "Ce n'est pas un kidnapping confirmé. Ce n'est pas la position actuelle. "
    "Une zone de recherche estimée ou prioritaire, si elle est affichée, n'est pas la position réelle."
)
OPEN_SOS = {
    AlertStatus.CREATED,
    AlertStatus.ACTIVE,
    AlertStatus.ACKNOWLEDGED,
    AlertStatus.IN_PROGRESS,
}
OPEN_CASE = {CaseStatus.OPEN, CaseStatus.ACKNOWLEDGED, CaseStatus.SEARCHING, CaseStatus.INFO}
WALKING_M_S = 1.2
RANGE_CAP_M = 50_000.0
LOOKBACK = timedelta(hours=6)


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


def _latest_point(db: Session, young_id: UUID) -> TrackerLocation | None:
    return (
        db.query(TrackerLocation)
        .filter(TrackerLocation.young_person_id == young_id)
        .order_by(TrackerLocation.recorded_at.desc())
        .first()
    )


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


def _open_sos(db: Session, young_id: UUID) -> Alert | None:
    return (
        db.query(Alert)
        .filter(Alert.young_person_id == young_id, Alert.status.in_(OPEN_SOS))
        .order_by(Alert.triggered_at.desc())
        .first()
    )


def to_read(row: RiskAnalysis) -> SearchIntelligenceRead:
    factors: dict = {}
    if row.factors:
        try:
            parsed = json.loads(row.factors)
            if isinstance(parsed, dict):
                factors = parsed
        except json.JSONDecodeError:
            factors = {}
    return SearchIntelligenceRead(
        id=row.id,
        case_id=row.case_id,
        young_person_id=row.young_person_id,
        risk_level=row.risk_level,
        explanation=row.explanation,
        method=row.method,
        created_at=row.created_at,
        updated_at=row.updated_at,
        factors=factors,
        has_search_zone=bool(factors.get("has_search_zone")),
        disclaimer=DISCLAIMER,
    )


def _level_for(score: int) -> RiskLevel:
    if score >= 6:
        return RiskLevel.HIGH
    if score >= 3:
        return RiskLevel.MEDIUM
    return RiskLevel.LOW


def attach_analysis(db: Session, case: MissingPersonCase, young: YoungPerson, *, notify: bool) -> RiskAnalysis:
    now = _utcnow()
    since_events = now - LOOKBACK
    until = now if case.status in OPEN_CASE else _aware(case.updated_at)
    traj_since = min(_aware(case.occurred_at) - LOOKBACK, since_events)
    trajectory = reconstruct_window(db, young.id, since=traj_since, until=until, limit=200)
    latest = _latest_point(db, young.id)
    last_lat = latest.latitude if latest else case.last_known_latitude
    last_lng = latest.longitude if latest else case.last_known_longitude
    last_at = _aware(latest.recorded_at) if latest else (_aware(case.last_known_at) if case.last_known_at else None)
    age_seconds = int((now - last_at).total_seconds()) if last_at else None

    contributors: list[dict] = []
    score = 0

    if last_at is None or last_lat is None or last_lng is None:
        contributors.append(
            {
                "code": "NO_FIX",
                "points": 0,
                "label": "Aucune position enregistrée. Impossible d'estimer un déplacement.",
            }
        )
    elif age_seconds is not None and age_seconds >= 7200:
        contributors.append({"code": "STALE_POSITION", "points": 3, "label": "Dernière position connue il y a plus de 2 h."})
        score += 3
    elif age_seconds is not None and age_seconds >= 1800:
        contributors.append({"code": "STALE_POSITION", "points": 2, "label": "Dernière position connue il y a plus de 30 min."})
        score += 2
    elif age_seconds is not None and age_seconds >= 300:
        contributors.append(
            {"code": "STALE_POSITION", "points": 1, "label": "Dernière position connue a plus de 5 min — pas actuelle."}
        )
        score += 1

    exit_event = _recent_event(db, young.id, TrackerEventType.GEOFENCE_EXIT, since_events)
    if exit_event is not None:
        contributors.append(
            {
                "code": "GEOFENCE_EXIT",
                "points": 2,
                "label": "Une sortie de zone de sécurité a été enregistrée. Ce n'est pas un kidnapping.",
            }
        )
        score += 2
    lost = _recent_event(db, young.id, TrackerEventType.SIGNAL_LOST, since_events)
    if lost is not None:
        contributors.append({"code": "SIGNAL_LOST", "points": 3, "label": "Le kit a signalé une perte de connexion récemment."})
        score += 3
    removed = _recent_event(db, young.id, TrackerEventType.DEVICE_REMOVED, since_events)
    if removed is not None:
        contributors.append({"code": "DEVICE_REMOVED", "points": 3, "label": "Un retrait du kit a été enregistré récemment."})
        score += 3
    sos = _open_sos(db, young.id)
    if sos is not None:
        contributors.append({"code": "OPEN_SOS", "points": 2, "label": "Un SOS est ouvert. Ce n'est pas un kidnapping confirmé."})
        score += 2
    if trajectory.gap_count:
        contributors.append(
            {
                "code": "TRAJECTORY_GAPS",
                "points": 1,
                "label": f"{trajectory.gap_count} trou(s) dans la trajectoire reconstruite — pas interpolé.",
            }
        )
        score += 1

    last_movement = None
    points = trajectory.points
    if len(points) >= 2:
        prev, last = points[-2], points[-1]
        dt = (_aware(last.recorded_at) - _aware(prev.recorded_at)).total_seconds()
        dist = haversine_meters(prev.latitude, prev.longitude, last.latitude, last.longitude)
        speed = last.speed if last.speed is not None else (dist / dt if dt > 1 else None)
        heading = last.heading if last.heading is not None else _bearing(
            prev.latitude, prev.longitude, last.latitude, last.longitude
        )
        last_movement = {
            "from_latitude": prev.latitude,
            "from_longitude": prev.longitude,
            "to_latitude": last.latitude,
            "to_longitude": last.longitude,
            "distance_meters": round(dist, 1),
            "speed_mps": round(speed, 2) if speed is not None else None,
            "heading_degrees": round(heading, 1) if heading is not None else None,
            "from_at": _iso(prev.recorded_at),
            "to_at": _iso(last.recorded_at),
        }
        if speed is not None and speed >= 15:
            contributors.append(
                {
                    "code": "HIGH_SPEED",
                    "points": 1,
                    "label": "Dernier déplacement enregistré à vitesse élevée (ordre de grandeur, pas une preuve).",
                }
            )
            score += 1

    near_risk = None
    in_safety = None
    if last_lat is not None and last_lng is not None:
        at = last_at or now
        for zone in db.query(RiskZone).filter(RiskZone.is_active.is_(True)).all():
            if not hour_window_active(zone.typical_start_hour, zone.typical_end_hour, at):
                continue
            distance = haversine_meters(last_lat, last_lng, zone.latitude, zone.longitude)
            if _membership(distance, None, zone.radius_meters, 40.0) == "inside":
                near_risk = {
                    "name": zone.name,
                    "distance_meters": round(distance, 1),
                    "latitude": zone.latitude,
                    "longitude": zone.longitude,
                    "radius_meters": zone.radius_meters,
                }
                contributors.append(
                    {
                        "code": "RISK_ZONE",
                        "points": 2,
                        "label": (
                            f"La dernière position connue est dans une zone à risque « {zone.name} ». "
                            "Prévention, pas un kidnapping."
                        ),
                    }
                )
                score += 2
                break
        safety_zones = (
            db.query(SafetyZone)
            .options(selectinload(SafetyZone.schedules))
            .filter(SafetyZone.young_person_id == young.id, SafetyZone.is_active.is_(True))
            .all()
        )
        for zone in safety_zones:
            if zone.schedules and not schedule_active_now(zone.schedules, at):
                continue
            distance = haversine_meters(last_lat, last_lng, zone.latitude, zone.longitude)
            if _membership(distance, None, zone.radius_meters, zone.accuracy_tolerance_meters) == "inside":
                in_safety = {"name": zone.name, "distance_meters": round(distance, 1)}
                break

    kits = db.query(GPSTracker).filter(GPSTracker.young_person_id == young.id).all()
    kit_snapshot = [
        {"label": kit.label, "status": kit.status.value, "battery_level": kit.battery_level}
        for kit in kits
        if kit.status != TrackerStatus.INACTIVE
    ]
    if any(kit.status in {TrackerStatus.SIGNAL_LOST, TrackerStatus.REMOVED} for kit in kits):
        if not any(item["code"] in {"SIGNAL_LOST", "DEVICE_REMOVED"} for item in contributors):
            contributors.append(
                {
                    "code": "KIT_STATUS",
                    "points": 1,
                    "label": "Un kit est en perte de signal ou retiré (dernière info connue).",
                }
            )
            score += 1

    elapsed = age_seconds
    crude_range = None
    range_assumption = "none"
    if last_at is not None and elapsed is not None and elapsed > 0:
        speed = None
        if last_movement and last_movement.get("speed_mps"):
            speed = float(last_movement["speed_mps"])
            range_assumption = "last_recorded_speed"
        if speed is None or speed < 0.3:
            speed = WALKING_M_S
            range_assumption = "walking_hypothesis_1_2_mps"
        crude_range = min(RANGE_CAP_M, speed * elapsed)

    level = _level_for(score)
    lines = [
        f"Niveau d'aide à la décision : {level.value} (score {score}, règles métier).",
        DISCLAIMER,
    ]
    for item in contributors:
        if item["points"] or item["code"] == "NO_FIX":
            lines.append(f"- {item['label']}")
    if last_movement and last_movement.get("heading_degrees") is not None:
        lines.append(
            f"- Dernière direction enregistrée : {last_movement['heading_degrees']}°. "
            "Ce n'est pas une prédiction de destination."
        )
    if crude_range is not None:
        lines.append(
            f"- Ordre de grandeur si le déplacement avait continué : {int(crude_range)} m "
            f"({range_assumption}). Sert à estimer un cercle, pas la position réelle."
        )
    heading = None
    if last_movement and last_movement.get("heading_degrees") is not None:
        heading = float(last_movement["heading_degrees"])
    zone = upsert_probable_zone(
        db,
        case,
        last_lat=last_lat,
        last_lng=last_lng,
        last_at=last_at,
        heading_degrees=heading,
        crude_range_meters=crude_range,
        range_assumption=range_assumption,
        elapsed_seconds=elapsed,
    )
    priority_rows = replace_priority_zones(
        db,
        case,
        last_lat=last_lat,
        last_lng=last_lng,
        last_at=last_at,
        heading_degrees=heading,
        crude_range_meters=crude_range,
        range_assumption=range_assumption,
        elapsed_seconds=elapsed,
        near_risk=near_risk,
        exit_lat=exit_event.latitude if exit_event is not None else None,
        exit_lng=exit_event.longitude if exit_event is not None else None,
        open_sos=sos is not None,
        signal_lost=lost is not None,
    )
    if zone is not None:
        lines.append(
            "- Une zone de recherche estimée a été dessinée sur la carte. "
            "Ce n'est pas la position actuelle."
        )
    if priority_rows:
        lines.append(
            f"- {len(priority_rows)} zone(s) de recherche prioritaire(s), classée(s) par règles métier. "
            "Ce n'est pas la position actuelle ni un kidnapping confirmé."
        )
    testimony_rows = refresh_case_consistencies(db, case)
    by_consistency = {"LOW": 0, "MEDIUM": 0, "HIGH": 0}
    for row in testimony_rows:
        if row.consistency is not None:
            by_consistency[row.consistency.value] += 1
    if testimony_rows:
        lines.append(
            f"- {len(testimony_rows)} témoignage(s) croisé(s) avec la trajectoire enregistrée "
            f"(élevée {by_consistency['HIGH']}, moyenne {by_consistency['MEDIUM']}, "
            f"faible {by_consistency['LOW']}). Pas une preuve."
        )
    explanation = "\n".join(lines)

    factors = {
        "disclaimer": DISCLAIMER,
        "method": "rules",
        "score": score,
        "last_known": None
        if last_lat is None
        else {
            "latitude": last_lat,
            "longitude": last_lng,
            "recorded_at": _iso(last_at),
            "age_seconds": age_seconds,
        },
        "last_movement": last_movement,
        "elapsed_seconds": elapsed,
        "crude_range_meters": None if crude_range is None else round(crude_range, 1),
        "range_assumption": range_assumption,
        "trajectory": {
            "point_count": trajectory.point_count,
            "gap_count": trajectory.gap_count,
            "distance_meters": trajectory.distance_meters,
        },
        "events": {
            "geofence_exit_at": _iso(exit_event.recorded_at) if exit_event else None,
            "signal_lost_at": _iso(lost.recorded_at) if lost else None,
            "device_removed_at": _iso(removed.recorded_at) if removed else None,
            "open_sos_id": str(sos.id) if sos else None,
        },
        "near_risk_zone": near_risk,
        "in_safety_zone": in_safety,
        "kits": kit_snapshot,
        "testimonies": {
            "count": len(testimony_rows),
            "by_consistency": by_consistency,
            "note": "Croisés avec la trajectoire enregistrée (règles métier). Ce n'est pas une preuve.",
        },
        "contributors": contributors,
        "has_search_zone": zone is not None,
        "probable_zone": None
        if zone is None
        else {
            "id": str(zone.id),
            "kind": zone.kind.value,
            "center_latitude": zone.center_latitude,
            "center_longitude": zone.center_longitude,
            "radius_meters": zone.radius_meters,
        },
        "priority_zones": [
            {
                "id": str(row.id),
                "kind": row.kind.value,
                "priority": row.priority.value,
                "center_latitude": row.center_latitude,
                "center_longitude": row.center_longitude,
                "radius_meters": row.radius_meters,
            }
            for row in priority_rows
        ],
    }

    existing = (
        db.query(RiskAnalysis)
        .filter(RiskAnalysis.case_id == case.id, RiskAnalysis.method == "rules")
        .order_by(RiskAnalysis.created_at.desc())
        .first()
    )
    previous_level = existing.risk_level if existing is not None else None
    payload = json.dumps(factors, ensure_ascii=False)
    if existing is None:
        existing = RiskAnalysis(
            case_id=case.id,
            young_person_id=young.id,
            risk_level=level,
            explanation=explanation,
            factors=payload,
            method="rules",
        )
        db.add(existing)
        db.flush()
        if notify:
            _notify(db, case, young, existing)
    else:
        existing.risk_level = level
        existing.explanation = explanation
        existing.factors = payload
        existing.method = "rules"
        db.flush()
        if notify and previous_level != level:
            _notify(db, case, young, existing)
    from app.services.ai_service import attach_ai_analysis

    attach_ai_analysis(db, case, young, notify=False)
    return existing


def _notify(db: Session, case: MissingPersonCase, young: YoungPerson, analysis: RiskAnalysis) -> None:
    body = (
        f"Aide à la décision ({analysis.risk_level.value}) concernant {young.display_name}. "
        "Règles métier, pas de ML. Ce n'est pas un kidnapping confirmé, pas une zone de recherche."
    )
    payload = json.dumps(
        {
            "young_person_id": str(young.id),
            "young_display_name": young.display_name,
            "case_id": str(case.id),
            "risk_level": analysis.risk_level.value,
            "method": "rules",
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
                notification_type=NotificationType.SEARCH_UPDATE,
                title="Search Intelligence",
                body=body,
                case_id=case.id,
                payload=payload,
            )
        )


def get_intelligence(db: Session, user: User, case_id: UUID) -> SearchIntelligenceRead:
    from app.services.case_service import CaseError, get_case

    get_case(db, user, case_id)
    row = (
        db.query(RiskAnalysis)
        .filter(RiskAnalysis.case_id == case_id, RiskAnalysis.method == "rules")
        .order_by(RiskAnalysis.created_at.desc())
        .first()
    )
    if row is None:
        raise CaseError("Aucune analyse Search Intelligence pour ce dossier", 404)
    return to_read(row)


def refresh_intelligence(db: Session, user: User, case_id: UUID) -> SearchIntelligenceRead:
    from app.services.case_service import CaseError, _can_view, _query

    row = _query(db).filter(MissingPersonCase.id == case_id).one_or_none()
    if row is None:
        raise CaseError("Dossier introuvable", 404)
    _can_view(db, user, row.young_person_id)
    analysis = attach_analysis(db, row, row.young_person, notify=True)
    db.commit()
    loaded = db.query(RiskAnalysis).filter(RiskAnalysis.id == analysis.id).one()
    return to_read(loaded)
