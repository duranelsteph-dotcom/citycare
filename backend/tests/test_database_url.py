from app.core.config import normalize_database_url


def test_normalize_supabase_uri() -> None:
    raw = "postgresql://postgres.abc:secret@aws-0-eu.pooler.supabase.com:6543/postgres"
    out = normalize_database_url(raw)
    assert out.startswith("postgresql+psycopg://")
    assert "sslmode=require" in out
    assert "postgres.abc:secret@" in out


def test_normalize_postgres_scheme() -> None:
    out = normalize_database_url("postgres://u:p@h:5432/db")
    assert out.startswith("postgresql+psycopg://u:p@h:5432/db")
    assert "sslmode=require" in out


def test_sqlite_unchanged() -> None:
    assert normalize_database_url("sqlite:///./citycare.db") == "sqlite:///./citycare.db"
