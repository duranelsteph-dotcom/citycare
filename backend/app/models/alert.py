from __future__ import annotations

from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.enums import AlertSeverity, AlertSource, AlertStatus, NotificationType
from app.db.base import Base
from app.db.types import enum_column
from app.models.mixins import TimestampMixin, utcnow


class Alert(TimestampMixin, Base):
    """Alerte unique, quelle que soit la source (mobile, kit, proche, voix, système)."""

    __tablename__ = "alerts"

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    young_person_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("young_persons.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    triggered_by_user_id: Mapped[UUID | None] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    source: Mapped[AlertSource] = mapped_column(enum_column(AlertSource), nullable=False)
    status: Mapped[AlertStatus] = mapped_column(
        enum_column(AlertStatus),
        nullable=False,
        default=AlertStatus.CREATED,
        index=True,
    )
    severity: Mapped[AlertSeverity] = mapped_column(
        enum_column(AlertSeverity),
        nullable=False,
        default=AlertSeverity.HIGH,
    )
    latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    longitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    accuracy: Mapped[float | None] = mapped_column(Float, nullable=True)
    triggered_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=utcnow)
    battery_level: Mapped[int | None] = mapped_column(Integer, nullable=True)
    tracker_status: Mapped[str | None] = mapped_column(String(32), nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    last_known_latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    last_known_longitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    last_known_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    young_person: Mapped[YoungPerson] = relationship("YoungPerson", back_populates="alerts")


class AppNotification(TimestampMixin, Base):
    __tablename__ = "notifications"

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    recipient_user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    notification_type: Mapped[NotificationType] = mapped_column(enum_column(NotificationType), nullable=False)
    title: Mapped[str] = mapped_column(String(160), nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    is_read: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    alert_id: Mapped[UUID | None] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("alerts.id", ondelete="SET NULL"),
        nullable=True,
    )
    case_id: Mapped[UUID | None] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("missing_person_cases.id", ondelete="SET NULL"),
        nullable=True,
    )
    payload: Mapped[str | None] = mapped_column(Text, nullable=True)

    recipient: Mapped[User] = relationship("User", back_populates="notifications")
