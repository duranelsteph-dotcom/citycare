# Déploiement CityCare sur VPS (production permanente)

Architecture :

```
Téléphone (4G/Wi‑Fi)
    → HTTPS
        → Caddy (Let's Encrypt)
            → FastAPI CityCare
                → PostgreSQL
```

Sans câble USB, sans ADB reverse, sans tunnel Cloudflare, **sans PC allumé**.

## 1. Louer un VPS (une fois)

Recommandé (simple, ~4–6 €/mois, Ubuntu 22.04 ou 24.04) :

| Hébergeur | Lien |
|-----------|------|
| **Contabo** | https://contabo.com (VPS S) |
| **Hetzner** | https://www.hetzner.com/cloud (CX22) |
| **OVH** | https://www.ovhcloud.com |

Choisissez : **Ubuntu 24.04**, au moins **1 vCPU / 2 Go RAM**, région EU.

Notez l’**IP publique** du serveur.

## 2. Domaine (recommandé pour HTTPS automatique)

Chez votre registrar (Namecheap, OVH, Cloudflare DNS, etc.) :

1. Créez un enregistrement **A** : `api` → IP du VPS  
   Exemple : `api.votredomaine.com` → `203.0.113.10`
2. Attendez la propagation DNS (souvent quelques minutes)

Sans domaine : possible avec un certificat manuel, mais plus fragile. Préférez un domaine.

## 3. Préparer le serveur (SSH)

Depuis votre PC (PowerShell ou terminal) :

```bash
ssh root@IP_DU_VPS
```

Puis sur le VPS :

```bash
apt update && apt upgrade -y
apt install -y docker.io docker-compose-v2 git
systemctl enable --now docker
```

## 4. Copier CityCare et démarrer

Sur le VPS :

```bash
git clone https://github.com/VOTRE_REPO/citycare.git
# ou : scp / rsync depuis votre PC
cd citycare/deploy
cp .env.example .env
nano .env
```

Dans `.env`, renseignez au minimum :

- `DOMAIN=api.votredomaine.com`
- `POSTGRES_PASSWORD=` (mot de passe fort)
- `SECRET_KEY=` (générer : `openssl rand -hex 32`)

Puis :

```bash
docker compose up -d --build
docker compose ps
curl -s https://api.votredomaine.com/api/v1/health
```

Réponse attendue : `"status":"ok"`.

## 5. Comptes de démo (optionnel)

```bash
docker compose exec api python -m simulator seed
```

Comptes habituels (`+237699000001` / `motdepasse` / OTP `otp_dev` en mode seed).

## 6. APK production (sur votre PC Windows)

1. Écrire l’URL dans `deploy/production.url` (une seule ligne) :

```
https://api.votredomaine.com/api/v1
```

2. Lancer :

```powershell
cd C:\Users\DURANEL\citycare
.\scripts\build_release_apk.ps1
```

3. Installer l’APK :

`build\app\outputs\flutter-apk\app-release.apk`

## 7. Mise à jour ultérieure

```bash
cd ~/citycare
git pull
cd deploy
docker compose up -d --build
```

## Dépannage

| Symptôme | Action |
|----------|--------|
| Certificat HTTPS échoue | Vérifier DNS A + ports 80/443 ouverts |
| `SECRET_KEY trop faible` | `openssl rand -hex 32` dans `.env` |
| App « serveur injoignable » | Vérifier `production.url` / rebuild APK ; tester `/health` dans le navigateur du téléphone |
