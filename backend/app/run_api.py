"""Démarre l'API. Active TLS seulement si TLS_CERTFILE et TLS_KEYFILE existent."""

import uvicorn

from app.core.config import settings


def main() -> None:
    kwargs: dict = {
        "host": "0.0.0.0",
        "port": 8000,
        "reload": not settings.is_production,
    }
    if settings.tls_files_ready:
        kwargs["ssl_certfile"] = settings.tls_certfile
        kwargs["ssl_keyfile"] = settings.tls_keyfile
    uvicorn.run("app.main:app", **kwargs)


if __name__ == "__main__":
    main()
