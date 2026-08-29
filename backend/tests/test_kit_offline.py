from pathlib import Path

from simulator.offline_queue import KitOfflineQueue


def test_kit_queue_keeps_recorded_at(tmp_path: Path) -> None:
    queue = KitOfflineQueue(tmp_path / "kit.json")
    body = {
        "device_uid": "CCKIT-1",
        "latitude": 3.868,
        "longitude": 11.521,
        "recorded_at": "2026-08-24T16:30:00+01:00",
    }
    queue.enqueue("POST", "/api/v1/iot/location", body)
    items = queue.load()
    assert len(items) == 1
    assert items[0]["body"]["recorded_at"] == "2026-08-24T16:30:00+01:00"
    assert items[0]["path"] == "/api/v1/iot/location"
    assert queue.pending_count == 1
