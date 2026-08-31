from uuid import UUID

from sqlalchemy.orm import Session

from app.core.enums import AlertStatus, CaseStatus, TrackingMode, TrackerStatus
from app.models.alert import Alert
from app.models.search import MissingPersonCase
from app.models.tracker import GPSTracker

OPEN_SOS = {
    AlertStatus.CREATED,
    AlertStatus.ACTIVE,
    AlertStatus.ACKNOWLEDGED,
    AlertStatus.IN_PROGRESS,
}
OPEN_CASE = {CaseStatus.OPEN, CaseStatus.ACKNOWLEDGED, CaseStatus.SEARCHING, CaseStatus.INFO}

INTERVAL_SECONDS = {
    TrackingMode.NORMAL: 60,
    TrackingMode.SURVEILLANCE: 20,
    TrackingMode.EMERGENCY: 10,
    TrackingMode.POWER_SAVE: 180,
}

MODE_RANK = {
    TrackingMode.POWER_SAVE: 0,
    TrackingMode.NORMAL: 1,
    TrackingMode.SURVEILLANCE: 2,
    TrackingMode.EMERGENCY: 3,
}


def has_open_sos(db: Session, young_person_id: UUID) -> bool:
    return (
        db.query(Alert.id)
        .filter(Alert.young_person_id == young_person_id, Alert.status.in_(OPEN_SOS))
        .first()
        is not None
    )


def has_open_case(db: Session, young_person_id: UUID) -> bool:
    return (
        db.query(MissingPersonCase.id)
        .filter(MissingPersonCase.young_person_id == young_person_id, MissingPersonCase.status.in_(OPEN_CASE))
        .first()
        is not None
    )


def interval_for(mode: TrackingMode) -> int:
    return INTERVAL_SECONDS[mode]


def effective_mode(db: Session, young_person_id: UUID, tracker: GPSTracker | None = None) -> TrackingMode:
    """Mode conseillé pour le rafraîchissement. Ce n'est pas un GPS continu."""
    if has_open_sos(db, young_person_id) or has_open_case(db, young_person_id):
        return TrackingMode.EMERGENCY
    if tracker is not None:
        if tracker.status == TrackerStatus.LOW_BATTERY or tracker.tracking_mode == TrackingMode.POWER_SAVE:
            return TrackingMode.POWER_SAVE
        return tracker.tracking_mode
    kits = (
        db.query(GPSTracker)
        .filter(
            GPSTracker.young_person_id == young_person_id,
            GPSTracker.status != TrackerStatus.INACTIVE,
        )
        .all()
    )
    if not kits:
        return TrackingMode.NORMAL
    if any(kit.status == TrackerStatus.LOW_BATTERY or kit.tracking_mode == TrackingMode.POWER_SAVE for kit in kits):
        return TrackingMode.POWER_SAVE
    return max(kits, key=lambda kit: MODE_RANK[kit.tracking_mode]).tracking_mode
