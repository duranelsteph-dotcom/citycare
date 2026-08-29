from __future__ import annotations

from uuid import UUID, uuid4

from sqlalchemy import Boolean, String, Uuid
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
