from __future__ import annotations

from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import DateTime, ForeignKey, Integer, String, Uuid
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.models.mixins import TimestampMixin


class Subscription(TimestampMixin, Base):
    """Intention d’abonnement annuelle. Aucun paiement n’est débité ici."""

    __tablename__ = "subscriptions"

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True), ForeignKey("users.id"), nullable=False, unique=True, index=True
    )
    plan: Mapped[str] = mapped_column(String(32), nullable=False, default="annual_xaf")
    currency: Mapped[str] = mapped_column(String(8), nullable=False, default="XAF")
    amount: Mapped[int] = mapped_column(Integer, nullable=False, default=12000)
    status: Mapped[str] = mapped_column(String(16), nullable=False, default="recorded")
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    note: Mapped[str | None] = mapped_column(String(255), nullable=True)

    user: Mapped[User] = relationship("User", back_populates="subscription")
