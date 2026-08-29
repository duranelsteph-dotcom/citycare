from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_name: str = "CityCare"
    app_version: str = "0.34.0"
    app_env: str = "development"
    api_v1_prefix: str = "/api/v1"
    database_url: str = "sqlite:///./citycare.db"
    cors_origins: str = "http://localhost:8080,http://127.0.0.1:8080"
    # Loaded from environment only — never commit a real secret.
    secret_key: str = "change-me-in-local-env-not-in-source"
    jwt_algorithm: str = "HS256"
    jwt_issuer: str = "citycare"
    access_token_expire_minutes: int = 1440
    https_only: bool = False
    tls_certfile: str = ""
    tls_keyfile: str = ""
    fcm_service_account_path: str = ""
    fcm_project_id: str = ""
    login_fail_max: int = 8
    login_fail_window_seconds: int = 900
    # Chemin optionnel vers un artefact ML. Ignoré tant qu'aucun dataset labellisé n'existe.
    ai_model_path: str = ""

    @property
    def cors_origin_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]

    @property
    def is_sqlite(self) -> bool:
        return self.database_url.startswith("sqlite")

    @property
    def database_dialect(self) -> str:
        url = self.database_url.lower()
        if url.startswith("postgresql") or url.startswith("postgres"):
            return "postgresql"
        if url.startswith("sqlite"):
            return "sqlite"
        return "other"

    @property
    def tls_files_ready(self) -> bool:
        from pathlib import Path

        cert = (self.tls_certfile or "").strip()
        key = (self.tls_keyfile or "").strip()
        return bool(cert and key and Path(cert).is_file() and Path(key).is_file())

    @property
    def is_production(self) -> bool:
        return self.app_env.lower() in {"production", "prod"}

    @property
    def docs_enabled(self) -> bool:
        return not self.is_production



settings = Settings()
