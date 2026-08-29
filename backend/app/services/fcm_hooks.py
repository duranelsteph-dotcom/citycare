"""Après commit, tente un push FCM. L'inbox est déjà persisté — un échec FCM ne l'annule pas."""

from sqlalchemy import event
from sqlalchemy.orm import Session

from app.models.alert import AppNotification


def _before_flush(session: Session, _ctx, _instances) -> None:
    notes = [obj for obj in session.new if isinstance(obj, AppNotification)]
    if notes:
        session.info.setdefault("citycare_fcm_pending", []).extend(notes)


def _after_flush(session: Session, _ctx) -> None:
    pending = session.info.pop("citycare_fcm_pending", [])
    ids = session.info.setdefault("citycare_fcm_ids", [])
    for obj in pending:
        if getattr(obj, "id", None) is not None:
            ids.append(obj.id)


def _clear(session: Session) -> None:
    session.info.pop("citycare_fcm_ids", None)
    session.info.pop("citycare_fcm_pending", None)


def _dispatch(session: Session) -> None:
    ids = list(session.info.pop("citycare_fcm_ids", []))
    if not ids:
        return
    from app.db.session import SessionLocal
    from app.services.fcm_service import dispatch_ids, is_configured

    if not is_configured():
        return
    extra = SessionLocal()
    try:
        dispatch_ids(extra, ids)
        extra.commit()
    except Exception:
        extra.rollback()
    finally:
        extra.close()


_registered = False


def register_fcm_hooks() -> None:
    global _registered
    if _registered:
        return
    _registered = True
    event.listen(Session, "before_flush", _before_flush)
    event.listen(Session, "after_flush", _after_flush)
    event.listen(Session, "after_commit", _dispatch)
    event.listen(Session, "after_rollback", _clear)
