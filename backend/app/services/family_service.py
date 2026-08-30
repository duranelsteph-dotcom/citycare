import secrets
from datetime import datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy.orm import Session, joinedload

from app.core.enums import GuardianLinkStatus, GuardianRelation, UserRole
from app.models.people import EmergencyContact, GuardianLink, YoungPerson
from app.models.user import User
from app.schemas.entities import EmergencyContactRead, GuardianLinkRead, YoungPersonRead
from app.schemas.family import (
    EmergencyContactCreate,
    InviteByPhoneRequest,
    LinkByCodeRequest,
    PairingCodeRead,
    PermissionsUpdate,
    UserProfileUpdate,
    YoungProfileUpdate,
)

PAIRING_TTL = timedelta(minutes=15)


class FamilyError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _defaults(relation: GuardianRelation) -> dict:
    if relation == GuardianRelation.PARENT:
        return {
            "can_view_location": False,
            "can_receive_alerts": True,
            "can_trigger_alert": False,
            "can_report_missing": True,
            "can_manage_zones": True,
            "can_manage_tracker": True,
        }
    return {
        "can_view_location": False,
        "can_receive_alerts": True,
        "can_trigger_alert": False,
        "can_report_missing": False,
        "can_manage_zones": False,
        "can_manage_tracker": False,
    }


def _link_query(db: Session):
    return db.query(GuardianLink).options(
        joinedload(GuardianLink.guardian),
        joinedload(GuardianLink.young_person).joinedload(YoungPerson.user),
    )


def link_to_read(link: GuardianLink) -> GuardianLinkRead:
    payload = GuardianLinkRead.model_validate(link)
    guardian = link.guardian
    young = link.young_person
    return payload.model_copy(
        update={
            "guardian_name": guardian.full_name if guardian else None,
            "guardian_phone": guardian.phone if guardian else None,
            "young_display_name": young.display_name if young else None,
            "young_phone": young.user.phone if young and young.user else None,
            "young_photo_url": (
                (young.photo_url or (young.user.photo_url if young.user else None)) if young else None
            ),
        }
    )


def require_young(user: User) -> YoungPerson:
    if user.role != UserRole.YOUNG or user.young_profile is None:
        raise FamilyError("Réservé au compte jeune", 403)
    return user.young_profile


def require_guardian_role(user: User) -> None:
    if user.role not in {UserRole.PARENT, UserRole.RELATIVE}:
        raise FamilyError("Réservé au parent ou au proche autorisé", 403)


def update_user_profile(db: Session, user: User, payload: UserProfileUpdate) -> User:
    if payload.full_name:
        user.full_name = payload.full_name
        if user.young_profile is not None:
            user.young_profile.display_name = payload.full_name
    db.commit()
    db.refresh(user)
    return user


def get_young_profile(user: User) -> YoungPersonRead:
    young = require_young(user)
    return YoungPersonRead.model_validate(young)


def update_young_profile(db: Session, user: User, payload: YoungProfileUpdate) -> YoungPersonRead:
    young = require_young(user)
    if payload.display_name:
        young.display_name = payload.display_name
        user.full_name = payload.display_name
    if payload.birth_date is not None:
        young.birth_date = payload.birth_date
    if payload.notes is not None:
        young.notes = payload.notes
    db.commit()
    db.refresh(young)
    return YoungPersonRead.model_validate(young)


def create_pairing_code(db: Session, user: User) -> PairingCodeRead:
    young = require_young(user)
    for _ in range(12):
        code = f"{secrets.randbelow(1_000_000):06d}"
        taken = db.query(YoungPerson).filter(YoungPerson.pairing_code == code).one_or_none()
        if taken is None or taken.id == young.id:
            young.pairing_code = code
            young.pairing_code_expires_at = _utcnow() + PAIRING_TTL
            db.commit()
            db.refresh(young)
            return PairingCodeRead(code=code, expires_at=young.pairing_code_expires_at)
    raise FamilyError("Impossible de générer un code, réessayez", 500)


def _relation_from_role(user: User, requested: GuardianRelation | None = None) -> GuardianRelation:
    if user.role == UserRole.PARENT:
        return GuardianRelation.PARENT
    if user.role == UserRole.RELATIVE:
        return requested if requested in {GuardianRelation.RELATIVE, GuardianRelation.OTHER} else GuardianRelation.RELATIVE
    return GuardianRelation.OTHER


def _upsert_link(
    db: Session,
    *,
    guardian: User,
    young: YoungPerson,
    relation: GuardianRelation,
    status: GuardianLinkStatus,
) -> GuardianLink:
    existing = (
        db.query(GuardianLink)
        .filter(
            GuardianLink.guardian_user_id == guardian.id,
            GuardianLink.young_person_id == young.id,
        )
        .one_or_none()
    )
    if existing is None:
        link = GuardianLink(
            guardian_user_id=guardian.id,
            young_person_id=young.id,
            relation=relation,
            status=status,
            **_defaults(relation),
        )
        db.add(link)
        return link
    if existing.status == GuardianLinkStatus.ACTIVE:
        raise FamilyError("Ce jeune est déjà rattaché à votre compte", 409)
    existing.relation = relation
    existing.status = status
    return existing


def link_by_code(db: Session, guardian: User, payload: LinkByCodeRequest) -> GuardianLinkRead:
    require_guardian_role(guardian)
    now = _utcnow()
    young = (
        db.query(YoungPerson)
        .options(joinedload(YoungPerson.user))
        .filter(YoungPerson.pairing_code == payload.code)
        .one_or_none()
    )
    if young is None or young.pairing_code_expires_at is None:
        raise FamilyError("Code invalide ou expiré", 404)
    expires = young.pairing_code_expires_at
    if expires.tzinfo is None:
        expires = expires.replace(tzinfo=timezone.utc)
    if expires < now:
        raise FamilyError("Code invalide ou expiré", 404)
    if young.user_id == guardian.id:
        raise FamilyError("Vous ne pouvez pas vous rattacher à vous-même", 400)
    relation = _relation_from_role(guardian)
    link = _upsert_link(db, guardian=guardian, young=young, relation=relation, status=GuardianLinkStatus.ACTIVE)
    young.pairing_code = None
    young.pairing_code_expires_at = None
    db.commit()
    loaded = _link_query(db).filter(GuardianLink.id == link.id).one()
    return link_to_read(loaded)


def invite_by_phone(db: Session, guardian: User, payload: InviteByPhoneRequest) -> GuardianLinkRead:
    require_guardian_role(guardian)
    target = (
        db.query(User)
        .options(joinedload(User.young_profile))
        .filter(User.phone == payload.phone)
        .one_or_none()
    )
    if target is None or target.role != UserRole.YOUNG or target.young_profile is None:
        raise FamilyError("Aucun compte jeune avec ce numéro", 404)
    if target.id == guardian.id:
        raise FamilyError("Vous ne pouvez pas vous rattacher à vous-même", 400)
    relation = _relation_from_role(guardian, payload.relation)
    link = _upsert_link(
        db,
        guardian=guardian,
        young=target.young_profile,
        relation=relation,
        status=GuardianLinkStatus.PENDING,
    )
    db.commit()
    loaded = _link_query(db).filter(GuardianLink.id == link.id).one()
    return link_to_read(loaded)


def list_children(db: Session, guardian: User) -> list[GuardianLinkRead]:
    require_guardian_role(guardian)
    links = (
        _link_query(db)
        .filter(GuardianLink.guardian_user_id == guardian.id)
        .filter(GuardianLink.status != GuardianLinkStatus.REVOKED)
        .all()
    )
    return [link_to_read(link) for link in links]


def list_guardians(db: Session, user: User) -> list[GuardianLinkRead]:
    young = require_young(user)
    links = (
        _link_query(db)
        .filter(GuardianLink.young_person_id == young.id)
        .filter(GuardianLink.status != GuardianLinkStatus.REVOKED)
        .all()
    )
    return [link_to_read(link) for link in links]


def accept_link(db: Session, user: User, link_id: UUID) -> GuardianLinkRead:
    young = require_young(user)
    link = _link_query(db).filter(GuardianLink.id == link_id).one_or_none()
    if link is None or link.young_person_id != young.id:
        raise FamilyError("Invitation introuvable", 404)
    if link.status != GuardianLinkStatus.PENDING:
        raise FamilyError("Cette invitation n'est plus en attente", 409)
    link.status = GuardianLinkStatus.ACTIVE
    db.commit()
    return link_to_read(link)


def reject_or_revoke(db: Session, user: User, link_id: UUID) -> None:
    link = _link_query(db).filter(GuardianLink.id == link_id).one_or_none()
    if link is None:
        raise FamilyError("Lien introuvable", 404)
    is_young = user.young_profile is not None and link.young_person_id == user.young_profile.id
    is_guardian = link.guardian_user_id == user.id
    if not is_young and not is_guardian:
        raise FamilyError("Accès refusé", 403)
    link.status = GuardianLinkStatus.REVOKED
    db.commit()


def update_permissions(db: Session, user: User, link_id: UUID, payload: PermissionsUpdate) -> GuardianLinkRead:
    young = require_young(user)
    link = _link_query(db).filter(GuardianLink.id == link_id).one_or_none()
    if link is None or link.young_person_id != young.id:
        raise FamilyError("Lien introuvable", 404)
    if link.status != GuardianLinkStatus.ACTIVE:
        raise FamilyError("Seuls les rattachements actifs ont des permissions", 409)
    for field in (
        "can_view_location",
        "can_receive_alerts",
        "can_trigger_alert",
        "can_report_missing",
        "can_manage_zones",
        "can_manage_tracker",
    ):
        value = getattr(payload, field)
        if value is not None:
            setattr(link, field, value)
    db.commit()
    db.refresh(link)
    return link_to_read(link)


def list_emergency_contacts(db: Session, user: User) -> list[EmergencyContactRead]:
    young = require_young(user)
    rows = (
        db.query(EmergencyContact)
        .filter(EmergencyContact.young_person_id == young.id)
        .order_by(EmergencyContact.name)
        .all()
    )
    return [EmergencyContactRead.model_validate(row) for row in rows]


def add_emergency_contact(db: Session, user: User, payload: EmergencyContactCreate) -> EmergencyContactRead:
    young = require_young(user)
    row = EmergencyContact(young_person_id=young.id, name=payload.name.strip(), phone=payload.phone)
    db.add(row)
    db.commit()
    db.refresh(row)
    return EmergencyContactRead.model_validate(row)


def delete_emergency_contact(db: Session, user: User, contact_id: UUID) -> None:
    young = require_young(user)
    row = (
        db.query(EmergencyContact)
        .filter(EmergencyContact.id == contact_id, EmergencyContact.young_person_id == young.id)
        .one_or_none()
    )
    if row is None:
        raise FamilyError("Contact introuvable", 404)
    db.delete(row)
    db.commit()
