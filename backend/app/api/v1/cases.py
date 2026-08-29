from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.core.enums import CaseStatus
from app.db.session import get_db
from app.models.user import User
from app.schemas.case import CaseCreate
from app.schemas.testimony import TestimonyCreate
from app.schemas.entities import (
    AiAnalysisRead,
    MissingPersonCaseRead,
    SearchIntelligenceRead,
    SearchZoneRead,
    TestimonyRead,
    TrajectoryRead,
)
from app.services.case_service import (
    CaseError,
    create_case,
    get_case,
    list_for_guardian,
    list_own,
    set_status,
)
from app.services.family_service import FamilyError
from app.services.intelligence_service import get_intelligence, refresh_intelligence
from app.services.ai_service import get_ai_analysis, refresh_ai_analysis
from app.services.location_service import LocationError
from app.services.search_zone_service import list_search_zones
from app.services.consistency_service import refresh_all as refresh_testimony_consistencies
from app.services.testimony_service import (
    TestimonyError,
    create_testimony,
    list_testimonies,
    reject_testimony,
    review_testimony,
    verify_testimony,
)
from app.services.trajectory_service import case_trajectory

router = APIRouter(prefix="/cases", tags=["cases"])


def _http(exc: CaseError | FamilyError | LocationError | TestimonyError) -> None:
    raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc


@router.post("", response_model=MissingPersonCaseRead)
def post_case(
    payload: CaseCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> MissingPersonCaseRead:
    try:
        return create_case(db, user, payload)
    except (CaseError, FamilyError) as exc:
        _http(exc)


@router.get("/me", response_model=list[MissingPersonCaseRead])
def get_my_cases(db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> list[MissingPersonCaseRead]:
    try:
        return list_own(db, user)
    except (CaseError, FamilyError) as exc:
        _http(exc)


@router.get("/mine", response_model=list[MissingPersonCaseRead])
def get_guardian_cases(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[MissingPersonCaseRead]:
    try:
        return list_for_guardian(db, user)
    except (CaseError, FamilyError) as exc:
        _http(exc)


@router.get("/{case_id}", response_model=MissingPersonCaseRead)
def get_one(
    case_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> MissingPersonCaseRead:
    try:
        return get_case(db, user, case_id)
    except (CaseError, FamilyError) as exc:
        _http(exc)


@router.get("/{case_id}/trajectory", response_model=TrajectoryRead)
def get_case_trajectory(
    case_id: UUID,
    hours: int = Query(default=6, ge=1, le=24),
    limit: int = Query(default=200, ge=1, le=200),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> TrajectoryRead:
    try:
        return case_trajectory(db, user, case_id, hours=hours, limit=limit)
    except (CaseError, FamilyError, LocationError) as exc:
        _http(exc)


@router.get("/{case_id}/intelligence", response_model=SearchIntelligenceRead)
def get_case_intelligence(
    case_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> SearchIntelligenceRead:
    try:
        return get_intelligence(db, user, case_id)
    except (CaseError, FamilyError) as exc:
        _http(exc)


@router.post("/{case_id}/intelligence", response_model=SearchIntelligenceRead)
def post_case_intelligence(
    case_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> SearchIntelligenceRead:
    try:
        return refresh_intelligence(db, user, case_id)
    except (CaseError, FamilyError) as exc:
        _http(exc)


@router.get("/{case_id}/ai-analysis", response_model=AiAnalysisRead)
def get_case_ai_analysis(
    case_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> AiAnalysisRead:
    try:
        return get_ai_analysis(db, user, case_id)
    except (CaseError, FamilyError) as exc:
        _http(exc)


@router.post("/{case_id}/ai-analysis", response_model=AiAnalysisRead)
def post_case_ai_analysis(
    case_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> AiAnalysisRead:
    try:
        return refresh_ai_analysis(db, user, case_id)
    except (CaseError, FamilyError) as exc:
        _http(exc)


@router.get("/{case_id}/search-zones", response_model=list[SearchZoneRead])
def get_case_search_zones(
    case_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[SearchZoneRead]:
    try:
        return list_search_zones(db, user, case_id)
    except (CaseError, FamilyError) as exc:
        _http(exc)


@router.get("/{case_id}/testimonies", response_model=list[TestimonyRead])
def get_case_testimonies(
    case_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[TestimonyRead]:
    try:
        return list_testimonies(db, user, case_id)
    except (CaseError, FamilyError, TestimonyError) as exc:
        _http(exc)


@router.post("/{case_id}/testimonies", response_model=TestimonyRead)
def post_case_testimony(
    case_id: UUID,
    payload: TestimonyCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> TestimonyRead:
    try:
        return create_testimony(db, user, case_id, payload)
    except (CaseError, FamilyError, TestimonyError) as exc:
        _http(exc)


@router.post("/{case_id}/testimonies/consistency", response_model=list[TestimonyRead])
def post_refresh_testimony_consistencies(
    case_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> list[TestimonyRead]:
    try:
        return refresh_testimony_consistencies(db, user, case_id)
    except (CaseError, FamilyError, TestimonyError) as exc:
        _http(exc)


@router.post("/{case_id}/testimonies/{testimony_id}/review", response_model=TestimonyRead)
def post_review_testimony(
    case_id: UUID,
    testimony_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> TestimonyRead:
    try:
        return review_testimony(db, user, case_id, testimony_id)
    except (CaseError, FamilyError, TestimonyError) as exc:
        _http(exc)


@router.post("/{case_id}/testimonies/{testimony_id}/verify", response_model=TestimonyRead)
def post_verify_testimony(
    case_id: UUID,
    testimony_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> TestimonyRead:
    try:
        return verify_testimony(db, user, case_id, testimony_id)
    except (CaseError, FamilyError, TestimonyError) as exc:
        _http(exc)


@router.post("/{case_id}/testimonies/{testimony_id}/reject", response_model=TestimonyRead)
def post_reject_testimony(
    case_id: UUID,
    testimony_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> TestimonyRead:
    try:
        return reject_testimony(db, user, case_id, testimony_id)
    except (CaseError, FamilyError, TestimonyError) as exc:
        _http(exc)


@router.post("/{case_id}/searching", response_model=MissingPersonCaseRead)
def post_searching(
    case_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> MissingPersonCaseRead:
    try:
        return set_status(db, user, case_id, CaseStatus.SEARCHING)
    except (CaseError, FamilyError) as exc:
        _http(exc)


@router.post("/{case_id}/found", response_model=MissingPersonCaseRead)
def post_found(
    case_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> MissingPersonCaseRead:
    try:
        return set_status(db, user, case_id, CaseStatus.FOUND)
    except (CaseError, FamilyError) as exc:
        _http(exc)


@router.post("/{case_id}/close", response_model=MissingPersonCaseRead)
def post_close(
    case_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> MissingPersonCaseRead:
    try:
        return set_status(db, user, case_id, CaseStatus.CLOSED)
    except (CaseError, FamilyError) as exc:
        _http(exc)
