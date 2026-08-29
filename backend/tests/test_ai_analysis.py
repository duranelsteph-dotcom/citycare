from datetime import datetime, timedelta, timezone
from uuid import uuid4

from fastapi.testclient import TestClient

from app.core.enums import UserRole
from app.main import app

client = TestClient(app)

POINT = {"latitude": 3.8480, "longitude": 11.5021, "accuracy": 15}
FAR = {"latitude": 10.0, "longitude": 15.0, "accuracy": 15}


def _register(role: UserRole, name: str) -> dict:
    phone = f"+2377{uuid4().hex[:8]}"
    response = client.post(
        "/api/v1/auth/register",
        json={"full_name": name, "phone": phone, "password": "motdepasse", "role": role.value},
    )
    assert response.status_code == 200, response.text
    body = response.json()
    body["_phone"] = phone
    return body


def _auth(session: dict) -> dict:
    return {"Authorization": f"Bearer {session['access_token']}"}


def _pair(young: dict, guardian: dict) -> dict:
    code = client.post("/api/v1/family/young/pairing-code", headers=_auth(young))
    linked = client.post(
        "/api/v1/family/links/code",
        headers=_auth(guardian),
        json={"code": code.json()["code"]},
    )
    assert linked.status_code == 200, linked.text
    return linked.json()


def test_ai_analysis_is_rules_not_trained_ml() -> None:
    young = _register(UserRole.YOUNG, "Amina IA")
    parent = _register(UserRole.PARENT, "Marie IA")
    link = _pair(young, parent)
    old = (datetime.now(timezone.utc) - timedelta(minutes=40)).isoformat()
    client.post("/api/v1/locations", headers=_auth(young), json={**POINT, "recorded_at": old})
    sos = client.post("/api/v1/alerts/sos", headers=_auth(young), json={})
    assert sos.status_code == 200, sos.text
    created = client.post("/api/v1/cases", headers=_auth(parent), json={"young_person_id": link["young_person_id"]})
    assert created.status_code == 200, created.text
    case_id = created.json()["id"]

    intel = client.get(f"/api/v1/cases/{case_id}/intelligence", headers=_auth(parent))
    assert intel.status_code == 200, intel.text
    assert intel.json()["method"] == "rules"

    analysis = client.get(f"/api/v1/cases/{case_id}/ai-analysis", headers=_auth(parent))
    assert analysis.status_code == 200, analysis.text
    body = analysis.json()
    assert body["method"] == "rules_ai"
    assert body["id"] != intel.json()["id"]
    assert body["trained_model"] is False
    assert body["factors"]["trained_model"] is False
    assert body["factors"]["ml"]["trained_model"] is False
    assert body["risk_level"] == "MEDIUM"
    assert body["factors"]["score"] >= 3
    assert body["factors"]["dimensions"]["anomalies"]["score"] >= 2
    text = (body["disclaimer"] + body["explanation"]).lower()
    assert "kidnapping" in text
    assert "preuve" in text
    assert "machine learning" in text or "modèle" in text or "ml" in text
    assert "dataset" in text

    children = client.get("/api/v1/family/children", headers=_auth(parent))
    assert children.json()[0]["can_view_location"] is False

    young_view = client.get(f"/api/v1/cases/{case_id}/ai-analysis", headers=_auth(young))
    assert young_view.status_code == 200
    assert young_view.json()["trained_model"] is False


def test_ai_analysis_without_signals_is_low() -> None:
    young = _register(UserRole.YOUNG, "Paul IA")
    parent = _register(UserRole.PARENT, "Lucie IA")
    link = _pair(young, parent)
    created = client.post("/api/v1/cases", headers=_auth(parent), json={"young_person_id": link["young_person_id"]})
    case_id = created.json()["id"]
    analysis = client.get(f"/api/v1/cases/{case_id}/ai-analysis", headers=_auth(parent))
    assert analysis.status_code == 200, analysis.text
    body = analysis.json()
    assert body["risk_level"] == "LOW"
    assert body["trained_model"] is False
    assert body["factors"]["dimensions"]["geography"]["score"] == 0
    assert "aucune position" in " ".join(body["factors"]["dimensions"]["geography"]["notes"]).lower()


def test_ai_analysis_implausible_jump_with_sos_is_high() -> None:
    young = _register(UserRole.YOUNG, "Sara IA")
    parent = _register(UserRole.PARENT, "Jean IA")
    link = _pair(young, parent)
    t1 = datetime.now(timezone.utc) - timedelta(hours=2, minutes=1)
    t0 = t1 - timedelta(seconds=10)
    client.post("/api/v1/locations", headers=_auth(young), json={**POINT, "recorded_at": t0.isoformat()})
    client.post("/api/v1/locations", headers=_auth(young), json={**FAR, "recorded_at": t1.isoformat()})
    sos = client.post("/api/v1/alerts/sos", headers=_auth(young), json={})
    assert sos.status_code == 200, sos.text
    created = client.post("/api/v1/cases", headers=_auth(parent), json={"young_person_id": link["young_person_id"]})
    case_id = created.json()["id"]
    analysis = client.get(f"/api/v1/cases/{case_id}/ai-analysis", headers=_auth(parent))
    assert analysis.status_code == 200, analysis.text
    body = analysis.json()
    assert body["risk_level"] == "HIGH"
    assert body["factors"]["dimensions"]["trajectory"]["score"] == 3
    assert body["factors"]["dimensions"]["anomalies"]["score"] >= 2
    assert body["factors"]["dimensions"]["geography"]["score"] >= 2
    assert "irréaliste" in body["explanation"].lower() or "irrealiste" in body["explanation"].lower()
    assert "preuve" in body["explanation"].lower()
    assert body["trained_model"] is False


def test_stranger_cannot_read_or_refresh_ai_analysis() -> None:
    young = _register(UserRole.YOUNG, "Lea IA")
    parent = _register(UserRole.PARENT, "Hugo IA")
    stranger = _register(UserRole.PARENT, "Nina IA")
    link = _pair(young, parent)
    created = client.post("/api/v1/cases", headers=_auth(parent), json={"young_person_id": link["young_person_id"]})
    case_id = created.json()["id"]
    denied = client.get(f"/api/v1/cases/{case_id}/ai-analysis", headers=_auth(stranger))
    assert denied.status_code == 403
    denied_post = client.post(f"/api/v1/cases/{case_id}/ai-analysis", headers=_auth(stranger))
    assert denied_post.status_code == 403

    refreshed = client.post(f"/api/v1/cases/{case_id}/ai-analysis", headers=_auth(parent))
    assert refreshed.status_code == 200, refreshed.text
    assert refreshed.json()["method"] == "rules_ai"
    assert refreshed.json()["trained_model"] is False
    children = client.get("/api/v1/family/children", headers=_auth(parent))
    assert children.json()[0]["can_view_location"] is False
