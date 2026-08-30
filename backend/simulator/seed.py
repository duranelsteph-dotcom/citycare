"""Comptes et données de démonstration soutenance. Aucun secret n'est dans le code source du kit : le secret n'est écrit que localement dans .demo_kit.json (gitignoré)."""

from __future__ import annotations

import json
from pathlib import Path

from simulator.scenario import DEMO_STEPS, SCHOOL, STOP

PASSWORD = "motdepasse"
PARENT = {"full_name": "Marie Demo", "phone": "+237699000001", "password": PASSWORD, "role": "PARENT"}
YOUNG = {"full_name": "Amina Demo", "phone": "+237699000002", "password": PASSWORD, "role": "YOUNG"}
RELATIVE = {"full_name": "Marc Demo", "phone": "+237699000003", "password": PASSWORD, "role": "RELATIVE"}
AUTHORITY = {"full_name": "Poste Demo", "phone": "+237699000004", "password": PASSWORD, "role": "AUTHORITY"}
HOME = {"latitude": 3.8480, "longitude": 11.5021}
SIGHT = {"latitude": 3.875, "longitude": 11.522}
OPEN_SOS = {"CREATED", "ACTIVE", "ACKNOWLEDGED", "IN_PROGRESS"}
OPEN_CASE = {"OPEN", "SEARCHING"}
KIT_FILE = Path(__file__).resolve().parent.parent / ".demo_kit.json"

SCHOOL_ZONE = {
    "name": "École",
    **SCHOOL,
    "radius_meters": 300,
    "min_exit_duration_seconds": 0,
    "schedules": [{"weekday": day, "start_time": "07:30:00", "end_time": "17:00:00"} for day in range(5)],
}
HOME_ZONE = {
    "name": "Maison",
    **HOME,
    "radius_meters": 150,
    "min_exit_duration_seconds": 0,
    "schedules": [{"weekday": day, "start_time": "18:00:00", "end_time": "07:00:00"} for day in range(7)],
}
MARKET_RISK = {
    "name": "Carrefour du marché",
    **SIGHT,
    "radius_meters": 250,
    "typical_start_hour": 18,
    "typical_end_hour": 23,
}


def _auth(session: dict) -> dict:
    return {"Authorization": f"Bearer {session['access_token']}"}


def _complete_login(http, body: dict) -> dict:
    """Après le mot de passe, valide l'OTP (otp_dev en développement seulement)."""
    if body.get("access_token"):
        return body
    otp = body.get("otp_dev")
    if not otp:
        raise RuntimeError("Login 2FA sans otp_dev — aucun SMS n'est envoyé, le seed exige le mode développement")
    verified = http.post(
        "/api/v1/auth/verify-otp",
        json={"challenge_id": body["challenge_id"], "code": otp},
    )
    if verified.status_code != 200:
        raise RuntimeError(verified.text)
    return verified.json()


def _insert_legacy_demo_user(payload: dict) -> None:
    """Crée le compte seed avec motdepasse, hors règle d’inscription forte."""
    from app.core.enums import UserRole
    from app.core.security import hash_password
    from app.db.session import SessionLocal
    from app.models.people import YoungPerson
    from app.models.user import User

    db = SessionLocal()
    try:
        existing = db.query(User).filter(User.phone == payload["phone"]).one_or_none()
        if existing is not None:
            return
        role = UserRole(payload["role"])
        user = User(
            full_name=payload["full_name"],
            phone=payload["phone"],
            password_hash=hash_password(payload["password"]),
            role=role,
            is_active=True,
        )
        db.add(user)
        db.flush()
        if role == UserRole.YOUNG:
            db.add(YoungPerson(user_id=user.id, display_name=payload["full_name"]))
        db.commit()
    finally:
        db.close()


def register_or_login(http, payload: dict) -> dict:
    login = http.post("/api/v1/auth/login", json={"phone": payload["phone"], "password": payload["password"]})
    if login.status_code == 200:
        return _complete_login(http, login.json())
    created = http.post("/api/v1/auth/register", json=payload)
    if created.status_code == 200:
        return created.json()
    # Comptes seed historiques : motdepasse (grandfather). L’inscription
    # publique exige désormais un mot de passe fort.
    _insert_legacy_demo_user(payload)
    login = http.post("/api/v1/auth/login", json={"phone": payload["phone"], "password": payload["password"]})
    if login.status_code != 200:
        raise RuntimeError(f"Compte {payload['phone']} : {created.text} / {login.text}")
    return _complete_login(http, login.json())


def _pair(http, young: dict, guardian: dict) -> dict:
    listed = http.get("/api/v1/family/children", headers=_auth(guardian))
    young_id = young["user"]["young_person_id"]
    for link in listed.json():
        if link["young_person_id"] == young_id and link["status"] == "ACTIVE":
            return link
    code = http.post("/api/v1/family/young/pairing-code", headers=_auth(young))
    if code.status_code != 200:
        raise RuntimeError(code.text)
    linked = http.post("/api/v1/family/links/code", headers=_auth(guardian), json={"code": code.json()["code"]})
    if linked.status_code != 200:
        raise RuntimeError(linked.text)
    return linked.json()


def _ensure_zone(http, parent: dict, young_id: str, payload: dict) -> None:
    listed = http.get(f"/api/v1/zones/children/{young_id}", headers=_auth(parent))
    names = {zone["name"] for zone in listed.json()}
    if payload["name"] in names:
        return
    created = http.post("/api/v1/zones", headers=_auth(parent), json={"young_person_id": young_id, **payload})
    if created.status_code != 200:
        raise RuntimeError(created.text)


def _ensure_risk_zone(http, parent: dict, payload: dict) -> None:
    listed = http.get("/api/v1/risk-zones/list", headers=_auth(parent))
    if listed.status_code >= 300:
        raise RuntimeError(listed.text)
    names = {zone["name"] for zone in listed.json()}
    if payload["name"] in names:
        return
    created = http.post("/api/v1/risk-zones", headers=_auth(parent), json=payload)
    if created.status_code != 200:
        raise RuntimeError(created.text)


def _ensure_relative_trigger(http, young: dict, link: dict) -> dict:
    if link.get("can_trigger_alert") and link.get("can_report_missing"):
        return link
    patched = http.patch(
        f"/api/v1/family/links/{link['id']}/permissions",
        headers=_auth(young),
        json={"can_trigger_alert": True, "can_report_missing": True},
    )
    if patched.status_code != 200:
        raise RuntimeError(patched.text)
    return patched.json()


def _ensure_share(http, young: dict, parent: dict) -> dict | None:
    listed = http.get("/api/v1/shares/me", headers=_auth(young))
    if listed.status_code >= 300:
        raise RuntimeError(listed.text)
    parent_id = parent["user"]["id"]
    for share in listed.json():
        if share["target_user_id"] == parent_id and share["is_active"]:
            return share
    created = http.post(
        "/api/v1/shares",
        headers=_auth(young),
        json={"target_user_id": parent_id, "duration_minutes": 480},
    )
    if created.status_code != 200:
        raise RuntimeError(created.text)
    return created.json()


def _ensure_demo_circle(http, parent: dict, young: dict, relative: dict) -> dict:
    """Cercle « Famille Demo » : grouping des comptes seed, sans toucher aux GuardianLink."""
    listed = http.get("/api/v1/circles", headers=_auth(parent))
    if listed.status_code >= 300:
        raise RuntimeError(listed.text)
    circle = next((item for item in listed.json() if item["name"] == "Famille Demo"), None)
    if circle is None:
        created = http.post("/api/v1/circles", headers=_auth(parent), json={"name": "Famille Demo"})
        if created.status_code != 200:
            raise RuntimeError(created.text)
        circle = created.json()
    code = circle["invite_code"]
    for session in (young, relative):
        joined = http.post("/api/v1/circles/join", headers=_auth(session), json={"code": code})
        if joined.status_code != 200:
            raise RuntimeError(joined.text)
    return circle


def _ensure_kit(http, young: dict) -> dict:
    listed = http.get("/api/v1/trackers/me", headers=_auth(young))
    if listed.status_code == 200 and listed.json():
        row = listed.json()[0]
        saved = {}
        if KIT_FILE.exists():
            saved = json.loads(KIT_FILE.read_text(encoding="utf-8"))
        return {
            "id": row["id"],
            "device_uid": row["device_uid"],
            "device_secret": saved.get("device_secret") if saved.get("device_uid") == row["device_uid"] else None,
            "created": False,
        }
    created = http.post("/api/v1/trackers", headers=_auth(young), json={"label": "Bracelet démo"})
    if created.status_code != 200:
        raise RuntimeError(created.text)
    kit = created.json()
    KIT_FILE.write_text(
        json.dumps({"device_uid": kit["device_uid"], "device_secret": kit["device_secret"]}, indent=2),
        encoding="utf-8",
    )
    return {**kit, "created": True}


def play_scenario(http, creds: dict) -> None:
    for step in DEMO_STEPS:
        if step["kind"] == "location":
            body = {
                **creds,
                "latitude": step["latitude"],
                "longitude": step["longitude"],
                "accuracy": step.get("accuracy"),
                "battery_level": step.get("battery_level"),
                "speed": step.get("speed"),
                "heading": step.get("heading"),
                "recorded_at": step["recorded_at"],
            }
            response = http.post("/api/v1/iot/location", json=body)
        else:
            body = {
                **creds,
                "event_type": step["event_type"],
                "recorded_at": step["recorded_at"],
                "latitude": step.get("latitude"),
                "longitude": step.get("longitude"),
            }
            response = http.post("/api/v1/iot/events", json=body)
        if response.status_code >= 300:
            raise RuntimeError(f"{step['label']}: {response.text}")


def play_search_act(http, parent: dict, young: dict, young_id: str) -> dict:
    """Scénarios 3–6 : SOS, disparition, search intelligence, témoignage. Idempotent."""
    alerts = http.get("/api/v1/alerts/me", headers=_auth(young))
    if alerts.status_code >= 300:
        raise RuntimeError(alerts.text)
    sos = next((item for item in alerts.json() if item["status"] in OPEN_SOS), None)
    if sos is None:
        posted = http.post(
            "/api/v1/alerts/sos",
            headers=_auth(young),
            json={
                **STOP,
                "accuracy": 15,
                "recorded_at": "2026-08-24T16:52:00+01:00",
                "description": "Démo soutenance — pas un kidnapping confirmé",
            },
        )
        if posted.status_code >= 300:
            raise RuntimeError(posted.text)
        sos = posted.json()
    cases = http.get("/api/v1/cases/mine", headers=_auth(parent))
    if cases.status_code >= 300:
        raise RuntimeError(cases.text)
    case = next(
        (item for item in cases.json() if item["status"] in OPEN_CASE and item["young_person_id"] == young_id),
        None,
    )
    if case is None:
        created = http.post(
            "/api/v1/cases",
            headers=_auth(parent),
            json={
                "young_person_id": young_id,
                "circumstances": "Pas rentré de l'école (démo). Ce n'est pas un kidnapping confirmé.",
                "occurred_at": "2026-08-24T16:52:00+01:00",
            },
        )
        if created.status_code >= 300:
            raise RuntimeError(created.text)
        case = created.json()
    if case["status"] == "OPEN":
        started = http.post(f"/api/v1/cases/{case['id']}/searching", headers=_auth(parent))
        if started.status_code >= 300:
            raise RuntimeError(started.text)
        case = started.json()
    intel = http.get(f"/api/v1/cases/{case['id']}/intelligence", headers=_auth(parent))
    if intel.status_code >= 300:
        raise RuntimeError(intel.text)
    notes = http.get(f"/api/v1/cases/{case['id']}/testimonies", headers=_auth(parent))
    if notes.status_code >= 300:
        raise RuntimeError(notes.text)
    if not notes.json():
        testimony = http.post(
            f"/api/v1/cases/{case['id']}/testimonies",
            headers=_auth(parent),
            json={
                "description": "J'ai aperçu l'enfant à cet endroit à 16h48.",
                **SIGHT,
                "observed_at": "2026-08-24T16:48:00+01:00",
            },
        )
        if testimony.status_code >= 300:
            raise RuntimeError(testimony.text)
    return {"sos": sos, "case": case, "intelligence": intel.json()}


def seed_demo(http, *, play: bool = False) -> dict:
    parent = register_or_login(http, PARENT)
    young = register_or_login(http, YOUNG)
    relative = register_or_login(http, RELATIVE)
    authority = register_or_login(http, AUTHORITY)
    parent_link = _pair(http, young, parent)
    relative_link = _ensure_relative_trigger(http, young, _pair(http, young, relative))
    young_id = young["user"]["young_person_id"]
    _ensure_zone(http, parent, young_id, SCHOOL_ZONE)
    _ensure_zone(http, parent, young_id, HOME_ZONE)
    _ensure_risk_zone(http, parent, MARKET_RISK)
    share = _ensure_share(http, young, parent)
    circle = _ensure_demo_circle(http, parent, young, relative)
    kit = _ensure_kit(http, young)
    search = None
    kit_played = False
    if play:
        secret = kit.get("device_secret")
        if secret:
            play_scenario(http, {"device_uid": kit["device_uid"], "device_secret": secret})
            kit_played = True
        search = play_search_act(http, parent, young, young_id)
    return {
        "parent": parent,
        "young": young,
        "relative": relative,
        "authority": authority,
        "link": parent_link,
        "relative_link": relative_link,
        "kit": kit,
        "young_person_id": young_id,
        "can_view_location": parent_link.get("can_view_location"),
        "can_trigger_alert": relative_link.get("can_trigger_alert"),
        "share": share,
        "circle": circle,
        "search": search,
        "kit_played": kit_played,
    }


def print_summary(result: dict) -> None:
    kit = result["kit"]
    secret = kit.get("device_secret")
    print("Comptes soutenance — mot de passe : motdepasse")
    print(f"  Parent  {PARENT['phone']}  {PARENT['full_name']}")
    print(f"  Jeune   {YOUNG['phone']}  {YOUNG['full_name']}")
    print(f"  Proche  {RELATIVE['phone']}  {RELATIVE['full_name']}")
    print(f"  Autorité {AUTHORITY['phone']}  {AUTHORITY['full_name']}")
    print("Le parent n'a pas la position en direct (can_view_location=false). Un SOS n'est pas un kidnapping confirmé.")
    print("Amina partage sa dernière position connue 8 h avec Marie (révocable). Pas un GPS continu.")
    print("Marc (proche) peut déclencher un SOS et déclarer un avis de recherche.")
    print("Un SOS n'est pas un kidnapping confirmé.")
    circle = result.get("circle") or {}
    print(
        f"Cercle « Famille Demo » (code {circle.get('invite_code', '—')}) : grouping des comptes, "
        "sans remplacer GuardianLink."
    )
    print("Zone à risque démo : Carrefour du marché (18h–23h). Signal, pas un kidnapping confirmé.")
    print(f"Kit uid={kit['device_uid']}")
    search = result.get("search")
    if search:
        print(f"SOS démo {search['sos']['id']} — demande d'aide, pas un kidnapping confirmé.")
        print(f"Dossier démo {search['case']['id']} ({search['case']['status']}) — instantané, pas un kidnapping confirmé.")
        print("Search Intelligence (règles) + témoignage 16h48. Cohérence estimée, pas une preuve.")
        if not result.get("kit_played"):
            print("Trajet kit non rejoué (secret manquant). Relancez après renouvellement du secret.")
    if secret:
        print(f"Kit secret={secret}  (copier maintenant ; pas renvoyé ensuite)")
        print(f"Exemple : python -m simulator --uid {kit['device_uid']} --secret {secret} scenario")
    else:
        print("Secret kit déjà émis. Renouveler dans l'app ou lire backend/.demo_kit.json s'il existe.")
