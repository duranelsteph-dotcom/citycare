from __future__ import annotations

from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.enums import LocationSource, TrackerEventType, TrackerStatus, TrackingMode
from app.db.base import Base
from app.db.types import enum_column
from app.models.mixins import TimestampMixin, utcnow


class GPSTracker(TimestampMixin, Base):
    """Kit IoT portable (bracelet, pendentif, boîtier). Communique avec le backend, pas avec Flutter."""

    __tablename__ = "gps_trackers"

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    young_person_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("young_persons.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    device_uid: Mapped[str] = mapped_column(String(64), unique=True, nullable=False, index=True)
    label: Mapped[str] = mapped_column(String(80), nullable=False, default="Kit CityCare")
    status: Mapped[TrackerStatus] = mapped_column(
        enum_column(TrackerStatus),
        nullable=False,
        default=TrackerStatus.INACTIVE,
    )
    tracking_mode: Mapped[TrackingMode] = mapped_column(
        enum_column(TrackingMode),
        nullable=False,
        default=TrackingMode.NORMAL,
    )
    battery_level: Mapped[int | None] = mapped_column(Integer, nullable=True)
    signal_strength: Mapped[int | None] = mapped_column(Integer, nullable=True)
    last_seen_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    last_latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    last_longitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    firmware_version: Mapped[str | None] = mapped_column(String(32), nullable=True)
    device_secret_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)

    young_person: Mapped[YoungPerson] = relationship("YoungPerson", back_populates="trackers")
    locations: Mapped[list[TrackerLocation]] = relationship("TrackerLocation", back_populates="tracker")
    events: Mapped[list[TrackerEvent]] = relationship("TrackerEvent", back_populates="tracker")


class TrackerLocation(Base):
    """Point GPS issu du téléphone ou du kit. Une position ancienne n'est jamais « actuelle »."""

    __tablename__ = "tracker_locations"

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    tracker_id: Mapped[UUID | None] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("gps_trackers.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    young_person_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("young_persons.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    source: Mapped[LocationSource] = mapped_column(enum_column(LocationSource), nullable=False)
    latitude: Mapped[float] = mapped_column(Float, nullable=False)
    longitude: Mapped[float] = mapped_column(Float, nullable=False)
    accuracy: Mapped[float | None] = mapped_column(Float, nullable=True)
    altitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    speed: Mapped[float | None] = mapped_column(Float, nullable=True)
    heading: Mapped[float | None] = mapped_column(Float, nullable=True)
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=utcnow, index=True)
    battery_level: Mapped[int | None] = mapped_column(Integer, nullable=True)
    signal_strength: Mapped[int | None] = mapped_column(Integer, nullable=True)

    tracker: Mapped[GPSTracker | None] = relationship("GPSTracker", back_populates="locations")


class TrackerEvent(Base):
    __tablename__ = "tracker_events"

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    tracker_id: Mapped[UUID | None] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("gps_trackers.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    young_person_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("young_persons.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    event_type: Mapped[TrackerEventType] = mapped_column(enum_column(TrackerEventType), nullable=False, index=True)
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=utcnow, index=True)
    latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    longitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    payload: Mapped[str | None] = mapped_column(Text, nullable=True)

    tracker: Mapped[GPSTracker | None] = relationship("GPSTracker", back_populates="events")


class PositionShare(TimestampMixin, Base):
    """Partage de position contrôlé, limité, révocable et traçable."""

    __tablename__ = "position_shares"

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    young_person_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("young_persons.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    target_user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=utcnow)
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    is_revoked: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    young_person: Mapped[YoungPerson] = relationship("YoungPerson", foreign_keys=[young_person_id])
    target_user: Mapped[User] = relationship("User", foreign_keys=[target_user_id])
