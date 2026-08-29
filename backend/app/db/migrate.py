from sqlalchemy import inspect, text
from sqlalchemy.engine import Engine


def ensure_schema(engine: Engine) -> None:
    """Ajoute les colonnes de la phase 4 si la base existait déjà (create_all ne les crée pas)."""
    inspector = inspect(engine)
    tables = set(inspector.get_table_names())
    statements: list[str] = []
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
    if not statements:
        return
    with engine.begin() as connection:
        for statement in statements:
            connection.execute(text(statement))
