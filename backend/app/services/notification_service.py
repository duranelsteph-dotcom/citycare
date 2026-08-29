import json
from uuid import UUID

from sqlalchemy.orm import Session

from app.core.enums import NotificationType
from app.models.alert import AppNotification
from app.models.user import User
from app.schemas.entities import NotificationContext, NotificationRead

DISCLAIMER = (
    "Inbox dans l'application, plus un push FCM si un jeton appareil est enregistré "
    "et si le serveur a un compte de service Firebase. "
    "Ce n'est pas un kidnapping confirmé. "
    "Une position indiquée est une dernière valeur connue, pas la position actuelle."
)

_TARGETS = {
    NotificationType.SOS: "SOS",
    NotificationType.GEOFENCE_EXIT: "MAP",
    NotificationType.RISK_ZONE_ENTER: "MAP",
    NotificationType.ANOMALY: "MAP",
    NotificationType.LOW_BATTERY: "KIT",
    NotificationType.SIGNAL_LOST: "KIT",
    NotificationType.DEVICE_REMOVED: "KIT",
    NotificationType.POSITION_SHARE: "SHARE",
    NotificationType.MISSING_CASE: "CASE",
    NotificationType.SEARCH_UPDATE: "CASE",
    NotificationType.TESTIMONY: "CASE",
}


class NotificationError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


def _payload_dict(row: AppNotification) -> dict:
    if not row.payload:
        return {}
    try:
        data = json.loads(row.payload)
    except json.JSONDecodeError:
        return {}
    return data if isinstance(data, dict) else {}


def _as_uuid(value) -> UUID | None:
    if value is None or value == "":
        return None
    try:
        return UUID(str(value))
    except ValueError:
        return None


def _as_float(value) -> float | None:
    if value is None or value == "":
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def to_read(row: AppNotification) -> NotificationRead:
    data = _payload_dict(row)
    context = NotificationContext(
        channel="IN_APP",
        target=_TARGETS.get(row.notification_type, "INBOX"),
        young_person_id=_as_uuid(data.get("young_person_id")),
        young_display_name=data.get("young_display_name"),
        latitude=_as_float(data.get("latitude")),
        longitude=_as_float(data.get("longitude")),
        zone_name=data.get("zone_name"),
        is_live_position=False,
        disclaimer=DISCLAIMER,
    )
    return NotificationRead.model_validate(row).model_copy(update={"context": context})


def list_mine(db: Session, user: User, limit: int = 50, *, unread_only: bool = False) -> list[NotificationRead]:
    cap = min(max(limit, 1), 100)
    query = db.query(AppNotification).filter(AppNotification.recipient_user_id == user.id)
    if unread_only:
        query = query.filter(AppNotification.is_read.is_(False))
    rows = query.order_by(AppNotification.created_at.desc()).limit(cap).all()
    return [to_read(row) for row in rows]


def unread_count(db: Session, user: User) -> int:
    return (
        db.query(AppNotification)
        .filter(AppNotification.recipient_user_id == user.id, AppNotification.is_read.is_(False))
        .count()
    )


def mark_read(db: Session, user: User, notification_id: UUID) -> NotificationRead:
    row = (
        db.query(AppNotification)
        .filter(AppNotification.id == notification_id, AppNotification.recipient_user_id == user.id)
        .one_or_none()
    )
    if row is None:
        raise NotificationError("Notification introuvable", 404)
    row.is_read = True
    db.commit()
    db.refresh(row)
    return to_read(row)


def mark_all_read(db: Session, user: User) -> int:
    rows = (
        db.query(AppNotification)
        .filter(AppNotification.recipient_user_id == user.id, AppNotification.is_read.is_(False))
        .all()
    )
    for row in rows:
        row.is_read = True
    db.commit()
    return len(rows)
