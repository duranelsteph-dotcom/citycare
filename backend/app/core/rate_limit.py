from collections import defaultdict
from threading import Lock
from time import time

from app.core.config import settings


class SlidingWindowLimiter:
    def __init__(self) -> None:
        self._hits: dict[str, list[float]] = defaultdict(list)
        self._lock = Lock()

    def blocked(self, key: str, *, limit: int | None = None, window: int | None = None) -> bool:
        cap = settings.login_fail_max if limit is None else limit
        span = settings.login_fail_window_seconds if window is None else window
        now = time()
        with self._lock:
            bucket = [stamp for stamp in self._hits[key] if now - stamp < span]
            self._hits[key] = bucket
            return len(bucket) >= cap

    def hit(self, key: str) -> None:
        with self._lock:
            self._hits[key].append(time())

    def clear(self, key: str) -> None:
        with self._lock:
            self._hits.pop(key, None)


auth_limiter = SlidingWindowLimiter()
kit_limiter = SlidingWindowLimiter()
