from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_name: str = "CityCare"
    app_version: str = "0.43.0"
    app_env: str = "development"
    api_v1_prefix: str = "/api/v1"
    database_url: str = "sqlite:///./citycare.db"
    cors_origins: str = "http://localhost:8080,http://127.0.0.1:8080,http://10.0.2.2:8080"
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
    otp_ttl_seconds: int = 300
    otp_resend_seconds: int = 30
    otp_max_attempts: int = 5
    # Reset mot de passe : code 6 chiffres, aucun SMS. TTL 15 min.
    reset_ttl_seconds: int = 900
    reset_max_attempts: int = 5
    # Chemin optionnel vers un artefact ML. Ignoré tant qu'aucun dataset labellisé n'existe.
    ai_model_path: str = ""
    # Photos de profil : disque local, pas Firebase. Relatif au dossier backend/ si non absolu.
    upload_dir: str = "static/uploads"
    upload_max_bytes: int = 2_097_152

    @property
    def resolved_upload_dir(self):
        from pathlib import Path

        raw = Path(self.upload_dir)
        if raw.is_absolute():
            return raw
        return Path(__file__).resolve().parents[2] / raw

    @property
    def cors_origin_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]

    @property
    def cors_origin_regex(self) -> str | None:
        """Flutter web / outils locaux : loopback, emul 10.0.2.2, LAN privee."""
        if self.app_env != "development":
            return None
        return (
            r"https://([a-z0-9-]+\.)?(ngrok-free\.app|ngrok\.io|trycloudflare\.com)(:\d+)?|"
            r"http://(localhost|127\.0\.0\.1|10\.0\.2\.2|"
            r"192\.168\.\d{1,3}\.\d{1,3}|"
            r"10\.\d{1,3}\.\d{1,3}\.\d{1,3}|"
            r"172\.(1[6-9]|2\d|3[0-1])\.\d{1,3}\.\d{1,3}"
            r")(:\d+)?"
        )

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
