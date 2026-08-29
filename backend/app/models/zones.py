from __future__ import annotations

from datetime import datetime, time
from uuid import UUID, uuid4

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Time, UniqueConstraint, Uuid
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.mixins import TimestampMixin


class SafetyZone(TimestampMixin, Base):
    """Zone de sécurité (école, maison…) liée à un jeune, avec rayon et plages horaires."""

    __tablename__ = "safety_zones"

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    young_person_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("young_persons.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(80), nullable=False)
    latitude: Mapped[float] = mapped_column(Float, nullable=False)
    longitude: Mapped[float] = mapped_column(Float, nullable=False)
    radius_meters: Mapped[float] = mapped_column(Float, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    # GPS noise must not create a critical alert on its own.
    accuracy_tolerance_meters: Mapped[float] = mapped_column(Float, nullable=False, default=40.0)
    min_exit_duration_seconds: Mapped[int] = mapped_column(Integer, nullable=False, default=90)

    young_person: Mapped[YoungPerson] = relationship("YoungPerson", back_populates="safety_zones")
    schedules: Mapped[list[SafetyZoneSchedule]] = relationship(
        "SafetyZoneSchedule",
        back_populates="zone",
        cascade="all, delete-orphan",
    )


class SafetyZoneSchedule(Base):
    """Plage jour + heures. Si end_time <= start_time, la fenêtre traverse minuit (ex. 18:00 → 07:00)."""

    __tablename__ = "safety_zone_schedules"

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    zone_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("safety_zones.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    weekday: Mapped[int] = mapped_column(Integer, nullable=False)  # 0 = lundi … 6 = dimanche
    start_time: Mapped[time] = mapped_column(Time, nullable=False)
    end_time: Mapped[time] = mapped_column(Time, nullable=False)

    zone: Mapped[SafetyZone] = relationship("SafetyZone", back_populates="schedules")


class RiskZone(TimestampMixin, Base):
    """Zone à risque (prévention), distincte d'une zone de sécurité."""

    __tablename__ = "risk_zones"

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    name: Mapped[str] = mapped_column(String(80), nullable=False)
    latitude: Mapped[float] = mapped_column(Float, nullable=False)
    longitude: Mapped[float] = mapped_column(Float, nullable=False)
    radius_meters: Mapped[float] = mapped_column(Float, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    incident_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    typical_start_hour: Mapped[int | None] = mapped_column(Integer, nullable=True)
    typical_end_hour: Mapped[int | None] = mapped_column(Integer, nullable=True)


class RiskZoneOccupancy(TimestampMixin, Base):
    """Présence dans une zone à risque, pour n'alerter qu'à l'entrée."""

    __tablename__ = "risk_zone_occupancies"
    __table_args__ = (UniqueConstraint("young_person_id", "risk_zone_id", name="uq_risk_occupancy_young_zone"),)

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    young_person_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("young_persons.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    risk_zone_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("risk_zones.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    is_inside: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)


class GeofenceOccupancy(TimestampMixin, Base):
    """État d'occupation d'une zone, pour exiger une présence puis une durée hors zone."""

    __tablename__ = "geofence_occupancies"
    __table_args__ = (UniqueConstraint("young_person_id", "zone_id", name="uq_occupancy_young_zone"),)

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    young_person_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("young_persons.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    zone_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("safety_zones.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    observed_inside: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    is_inside: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    candidate_exit_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

