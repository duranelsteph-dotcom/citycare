from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.billing import (
    MarketplaceOrderCreate,
    MarketplaceOrderRead,
    SubscribeRequest,
    SubscriptionRead,
)
from app.services.billing_service import get_mine, list_orders, record_annual, record_order

router = APIRouter(prefix="/billing", tags=["billing"])


@router.get("/me", response_model=SubscriptionRead)
def billing_me(db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> SubscriptionRead:
    return get_mine(db, user)


@router.post("/subscribe", response_model=SubscriptionRead)
def billing_subscribe(
    payload: SubscribeRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> SubscriptionRead:
    _ = payload.plan
    _ = payload.confirm_demo
    return record_annual(db, user)


@router.get("/orders", response_model=list[MarketplaceOrderRead])
def billing_orders(
    db: Session = Depends(get_db), user: User = Depends(get_current_user)
) -> list[MarketplaceOrderRead]:
    return list_orders(db, user)


@router.post("/orders", response_model=MarketplaceOrderRead)
def billing_create_order(
    payload: MarketplaceOrderCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> MarketplaceOrderRead:
    return record_order(db, user, payload)
