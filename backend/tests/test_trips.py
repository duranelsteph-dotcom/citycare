from datetime import datetime, timedelta, timezone
from uuid import uuid4

from fastapi.testclient import TestClient

from app.core.enums import UserRole
from app.main import app

client = TestClient(app)

A = {"latitude": 3.8480, "longitude": 11.5021, "accuracy": 12}
B = {"latitude": 3.8520, "longitude": 11.5060, "accuracy": 14}
C = {"latitude": 3.8560, "longitude": 11.5100, "accuracy": 18}
D = {"latitude": 3.8600, "longitude": 11.5140, "accuracy": 16}


def _register(role: UserRole, name: str) -> dict:
    phone = f"+2377{uuid4().hex[:8]}"
    response = client.post(
        "/api/v1/auth/register",
        json={"full_name": name, "phone": phone, "password": "VilleCare1!", "role": role.value},
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


def _stamp(minutes_ago: int) -> str:
    return (datetime.now(timezone.utc) - timedelta(minutes=minutes_ago)).isoformat()


def _grant(young: dict, link_id: str) -> None:
    granted = client.patch(
        f"/api/v1/family/links/{link_id}/permissions",
        headers=_auth(young),
        json={"can_view_location": True},
    )
    assert granted.status_code == 200, granted.text


def test_trips_group_on_eighteen_minute_gap() -> None:
    young = _register(UserRole.YOUNG, "Amina Trips")
    now = datetime.now(timezone.utc)
    base = now - timedelta(hours=2)
    # Deux points à 5 min, puis un trou de 30 min = 2 trajets (seuil 18 min).
    first = base
    second = base + timedelta(minutes=5)
    third = base + timedelta(minutes=35)
    assert client.post("/api/v1/locations", headers=_auth(young), json={**A, "recorded_at": first.isoformat()}).status_code == 200
    assert client.post("/api/v1/locations", headers=_auth(young), json={**B, "recorded_at": second.isoformat()}).status_code == 200
    assert client.post("/api/v1/locations", headers=_auth(young), json={**C, "recorded_at": third.isoformat()}).status_code == 200
    trips = client.get(
        "/api/v1/locations/me/trips",
        headers=_auth(young),
        params={"from": (base - timedelta(minutes=10)).isoformat(), "to": now.isoformat()},
    )
    assert trips.status_code == 200, trips.text
    body = trips.json()
    assert body["trip_count"] == 2
    assert body["point_count"] == 3
    assert body["period"] == "custom"
    assert body["gap_threshold_seconds"] == 1080
    assert body["trips"][0]["point_count"] == 2
    assert body["trips"][0]["distance_meters"] > 0
    assert body["trips"][1]["point_count"] == 1
    assert body["trips"][1]["distance_meters"] == 0
    assert "rapport de conduite" in body["disclaimer"]
    assert "vitesse max" in body["disclaimer"]
    # Phase 16 : aucun champ conduite.
    assert "max_speed" not in body
    assert "distracted" not in body
    assert "max_speed" not in body["trips"][0]


def test_trips_period_yesterday_and_last_7_days() -> None:
    young = _register(UserRole.YOUNG, "Paul Trips")
    now = datetime.now(timezone.utc)
    yesterday = (now.replace(hour=12, minute=0, second=0, microsecond=0) - timedelta(days=1)).isoformat()
    three_days = (now - timedelta(days=3)).isoformat()
    eight_days = (now - timedelta(days=8)).isoformat()
    client.post("/api/v1/locations", headers=_auth(young), json={**A, "recorded_at": yesterday})
    client.post("/api/v1/locations", headers=_auth(young), json={**B, "recorded_at": three_days})
    client.post("/api/v1/locations", headers=_auth(young), json={**C, "recorded_at": eight_days})

    yday = client.get("/api/v1/locations/me/trips?period=yesterday", headers=_auth(young))
    assert yday.status_code == 200, yday.text
    assert yday.json()["period"] == "yesterday"
    assert yday.json()["point_count"] == 1
    assert yday.json()["trips"][0]["points"][0]["latitude"] == A["latitude"]

    week = client.get("/api/v1/locations/me/trips?period=last_7_days", headers=_auth(young))
    assert week.status_code == 200, week.text
    assert week.json()["period"] == "last_7_days"
    assert week.json()["point_count"] == 2
    lats = {point["latitude"] for trip in week.json()["trips"] for point in trip["points"]}
    assert A["latitude"] in lats
    assert B["latitude"] in lats
    assert C["latitude"] not in lats


def test_trips_from_to_iso_window() -> None:
    young = _register(UserRole.YOUNG, "Sara Trips")
    start = datetime.now(timezone.utc) - timedelta(hours=3)
    mid = start + timedelta(minutes=10)
    later = start + timedelta(hours=5)
    client.post("/api/v1/locations", headers=_auth(young), json={**A, "recorded_at": start.isoformat()})
    client.post("/api/v1/locations", headers=_auth(young), json={**B, "recorded_at": mid.isoformat()})
    client.post("/api/v1/locations", headers=_auth(young), json={**C, "recorded_at": later.isoformat()})
    window_end = start + timedelta(hours=2)
    trips = client.get(
        "/api/v1/locations/me/trips",
        headers=_auth(young),
        params={"from": start.isoformat(), "to": window_end.isoformat()},
    )
    assert trips.status_code == 200, trips.text
    body = trips.json()
    assert body["period"] == "custom"
    assert body["point_count"] == 2
    assert body["trips"][0]["points"][-1]["latitude"] == B["latitude"]


def test_trajectory_accepts_same_filters() -> None:
    young = _register(UserRole.YOUNG, "Léo TrajFilter")
    client.post("/api/v1/locations", headers=_auth(young), json={**A, "recorded_at": _stamp(8)})
    client.post("/api/v1/locations", headers=_auth(young), json={**B, "recorded_at": _stamp(3)})
    traj = client.get("/api/v1/locations/me/trajectory?period=today", headers=_auth(young))
    assert traj.status_code == 200, traj.text
    body = traj.json()
    assert body["period"] == "today"
    assert body["point_count"] == 2
    assert len(body["trips"]) >= 1
    assert "suivi en direct" in body["disclaimer"]


def test_child_trips_need_watch_permission() -> None:
    young = _register(UserRole.YOUNG, "Nadia Trips")
    parent = _register(UserRole.PARENT, "Jean Trips")
    link = _pair(young, parent)
    young_id = link["young_person_id"]
    client.post("/api/v1/locations", headers=_auth(young), json=A)

    denied = client.get(f"/api/v1/locations/children/{young_id}/trips", headers=_auth(parent))
    assert denied.status_code == 403
    assert "autorisé" in denied.json()["detail"].lower() or "partage" in denied.json()["detail"].lower()

    # Un dossier ouvert n'ouvre pas l'historique (règles watch, pas CASE).
    created = client.post("/api/v1/cases", headers=_auth(parent), json={"young_person_id": young_id})
    assert created.status_code == 200, created.text
    still = client.get(f"/api/v1/locations/children/{young_id}/trips", headers=_auth(parent))
    assert still.status_code == 403

    _grant(young, link["id"])
    ok = client.get(f"/api/v1/locations/children/{young_id}/trips?period=today", headers=_auth(parent))
    assert ok.status_code == 200, ok.text
    assert ok.json()["access"] == "PERMISSION"
    assert ok.json()["point_count"] == 1
    assert "rapport de conduite" in ok.json()["disclaimer"]


def test_trips_empty_is_not_an_error() -> None:
    young = _register(UserRole.YOUNG, "Mira Empty")
    trips = client.get("/api/v1/locations/me/trips?period=today", headers=_auth(young))
    assert trips.status_code == 200, trips.text
    assert trips.json()["trip_count"] == 0
    assert trips.json()["trips"] == []


def test_from_without_to_is_rejected() -> None:
    young = _register(UserRole.YOUNG, "No To")
    bad = client.get(
        "/api/v1/locations/me/trips",
        headers=_auth(young),
        params={"from": datetime.now(timezone.utc).isoformat()},
    )
    assert bad.status_code == 422
