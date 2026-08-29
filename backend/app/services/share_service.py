import json
from datetime import datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy.orm import Session, joinedload

from app.core.enums import GuardianLinkStatus, NotificationType, UserRole
from app.models.alert import AppNotification
from app.models.people import GuardianLink
from app.models.tracker import PositionShare
from app.models.user import User
from app.schemas.entities import PositionShareRead
from app.schemas.location import ShareCreate
from app.services.family_service import require_young


class ShareError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _aware(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value


def share_is_active(share: PositionShare, at: datetime | None = None) -> bool:
    now = at or _utcnow()
    if share.is_revoked:
        return False
    if _aware(share.starts_at) > now:
        return False
    if share.expires_at is not None and _aware(share.expires_at) <= now:
        return False
    return True


def active_share(db: Session, young_person_id: UUID, target_user_id: UUID) -> PositionShare | None:
    rows = (
        db.query(PositionShare)
        .filter(
            PositionShare.young_person_id == young_person_id,
            PositionShare.target_user_id == target_user_id,
            PositionShare.is_revoked.is_(False),
        )
        .order_by(PositionShare.created_at.desc())
        .all()
    )
    for row in rows:
        if share_is_active(row):
            return row
    return None


def to_read(share: PositionShare) -> PositionShareRead:
    payload = PositionShareRead.model_validate(share)
    target = share.target_user
    young = share.young_person
    return payload.model_copy(
        update={
            "is_active": share_is_active(share),
            "target_display_name": target.full_name if target else None,
            "young_display_name": young.display_name if young else None,
        }
    )


def _query(db: Session):
    return db.query(PositionShare).options(
        joinedload(PositionShare.target_user),
        joinedload(PositionShare.young_person),
    )


def list_own(db: Session, user: User) -> list[PositionShareRead]:
    young = require_young(user)
    rows = _query(db).filter(PositionShare.young_person_id == young.id).order_by(PositionShare.created_at.desc()).all()
    return [to_read(row) for row in rows]


def list_received(db: Session, user: User) -> list[PositionShareRead]:
    if user.role not in {UserRole.PARENT, UserRole.RELATIVE}:
        raise ShareError("Réservé au parent ou au proche autorisé", 403)
    rows = (
        _query(db)
        .filter(PositionShare.target_user_id == user.id)
        .order_by(PositionShare.created_at.desc())
        .all()
    )
    return [to_read(row) for row in rows]


def create_share(db: Session, user: User, payload: ShareCreate) -> PositionShareRead:
    young = require_young(user)
    if payload.target_user_id == user.id:
        raise ShareError("Vous ne pouvez pas partager avec vous-même", 400)
    link = (
        db.query(GuardianLink)
        .filter(
            GuardianLink.young_person_id == young.id,
            GuardianLink.guardian_user_id == payload.target_user_id,
            GuardianLink.status == GuardianLinkStatus.ACTIVE,
        )
        .one_or_none()
    )
    if link is None:
        raise ShareError("Pas de rattachement actif avec ce contact", 403)
    existing = (
        db.query(PositionShare)
        .filter(
            PositionShare.young_person_id == young.id,
            PositionShare.target_user_id == payload.target_user_id,
            PositionShare.is_revoked.is_(False),
        )
        .all()
    )
    now = _utcnow()
    for row in existing:
        if share_is_active(row, now):
            row.is_revoked = True
            row.revoked_at = now
    share = PositionShare(
        young_person_id=young.id,
        target_user_id=payload.target_user_id,
        starts_at=now,
        expires_at=now + timedelta(minutes=payload.duration_minutes),
        is_revoked=False,
    )
    db.add(share)
    db.flush()
    payload_json = json.dumps(
        {
            "young_person_id": str(young.id),
            "young_display_name": young.display_name,
            "share_id": str(share.id),
            "expires_at": share.expires_at.isoformat() if share.expires_at else None,
        },
        ensure_ascii=False,
    )
    db.add(
        AppNotification(
            recipient_user_id=payload.target_user_id,
            notification_type=NotificationType.POSITION_SHARE,
            title="Position partagée",
            body=(
                f"{young.display_name} partage sa dernière position connue jusqu’à "
                f"{_aware(share.expires_at).astimezone().strftime('%H:%M')}. "
                "Ce n’est pas un suivi en direct ni un kidnapping confirmé."
            ),
            payload=payload_json,
        )
    )
    db.commit()
    return to_read(_query(db).filter(PositionShare.id == share.id).one())


def revoke_share(db: Session, user: User, share_id: UUID) -> PositionShareRead:
    share = _query(db).filter(PositionShare.id == share_id).one_or_none()
    if share is None:
        raise ShareError("Partage introuvable", 404)
    allowed = False
    if user.role == UserRole.YOUNG:
        owner = require_young(user)
        allowed = owner.id == share.young_person_id
    elif user.id == share.target_user_id:
        allowed = True
    if not allowed:
        raise ShareError("Vous ne pouvez pas révoquer ce partage", 403)
    if not share.is_revoked:
        share.is_revoked = True
        share.revoked_at = _utcnow()
        db.commit()
        share = _query(db).filter(PositionShare.id == share_id).one()
    return to_read(share)
