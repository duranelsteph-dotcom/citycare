from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

from app.core.config import settings

_QUERY_TOKEN_KEYS = {"access_token", "token", "jwt"}


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """Headers de protection API + interdiction du jeton dans l'URL. Ne remplace pas TLS."""

    async def dispatch(self, request: Request, call_next) -> Response:
        if any(key.lower() in _QUERY_TOKEN_KEYS for key in request.query_params):
            return JSONResponse(
                {"detail": "Le jeton ne doit pas figurer dans l'URL"},
                status_code=400,
            )
        if settings.https_only and request.url.scheme != "https":
            return JSONResponse(
                {
                    "detail": (
                        "HTTPS requis. Le TLS est attendu sur le reverse proxy ; "
                        "cette API n'implémente pas HTTPS elle-même."
                    )
                },
                status_code=403,
            )
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "no-referrer"
        response.headers["Cache-Control"] = "no-store"
        response.headers["Permissions-Policy"] = "geolocation=(), microphone=(), camera=()"
        if settings.https_only or request.url.scheme == "https":
            response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        return response
