from __future__ import annotations

from datetime import date, datetime
from uuid import UUID, uuid4

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, String, Text, UniqueConstraint, Uuid
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.enums import GuardianLinkStatus, GuardianRelation
from app.db.base import Base
from app.db.types import enum_column
from app.models.mixins import TimestampMixin


class YoungPerson(TimestampMixin, Base):
    """Profil d'un enfant ou jeune. Acteur central du système, pas un objet surveillé passif."""

    __tablename__ = "young_persons"

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    display_name: Mapped[str] = mapped_column(String(120), nullable=False)
    birth_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    photo_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    pairing_code: Mapped[str | None] = mapped_column(String(8), nullable=True, unique=True, index=True)
    pairing_code_expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    user: Mapped[User] = relationship("User", back_populates="young_profile")
    guardians: Mapped[list[GuardianLink]] = relationship("GuardianLink", back_populates="young_person")
    emergency_contacts: Mapped[list[EmergencyContact]] = relationship(
        "EmergencyContact",
        back_populates="young_person",
    )
    trackers: Mapped[list[GPSTracker]] = relationship("GPSTracker", back_populates="young_person")
    safety_zones: Mapped[list[SafetyZone]] = relationship("SafetyZone", back_populates="young_person")
    alerts: Mapped[list[Alert]] = relationship("Alert", back_populates="young_person")
    cases: Mapped[list[MissingPersonCase]] = relationship(
        "MissingPersonCase",
        back_populates="young_person",
    )


class GuardianLink(TimestampMixin, Base):
    """Lien parent / proche autorisé, avec permissions explicites (pas d'accès automatique)."""

    __tablename__ = "guardian_links"
    __table_args__ = (UniqueConstraint("guardian_user_id", "young_person_id", name="uq_guardian_young"),)

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    guardian_user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    young_person_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("young_persons.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    relation: Mapped[GuardianRelation] = mapped_column(enum_column(GuardianRelation), nullable=False)
    status: Mapped[GuardianLinkStatus] = mapped_column(
        enum_column(GuardianLinkStatus),
        nullable=False,
        default=GuardianLinkStatus.PENDING,
        index=True,
    )
    can_view_location: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    can_receive_alerts: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    can_trigger_alert: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    can_report_missing: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    can_manage_zones: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    can_manage_tracker: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    guardian: Mapped[User] = relationship(
        "User",
        back_populates="guardian_links",
        foreign_keys=[guardian_user_id],
    )
    young_person: Mapped[YoungPerson] = relationship("YoungPerson", back_populates="guardians")


class EmergencyContact(TimestampMixin, Base):
    __tablename__ = "emergency_contacts"

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    young_person_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("young_persons.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    phone: Mapped[str] = mapped_column(String(32), nullable=False)
    user_id: Mapped[UUID | None] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )

    young_person: Mapped[YoungPerson] = relationship("YoungPerson", back_populates="emergency_contacts")
