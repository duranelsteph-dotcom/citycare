from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api.v1.router import api_router
from app.core.config import settings
from app.core.middleware import SecurityHeadersMiddleware
from app.core.security import assert_runtime_security
from app.db.base import Base
from app.db.migrate import ensure_schema
from app.db.session import engine
from app.services.fcm_hooks import register_fcm_hooks
from app.services.photo_service import ensure_upload_dir

from app.models import *  # noqa: F403


@asynccontextmanager
async def lifespan(_: FastAPI):
    assert_runtime_security()
    register_fcm_hooks()
    Base.metadata.create_all(bind=engine)
    ensure_schema(engine)
    yield


def create_app() -> FastAPI:
    register_fcm_hooks()
    application = FastAPI(
        title=settings.app_name,
        description=(
            "API CityCare — prévention, alerte et assistance. "
            "Le kit IoT parle à cette API, pas à Flutter. "
            "Géolocalisation, zones, SOS, cercles nommés (par-dessus GuardianLink), "
            "gestion des kits et télémétrie IoT. "
            "Le kit (ou le simulateur) parle à cette API, pas à Flutter. "
            "Rafraîchissement périodique de la dernière position connue (pas un GPS continu). "
            "Un SOS n'est pas un kidnapping confirmé. "
            "Un dossier de disparition est une déclaration avec un instantané, pas un kidnapping confirmé. "
            "Une trajectoire est reconstruite à partir des positions enregistrées, pas un suivi en direct. "
            "Search Intelligence est une aide à la décision par règles, pas un kidnapping confirmé. "
            "Une zone probable de déplacement est une estimation, pas la position actuelle. "
            "Les zones de recherche prioritaires sont un classement par règles, pas la position réelle. "
            "Un témoignage est un signalement humain, pas une preuve. "
            "Sa cohérence avec la trajectoire est une estimation par règles, pas une preuve. "
            "L'analyse IA est une aide à la décision par règles, pas un modèle entraîné, "
            "pas un kidnapping confirmé. "
            "Une anomalie automatique est une alerte par règles (arrêt, signal, trajectoire), "
            "pas un modèle ML, pas un kidnapping confirmé. "
            "Les positions sont protégées par authentification et permissions. "
            "Le login exige un 2e facteur (OTP 6 chiffres) après le mot de passe ; "
            "le JWT n'est délivré qu'après verify-otp. En développement, otp_dev "
            "est renvoyé (aucun SMS n'est envoyé). "
            "Mot de passe oublié : POST /auth/forgot-password puis /auth/reset-password. "
            "Aucun SMS ni e-mail : en développement, reset_code_dev est renvoyé. "
            "Aucun secret n'est stocké dans le code source. "
            "Photo de profil : POST /auth/me/photo (multipart JPEG/PNG), fichiers dans static/uploads. "
            "Suppression de compte RGPD : DELETE /auth/me avec { password }. "
            "Anonymisation + is_active=false (pas de hard-delete : dossiers RESTRICT, cercles habités). "
            "Les notifications sont un inbox dans l'application, plus un push FCM si un jeton "
            "appareil est enregistré et si FCM_SERVICE_ACCOUNT_PATH pointe vers un compte de service. "
            "Mode hors ligne : file d'attente locale (téléphone et simulateur kit), heure conservée, pas Last Write Wins. "
            "Le SOS vocal utilise la reconnaissance vocale du système, pas une commande inventée. "
            "Le mode urgence affiche la dernière position connue, pas un suivi en direct. "
            "Une perte de signal kit n'est pas la position actuelle, pas un kidnapping confirmé. "
            "L'historique kit est une liste de traces datées, pas un suivi en direct. "
            "Le mode urgence reprend ces traces kit. "
            "Le seed de démo inclut une zone à risque, un proche autorisé SOS et un compte autorité. "
            "Démarrer une recherche passe le dossier en SEARCHING : aide à la décision, pas un kidnapping confirmé. "
            "Un partage de position est limité, révocable, pas un GPS continu. "
            "Clore un SOS n'est pas un kidnapping confirmé : la demande d'aide est close, pas une preuve. "
            "python -m simulator seed --play enchaîne école, sortie, SOS, dossier, search intelligence et témoignage. "
            "Comptes de démonstration : python -m simulator seed (API locale)."
        ),
        version=settings.app_version,
        lifespan=lifespan,
        docs_url="/docs" if settings.docs_enabled else None,
        redoc_url="/redoc" if settings.docs_enabled else None,
        openapi_url="/openapi.json" if settings.docs_enabled else None,
    )
    application.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list,
        allow_origin_regex=settings.cors_origin_regex,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "Accept", "ngrok-skip-browser-warning"],
    )
    application.add_middleware(SecurityHeadersMiddleware)
    application.include_router(api_router, prefix=settings.api_v1_prefix)
    # Fichiers publics : /static/uploads/{nom}. Flutter compose avec l'origine de ApiConfig.baseUrl.
    upload_root = ensure_upload_dir()
    application.mount("/static", StaticFiles(directory=str(upload_root.parent)), name="static")
    return application


app = create_app()
Base.metadata.create_all(bind=engine)
ensure_schema(engine)
