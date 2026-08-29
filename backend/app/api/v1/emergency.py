from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.entities import EmergencySnapshot
from app.services.emergency_service import EmergencyError, snapshot

router = APIRouter(prefix="/emergency", tags=["emergency"])


@router.get("/children/{young_person_id}", response_model=EmergencySnapshot)
def get_emergency(
    young_person_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> EmergencySnapshot:
    try:
        return snapshot(db, user, young_person_id)
    except EmergencyError as exc:
        raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc
