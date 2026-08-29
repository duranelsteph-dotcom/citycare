from __future__ import annotations

from datetime import datetime, timezone
from math import asin, atan2, cos, degrees, radians, sin
from uuid import UUID

from sqlalchemy.orm import Session

from app.core.enums import SearchPriority, SearchZoneKind
from app.models.search import MissingPersonCase, SearchZone
from app.models.user import User
from app.schemas.entities import SearchZoneRead
from app.services.geofence_service import EARTH_RADIUS_M

DISCLAIMER = (
    "Zone de recherche estimée. Ce n'est pas la position actuelle, "
    "pas un kidnapping confirmé, pas un itinéraire, pas une zone prioritaire."
)
PRIORITY_DISCLAIMER = (
    "Zone de recherche prioritaire (classement par règles métier). "
    "Ce n'est pas la position actuelle, pas un kidnapping confirmé, "
    "pas un itinéraire. Les témoignages ne classent pas cette zone."
)
PRIORITY_FOOTER = (
    "Classement par règles métier, pas de modèle ML, sans graphe routier. "
    "Les témoignages ne classent pas ces zones. "
    "Ce n'est pas la position actuelle ni un kidnapping confirmé."
)
MIN_RADIUS_M = 150.0
RANGE_CAP_M = 50_000.0
GPS_BUFFER_M = 80.0
PRIORITY_RADIUS_CAP_M = 2_500.0
_KIND_ORDER = {SearchZoneKind.PRIORITY_SEARCH: 0, SearchZoneKind.PROBABLE_DISPLACEMENT: 1}
_PRIO_ORDER = {SearchPriority.HIGH: 0, SearchPriority.MEDIUM: 1, SearchPriority.LOW: 2}


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def destination(lat: float, lon: float, heading_deg: float, distance_m: float) -> tuple[float, float]:
    """Point à `distance_m` du départ, suivant un cap en degrés. Pas un itinéraire routier."""
    if distance_m <= 0:
        return lat, lon
    delta = distance_m / EARTH_RADIUS_M
    theta = radians(heading_deg)
    phi1 = radians(lat)
    lambda1 = radians(lon)
    phi2 = asin(sin(phi1) * cos(delta) + cos(phi1) * sin(delta) * cos(theta))
    lambda2 = lambda1 + atan2(sin(theta) * sin(delta) * cos(phi1), cos(delta) - sin(phi1) * sin(phi2))
    return degrees(phi2), (degrees(lambda2) + 540) % 360 - 180


def to_read(row: SearchZone) -> SearchZoneRead:
    payload = SearchZoneRead.model_validate(row)
    disclaimer = PRIORITY_DISCLAIMER if row.kind == SearchZoneKind.PRIORITY_SEARCH else DISCLAIMER
    return payload.model_copy(update={"disclaimer": disclaimer})


def _clamp(value: float, low: float, high: float) -> float:
    return min(high, max(low, value))


def _add_priority(
    db: Session,
    case: MissingPersonCase,
    *,
    priority: SearchPriority,
    center_lat: float,
    center_lng: float,
    radius_meters: float,
    explanation: str,
    computed_at: datetime,
) -> SearchZone:
    row = SearchZone(
        case_id=case.id,
        kind=SearchZoneKind.PRIORITY_SEARCH,
        priority=priority,
        center_latitude=center_lat,
        center_longitude=center_lng,
        radius_meters=round(radius_meters, 1),
        explanation=explanation,
        computed_at=computed_at,
    )
    db.add(row)
    db.flush()
    return row


def upsert_probable_zone(
    db: Session,
    case: MissingPersonCase,
    *,
    last_lat: float | None,
    last_lng: float | None,
    last_at: datetime | None,
    heading_degrees: float | None,
    crude_range_meters: float | None,
    range_assumption: str,
    elapsed_seconds: int | None,
) -> SearchZone | None:
    """Une seule zone PROBABLE_DISPLACEMENT par dossier. Les priorités sont gérées à part."""
    existing = (
        db.query(SearchZone)
        .filter(
            SearchZone.case_id == case.id,
            SearchZone.kind == SearchZoneKind.PROBABLE_DISPLACEMENT,
        )
        .order_by(SearchZone.computed_at.desc())
        .first()
    )
    if last_lat is None or last_lng is None:
        if existing is not None:
            db.delete(existing)
            db.flush()
        return None

    travel = crude_range_meters if crude_range_meters is not None else 0.0
    travel = min(RANGE_CAP_M, max(travel, 0.0))
    use_heading = heading_degrees is not None and travel >= MIN_RADIUS_M
    if use_heading and heading_degrees is not None:
        offset = min(travel * 0.45, RANGE_CAP_M)
        center_lat, center_lng = destination(last_lat, last_lng, heading_degrees, offset)
        radius = min(RANGE_CAP_M, max(offset + GPS_BUFFER_M, travel * 0.6, MIN_RADIUS_M))
    else:
        center_lat, center_lng = last_lat, last_lng
        radius = min(RANGE_CAP_M, max(travel + GPS_BUFFER_M, MIN_RADIUS_M))

    elapsed_txt = f"{elapsed_seconds} s" if elapsed_seconds is not None else "inconnu"
    last_txt = last_at.isoformat() if last_at is not None else "inconnu"
    heading_txt = (
        f"dernière direction enregistrée {heading_degrees:.0f}°"
        if use_heading
        else "sans direction exploitable (cercle autour de la dernière position connue)"
    )
    explanation = (
        "Zone de recherche estimée (cercle, règles métier, pas de modèle ML). "
        f"Dernière position connue ({last_txt}) + temps écoulé ({elapsed_txt}) + {heading_txt}. "
        f"Hypothèse de portée : {range_assumption}. Rayon {int(radius)} m. "
        "Sans graphe routier : ce n'est pas un itinéraire. "
        "Ce n'est pas la position actuelle ni un kidnapping confirmé. "
        "Ce n'est pas une zone de recherche prioritaire."
    )
    now = _utcnow()
    if existing is None:
        existing = SearchZone(
            case_id=case.id,
            kind=SearchZoneKind.PROBABLE_DISPLACEMENT,
            priority=SearchPriority.MEDIUM,
            center_latitude=center_lat,
            center_longitude=center_lng,
            radius_meters=round(radius, 1),
            explanation=explanation,
            computed_at=now,
        )
        db.add(existing)
    else:
        existing.priority = SearchPriority.MEDIUM
        existing.center_latitude = center_lat
        existing.center_longitude = center_lng
        existing.radius_meters = round(radius, 1)
        existing.explanation = explanation
        existing.computed_at = now
    db.flush()
    return existing


def replace_priority_zones(
    db: Session,
    case: MissingPersonCase,
    *,
    last_lat: float | None,
    last_lng: float | None,
    last_at: datetime | None,
    heading_degrees: float | None,
    crude_range_meters: float | None,
    range_assumption: str,
    elapsed_seconds: int | None,
    near_risk: dict | None,
    exit_lat: float | None,
    exit_lng: float | None,
    open_sos: bool,
    signal_lost: bool,
) -> list[SearchZone]:
    """Remplace les PRIORITY_SEARCH du dossier. Au plus 3 cercles classés, pas d'itinéraire."""
    from app.services.geofence_service import haversine_meters

    previous = (
        db.query(SearchZone)
        .filter(
            SearchZone.case_id == case.id,
            SearchZone.kind == SearchZoneKind.PRIORITY_SEARCH,
        )
        .all()
    )
    for row in previous:
        db.delete(row)
    db.flush()
    if last_lat is None or last_lng is None:
        return []

    travel = _clamp(crude_range_meters or 0.0, 0.0, RANGE_CAP_M)
    now = _utcnow()
    last_txt = last_at.isoformat() if last_at is not None else "inconnu"
    created: list[SearchZone] = []

    last_priority = SearchPriority.HIGH if (open_sos or signal_lost or (elapsed_seconds or 0) >= 1800) else SearchPriority.MEDIUM
    last_radius = _clamp((travel * 0.22 if travel else 400.0) + GPS_BUFFER_M, 250.0, 1_200.0)
    created.append(
        _add_priority(
            db,
            case,
            priority=last_priority,
            center_lat=last_lat,
            center_lng=last_lng,
            radius_meters=last_radius,
            explanation=(
                "Priorité : dernière position connue. "
                f"Chercher d'abord autour du dernier point enregistré ({last_txt}), "
                f"rayon {int(last_radius)} m, hypothèse {range_assumption}. "
                f"{PRIORITY_FOOTER}"
            ),
            computed_at=now,
        )
    )

    if heading_degrees is not None and travel >= 400:
        offset = min(travel * 0.4, 8_000.0)
        if offset >= 200:
            forward_lat, forward_lng = destination(last_lat, last_lng, heading_degrees, offset)
            forward_radius = _clamp(travel * 0.28, 300.0, 2_000.0)
            created.append(
                _add_priority(
                    db,
                    case,
                    priority=SearchPriority.HIGH,
                    center_lat=forward_lat,
                    center_lng=forward_lng,
                    radius_meters=forward_radius,
                    explanation=(
                        "Priorité : dernière direction enregistrée. "
                        f"Si le déplacement avait continué au cap {heading_degrees:.0f}°, "
                        f"un secteur plus restreint (rayon {int(forward_radius)} m) mérite d'être fouillé. "
                        "Ce n'est pas une prédiction de destination. "
                        f"{PRIORITY_FOOTER}"
                    ),
                    computed_at=now,
                )
            )

    if len(created) < 3 and near_risk and near_risk.get("latitude") is not None and near_risk.get("longitude") is not None:
        risk_lat = float(near_risk["latitude"])
        risk_lng = float(near_risk["longitude"])
        risk_radius = _clamp(float(near_risk.get("radius_meters") or 400.0), 200.0, 1_500.0)
        name = str(near_risk.get("name") or "zone à risque")
        created.append(
            _add_priority(
                db,
                case,
                priority=SearchPriority.HIGH,
                center_lat=risk_lat,
                center_lng=risk_lng,
                radius_meters=risk_radius,
                explanation=(
                    f"Priorité : zone à risque « {name} ». "
                    "La dernière position connue s'y trouve (prévention, pas un kidnapping). "
                    f"Rayon {int(risk_radius)} m. "
                    f"{PRIORITY_FOOTER}"
                ),
                computed_at=now,
            )
        )

    if len(created) < 3 and exit_lat is not None and exit_lng is not None:
        if haversine_meters(last_lat, last_lng, exit_lat, exit_lng) >= 150:
            created.append(
                _add_priority(
                    db,
                    case,
                    priority=SearchPriority.MEDIUM,
                    center_lat=exit_lat,
                    center_lng=exit_lng,
                    radius_meters=400.0,
                    explanation=(
                        "Priorité : sortie de zone de sécurité enregistrée. "
                        "Ce n'est pas un kidnapping. Le point de sortie est un indice de recherche, "
                        "pas la position actuelle. "
                        f"{PRIORITY_FOOTER}"
                    ),
                    computed_at=now,
                )
            )

    return created


def list_search_zones(db: Session, user: User, case_id: UUID) -> list[SearchZoneRead]:
    from app.services.case_service import get_case

    get_case(db, user, case_id)
    rows = db.query(SearchZone).filter(SearchZone.case_id == case_id).all()
    rows.sort(
        key=lambda row: (
            _KIND_ORDER.get(row.kind, 9),
            _PRIO_ORDER.get(row.priority, 9),
            row.created_at,
        )
    )
    return [to_read(row) for row in rows]
