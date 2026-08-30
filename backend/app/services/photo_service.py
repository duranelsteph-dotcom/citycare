"""Upload de photo de profil : JPEG/PNG sur disque local, pas Firebase Storage."""

from __future__ import annotations

from pathlib import Path
from uuid import uuid4

from fastapi import UploadFile
from sqlalchemy.orm import Session, joinedload

from app.core.config import settings
from app.core.enums import UserRole
from app.models.user import User
from app.schemas.auth import AuthUserRead
from app.services.auth_service import auth_user_from_model

# Signatures binaires — on ne se fie pas au seul Content-Type du client.
_JPEG_MAGIC = b"\xff\xd8\xff"
_PNG_MAGIC = b"\x89PNG\r\n\x1a\n"
_PUBLIC_PREFIX = "/static/uploads/"


class PhotoError(Exception):
    def __init__(self, message: str, status_code: int = 400):
        super().__init__(message)
        self.message = message
        self.status_code = status_code


def ensure_upload_dir() -> Path:
    """Crée static/uploads si besoin. Appelé au démarrage et avant chaque écriture."""
    folder = settings.resolved_upload_dir
    folder.mkdir(parents=True, exist_ok=True)
    return folder


def _detect_extension(data: bytes) -> str:
    if data.startswith(_JPEG_MAGIC):
        return ".jpg"
    if data.startswith(_PNG_MAGIC):
        return ".png"
    raise PhotoError("Seuls les fichiers JPEG et PNG sont acceptés", 400)


def delete_profile_photo_file(photo_url: str | None) -> None:
    """Supprime le fichier disque lié à photo_url (RGPD, remplacement d'avatar)."""
    _safe_unlink(photo_url)


def _safe_unlink(photo_url: str | None) -> None:
    """Supprime l'ancien fichier s'il est bien sous static/uploads (pas de traversal)."""
    if not photo_url or not photo_url.startswith(_PUBLIC_PREFIX):
        return
    name = Path(photo_url).name
    if not name or name in {".", ".."}:
        return
    target = (ensure_upload_dir() / name).resolve()
    root = ensure_upload_dir().resolve()
    if target.parent != root:
        return
    if target.is_file():
        target.unlink()


def save_profile_photo(db: Session, user: User, upload: UploadFile) -> AuthUserRead:
    """Valide, écrit le fichier, met à jour User.photo_url et YoungPerson si jeune."""
    raw = upload.file.read()
    if not raw:
        raise PhotoError("Fichier vide", 400)
    if len(raw) > settings.upload_max_bytes:
        raise PhotoError("La photo ne doit pas dépasser 2 Mo", 413)
    extension = _detect_extension(raw)

    folder = ensure_upload_dir()
    filename = f"{user.id}_{uuid4().hex}{extension}"
    dest = folder / filename
    dest.write_bytes(raw)

    previous = user.photo_url
    if user.role == UserRole.YOUNG and user.young_profile is not None:
        previous = user.photo_url or user.young_profile.photo_url

    public_url = f"{_PUBLIC_PREFIX}{filename}"
    user.photo_url = public_url
    if user.young_profile is not None:
        user.young_profile.photo_url = public_url
    db.commit()
    db.refresh(user)
    if user.young_profile is not None:
        db.refresh(user, attribute_names=["young_profile"])

    _safe_unlink(previous if previous != public_url else None)

    fresh = (
        db.query(User)
        .options(joinedload(User.young_profile))
        .filter(User.id == user.id)
        .one()
    )
    return auth_user_from_model(fresh)
