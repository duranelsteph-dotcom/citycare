"""Scénario de démo soutenance. Horodatages un lundi scolaire — pas un suivi en direct."""

SCHOOL = {"latitude": 3.868, "longitude": 11.521}
POINT_A = {"latitude": 3.869, "longitude": 11.521}
POINT_B = {"latitude": 3.8705, "longitude": 11.522}
EXIT = {"latitude": 3.873, "longitude": 11.521}
MOVE = {"latitude": 3.880, "longitude": 11.530}
STOP = {"latitude": 3.880, "longitude": 11.530}

# Lundi 24 août 2026, dans la fenêtre école 07:30–17:00.
DEMO_STEPS = [
    {
        "label": "16:30 → École",
        "kind": "location",
        "recorded_at": "2026-08-24T16:30:00+01:00",
        "battery_level": 80,
        "speed": 0.4,
        "heading": 12,
        "accuracy": 14,
        **SCHOOL,
    },
    {
        "label": "16:35 → Position A",
        "kind": "location",
        "recorded_at": "2026-08-24T16:35:00+01:00",
        "battery_level": 78,
        "speed": 1.2,
        "heading": 18,
        "accuracy": 16,
        **POINT_A,
    },
    {
        "label": "16:40 → Position B",
        "kind": "location",
        "recorded_at": "2026-08-24T16:40:00+01:00",
        "battery_level": 76,
        "speed": 1.5,
        "heading": 40,
        "accuracy": 18,
        **POINT_B,
    },
    {
        "label": "16:45 → sortie de zone",
        "kind": "location",
        "recorded_at": "2026-08-24T16:45:00+01:00",
        "battery_level": 74,
        "speed": 1.8,
        "heading": 5,
        "accuracy": 15,
        **EXIT,
    },
    {
        "label": "16:48 → déplacement",
        "kind": "location",
        "recorded_at": "2026-08-24T16:48:00+01:00",
        "battery_level": 72,
        "speed": 1.4,
        "heading": 95,
        "accuracy": 20,
        **MOVE,
    },
    {
        "label": "16:52 → arrêt",
        "kind": "location",
        "recorded_at": "2026-08-24T16:52:00+01:00",
        "battery_level": 71,
        "speed": 0,
        "heading": 95,
        "accuracy": 12,
        **STOP,
    },
    {
        "label": "16:54 → perte du signal",
        "kind": "event",
        "event_type": "SIGNAL_LOST",
        "recorded_at": "2026-08-24T16:54:00+01:00",
        **STOP,
    },
]
