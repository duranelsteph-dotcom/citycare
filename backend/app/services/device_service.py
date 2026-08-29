from sqlalchemy.orm import Session

from app.models.device import DevicePushToken
from app.models.user import User
from app.schemas.device import DeviceTokenRead, DeviceTokenUpsert

ALLOWED_PLATFORMS = {"ANDROID", "IOS", "WEB"}


class DeviceError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


def _platform(value: str) -> str:
    platform = value.strip().upper()
    if platform not in ALLOWED_PLATFORMS:
        raise DeviceError("Plateforme inconnue (ANDROID, IOS ou WEB)")
    return platform


def register_token(db: Session, user: User, payload: DeviceTokenUpsert) -> DeviceTokenRead:
    token = payload.token.strip()
    if not token:
        raise DeviceError("Jeton FCM vide")
    platform = _platform(payload.platform)
    row = db.query(DevicePushToken).filter(DevicePushToken.token == token).one_or_none()
    if row is None:
        row = DevicePushToken(user_id=user.id, token=token, platform=platform, is_active=True)
        db.add(row)
    else:
        row.user_id = user.id
        row.platform = platform
        row.is_active = True
    db.commit()
    db.refresh(row)
    return DeviceTokenRead.model_validate(row)


def unregister_token(db: Session, user: User, token: str) -> int:
    value = token.strip()
    rows = (
        db.query(DevicePushToken)
        .filter(DevicePushToken.user_id == user.id, DevicePushToken.token == value)
        .all()
    )
    for row in rows:
        row.is_active = False
    db.commit()
    return len(rows)


def list_mine(db: Session, user: User) -> list[DeviceTokenRead]:
    rows = (
        db.query(DevicePushToken)
        .filter(DevicePushToken.user_id == user.id, DevicePushToken.is_active.is_(True))
        .all()
    )
    return [DeviceTokenRead.model_validate(row) for row in rows]
