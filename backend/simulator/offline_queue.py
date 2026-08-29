"""File locale du simulateur kit : horodatage conservé, pas Last Write Wins."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

DEFAULT_PATH = Path(__file__).resolve().parent.parent / ".kit_offline_queue.json"


class KitOfflineQueue:
    def __init__(self, path: Path | None = None) -> None:
        self.path = path or DEFAULT_PATH

    def load(self) -> list[dict[str, Any]]:
        if not self.path.is_file():
            return []
        try:
            data = json.loads(self.path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return []
        items = data.get("items") if isinstance(data, dict) else data
        return items if isinstance(items, list) else []

    def save(self, items: list[dict[str, Any]]) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        payload = {"items": items, "updated_at": datetime.now(timezone.utc).isoformat()}
        self.path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

    def enqueue(self, method: str, path: str, body: dict[str, Any]) -> None:
        items = self.load()
        items.append(
            {
                "method": method,
                "path": path,
                "body": body,
                "queued_at": datetime.now(timezone.utc).isoformat(),
            }
        )
        self.save(items)

    @property
    def pending_count(self) -> int:
        return len(self.load())
