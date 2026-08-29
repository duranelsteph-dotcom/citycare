from __future__ import annotations

from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import DateTime, Float, ForeignKey, Integer, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.enums import (
    CasePriority,
    CaseStatus,
    ConsistencyLevel,
    RiskLevel,
    SearchPriority,
    SearchZoneKind,
    TestimonyStatus,
)
from app.db.base import Base
from app.db.types import enum_column
from app.models.mixins import TimestampMixin, utcnow


class MissingPersonCase(TimestampMixin, Base):
    __tablename__ = "missing_person_cases"

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    young_person_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("young_persons.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    reported_by_user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="RESTRICT"),
        nullable=False,
    )
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=utcnow)
    last_known_latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    last_known_longitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    last_known_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    clothing: Mapped[str | None] = mapped_column(Text, nullable=True)
    circumstances: Mapped[str | None] = mapped_column(Text, nullable=True)
    last_seen_by: Mapped[str | None] = mapped_column(String(160), nullable=True)
    photo_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    snapshot_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[CaseStatus] = mapped_column(enum_column(CaseStatus), nullable=False, default=CaseStatus.OPEN, index=True)
    priority: Mapped[CasePriority] = mapped_column(
        enum_column(CasePriority),
        nullable=False,
        default=CasePriority.HIGH,
    )

    young_person: Mapped[YoungPerson] = relationship("YoungPerson", back_populates="cases")
    reported_by: Mapped[User] = relationship("User", foreign_keys=[reported_by_user_id])
    testimonies: Mapped[list[Testimony]] = relationship("Testimony", back_populates="case")
    search_zones: Mapped[list[SearchZone]] = relationship("SearchZone", back_populates="case")
    analyses: Mapped[list[RiskAnalysis]] = relationship("RiskAnalysis", back_populates="case")


class Testimony(TimestampMixin, Base):
    __tablename__ = "testimonies"

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    case_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("missing_person_cases.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    submitted_by_user_id: Mapped[UUID | None] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    description: Mapped[str] = mapped_column(Text, nullable=False)
    latitude: Mapped[float] = mapped_column(Float, nullable=False)
    longitude: Mapped[float] = mapped_column(Float, nullable=False)
    observed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    photo_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    status: Mapped[TestimonyStatus] = mapped_column(
        enum_column(TestimonyStatus),
        nullable=False,
        default=TestimonyStatus.SUBMITTED,
    )
    consistency: Mapped[ConsistencyLevel | None] = mapped_column(enum_column(ConsistencyLevel), nullable=True)
    consistency_note: Mapped[str | None] = mapped_column(Text, nullable=True)

    case: Mapped[MissingPersonCase] = relationship("MissingPersonCase", back_populates="testimonies")


class SearchZone(TimestampMixin, Base):
    """Zone estimée (probable ou prioritaire). Jamais présentée comme la position réelle."""

    __tablename__ = "search_zones"

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    case_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("missing_person_cases.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    kind: Mapped[SearchZoneKind] = mapped_column(enum_column(SearchZoneKind), nullable=False)
    priority: Mapped[SearchPriority] = mapped_column(enum_column(SearchPriority), nullable=False)
    center_latitude: Mapped[float] = mapped_column(Float, nullable=False)
    center_longitude: Mapped[float] = mapped_column(Float, nullable=False)
    radius_meters: Mapped[float] = mapped_column(Float, nullable=False)
    explanation: Mapped[str] = mapped_column(Text, nullable=False)
    computed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=utcnow)

    case: Mapped[MissingPersonCase] = relationship("MissingPersonCase", back_populates="search_zones")


class RiskAnalysis(TimestampMixin, Base):
    """Aide à la décision (règles / scoring). method=rules : Search Intelligence ; rules_ai : analyse IA. Jamais une preuve de kidnapping."""

    __tablename__ = "risk_analyses"

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    case_id: Mapped[UUID | None] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("missing_person_cases.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    young_person_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("young_persons.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    risk_level: Mapped[RiskLevel] = mapped_column(enum_column(RiskLevel), nullable=False)
    explanation: Mapped[str] = mapped_column(Text, nullable=False)
    factors: Mapped[str | None] = mapped_column(Text, nullable=True)
    method: Mapped[str] = mapped_column(String(64), nullable=False, default="rules")

    case: Mapped[MissingPersonCase | None] = relationship("MissingPersonCase", back_populates="analyses")


class Incident(TimestampMixin, Base):
    """Incident historique servant à alimenter les zones à risque — pas un kidnapping confirmé."""

    __tablename__ = "incidents"

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    risk_zone_id: Mapped[UUID | None] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("risk_zones.id", ondelete="SET NULL"),
        nullable=True,
    )
    title: Mapped[str] = mapped_column(String(160), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    latitude: Mapped[float] = mapped_column(Float, nullable=False)
    longitude: Mapped[float] = mapped_column(Float, nullable=False)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    source: Mapped[str | None] = mapped_column(String(80), nullable=True)
    count: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
