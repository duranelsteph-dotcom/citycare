from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.schemas.entities import AlertRead, TrackerLocationRead
from app.schemas.tracker import (
    IotConfigRead,
    IotConfigRequest,
    IotEventRequest,
    IotEventResult,
    IotLocationRequest,
    IotSosRequest,
)
from app.services.alert_service import AlertError, trigger_iot_sos
from app.services.iot_service import kit_config, record_kit_location, report_kit_event

router = APIRouter(prefix="/iot", tags=["iot"])


@router.post("/sos", response_model=AlertRead)
def post_iot_sos(payload: IotSosRequest, db: Session = Depends(get_db)) -> AlertRead:
    try:
        return trigger_iot_sos(db, payload.device_uid, payload.device_secret, payload)
    except AlertError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc


@router.post("/location", response_model=TrackerLocationRead)
def post_iot_location(payload: IotLocationRequest, db: Session = Depends(get_db)) -> TrackerLocationRead:
    try:
        return record_kit_location(db, payload)
    except AlertError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc


@router.post("/events", response_model=IotEventResult)
def post_iot_event(payload: IotEventRequest, db: Session = Depends(get_db)) -> IotEventResult:
    try:
        return report_kit_event(db, payload)
    except AlertError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc


@router.post("/config", response_model=IotConfigRead)
def post_iot_config(payload: IotConfigRequest, db: Session = Depends(get_db)) -> IotConfigRead:
    try:
        return kit_config(db, payload.device_uid, payload.device_secret)
    except AlertError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc
