from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from math import atan2, cos, degrees, radians, sin
from pathlib import Path
from uuid import UUID

from sqlalchemy.orm import Session, selectinload

from app.core.config import settings
from app.core.enums import (
    AlertStatus,
    CaseStatus,
    GuardianLinkStatus,
    NotificationType,
    RiskLevel,
    TrackerEventType,
)
from app.models.alert import Alert, AppNotification
from app.models.people import GuardianLink, YoungPerson
from app.models.search import MissingPersonCase, RiskAnalysis
from app.models.tracker import TrackerEvent, TrackerLocation
from app.models.user import User
from app.models.zones import RiskZone, SafetyZone
from app.schemas.entities import AiAnalysisRead
from app.services.consistency_service import refresh_case_consistencies
from app.services.geofence_service import _membership, haversine_meters
from app.services.location_service import _aware
from app.services.risk_zone_service import hour_window_active
from app.services.trajectory_service import reconstruct_window
from app.services.zone_service import schedule_active_now

AI_METHOD = "rules_ai"
MAX_PLAUSIBLE_M_S = 40.0
LOOKBACK = timedelta(hours=6)
OPEN_SOS = {
    AlertStatus.CREATED,
    AlertStatus.ACTIVE,
    AlertStatus.ACKNOWLEDGED,
    AlertStatus.IN_PROGRESS,
}
OPEN_CASE = {CaseStatus.OPEN, CaseStatus.SEARCHING}
DISCLAIMER = (
    "Analyse IA : aide à la décision par règles métier et calculs géographiques. "
    "Aucun modèle de machine learning n'a été entraîné (pas de dataset labellisé). "
    "Ce n'est pas un kidnapping confirmé, pas une preuve, pas la position actuelle."
)
FOOTER = (
    "Aide à la décision, pas de ML. Ce n'est pas une preuve, pas un kidnapping confirmé, "
    "pas la position actuelle."
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


def _ml_status() -> dict:
    path = (settings.ai_model_path or "").strip()
    artifact_present = bool(path) and Path(path).is_file()
    return {
        "trained_model": False,
        "artifact_present": artifact_present,
        "backend": "rules",
        "hook": "random_forest",
        "note": (
            "Pas de dataset labellisé : aucun modèle n'est utilisé pour le score. "
            "Un Random Forest pourra être branché ici lorsqu'un jeu réel existera. "
            "Un fichier modèle, s'il est configuré, n'est pas interprété comme une preuve de kidnapping."
            if artifact_present
            else "Pas de dataset labellisé : aucun modèle n'est utilisé pour le score. "
            "Un Random Forest pourra être branché ici lorsqu'un jeu réel existera."
        ),
    }


def try_ml_override(_features: dict) -> None:
    """Réservé à un modèle entraîné sur un dataset CityCare labellisé. Toujours None pour l'instant."""
    return None


def _level_for(score: int) -> RiskLevel:
    if score >= 7:
        return RiskLevel.HIGH
    if score >= 3:
        return RiskLevel.MEDIUM
    return RiskLevel.LOW


def _dimension(score: int, notes: list[str]) -> dict:
    return {"score": min(3, max(0, score)), "max": 3, "notes": notes}


def to_read(row: RiskAnalysis) -> AiAnalysisRead:
    factors: dict = {}
    if row.factors:
        try:
            parsed = json.loads(row.factors)
            if isinstance(parsed, dict):
                factors = parsed
        except json.JSONDecodeError:
            factors = {}
    return AiAnalysisRead(
        id=row.id,
        case_id=row.case_id,
        young_person_id=row.young_person_id,
        risk_level=row.risk_level,
        explanation=row.explanation,
        method=row.method,
        created_at=row.created_at,
        updated_at=row.updated_at,
        factors=factors,
        trained_model=bool(factors.get("trained_model")),
        disclaimer=DISCLAIMER,
    )


def attach_ai_analysis(db: Session, case: MissingPersonCase, young: YoungPerson, *, notify: bool) -> RiskAnalysis:
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

    geo_score = 0
    geo_notes: list[str] = []
    if last_at is None or last_lat is None or last_lng is None:
        geo_notes.append("Aucune position GPS enregistrée : comportement géographique non évaluable.")
    else:
        if age_seconds is not None and age_seconds >= 7200:
            geo_score += 2
            geo_notes.append("Dernière position connue il y a plus de 2 h (pas actuelle).")
        elif age_seconds is not None and age_seconds >= 1800:
            geo_score += 1
            geo_notes.append("Dernière position connue il y a plus de 30 min (pas actuelle).")
        safety_zones = (
            db.query(SafetyZone)
            .options(selectinload(SafetyZone.schedules))
            .filter(SafetyZone.young_person_id == young.id, SafetyZone.is_active.is_(True))
            .all()
        )
        active_safety = []
        inside_safety = False
        at = last_at or now
        for zone in safety_zones:
            if zone.schedules and not schedule_active_now(zone.schedules, at):
                continue
            active_safety.append(zone)
            distance = haversine_meters(last_lat, last_lng, zone.latitude, zone.longitude)
            if _membership(distance, None, zone.radius_meters, zone.accuracy_tolerance_meters) == "inside":
                inside_safety = True
                geo_notes.append(f"Dernière position connue dans la zone de sécurité « {zone.name} ».")
                break
        if active_safety and not inside_safety:
            geo_score += 1
            geo_notes.append(
                "Dernière position connue hors des zones de sécurité actives à cette heure. "
                "Ce n'est pas un kidnapping."
            )
        geo_score = min(3, geo_score)

    traj_score = 0
    traj_notes: list[str] = []
    points = trajectory.points
    if len(points) < 2:
        if points:
            traj_notes.append("Un seul point enregistré : trajectoire trop courte pour détecter une anomalie.")
        else:
            traj_notes.append("Aucune trajectoire enregistrée autour de l'heure du dossier.")
    else:
        implausible = False
        for prev, nxt in zip(points, points[1:]):
            dt = (_aware(nxt.recorded_at) - _aware(prev.recorded_at)).total_seconds()
            if dt < 1:
                continue
            dist = haversine_meters(prev.latitude, prev.longitude, nxt.latitude, nxt.longitude)
            speed = dist / dt
            if speed > MAX_PLAUSIBLE_M_S:
                implausible = True
                traj_score = 3
                traj_notes.append(
                    f"Saut GPS irréaliste ({speed:.0f} m/s requis). Possible aberration, pas une preuve de véhicule."
                )
                break
        if trajectory.gap_count:
            if traj_score < 3:
                traj_score += 2 if trajectory.gap_count >= 3 else 1
            traj_notes.append(
                f"{trajectory.gap_count} trou(s) de communication dans la trajectoire — pas interpolé."
            )
        if len(points) >= 3 and traj_score < 3:
            b1 = _bearing(points[-3].latitude, points[-3].longitude, points[-2].latitude, points[-2].longitude)
            b2 = _bearing(points[-2].latitude, points[-2].longitude, points[-1].latitude, points[-1].longitude)
            delta = _heading_delta(b1, b2)
            if delta > 90:
                traj_score += 1
                traj_notes.append(
                    f"Changement de cap enregistré de {delta:.0f}° sur les derniers points (pas une destination prédite)."
                )
        traj_score = min(3, traj_score)

    anom_score = 0
    anom_notes: list[str] = []
    exit_event = _recent_event(db, young.id, TrackerEventType.GEOFENCE_EXIT, since_events)
    lost = _recent_event(db, young.id, TrackerEventType.SIGNAL_LOST, since_events)
    removed = _recent_event(db, young.id, TrackerEventType.DEVICE_REMOVED, since_events)
    sos = _open_sos(db, young.id)
    if removed is not None:
        anom_score += 3
        anom_notes.append("Un retrait du kit a été enregistré récemment. Ce n'est pas un kidnapping confirmé.")
    elif lost is not None:
        anom_score += 3
        anom_notes.append("Le kit a signalé une perte de connexion récemment. Pas la position actuelle.")
    if sos is not None:
        anom_score += 2
        anom_notes.append("Un SOS est ouvert. Ce n'est pas un kidnapping confirmé.")
    if exit_event is not None:
        anom_score += 2
        anom_notes.append("Une sortie de zone de sécurité a été enregistrée. Ce n'est pas un kidnapping.")
    anom_score = min(3, anom_score)
    if not anom_notes:
        anom_notes.append("Aucune anomalie kit/SOS/sortie de zone récente.")

    risk_score = 0
    risk_notes: list[str] = []
    near_risk = None
    if last_lat is not None and last_lng is not None:
        at = last_at or now
        for zone in db.query(RiskZone).filter(RiskZone.is_active.is_(True)).all():
            if not hour_window_active(zone.typical_start_hour, zone.typical_end_hour, at):
                continue
            distance = haversine_meters(last_lat, last_lng, zone.latitude, zone.longitude)
            membership = _membership(distance, None, zone.radius_meters, 40.0)
            if membership == "inside":
                risk_score = 2
                near_risk = {"name": zone.name, "distance_meters": round(distance, 1)}
                risk_notes.append(
                    f"Dernière position connue dans la zone à risque « {zone.name} ». Prévention, pas un kidnapping."
                )
                break
            if distance <= zone.radius_meters * 2:
                risk_score = max(risk_score, 1)
                near_risk = {"name": zone.name, "distance_meters": round(distance, 1)}
                risk_notes.append(
                    f"Dernière position connue à proximité de la zone à risque « {zone.name} ». Pas un kidnapping."
                )
    if not risk_notes:
        risk_notes.append("Aucune zone à risque active recouvre la dernière position connue.")

    testimony_rows = refresh_case_consistencies(db, case)
    by_consistency = {"LOW": 0, "MEDIUM": 0, "HIGH": 0}
    for row in testimony_rows:
        if row.consistency is not None:
            by_consistency[row.consistency.value] += 1
    test_score = 0
    test_notes: list[str] = []
    if by_consistency["HIGH"]:
        test_score = 2
        test_notes.append(
            f"{by_consistency['HIGH']} témoignage(s) à cohérence estimée élevée avec la trajectoire. "
            "Aide à la décision, pas une preuve. Un statut vérifié ne change pas ce score."
        )
    elif by_consistency["MEDIUM"]:
        test_score = 1
        test_notes.append(
            f"{by_consistency['MEDIUM']} témoignage(s) à cohérence estimée moyenne. Pas une preuve."
        )
    elif testimony_rows:
        test_notes.append(
            f"{len(testimony_rows)} témoignage(s), cohérence estimée faible ou non discriminante. Pas une preuve."
        )
    else:
        test_notes.append("Aucun témoignage à croiser avec la trajectoire.")

    dimensions = {
        "geography": _dimension(geo_score, geo_notes),
        "trajectory": _dimension(traj_score, traj_notes),
        "anomalies": _dimension(anom_score, anom_notes),
        "risk_zones": _dimension(risk_score, risk_notes),
        "testimonies": _dimension(test_score, test_notes),
    }
    score = sum(item["score"] for item in dimensions.values())
    ml = _ml_status()
    try_ml_override({"score": score, "dimensions": dimensions})
    level = _level_for(score)
    lines = [
        f"Analyse IA : niveau {level.value} (score {score}/15, {AI_METHOD}).",
        DISCLAIMER,
        ml["note"],
    ]
    contributors: list[dict] = []
    labels = {
        "geography": "Comportement géographique",
        "trajectory": "Trajectoire",
        "anomalies": "Anomalies",
        "risk_zones": "Zones à risque",
        "testimonies": "Cohérence des témoignages",
    }
    for key, label in labels.items():
        dim = dimensions[key]
        lines.append(f"- {label} : {dim['score']}/{dim['max']}.")
        for note in dim["notes"]:
            lines.append(f"  {note}")
            contributors.append({"code": key.upper(), "points": dim["score"], "label": note})
    lines.append(FOOTER)
    explanation = "\n".join(lines)

    factors = {
        "disclaimer": DISCLAIMER,
        "method": AI_METHOD,
        "trained_model": False,
        "ml": ml,
        "score": score,
        "max_score": 15,
        "dimensions": dimensions,
        "contributors": contributors,
        "last_known": None
        if last_lat is None
        else {
            "latitude": last_lat,
            "longitude": last_lng,
            "recorded_at": _iso(last_at),
            "age_seconds": age_seconds,
        },
        "trajectory": {
            "point_count": trajectory.point_count,
            "gap_count": trajectory.gap_count,
            "distance_meters": trajectory.distance_meters,
        },
        "near_risk_zone": near_risk,
        "testimonies": {
            "count": len(testimony_rows),
            "by_consistency": by_consistency,
            "note": "Croisés avec la trajectoire (règles). Ce n'est pas une preuve.",
        },
        "events": {
            "geofence_exit_at": _iso(exit_event.recorded_at) if exit_event else None,
            "signal_lost_at": _iso(lost.recorded_at) if lost else None,
            "device_removed_at": _iso(removed.recorded_at) if removed else None,
            "open_sos_id": str(sos.id) if sos else None,
        },
    }

    existing = (
        db.query(RiskAnalysis)
        .filter(RiskAnalysis.case_id == case.id, RiskAnalysis.method == AI_METHOD)
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
            method=AI_METHOD,
        )
        db.add(existing)
        db.flush()
        if notify:
            _notify(db, case, young, existing)
    else:
        existing.risk_level = level
        existing.explanation = explanation
        existing.factors = payload
        existing.method = AI_METHOD
        db.flush()
        if notify and previous_level != level:
            _notify(db, case, young, existing)
    return existing


def _notify(db: Session, case: MissingPersonCase, young: YoungPerson, analysis: RiskAnalysis) -> None:
    body = (
        f"Analyse IA ({analysis.risk_level.value}) concernant {young.display_name}. "
        "Règles métier, pas de modèle ML. Ce n'est pas un kidnapping confirmé, pas une preuve."
    )
    payload = json.dumps(
        {
            "young_person_id": str(young.id),
            "young_display_name": young.display_name,
            "case_id": str(case.id),
            "risk_level": analysis.risk_level.value,
            "method": AI_METHOD,
            "trained_model": False,
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
                title="Analyse IA",
                body=body,
                case_id=case.id,
                payload=payload,
            )
        )


def get_ai_analysis(db: Session, user: User, case_id: UUID) -> AiAnalysisRead:
    from app.services.case_service import CaseError, get_case

    get_case(db, user, case_id)
    row = (
        db.query(RiskAnalysis)
        .filter(RiskAnalysis.case_id == case_id, RiskAnalysis.method == AI_METHOD)
        .order_by(RiskAnalysis.created_at.desc())
        .first()
    )
    if row is None:
        raise CaseError("Aucune analyse IA pour ce dossier", 404)
    return to_read(row)


def refresh_ai_analysis(db: Session, user: User, case_id: UUID) -> AiAnalysisRead:
    from app.services.case_service import CaseError, _can_view, _query

    row = _query(db).filter(MissingPersonCase.id == case_id).one_or_none()
    if row is None:
        raise CaseError("Dossier introuvable", 404)
    _can_view(db, user, row.young_person_id)
    analysis = attach_ai_analysis(db, row, row.young_person, notify=True)
    db.commit()
    loaded = db.query(RiskAnalysis).filter(RiskAnalysis.id == analysis.id).one()
    return to_read(loaded)
