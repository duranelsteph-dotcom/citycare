from __future__ import annotations

from datetime import datetime, timedelta
from math import atan2, cos, degrees, radians, sin
from uuid import UUID

from sqlalchemy.orm import Session

from app.core.enums import ConsistencyLevel
from app.models.search import MissingPersonCase, Testimony
from app.models.user import User
from app.schemas.entities import TestimonyRead, TrajectoryPointRead
from app.services.geofence_service import haversine_meters
from app.services.location_service import _aware
from app.services.trajectory_service import GAP_AFTER, reconstruct_window

LOOKBACK = timedelta(hours=6)
LOOKAHEAD = timedelta(hours=2)
MAX_PLAUSIBLE_M_S = 40.0
FOOTER = (
    "Aide à la décision par règles métier, pas de modèle ML. "
    "Ce n'est pas une preuve, pas un kidnapping confirmé, pas la position actuelle."
)


def _bearing(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    phi1, phi2 = radians(lat1), radians(lat2)
    d_lambda = radians(lon2 - lon1)
    x = sin(d_lambda) * cos(phi2)
    y = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(d_lambda)
    return (degrees(atan2(x, y)) + 360) % 360


def _heading_delta(a: float, b: float) -> float:
    delta = abs(a - b) % 360
    return min(delta, 360 - delta)


def _level_for(score: int) -> ConsistencyLevel:
    if score >= 3:
        return ConsistencyLevel.HIGH
    if score >= 2:
        return ConsistencyLevel.MEDIUM
    return ConsistencyLevel.LOW


def assess_consistency(
    db: Session,
    young_person_id: UUID,
    latitude: float,
    longitude: float,
    observed_at: datetime,
) -> tuple[ConsistencyLevel, str]:
    """Compare un témoignage aux points GPS enregistrés. N'invente pas de position dans un trou."""
    at = _aware(observed_at)
    trajectory = reconstruct_window(
        db,
        young_person_id,
        since=at - LOOKBACK,
        until=at + LOOKAHEAD,
        limit=200,
        access="CASE",
    )
    points = trajectory.points
    if not points:
        return ConsistencyLevel.LOW, (
            "Cohérence estimée faible : aucune position GPS enregistrée autour de l'heure du témoignage. "
            f"{FOOTER}"
        )

    before: TrajectoryPointRead | None = None
    after: TrajectoryPointRead | None = None
    nearest = points[0]
    nearest_dt = abs((_aware(points[0].recorded_at) - at).total_seconds())
    for point in points:
        recorded = _aware(point.recorded_at)
        delta = (recorded - at).total_seconds()
        if recorded <= at:
            before = point
        if after is None and recorded >= at:
            after = point
        if abs(delta) < nearest_dt:
            nearest = point
            nearest_dt = abs(delta)

    notes: list[str] = []
    score = 0
    nearest_dist = haversine_meters(latitude, longitude, nearest.latitude, nearest.longitude)
    notes.append(
        f"Point GPS le plus proche : {int(nearest_dt)} s et {int(nearest_dist)} m "
        "(dernière connue, pas la position actuelle)."
    )

    interpolated = False
    if before is not None and after is not None and before.location_id != after.location_id:
        span = _aware(after.recorded_at) - _aware(before.recorded_at)
        if timedelta(seconds=1) <= span <= GAP_AFTER:
            ratio = (at - _aware(before.recorded_at)).total_seconds() / span.total_seconds()
            expected_lat = before.latitude + ratio * (after.latitude - before.latitude)
            expected_lng = before.longitude + ratio * (after.longitude - before.longitude)
            expected_dist = haversine_meters(latitude, longitude, expected_lat, expected_lng)
            interpolated = True
            notes.append(
                f"Interpolation entre deux points enregistrés ({int(span.total_seconds())} s, pas un trou) : "
                f"écart {int(expected_dist)} m. Ce n'est pas un GPS mesuré à cette seconde."
            )
            if expected_dist < 150:
                score = 3
            elif expected_dist < 400:
                score = 2
            elif expected_dist < 1200:
                score = 1
            else:
                score = 0

    if not interpolated:
        if nearest_dt < 300 and nearest_dist < 250:
            score = 3
        elif nearest_dt < 1200 and nearest_dist < 800:
            score = 2
        elif nearest_dt < 3600 and nearest_dist < 2000:
            score = 1
        else:
            score = 0
        notes.append("Pas d'interpolation : trou de communication ou un seul point de part et d'autre.")

    if nearest_dt >= 1:
        required_speed = nearest_dist / nearest_dt
        notes.append(
            f"Vitesse requise depuis le point le plus proche : {required_speed:.1f} m/s "
            "(ordre de grandeur, pas une preuve de véhicule)."
        )
        if required_speed > MAX_PLAUSIBLE_M_S:
            score = 0
            notes.append("Vitesse requise irréaliste : cohérence ramenée à faible.")

    heading = nearest.heading
    if heading is None and before is not None and after is not None:
        heading = _bearing(before.latitude, before.longitude, after.latitude, after.longitude)
    if heading is not None and nearest_dist > 300:
        to_sight = _bearing(nearest.latitude, nearest.longitude, latitude, longitude)
        delta = _heading_delta(heading, to_sight)
        notes.append(
            f"Écart de cap par rapport à la dernière direction enregistrée : {delta:.0f}° "
            "(pas une prédiction de destination)."
        )
        if delta > 90:
            score = max(0, score - 1)

    level = _level_for(score)
    label = {"LOW": "faible", "MEDIUM": "moyenne", "HIGH": "élevée"}[level.value]
    explanation = (
        f"Cohérence estimée {label} (score {score}/3, règles métier). "
        + " ".join(notes)
        + f" {FOOTER}"
    )
    return level, explanation


def apply_consistency(db: Session, case: MissingPersonCase, row: Testimony) -> Testimony:
    level, note = assess_consistency(
        db,
        case.young_person_id,
        row.latitude,
        row.longitude,
        row.observed_at,
    )
    row.consistency = level
    row.consistency_note = note
    return row


def refresh_case_consistencies(db: Session, case: MissingPersonCase) -> list[Testimony]:
    rows = db.query(Testimony).filter(Testimony.case_id == case.id).all()
    for row in rows:
        apply_consistency(db, case, row)
    if rows:
        db.flush()
    return rows


def refresh_all(db: Session, user: User, case_id: UUID) -> list[TestimonyRead]:
    from app.services.case_service import get_case
    from app.services.testimony_service import _case, _submitter_name, to_read

    get_case(db, user, case_id)
    case = _case(db, case_id)
    rows = refresh_case_consistencies(db, case)
    db.commit()
    return [to_read(row, _submitter_name(db, row.submitted_by_user_id)) for row in rows]
