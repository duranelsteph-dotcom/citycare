from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy.orm import Session

from app.core.enums import UserRole
from app.models.search import Incident
from app.models.user import User
from app.models.zones import RiskZone
from app.schemas.entities import IncidentRead, RiskZoneRead
from app.schemas.risk import IncidentCreate, RiskZoneCreate, RiskZoneUpdate


class RiskZoneError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


def hour_window_active(start: int | None, end: int | None, at: datetime) -> bool:
    """Heures de l'horodatage fourni (pas le fuseau du serveur).

    Si les deux bornes sont vides, la zone est considérée à tout moment.
    Si end <= start, la fenêtre traverse minuit (ex. 20h → 6h).
    """
    if start is None and end is None:
        return True
    if start is None or end is None:
        return True
    hour = at.hour
    if start == end:
        return True
    if end > start:
        return start <= hour < end
    return hour >= start or hour < end


def to_read(zone: RiskZone, at: datetime | None = None) -> RiskZoneRead:
    moment = at or datetime.now().astimezone()
    payload = RiskZoneRead.model_validate(zone)
    return payload.model_copy(
        update={"is_hour_active_now": hour_window_active(zone.typical_start_hour, zone.typical_end_hour, moment)}
    )


def _can_manage(user: User) -> bool:
    return user.role in {UserRole.AUTHORITY, UserRole.PARENT}


def _require_manage(user: User) -> None:
    if not _can_manage(user):
        raise RiskZoneError("Réservé à l'autorité ou au parent (déclaration de zone à risque)", 403)


def list_zones(db: Session, user: User) -> list[RiskZoneRead]:
    query = db.query(RiskZone).order_by(RiskZone.name)
    if user.role in {UserRole.YOUNG, UserRole.RELATIVE}:
        query = query.filter(RiskZone.is_active.is_(True))
    return [to_read(zone) for zone in query.all()]


def create_zone(db: Session, user: User, payload: RiskZoneCreate) -> RiskZoneRead:
    _require_manage(user)
    zone = RiskZone(
        name=payload.name.strip(),
        latitude=payload.latitude,
        longitude=payload.longitude,
        radius_meters=payload.radius_meters,
        is_active=payload.is_active,
        typical_start_hour=payload.typical_start_hour,
        typical_end_hour=payload.typical_end_hour,
    )
    db.add(zone)
    db.commit()
    db.refresh(zone)
    return to_read(zone)


def update_zone(db: Session, user: User, zone_id: UUID, payload: RiskZoneUpdate) -> RiskZoneRead:
    _require_manage(user)
    zone = db.query(RiskZone).filter(RiskZone.id == zone_id).one_or_none()
    if zone is None:
        raise RiskZoneError("Zone à risque introuvable", 404)
    data = payload.model_dump(exclude_unset=True)
    if "name" in data and data["name"] is not None:
        data["name"] = data["name"].strip()
    for key, value in data.items():
        setattr(zone, key, value)
    db.commit()
    db.refresh(zone)
    return to_read(zone)


def delete_zone(db: Session, user: User, zone_id: UUID) -> None:
    _require_manage(user)
    zone = db.query(RiskZone).filter(RiskZone.id == zone_id).one_or_none()
    if zone is None:
        raise RiskZoneError("Zone à risque introuvable", 404)
    db.delete(zone)
    db.commit()


def add_incident(db: Session, user: User, zone_id: UUID, payload: IncidentCreate) -> IncidentRead:
    _require_manage(user)
    zone = db.query(RiskZone).filter(RiskZone.id == zone_id).one_or_none()
    if zone is None:
        raise RiskZoneError("Zone à risque introuvable", 404)
    occurred = payload.occurred_at or datetime.now(timezone.utc)
    if occurred.tzinfo is None:
        occurred = occurred.replace(tzinfo=timezone.utc)
    incident = Incident(
        risk_zone_id=zone.id,
        title=payload.title.strip(),
        description=payload.description,
        latitude=payload.latitude if payload.latitude is not None else zone.latitude,
        longitude=payload.longitude if payload.longitude is not None else zone.longitude,
        occurred_at=occurred,
        source=payload.source,
        count=payload.count,
    )
    zone.incident_count += payload.count
    db.add(incident)
    db.commit()
    db.refresh(incident)
    return IncidentRead.model_validate(incident)


def list_incidents(db: Session, zone_id: UUID) -> list[IncidentRead]:
    zone = db.query(RiskZone).filter(RiskZone.id == zone_id).one_or_none()
    if zone is None:
        raise RiskZoneError("Zone à risque introuvable", 404)
    rows = (
        db.query(Incident)
        .filter(Incident.risk_zone_id == zone_id)
        .order_by(Incident.occurred_at.desc())
        .all()
    )
    return [IncidentRead.model_validate(row) for row in rows]
