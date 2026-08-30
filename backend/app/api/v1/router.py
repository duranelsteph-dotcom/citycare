from fastapi import APIRouter

from app.api.v1 import alerts, auth, billing, cases, circles, devices, emergency, family, health, iot, locations, notifications, risk_zones, shares, trackers, zones

api_router = APIRouter()
api_router.include_router(health.router)
api_router.include_router(auth.router)
api_router.include_router(devices.router)
api_router.include_router(family.router)
api_router.include_router(circles.router)
api_router.include_router(locations.router)
api_router.include_router(shares.router)
api_router.include_router(zones.router)
api_router.include_router(risk_zones.router)
api_router.include_router(notifications.router)
api_router.include_router(alerts.router)
api_router.include_router(cases.router)
api_router.include_router(emergency.router)
api_router.include_router(trackers.router)
api_router.include_router(iot.router)
api_router.include_router(billing.router)
