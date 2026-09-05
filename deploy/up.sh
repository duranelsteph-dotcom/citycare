#!/usr/bin/env bash
# À exécuter SUR le VPS, depuis citycare/deploy
set -euo pipefail
cd "$(dirname "$0")"

if [[ ! -f .env ]]; then
  echo "Copiez .env.example vers .env et renseignez DOMAIN, SECRET_KEY, POSTGRES_PASSWORD"
  exit 1
fi

# shellcheck disable=SC1091
set -a
source .env
set +a

if [[ -z "${DOMAIN:-}" || -z "${SECRET_KEY:-}" || -z "${POSTGRES_PASSWORD:-}" ]]; then
  echo "DOMAIN, SECRET_KEY et POSTGRES_PASSWORD sont obligatoires dans .env"
  exit 1
fi

docker compose up -d --build
docker compose ps
echo "Attente HTTPS…"
for i in $(seq 1 30); do
  if curl -fsS "https://${DOMAIN}/api/v1/health" >/dev/null 2>&1; then
    curl -sS "https://${DOMAIN}/api/v1/health"
    echo
    echo "OK — URL API : https://${DOMAIN}/api/v1"
    exit 0
  fi
  sleep 3
done
echo "Health HTTPS pas encore prêt. Vérifiez DNS et : docker compose logs caddy api"
exit 1
