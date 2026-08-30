"""Cercle nommé par-dessus GuardianLink.

Quitter / retirer un membre n'efface pas GuardianLink : le cercle groupe des
comptes, les permissions de localisation restent dyadiques.
"""

from __future__ import annotations

import secrets
from uuid import UUID

from sqlalchemy.orm import Session, joinedload

from app.core.enums import CircleRole, GuardianLinkStatus, UserRole
from app.models.circle import Circle, CircleMembership
from app.models.people import GuardianLink, YoungPerson
from app.models.user import User
from app.schemas.circle import (
    CircleCreate,
    CircleInviteCodeRead,
    CircleJoinRequest,
    CircleMemberRead,
    CircleRead,
    CircleUpdate,
)

# Alphabet sans 0/O/1/I pour limiter les confusions à la saisie.
_INVITE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


class CircleError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


def _require_circle_role(user: User) -> None:
    if user.role == UserRole.AUTHORITY:
        raise CircleError("Les comptes autorité n'utilisent pas les cercles", 403)


def _unique_invite_code(db: Session) -> str:
    for _ in range(16):
        code = "".join(secrets.choice(_INVITE_ALPHABET) for _ in range(6))
        taken = db.query(Circle).filter(Circle.invite_code == code).one_or_none()
        if taken is None:
            return code
    raise CircleError("Impossible de générer un code, réessayez", 500)


def _membership_of(db: Session, circle_id: UUID, user_id: UUID) -> CircleMembership | None:
    return (
        db.query(CircleMembership)
        .options(joinedload(CircleMembership.circle))
        .filter(CircleMembership.circle_id == circle_id, CircleMembership.user_id == user_id)
        .one_or_none()
    )


def _require_membership(db: Session, circle_id: UUID, user: User) -> CircleMembership:
    membership = _membership_of(db, circle_id, user.id)
    if membership is None:
        raise CircleError("Vous n'appartenez pas à ce cercle", 403)
    return membership


def _circle_to_read(circle: Circle, user_id: UUID) -> CircleRead:
    my_role = next((item.role for item in circle.memberships if item.user_id == user_id), CircleRole.MEMBER)
    return CircleRead(
        id=circle.id,
        name=circle.name,
        invite_code=circle.invite_code,
        created_by_user_id=circle.created_by_user_id,
        my_role=my_role,
        member_count=len(circle.memberships),
        created_at=circle.created_at,
        updated_at=circle.updated_at,
    )


def _location_from_existing_link(db: Session, viewer: User, member: User) -> tuple[bool, UUID | None]:
    """Relit GuardianLink.can_view_location. N'accorde rien de nouveau."""
    if member.young_profile is not None:
        link = (
            db.query(GuardianLink)
            .filter(
                GuardianLink.guardian_user_id == viewer.id,
                GuardianLink.young_person_id == member.young_profile.id,
                GuardianLink.status == GuardianLinkStatus.ACTIVE,
            )
            .one_or_none()
        )
        if link is not None:
            return link.can_view_location, link.id
    if viewer.young_profile is not None:
        link = (
            db.query(GuardianLink)
            .filter(
                GuardianLink.guardian_user_id == member.id,
                GuardianLink.young_person_id == viewer.young_profile.id,
                GuardianLink.status == GuardianLinkStatus.ACTIVE,
            )
            .one_or_none()
        )
        if link is not None:
            return link.can_view_location, link.id
    return False, None


def list_circles(db: Session, user: User) -> list[CircleRead]:
    _require_circle_role(user)
    circle_ids = db.query(CircleMembership.circle_id).filter(CircleMembership.user_id == user.id)
    rows = (
        db.query(Circle)
        .options(joinedload(Circle.memberships))
        .filter(Circle.id.in_(circle_ids))
        .order_by(Circle.created_at.asc())
        .all()
    )
    return [_circle_to_read(circle, user.id) for circle in rows]


def create_circle(db: Session, user: User, payload: CircleCreate) -> CircleRead:
    _require_circle_role(user)
    circle = Circle(
        name=payload.name,
        invite_code=_unique_invite_code(db),
        created_by_user_id=user.id,
    )
    db.add(circle)
    db.flush()
    db.add(CircleMembership(circle_id=circle.id, user_id=user.id, role=CircleRole.OWNER))
    db.commit()
    db.refresh(circle)
    circle = (
        db.query(Circle)
        .options(joinedload(Circle.memberships))
        .filter(Circle.id == circle.id)
        .one()
    )
    return _circle_to_read(circle, user.id)


def get_circle(db: Session, user: User, circle_id: UUID) -> CircleRead:
    _require_circle_role(user)
    membership = _require_membership(db, circle_id, user)
    circle = (
        db.query(Circle)
        .options(joinedload(Circle.memberships))
        .filter(Circle.id == membership.circle_id)
        .one()
    )
    return _circle_to_read(circle, user.id)


def update_circle(db: Session, user: User, circle_id: UUID, payload: CircleUpdate) -> CircleRead:
    _require_circle_role(user)
    membership = _require_membership(db, circle_id, user)
    if membership.role != CircleRole.OWNER:
        raise CircleError("Seul le propriétaire peut renommer le cercle", 403)
    if payload.name:
        membership.circle.name = payload.name
    db.commit()
    circle = (
        db.query(Circle)
        .options(joinedload(Circle.memberships))
        .filter(Circle.id == circle_id)
        .one()
    )
    return _circle_to_read(circle, user.id)


def get_invite(db: Session, user: User, circle_id: UUID) -> CircleInviteCodeRead:
    """Code actuel. Tout membre le voit déjà sur CircleRead ; cet endpoint évite un GET cercle complet."""
    _require_circle_role(user)
    membership = _require_membership(db, circle_id, user)
    return CircleInviteCodeRead(invite_code=membership.circle.invite_code)


def regenerate_invite(db: Session, user: User, circle_id: UUID) -> CircleInviteCodeRead:
    _require_circle_role(user)
    membership = _require_membership(db, circle_id, user)
    if membership.role != CircleRole.OWNER:
        raise CircleError("Seul le propriétaire peut régénérer le code", 403)
    membership.circle.invite_code = _unique_invite_code(db)
    db.commit()
    db.refresh(membership.circle)
    return CircleInviteCodeRead(invite_code=membership.circle.invite_code)


def join_circle(db: Session, user: User, payload: CircleJoinRequest) -> CircleRead:
    _require_circle_role(user)
    circle = (
        db.query(Circle)
        .options(joinedload(Circle.memberships))
        .filter(Circle.invite_code == payload.code)
        .one_or_none()
    )
    if circle is None:
        raise CircleError("Code d'invitation inconnu", 404)
    existing = next((item for item in circle.memberships if item.user_id == user.id), None)
    if existing is None:
        db.add(CircleMembership(circle_id=circle.id, user_id=user.id, role=CircleRole.MEMBER))
        db.commit()
        circle = (
            db.query(Circle)
            .options(joinedload(Circle.memberships))
            .filter(Circle.id == circle.id)
            .one()
        )
    return _circle_to_read(circle, user.id)


def leave_circle(db: Session, user: User, circle_id: UUID) -> None:
    """Retire l'appartenance. Les GuardianLink du compte restent intacts."""
    _require_circle_role(user)
    membership = _require_membership(db, circle_id, user)
    others = (
        db.query(CircleMembership)
        .filter(CircleMembership.circle_id == circle_id, CircleMembership.user_id != user.id)
        .order_by(CircleMembership.joined_at.asc())
        .all()
    )
    was_owner = membership.role == CircleRole.OWNER
    db.delete(membership)
    if not others:
        circle = db.query(Circle).filter(Circle.id == circle_id).one_or_none()
        if circle is not None:
            db.delete(circle)
    elif was_owner:
        others[0].role = CircleRole.OWNER
    db.commit()


def list_members(db: Session, user: User, circle_id: UUID) -> list[CircleMemberRead]:
    _require_circle_role(user)
    _require_membership(db, circle_id, user)
    rows = (
        db.query(CircleMembership)
        .options(
            joinedload(CircleMembership.user).joinedload(User.young_profile),
        )
        .filter(CircleMembership.circle_id == circle_id)
        .order_by(CircleMembership.joined_at.asc())
        .all()
    )
    members: list[CircleMemberRead] = []
    for row in rows:
        member_user = row.user
        young: YoungPerson | None = member_user.young_profile
        can_view, link_id = _location_from_existing_link(db, user, member_user)
        photo = member_user.photo_url
        if not photo and young is not None:
            photo = young.photo_url
        members.append(
            CircleMemberRead(
                user_id=member_user.id,
                full_name=member_user.full_name,
                user_role=member_user.role,
                circle_role=row.role,
                joined_at=row.joined_at,
                young_person_id=young.id if young is not None else None,
                photo_url=photo,
                can_view_location=can_view,
                guardian_link_id=link_id,
            )
        )
    return members


def remove_member(db: Session, user: User, circle_id: UUID, target_user_id: UUID) -> None:
    """Retire un membre du cercle. N'efface pas son GuardianLink."""
    _require_circle_role(user)
    actor = _require_membership(db, circle_id, user)
    if actor.role != CircleRole.OWNER:
        raise CircleError("Seul le propriétaire peut retirer un membre", 403)
    if target_user_id == user.id:
        raise CircleError("Utilisez « quitter » pour vous retirer du cercle", 400)
    target = _membership_of(db, circle_id, target_user_id)
    if target is None:
        raise CircleError("Ce compte n'appartient pas au cercle", 404)
    db.delete(target)
    db.commit()
