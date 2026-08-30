from __future__ import annotations

from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import Boolean, DateTime, Integer, String, Uuid
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.enums import UserRole
from app.db.base import Base
from app.db.types import enum_column
from app.models.mixins import TimestampMixin


class User(TimestampMixin, Base):
    __tablename__ = "users"

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    full_name: Mapped[str] = mapped_column(String(120), nullable=False)
    email: Mapped[str | None] = mapped_column(String(255), unique=True, nullable=True, index=True)
    phone: Mapped[str] = mapped_column(String(32), unique=True, nullable=False, index=True)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[UserRole] = mapped_column(enum_column(UserRole), nullable=False, index=True)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    # Chemin relatif servi par GET /static (ex. /static/uploads/uuid.jpg). Pas d'URL Firebase.
    photo_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    # Rempli au reset (audit). L'invalidation JWT passe par token_version.
    password_changed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    token_version: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    young_profile: Mapped[YoungPerson | None] = relationship(
        "YoungPerson",
        back_populates="user",
        uselist=False,
    )
    guardian_links: Mapped[list[GuardianLink]] = relationship(
        "GuardianLink",
        back_populates="guardian",
        foreign_keys="GuardianLink.guardian_user_id",
    )
    notifications: Mapped[list[AppNotification]] = relationship(
        "AppNotification",
        back_populates="recipient",
    )
    push_tokens: Mapped[list[DevicePushToken]] = relationship(
        "DevicePushToken",
        back_populates="user",
    )
    subscription: Mapped[Subscription | None] = relationship(
        "Subscription",
        back_populates="user",
        uselist=False,
    )
    marketplace_orders: Mapped[list["MarketplaceOrder"]] = relationship(
        "MarketplaceOrder",
        back_populates="user",
    )
