from __future__ import annotations

import json
from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy.orm import Session

from app.core.enums import CaseStatus, GuardianLinkStatus, NotificationType, TestimonyStatus, UserRole
from app.models.alert import AppNotification
from app.models.people import GuardianLink
from app.models.search import MissingPersonCase, Testimony
from app.models.user import User
from app.schemas.entities import TestimonyRead
from app.schemas.testimony import TestimonyCreate
from app.services.location_service import _aware

DISCLAIMER = (
    "Témoignage humain. Aide à la décision par règles métier. "
    "Ce n'est pas un kidnapping confirmé, pas la position actuelle, pas une preuve."
)
OPEN_CASE = {CaseStatus.OPEN, CaseStatus.SEARCHING}
TERMINAL = {TestimonyStatus.VERIFIED, TestimonyStatus.REJECTED}


class TestimonyError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def to_read(row: Testimony, submitter_name: str | None = None) -> TestimonyRead:
    payload = TestimonyRead.model_validate(row)
    return payload.model_copy(
        update={
            "disclaimer": DISCLAIMER,
            "submitter_name": submitter_name,
        }
    )


def _submitter_name(db: Session, user_id: UUID | None) -> str | None:
    if user_id is None:
        return None
    user = db.query(User).filter(User.id == user_id).one_or_none()
    return user.full_name if user is not None else None


def _case(db: Session, case_id: UUID) -> MissingPersonCase:
    from app.services.case_service import CaseError, _query

    row = _query(db).filter(MissingPersonCase.id == case_id).one_or_none()
    if row is None:
        raise CaseError("Dossier introuvable", 404)
    return row


def list_testimonies(db: Session, user: User, case_id: UUID) -> list[TestimonyRead]:
    from app.services.case_service import get_case

    get_case(db, user, case_id)
    rows = (
        db.query(Testimony)
        .filter(Testimony.case_id == case_id)
        .order_by(Testimony.observed_at.desc())
        .all()
    )
    return [to_read(row, _submitter_name(db, row.submitted_by_user_id)) for row in rows]


def create_testimony(db: Session, user: User, case_id: UUID, payload: TestimonyCreate) -> TestimonyRead:
    from app.services.case_service import _active_link

    if user.role == UserRole.YOUNG:
        raise TestimonyError("Le jeune concerné ne dépose pas un témoignage sur son propre dossier", 403)
    case = _case(db, case_id)
    _active_link(db, user, case.young_person_id)
    if case.status not in OPEN_CASE:
        raise TestimonyError("Ce dossier est clos : on n'y ajoute plus de témoignage", 409)
    observed = _aware(payload.observed_at) if payload.observed_at is not None else _utcnow()
    photo = payload.photo_url.strip() if payload.photo_url else None
    row = Testimony(
        case_id=case.id,
        submitted_by_user_id=user.id,
        description=payload.description.strip(),
        latitude=payload.latitude,
        longitude=payload.longitude,
        observed_at=observed,
        photo_url=photo or None,
        status=TestimonyStatus.SUBMITTED,
    )
    db.add(row)
    db.flush()
    from app.services.consistency_service import apply_consistency

    apply_consistency(db, case, row)
    _notify_new(db, case, row)
    db.commit()
    loaded = db.query(Testimony).filter(Testimony.id == row.id).one()
    return to_read(loaded, user.full_name)


def _load_for_moderation(db: Session, user: User, case_id: UUID, testimony_id: UUID) -> Testimony:
    from app.services.case_service import _can_report

    case = _case(db, case_id)
    _can_report(db, user, case.young_person_id)
    row = (
        db.query(Testimony)
        .filter(Testimony.id == testimony_id, Testimony.case_id == case_id)
        .one_or_none()
    )
    if row is None:
        raise TestimonyError("Témoignage introuvable", 404)
    return row


def review_testimony(db: Session, user: User, case_id: UUID, testimony_id: UUID) -> TestimonyRead:
    row = _load_for_moderation(db, user, case_id, testimony_id)
    if row.status in TERMINAL:
        raise TestimonyError("Ce témoignage a déjà été tranché", 409)
    row.status = TestimonyStatus.UNDER_REVIEW
    db.commit()
    db.refresh(row)
    return to_read(row, _submitter_name(db, row.submitted_by_user_id))


def verify_testimony(db: Session, user: User, case_id: UUID, testimony_id: UUID) -> TestimonyRead:
    row = _load_for_moderation(db, user, case_id, testimony_id)
    if row.status in TERMINAL:
        raise TestimonyError("Ce témoignage a déjà été tranché", 409)
    row.status = TestimonyStatus.VERIFIED
    db.commit()
    db.refresh(row)
    return to_read(row, _submitter_name(db, row.submitted_by_user_id))


def reject_testimony(db: Session, user: User, case_id: UUID, testimony_id: UUID) -> TestimonyRead:
    row = _load_for_moderation(db, user, case_id, testimony_id)
    if row.status in TERMINAL:
        raise TestimonyError("Ce témoignage a déjà été tranché", 409)
    row.status = TestimonyStatus.REJECTED
    db.commit()
    db.refresh(row)
    return to_read(row, _submitter_name(db, row.submitted_by_user_id))


def _notify_new(db: Session, case: MissingPersonCase, row: Testimony) -> None:
    young = case.young_person
    level = row.consistency.value.lower() if row.consistency is not None else "indéterminée"
    body = (
        f"Un témoignage a été enregistré concernant {young.display_name}. "
        f"Cohérence estimée : {level}. "
        "Aide à la décision, pas une preuve, pas un kidnapping confirmé, pas la position actuelle."
    )
    payload = json.dumps(
        {
            "young_person_id": str(young.id),
            "young_display_name": young.display_name,
            "case_id": str(case.id),
            "testimony_id": str(row.id),
            "latitude": row.latitude,
            "longitude": row.longitude,
        },
        ensure_ascii=False,
    )
    recipients = [young.user_id]
    links = (
        db.query(GuardianLink)
        .filter(
            GuardianLink.young_person_id == young.id,
            GuardianLink.status == GuardianLinkStatus.ACTIVE,
            GuardianLink.can_receive_alerts.is_(True),
        )
        .all()
    )
    recipients.extend(link.guardian_user_id for link in links)
    seen: set[UUID] = set()
    for recipient_id in recipients:
        if recipient_id in seen or recipient_id == row.submitted_by_user_id:
            continue
        seen.add(recipient_id)
        db.add(
            AppNotification(
                recipient_user_id=recipient_id,
                notification_type=NotificationType.TESTIMONY,
                title="Nouveau témoignage",
                body=body,
                case_id=case.id,
                payload=payload,
            )
        )
