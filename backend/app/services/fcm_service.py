"""Envoi FCM HTTP v1. Ne fait rien si le compte de service n'est pas configuré."""

from __future__ import annotations

import json
import logging
from pathlib import Path
from uuid import UUID

import httpx
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.alert import AppNotification
from app.models.device import DevicePushToken

logger = logging.getLogger(__name__)

_FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
_INVALID = {"UNREGISTERED", "NOT_FOUND", "INVALID_ARGUMENT"}


def is_configured() -> bool:
    path = (settings.fcm_service_account_path or "").strip()
    return bool(path) and Path(path).is_file()


def project_id() -> str | None:
    if settings.fcm_project_id.strip():
        return settings.fcm_project_id.strip()
    if not is_configured():
        return None
    try:
        data = json.loads(Path(settings.fcm_service_account_path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    value = data.get("project_id")
    return str(value) if value else None


def _access_token() -> str | None:
    if not is_configured():
        return None
    try:
        from google.auth.transport.requests import Request
        from google.oauth2 import service_account

        creds = service_account.Credentials.from_service_account_file(
            settings.fcm_service_account_path,
            scopes=[_FCM_SCOPE],
        )
        creds.refresh(Request())
        return creds.token
    except Exception:
        logger.exception("Impossible d'obtenir un jeton FCM (compte de service)")
        return None


def _post_message(access_token: str, project: str, device_token: str, row: AppNotification) -> str:
    """Retourne 'ok', 'invalid' ou 'error'."""
    url = f"https://fcm.googleapis.com/v1/projects/{project}/messages:send"
    body_text = row.body if len(row.body) <= 240 else f"{row.body[:237]}..."
    payload = {
        "message": {
            "token": device_token,
            "notification": {"title": row.title, "body": body_text},
            "data": {
                "notification_id": str(row.id),
                "type": row.notification_type.value,
                "alert_id": str(row.alert_id) if row.alert_id else "",
                "case_id": str(row.case_id) if row.case_id else "",
                "channel": "FCM",
            },
            "android": {"priority": "HIGH"},
        }
    }
    try:
        response = httpx.post(
            url,
            headers={"Authorization": f"Bearer {access_token}", "Content-Type": "application/json"},
            json=payload,
            timeout=12.0,
        )
    except httpx.HTTPError:
        logger.exception("Appel FCM réseau")
        return "error"
    if response.status_code < 300:
        return "ok"
    try:
        err = response.json()
        status = str(err.get("error", {}).get("status", ""))
    except ValueError:
        status = ""
    if status in _INVALID or response.status_code in {400, 404}:
        return "invalid"
    logger.warning("FCM HTTP %s: %s", response.status_code, response.text[:300])
    return "error"


def dispatch_ids(db: Session, notification_ids: list[UUID]) -> int:
    """Envoie un push pour chaque notification. Ne lève pas. Retourne le nombre d'envois OK."""
    if not notification_ids or not is_configured():
        return 0
    access = _access_token()
    project = project_id()
    if not access or not project:
        return 0
    sent = 0
    rows = db.query(AppNotification).filter(AppNotification.id.in_(notification_ids)).all()
    for row in rows:
        devices = (
            db.query(DevicePushToken)
            .filter(
                DevicePushToken.user_id == row.recipient_user_id,
                DevicePushToken.is_active.is_(True),
            )
            .all()
        )
        for device in devices:
            result = _post_message(access, project, device.token, row)
            if result == "ok":
                sent += 1
            elif result == "invalid":
                device.is_active = False
    return sent
