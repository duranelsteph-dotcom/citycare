from datetime import datetime, timedelta, timezone

from sqlalchemy.orm import Session

from app.models.marketplace_order import MarketplaceOrder
from app.models.subscription import Subscription
from app.models.user import User
from app.schemas.billing import MarketplaceOrderCreate, MarketplaceOrderRead, SubscriptionRead

ANNUAL_AMOUNT = 12000
ANNUAL_CURRENCY = "XAF"
ANNUAL_PLAN = "annual_xaf"
DEMO_NOTE = (
    "Paiement démo confirmé. Aucun Mobile Money ni carte n’a été débité. "
    "Abonnement actif jusqu’à la date d’échéance."
)
ORDER_NOTE = (
    "Commande démo enregistrée. Aucun Mobile Money ni carte n’a été débité."
)


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _to_read(row: Subscription | None) -> SubscriptionRead:
    if row is None:
        return SubscriptionRead(
            plan=ANNUAL_PLAN,
            currency=ANNUAL_CURRENCY,
            amount=ANNUAL_AMOUNT,
            status="none",
            message="Aucun abonnement. Choisissez l’offre puis confirmez le paiement démo.",
        )
    return SubscriptionRead(
        id=row.id,
        plan=row.plan,
        currency=row.currency,
        amount=row.amount,
        status=row.status,
        expires_at=row.expires_at,
        message=row.note,
    )


def get_mine(db: Session, user: User) -> SubscriptionRead:
    row = db.query(Subscription).filter(Subscription.user_id == user.id).one_or_none()
    return _to_read(row)


def record_annual(db: Session, user: User) -> SubscriptionRead:
    """Confirme un paiement démo et passe le statut à Actif (écrit en base)."""
    row = db.query(Subscription).filter(Subscription.user_id == user.id).one_or_none()
    if row is None:
        row = Subscription(
            user_id=user.id,
            plan=ANNUAL_PLAN,
            currency=ANNUAL_CURRENCY,
            amount=ANNUAL_AMOUNT,
            status="active",
            expires_at=_utcnow() + timedelta(days=365),
            note=DEMO_NOTE,
        )
        db.add(row)
    else:
        row.status = "active"
        row.plan = ANNUAL_PLAN
        row.amount = ANNUAL_AMOUNT
        row.currency = ANNUAL_CURRENCY
        row.expires_at = _utcnow() + timedelta(days=365)
        row.note = DEMO_NOTE
    db.commit()
    db.refresh(row)
    return _to_read(row)


def _order_to_read(row: MarketplaceOrder) -> MarketplaceOrderRead:
    return MarketplaceOrderRead(
        id=row.id,
        product_id=row.product_id,
        product_name=row.product_name,
        amount=row.amount,
        currency=row.currency,
        status=row.status,
        message=row.note,
        created_at=row.created_at,
    )


def list_orders(db: Session, user: User) -> list[MarketplaceOrderRead]:
    rows = (
        db.query(MarketplaceOrder)
        .filter(MarketplaceOrder.user_id == user.id)
        .order_by(MarketplaceOrder.created_at.desc())
        .all()
    )
    return [_order_to_read(row) for row in rows]


def record_order(db: Session, user: User, payload: MarketplaceOrderCreate) -> MarketplaceOrderRead:
    existing = (
        db.query(MarketplaceOrder)
        .filter(
            MarketplaceOrder.user_id == user.id,
            MarketplaceOrder.product_id == payload.product_id,
        )
        .order_by(MarketplaceOrder.created_at.desc())
        .first()
    )
    if existing is not None:
        return _order_to_read(existing)
    row = MarketplaceOrder(
        user_id=user.id,
        product_id=payload.product_id,
        product_name=payload.product_name,
        amount=payload.amount,
        currency=payload.currency or ANNUAL_CURRENCY,
        status="recorded",
        note=ORDER_NOTE,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return _order_to_read(row)
