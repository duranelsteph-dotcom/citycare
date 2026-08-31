from sqlalchemy import inspect, text
from sqlalchemy.engine import Engine


def ensure_schema(engine: Engine) -> None:
    """Ajoute les colonnes de la phase 4 si la base existait déjà (create_all ne les crée pas)."""
    inspector = inspect(engine)
    tables = set(inspector.get_table_names())
    statements: list[str] = []
    if "users" in tables:
        users = {col["name"] for col in inspector.get_columns("users")}
        if "password_changed_at" not in users:
            statements.append("ALTER TABLE users ADD COLUMN password_changed_at DATETIME")
        if "token_version" not in users:
            statements.append("ALTER TABLE users ADD COLUMN token_version INTEGER NOT NULL DEFAULT 0")
        if "photo_url" not in users:
            statements.append("ALTER TABLE users ADD COLUMN photo_url VARCHAR(512)")
    if "young_persons" in tables:
        yp = {col["name"] for col in inspector.get_columns("young_persons")}
        if "pairing_code" not in yp:
            statements.append("ALTER TABLE young_persons ADD COLUMN pairing_code VARCHAR(8)")
        if "pairing_code_expires_at" not in yp:
            statements.append("ALTER TABLE young_persons ADD COLUMN pairing_code_expires_at DATETIME")
    if "guardian_links" in tables:
        gl = {col["name"] for col in inspector.get_columns("guardian_links")}
        if "status" not in gl:
            statements.append(
                "ALTER TABLE guardian_links ADD COLUMN status VARCHAR(16) NOT NULL DEFAULT 'ACTIVE'"
            )
    if "gps_trackers" in tables:
        gt = {col["name"] for col in inspector.get_columns("gps_trackers")}
        if "device_secret_hash" not in gt:
            statements.append("ALTER TABLE gps_trackers ADD COLUMN device_secret_hash VARCHAR(255)")
    if "missing_person_cases" in tables:
        mc = {col["name"] for col in inspector.get_columns("missing_person_cases")}
        if "snapshot_json" not in mc:
            statements.append("ALTER TABLE missing_person_cases ADD COLUMN snapshot_json TEXT")
        if "subject_name" not in mc:
            statements.append("ALTER TABLE missing_person_cases ADD COLUMN subject_name VARCHAR(120)")
        if "subject_age_approx" not in mc:
            statements.append("ALTER TABLE missing_person_cases ADD COLUMN subject_age_approx VARCHAR(40)")
        if "subject_sex" not in mc:
            statements.append("ALTER TABLE missing_person_cases ADD COLUMN subject_sex VARCHAR(32)")
        if "distinctive_signs" not in mc:
            statements.append("ALTER TABLE missing_person_cases ADD COLUMN distinctive_signs TEXT")
        if "last_known_address" not in mc:
            statements.append("ALTER TABLE missing_person_cases ADD COLUMN last_known_address VARCHAR(255)")
        if "photo_url" not in mc:
            statements.append("ALTER TABLE missing_person_cases ADD COLUMN photo_url VARCHAR(512)")
    if "case_events" not in tables:
        statements.append(
            "CREATE TABLE case_events ("
            "id CHAR(32) NOT NULL, "
            "case_id CHAR(32) NOT NULL, "
            "status VARCHAR(16) NOT NULL, "
            "label VARCHAR(160) NOT NULL, "
            "actor_user_id CHAR(32), "
            "created_at DATETIME NOT NULL, "
            "updated_at DATETIME NOT NULL, "
            "PRIMARY KEY (id)"
            ")"
        )
    if "marketplace_orders" not in tables:
        statements.append(
            "CREATE TABLE marketplace_orders ("
            "id CHAR(32) NOT NULL, "
            "user_id CHAR(32) NOT NULL, "
            "product_id VARCHAR(64) NOT NULL, "
            "product_name VARCHAR(120) NOT NULL, "
            "amount INTEGER NOT NULL, "
            "currency VARCHAR(8) NOT NULL, "
            "status VARCHAR(16) NOT NULL, "
            "note VARCHAR(255), "
            "created_at DATETIME NOT NULL, "
            "updated_at DATETIME NOT NULL, "
            "PRIMARY KEY (id)"
            ")"
        )
    if not statements:
        return
    with engine.begin() as connection:
        for statement in statements:
            connection.execute(text(statement))
