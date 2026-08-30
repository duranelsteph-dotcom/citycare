"""Cercle nommé (style Life360) posé par-dessus GuardianLink, sans le remplacer.

Quitter un cercle ou retirer un membre n'efface pas les liens dyadiques
GuardianLink : le cercle est un regroupement d'utilisateurs, pas une source
de permissions de localisation.
"""

from __future__ import annotations

from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import DateTime, ForeignKey, String, UniqueConstraint, Uuid
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.enums import CircleRole
from app.db.base import Base
from app.db.types import enum_column
from app.models.mixins import TimestampMixin, utcnow


class Circle(TimestampMixin, Base):
    """Groupe nommé (ex. « Famille Steph ») avec un code d'invitation unique."""

    __tablename__ = "circles"

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    name: Mapped[str] = mapped_column(String(80), nullable=False)
    invite_code: Mapped[str] = mapped_column(String(6), nullable=False, unique=True, index=True)
    created_by_user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    memberships: Mapped[list[CircleMembership]] = relationship(
        "CircleMembership",
        back_populates="circle",
        cascade="all, delete-orphan",
    )
    creator: Mapped[User] = relationship("User", foreign_keys=[created_by_user_id])


class CircleMembership(Base):
    """Appartenance à un cercle. Le rôle est local au cercle, pas à GuardianLink."""

    __tablename__ = "circle_memberships"
    __table_args__ = (UniqueConstraint("circle_id", "user_id", name="uq_circle_user"),)

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    circle_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("circles.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    role: Mapped[CircleRole] = mapped_column(enum_column(CircleRole), nullable=False, default=CircleRole.MEMBER)
    joined_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=utcnow)

    circle: Mapped[Circle] = relationship("Circle", back_populates="memberships")
    user: Mapped[User] = relationship("User", foreign_keys=[user_id])
