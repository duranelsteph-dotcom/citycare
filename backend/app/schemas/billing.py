from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class SubscriptionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID | None = None
    plan: str
    currency: str
    amount: int
    status: str
    expires_at: datetime | None = None
    message: str | None = None


class SubscribeRequest(BaseModel):
    plan: str = "annual_xaf"
    confirm_demo: bool = True


class MarketplaceOrderRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    product_id: str
    product_name: str
    amount: int
    currency: str
    status: str
    message: str | None = None
    created_at: datetime | None = None


class MarketplaceOrderCreate(BaseModel):
    product_id: str = Field(min_length=2, max_length=64)
    product_name: str = Field(min_length=2, max_length=120)
    amount: int = Field(ge=0)
    currency: str = "XAF"
    confirm_demo: bool = True
