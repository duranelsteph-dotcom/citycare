"""CLI simulateur kit IoT.

Exemple :
  .venv\\Scripts\\python.exe -m simulator seed
  .venv\\Scripts\\python.exe -m simulator seed --play
  .venv\\Scripts\\python.exe -m simulator --uid CCKIT-... --secret ... scenario
  .venv\\Scripts\\python.exe -m simulator --uid CCKIT-... --secret ... ping --lat 3.868 --lng 11.521
  .venv\\Scripts\\python.exe -m simulator --uid CCKIT-... --secret ... event SIGNAL_LOST
  .venv\\Scripts\\python.exe -m simulator --uid CCKIT-... --secret ... sos
"""

from __future__ import annotations

import argparse
import os
import sys
import time
from pathlib import Path

import httpx

from simulator.offline_queue import KitOfflineQueue
from simulator.scenario import DEMO_STEPS

BANNER = (
    "Simulateur CityCare — le kit parle à l'API, pas à Flutter. "
    "Ce n'est pas un bracelet réel. Le rafraîchissement suit un intervalle conseillé, "
    "pas un GPS continu. Un SOS n'est pas un kidnapping confirmé. "
    "Hors ligne : file locale du simulateur, horodatage conservé, pas Last Write Wins. "
    "Actualisez l'app pour la dernière valeur connue."
)


def _client(base_url: str) -> httpx.Client:
    return httpx.Client(base_url=base_url.rstrip("/"), timeout=20.0)


def _creds(args: argparse.Namespace) -> dict:
    uid = args.uid or os.environ.get("CITYCARE_KIT_UID")
    secret = args.secret or os.environ.get("CITYCARE_KIT_SECRET")
    if not uid or not secret:
        print("Indiquez --uid et --secret (ou CITYCARE_KIT_UID / CITYCARE_KIT_SECRET).", file=sys.stderr)
        sys.exit(2)
    return {"device_uid": uid, "device_secret": secret}


def _fail(response: httpx.Response) -> None:
    print(f"HTTP {response.status_code}: {response.text}", file=sys.stderr)
    sys.exit(1)


def _queue() -> KitOfflineQueue:
    override = os.environ.get("CITYCARE_KIT_QUEUE")
    return KitOfflineQueue(Path(override) if override else None)


def _post(client: httpx.Client, queue: KitOfflineQueue, path: str, body: dict, *, enqueue: bool = True):
    try:
        response = client.post(path, json=body)
    except httpx.RequestError as exc:
        if enqueue:
            queue.enqueue("POST", path, body)
            print(
                f"Kit hors ligne ({exc.__class__.__name__}). Mis en file ({queue.path.name}). "
                "Horodatage conservé, pas Last Write Wins. Ce n'est pas un bracelet réel."
            )
            return None
        print(f"Réseau indisponible: {exc}", file=sys.stderr)
        return None
    if response.status_code >= 500 and enqueue:
        queue.enqueue("POST", path, body)
        print(
            f"HTTP {response.status_code} — mis en file kit. "
            "Horodatage conservé, pas Last Write Wins."
        )
        return None
    if response.status_code >= 300:
        _fail(response)
    return response


def cmd_ping(client: httpx.Client, creds: dict, args: argparse.Namespace) -> None:
    body = {
        **creds,
        "latitude": args.lat,
        "longitude": args.lng,
        "accuracy": args.accuracy,
        "battery_level": args.battery,
        "speed": args.speed,
        "heading": args.heading,
    }
    response = _post(client, _queue(), "/api/v1/iot/location", body)
    if response is None:
        return
    data = response.json()
    print(
        f"Position kit enregistrée ({data['source']}) "
        f"{data['latitude']}, {data['longitude']} — dernière connue, pas actuelle."
    )


def cmd_sos(client: httpx.Client, creds: dict, args: argparse.Namespace) -> None:
    body = {**creds}
    if args.lat is not None and args.lng is not None:
        body["latitude"] = args.lat
        body["longitude"] = args.lng
        body["battery_level"] = args.battery
    response = _post(client, _queue(), "/api/v1/iot/sos", body)
    if response is None:
        return
    data = response.json()
    print(f"SOS kit {data['status']} source={data['source']} — ce n'est pas un kidnapping confirmé.")


def cmd_event(client: httpx.Client, creds: dict, args: argparse.Namespace) -> None:
    body = {**creds, "event_type": args.event_type}
    if args.lat is not None and args.lng is not None:
        body["latitude"] = args.lat
        body["longitude"] = args.lng
    if args.battery is not None:
        body["battery_level"] = args.battery
    response = _post(client, _queue(), "/api/v1/iot/events", body)
    if response is None:
        return
    data = response.json()
    print(f"Événement {data['event']['event_type']} — statut kit {data['tracker']['status']}.")


def cmd_scenario(client: httpx.Client, creds: dict, args: argparse.Namespace) -> None:
    print("Scénario soutenance (horodatages lundi 16:30–16:54). Zone école à configurer dans l'app.")
    queue = _queue()
    for step in DEMO_STEPS:
        print(f"→ {step['label']}")
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
            response = _post(client, queue, "/api/v1/iot/location", body)
        else:
            body = {
                **creds,
                "event_type": step["event_type"],
                "recorded_at": step["recorded_at"],
                "latitude": step.get("latitude"),
                "longitude": step.get("longitude"),
            }
            response = _post(client, queue, "/api/v1/iot/events", body)
        if response is None:
            continue
        if args.sleep > 0:
            time.sleep(args.sleep)
    print("Terminé. Dans l'app : laisser l'écran Position ouvert (rafraîchissement) ou actualiser. Pas un GPS continu.")


def cmd_config(client: httpx.Client, creds: dict, args: argparse.Namespace) -> None:
    response = client.post("/api/v1/iot/config", json=creds)
    if response.status_code >= 300:
        _fail(response)
    data = response.json()
    print(
        f"Mode stocké {data['tracking_mode']} → effectif {data['effective_mode']} "
        f"({data['suggested_interval_seconds']} s). SOS ouvert : {data['open_sos']}. "
        f"{data['message']}"
    )


def cmd_watch(client: httpx.Client, creds: dict, args: argparse.Namespace) -> None:
    print("Envoi périodique selon l'intervalle API. Ctrl+C pour arrêter. Pas un GPS continu.")
    remaining = args.count
    lat, lng = args.lat, args.lng
    while remaining != 0:
        cfg = client.post("/api/v1/iot/config", json=creds)
        if cfg.status_code >= 300:
            _fail(cfg)
        wait = int(cfg.json()["suggested_interval_seconds"])
        ping = _post(
            client,
            _queue(),
            "/api/v1/iot/location",
            {
                **creds,
                "latitude": lat,
                "longitude": lng,
                "accuracy": args.accuracy,
                "battery_level": args.battery,
            },
        )
        if ping is None:
            time.sleep(wait if args.sleep is None else args.sleep)
            continue
        body = ping.json()
        print(
            f"Ping {body['source']} {body['latitude']}, {body['longitude']} "
            f"— prochaine pause {wait} s (mode {cfg.json()['effective_mode']})."
        )
        if remaining > 0:
            remaining -= 1
            if remaining == 0:
                break
        time.sleep(wait if args.sleep is None else args.sleep)
    print("Watch terminé.")


def cmd_flush(client: httpx.Client, creds: dict, args: argparse.Namespace) -> None:
    queue = _queue()
    items = queue.load()
    if not items:
        print("File kit vide.")
        return
    leftover = []
    sent = 0
    for item in items:
        path = item.get("path")
        body = item.get("body") or {}
        if not isinstance(body, dict):
            leftover.append(item)
            continue
        body = {**body, **creds}
        response = _post(client, queue, str(path), body, enqueue=False)
        if response is None:
            leftover.append(item)
            continue
        sent += 1
        recorded = body.get("recorded_at")
        print(f"Rejoué {path} (recorded_at={recorded}) — horodatage d'origine conservé, pas Last Write Wins.")
    queue.save(leftover)
    print(f"Synchronisé {sent}, restant {len(leftover)}.")


def main() -> None:
    parser = argparse.ArgumentParser(description=BANNER)
    parser.add_argument("--base-url", default=os.environ.get("CITYCARE_API", "http://127.0.0.1:8000"))
    parser.add_argument("--uid", default=None)
    parser.add_argument("--secret", default=None)
    sub = parser.add_subparsers(dest="command", required=True)

    ping = sub.add_parser("ping", help="Envoyer une position kit")
    ping.add_argument("--lat", type=float, required=True)
    ping.add_argument("--lng", type=float, required=True)
    ping.add_argument("--battery", type=int, default=72)
    ping.add_argument("--accuracy", type=float, default=15)
    ping.add_argument("--speed", type=float, default=None)
    ping.add_argument("--heading", type=float, default=None)
    ping.set_defaults(func=cmd_ping)

    sos = sub.add_parser("sos", help="SOS physique du kit")
    sos.add_argument("--lat", type=float, default=None)
    sos.add_argument("--lng", type=float, default=None)
    sos.add_argument("--battery", type=int, default=40)
    sos.set_defaults(func=cmd_sos)

    event = sub.add_parser("event", help="SIGNAL_LOST, DEVICE_REMOVED, LOW_BATTERY, SIGNAL_RESTORED")
    event.add_argument("event_type", choices=["SIGNAL_LOST", "DEVICE_REMOVED", "LOW_BATTERY", "SIGNAL_RESTORED"])
    event.add_argument("--lat", type=float, default=None)
    event.add_argument("--lng", type=float, default=None)
    event.add_argument("--battery", type=int, default=None)
    event.set_defaults(func=cmd_event)

    scenario = sub.add_parser("scenario", help="Trajet école → sortie de zone → perte de signal")
    scenario.add_argument("--sleep", type=float, default=0, help="Pause en secondes entre les points (démo orale)")
    scenario.set_defaults(func=cmd_scenario)

    config = sub.add_parser("config", help="Intervalle conseillé (mode, SOS, batterie)")
    config.set_defaults(func=cmd_config)

    watch = sub.add_parser("watch", help="Pings répétés selon l'intervalle API")
    watch.add_argument("--lat", type=float, default=3.868)
    watch.add_argument("--lng", type=float, default=11.521)
    watch.add_argument("--battery", type=int, default=72)
    watch.add_argument("--accuracy", type=float, default=15)
    watch.add_argument("--count", type=int, default=5, help="-1 = infini")
    watch.add_argument("--sleep", type=float, default=None, help="Forcer la pause (sinon intervalle API)")
    watch.set_defaults(func=cmd_watch)

    flush = sub.add_parser("flush", help="Rejouer la file hors ligne du simulateur kit")
    flush.set_defaults(func=cmd_flush)

    seed = sub.add_parser("seed", help="Créer les comptes soutenance Marie / Amina / Marc")
    seed.add_argument("--play", action="store_true", help="École → sortie → SOS → dossier → search intelligence → témoignage")
    seed.set_defaults(func=None)

    args = parser.parse_args()
    print(BANNER)
    if args.command == "seed":
        from simulator.seed import print_summary, seed_demo

        with _client(args.base_url) as http:
            result = seed_demo(http, play=args.play)
            print_summary(result)
        return
    creds = _creds(args)
    with _client(args.base_url) as client:
        args.func(client, creds, args)


if __name__ == "__main__":
    main()
