from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.auth import AuthUserRead
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
from app.services.auth_service import auth_user_from_model
from app.services.family_service import (
    FamilyError,
    accept_link,
    add_emergency_contact,
    create_pairing_code,
    delete_emergency_contact,
    get_young_profile,
    invite_by_phone,
    link_by_code,
    list_children,
    list_emergency_contacts,
    list_guardians,
    reject_or_revoke,
    update_permissions,
    update_user_profile,
    update_young_profile,
)

router = APIRouter(prefix="/family", tags=["family"])


def _raise(exc: FamilyError) -> None:
    raise HTTPException(status_code=exc.status_code, detail=exc.message) from exc


@router.patch("/me", response_model=AuthUserRead)
def patch_me(
    payload: UserProfileUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> AuthUserRead:
    try:
        updated = update_user_profile(db, user, payload)
        return auth_user_from_model(updated)
    except FamilyError as exc:
        _raise(exc)


@router.get("/young/me", response_model=YoungPersonRead)
def young_me(user: User = Depends(get_current_user)) -> YoungPersonRead:
    try:
        return get_young_profile(user)
    except FamilyError as exc:
        _raise(exc)


@router.patch("/young/me", response_model=YoungPersonRead)
def patch_young_me(
    payload: YoungProfileUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> YoungPersonRead:
    try:
        return update_young_profile(db, user, payload)
    except FamilyError as exc:
        _raise(exc)


@router.post("/young/pairing-code", response_model=PairingCodeRead)
def pairing_code(db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> PairingCodeRead:
    try:
        return create_pairing_code(db, user)
    except FamilyError as exc:
        _raise(exc)


@router.get("/young/contacts", response_model=list[EmergencyContactRead])
def get_contacts(db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> list[EmergencyContactRead]:
    try:
        return list_emergency_contacts(db, user)
    except FamilyError as exc:
        _raise(exc)


@router.post("/young/contacts", response_model=EmergencyContactRead)
def post_contact(
    payload: EmergencyContactCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> EmergencyContactRead:
    try:
        return add_emergency_contact(db, user, payload)
    except FamilyError as exc:
        _raise(exc)


@router.delete("/young/contacts/{contact_id}", status_code=204)
def remove_contact(
    contact_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> None:
    try:
        delete_emergency_contact(db, user, contact_id)
    except FamilyError as exc:
        _raise(exc)


@router.get("/children", response_model=list[GuardianLinkRead])
def children(db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> list[GuardianLinkRead]:
    try:
        return list_children(db, user)
    except FamilyError as exc:
        _raise(exc)


@router.get("/guardians", response_model=list[GuardianLinkRead])
def guardians(db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> list[GuardianLinkRead]:
    try:
        return list_guardians(db, user)
    except FamilyError as exc:
        _raise(exc)


@router.post("/links/code", response_model=GuardianLinkRead)
def post_link_code(
    payload: LinkByCodeRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> GuardianLinkRead:
    try:
        return link_by_code(db, user, payload)
    except FamilyError as exc:
        _raise(exc)


@router.post("/links/invite", response_model=GuardianLinkRead)
def post_invite(
    payload: InviteByPhoneRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> GuardianLinkRead:
    try:
        return invite_by_phone(db, user, payload)
    except FamilyError as exc:
        _raise(exc)


@router.post("/links/{link_id}/accept", response_model=GuardianLinkRead)
def post_accept(
    link_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> GuardianLinkRead:
    try:
        return accept_link(db, user, link_id)
    except FamilyError as exc:
        _raise(exc)


@router.post("/links/{link_id}/revoke", status_code=204)
def post_revoke(
    link_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> None:
    try:
        reject_or_revoke(db, user, link_id)
    except FamilyError as exc:
        _raise(exc)


@router.patch("/links/{link_id}/permissions", response_model=GuardianLinkRead)
def patch_permissions(
    link_id: UUID,
    payload: PermissionsUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> GuardianLinkRead:
    try:
        return update_permissions(db, user, link_id, payload)
    except FamilyError as exc:
        _raise(exc)
