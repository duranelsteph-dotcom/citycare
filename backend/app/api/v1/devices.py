from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.device import DeviceTokenRead, DeviceTokenUpsert
from app.services.device_service import DeviceError, list_mine, register_token, unregister_token

router = APIRouter(prefix="/devices", tags=["devices"])


@router.post("/me", response_model=DeviceTokenRead)
def post_my_device(
    payload: DeviceTokenUpsert,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> DeviceTokenRead:
    try:
        return register_token(db, user, payload)
    except DeviceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc


@router.get("/me", response_model=list[DeviceTokenRead])
def get_my_devices(db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> list[DeviceTokenRead]:
    return list_mine(db, user)


@router.delete("/me")
def delete_my_device(
    payload: DeviceTokenUpsert,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> dict:
    try:
        updated = unregister_token(db, user, payload.token)
    except DeviceError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc
    return {"updated": updated, "channel": "FCM"}
