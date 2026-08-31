"""Destinataires transverses : comptes autorité actifs. Pas de SMS."""

from uuid import UUID

from sqlalchemy.orm import Session

from app.core.enums import UserRole
from app.models.user import User


def active_authority_ids(db: Session) -> list[UUID]:
    """Tous les comptes AUTHORITY actifs (seed …004 inclus)."""
    rows = (
        db.query(User.id)
        .filter(User.role == UserRole.AUTHORITY, User.is_active.is_(True))
        .all()
    )
    return [row[0] for row in rows]
