# CityCare — Render (API) + Supabase (PostgreSQL) — soutenance

Architecture gratuite pour la démo :

```
Téléphone (4G)
  → https://citycare-api-xxxx.onrender.com/api/v1
      → FastAPI (Render free)
          → PostgreSQL (Supabase free)
```

**Note free Render :** le service s’endort après ~15 min d’inactivité.
La 1ʳᵉ requête peut prendre 30–60 s (cold start). Avant la soutenance,
ouvrez `/api/v1/health` dans le navigateur pour « réveiller » l’API.
L’URL HTTPS reste **la même** (permanente).

Le développement local (SQLite + USB) n’est **pas** cassé.

---

## A. Supabase (base)

1. Créez un projet sur https://supabase.com (gratuit).
2. **Project Settings → Database → Connection string → URI**
3. Choisissez **Transaction** pooler (port **6543**) ou **Session** (5432).
4. Remplacez `[YOUR-PASSWORD]` par le mot de passe de la base.
5. Copiez l’URI (commence par `postgresql://` ou `postgres://`).

Exemple (ne pas committer) :

```
postgresql://postgres.xxxx:MOTDEPASSE@aws-0-eu-central-1.pooler.supabase.com:6543/postgres
```

L’API CityCare normalise automatiquement vers `postgresql+psycopg://…?sslmode=require`.

Au **premier démarrage** Render, `create_all` + `ensure_schema` créent les tables.
Les comptes démo (Marie / Amina / Marc / Poste, mot de passe `motdepasse`) sont
créés automatiquement si `SEED_DEMO_ACCOUNTS=true` (défaut Blueprint).

Sinon, une fois l’API en ligne :

```bash
# Via curl (public, tant que SEED_DEMO_ACCOUNTS=true) :
curl -X POST https://VOTRE-SERVICE.onrender.com/api/v1/auth/seed-demo

# Ou Render Shell :
python -m simulator seed
```

`ALLOW_OTP_DEV=true` renvoie `otp_dev` dans la réponse login (aucun SMS) même si
`APP_ENV=production` — indispensable pour la soutenance sans passerelle SMS.

---

## B. Render (API)

1. https://dashboard.render.com → connectez GitHub
2. **New → Blueprint** → sélectionnez le dépôt `citycare`
3. Validez `render.yaml`
4. Dans les variables d’environnement, collez **DATABASE_URL** = URI Supabase
5. Déployez

URL publique typique :

```
https://citycare-api.onrender.com
```

Health :

```
https://citycare-api.onrender.com/api/v1/health
```

---

## C. APK production (PC)

```powershell
# Une ligne dans deploy/production.url :
# https://citycare-api.onrender.com/api/v1

cd C:\Users\DURANEL\citycare
.\scripts\build_release_apk.ps1
```

Installez `build\app\outputs\flutter-apk\app-release.apk`, **débranchez l’USB**, utilisez la 4G.

---

## Variables Render (résumé)

| Variable | Valeur |
|----------|--------|
| `APP_ENV` | `production` |
| `HTTPS_ONLY` | `true` |
| `SECRET_KEY` | auto (Blueprint) ou `openssl rand -hex 32` |
| `DATABASE_URL` | URI Supabase |
| `CORS_ORIGINS` | `*` |
| `UPLOAD_DIR` | `/app/static/uploads` |
