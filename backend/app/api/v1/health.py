from fastapi import APIRouter

from app.core.config import settings
from app.core.security import INSECURE_DEFAULT_SECRET
from app.services.fcm_service import is_configured as fcm_configured

router = APIRouter(tags=["health"])


@router.get("/health")
def health() -> dict[str, str]:
    return {
        "status": "ok",
        "service": settings.app_name,
        "env": settings.app_env,
        "version": settings.app_version,
    }


@router.get("/security")
def security_status() -> dict:
    """État des contrôles — aucun secret n'est renvoyé."""
    return {
        "https_enforced": settings.https_only,
        "tls_files_ready": settings.tls_files_ready,
        "tls_note": (
            "En production, HTTPS_ONLY et un reverse proxy TLS. "
            "En local, TLS_CERTFILE et TLS_KEYFILE (mkcert) avec python -m app.run_api. "
            "Sans ces fichiers, l'API locale reste en HTTP."
        ),
        "database_dialect": settings.database_dialect,
        "fcm_configured": fcm_configured(),
        "fcm_note": (
            "Push FCM réel via HTTP v1 si FCM_SERVICE_ACCOUNT_PATH est un fichier JSON de compte de service. "
            "Sans cela, seul l'inbox in-app est utilisé. Ce n'est pas un kidnapping confirmé."
        ),
        "passwords_hashed": True,
        "kit_secrets_hashed": True,
        "jwt_algorithm": settings.jwt_algorithm,
        "jwt_in_query_forbidden": True,
        "docs_enabled": settings.docs_enabled,
        "default_parent_live_location": False,
        "secret_from_environment": settings.secret_key != INSECURE_DEFAULT_SECRET,
        "weak_default_secret_allowed": not settings.is_production,
        "login_fail_max": settings.login_fail_max,
        "disclaimer": (
            "Les positions des jeunes sont protégées par authentification et permissions. "
            "Ce n'est pas un GPS continu, pas un kidnapping confirmé. "
            "Aucun secret n'est stocké dans le code source."
        ),
    }
