"""Comptes soutenance (Marie / Amina / Marc / Poste) — idempotent, sans HTTP."""

from __future__ import annotations

import logging

from app.core.enums import UserRole
from app.core.security import hash_password
from app.db.session import SessionLocal
from app.models.people import YoungPerson
from app.models.user import User

logger = logging.getLogger(__name__)

# Mot de passe historique des comptes démo (grandfather vs règle d’inscription forte).
_DEMO_PASSWORD = "motdepasse"

_DEMO_ACCOUNTS: tuple[dict[str, str], ...] = (
    {"full_name": "Marie Demo", "phone": "+237699000001", "role": "PARENT"},
    {"full_name": "Amina Demo", "phone": "+237699000002", "role": "YOUNG"},
    {"full_name": "Marc Demo", "phone": "+237699000003", "role": "RELATIVE"},
    {"full_name": "Poste Demo", "phone": "+237699000004", "role": "AUTHORITY"},
)


def ensure_demo_accounts() -> int:
    """Crée les comptes manquants. Retourne le nombre d’insertions (pas les resets MDP)."""
    from app.core.security import verify_password

    created = 0
    db = SessionLocal()
    try:
        for payload in _DEMO_ACCOUNTS:
            phone = payload["phone"]
            existing = db.query(User).filter(User.phone == phone).one_or_none()
            if existing is not None:
                # Soutenance : garantit motdepasse même si un hash différent existait.
                if not verify_password(_DEMO_PASSWORD, existing.password_hash):
                    existing.password_hash = hash_password(_DEMO_PASSWORD)
                    existing.is_active = True
                continue
            role = UserRole(payload["role"])
            user = User(
                full_name=payload["full_name"],
                phone=phone,
                password_hash=hash_password(_DEMO_PASSWORD),
                role=role,
                is_active=True,
            )
            db.add(user)
            db.flush()
            if role == UserRole.YOUNG:
                db.add(YoungPerson(user_id=user.id, display_name=payload["full_name"]))
            created += 1
        db.commit()
        if created:
            logger.warning("Seed démo : %s compte(s) créé(s) (mot de passe : motdepasse)", created)
    except Exception:
        db.rollback()
        logger.exception("Seed démo impossible — login peut renvoyer 401 jusqu’à correction DB")
        raise
    finally:
        db.close()
    return created
