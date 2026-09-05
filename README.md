# CityCare

Application mobile Flutter + backend FastAPI de prévention, d'alerte, de
localisation et d'assistance à la recherche des enfants et des jeunes en
situation de danger ou de disparition.

- Application Flutter : racine du dépôt
- Backend FastAPI : `backend/`

## Architecture

Découpage en couches, sans logique métier dans les widgets :

```
lib/presentation   écrans, contrôleurs (ChangeNotifier), scopes, textes affichés
lib/domain         entités, énumérations, contrats de repositories
lib/data           datasources (HTTP, GPS, stockage sécurisé) et implémentations
lib/core           configuration et erreurs transverses
lib/app            thème, identité visuelle, composition de l'application
```

## Identité visuelle

Tout est **vectoriel** : aucun fichier image binaire dans le dépôt.

| Élément | Fichier |
| --- | --- |
| Palette, espacements, rayons | `lib/app/brand.dart` |
| Thèmes clair et sombre | `lib/app/theme.dart` |
| Logo (symbole, nom, logo complet) | `lib/presentation/widgets/citycare_logo.dart` |
| Illustrations de prévention | `lib/presentation/widgets/prevention_illustrations.dart` |
| Splash Flutter | `lib/presentation/splash/splash_page.dart` |
| Splash natif Android | `android/app/src/main/res/drawable-v23/launch_background.xml` |

Le thème suit le réglage clair/sombre du téléphone (`ThemeMode.system`).

## Carte

L'application sait afficher **deux** fournisseurs de carte et choisit
automatiquement :

- **Google Maps** si une clé d'API est configurée et la plateforme le supporte ;
- **OpenStreetMap** (`flutter_map`) sinon.

L'absence de clé ne provoque **aucun plantage** : la carte OpenStreetMap
historique reste affichée avec toutes les positions, zones et trajectoires, et
une pastille discrète explique comment activer Google Maps.

### Configurer la clé Google Maps

Aucune clé n'est versionnée. Deux endroits doivent la recevoir.

1. **SDK natif Android** — copier le modèle et renseigner la clé :

```bash
cp android/secrets.properties.example android/secrets.properties
# puis éditer CITYCARE_MAPS_API_KEY=...
```

2. **Interface Flutter** — indiquer au code Dart que la clé existe :

```bash
flutter run --dart-define=CITYCARE_MAPS_API_KEY=VOTRE_CLE
```

Pour iOS, copier `ios/Flutter/Secrets.xcconfig.example` en
`ios/Flutter/Secrets.xcconfig`.

`android/secrets.properties` et `ios/Flutter/Secrets.xcconfig` sont ignorés par
git.

## Localisation

Le parcours d'autorisation est géré de bout en bout par
`DeviceLocationService` (couche data, sur `geolocator`) et présenté par
`LocationPermissionCard` :

- service de localisation éteint → ouverture des réglages système ;
- refus simple → nouvelle demande possible ;
- refus définitif → ouverture des réglages de l'application ;
- état indéterminable → nouvel essai.

Le bandeau se rafraîchit automatiquement au retour des réglages.

## File hors ligne (Phase 13)

Les positions et SOS capturés hors ligne restent dans `OfflineQueue`
(horodatage téléphone conservé, pas Last Write Wins, aucun GPS inventé).

Le flush est le même partout :

- à l’ouverture de l’app et au retour réseau (premier plan) ;
- bouton « Réessayer » du bandeau (file non vide ≠ « synchronisé ») ;
- **Android** : tâche WorkManager périodique (~15 min, minimum OS) si la file
  n’est pas vide **et** qu’un jeton existe. Sinon no-op.

Ce n’est **pas** une garantie de 15 minutes : Doze, batterie et skins OEM
(Xiaomi, Huawei, Samsung, …) peuvent retarder, grouper ou supprimer le travail
en arrière-plan.

**iOS** : Workmanager s’appuie sur BGTaskScheduler / Background Fetch. iOS
décide du moment (souvent ~1×/jour selon l’usage). CityCare n’enregistre pas
de tâche périodique iOS ; le flush reste au premier plan.

## URL du backend

### Production cloud (Render + Supabase, gratuit soutenance)

Voir `deploy/RENDER_SUPABASE.md`. Build APK :

```powershell
# deploy/production.url = https://VOTRE-SERVICE.onrender.com/api/v1
.\scripts\build_release_apk.ps1
```

### Production VPS (Docker, option payante)

Voir `deploy/README.md`. Build APK :

```powershell
# deploy/production.url = https://api.votredomaine.com/api/v1
.\scripts\build_release_apk.ps1
```

L’APK release n’utilise **pas** USB, LAN ni Cloudflare.

### Développement local

```bash
flutter run --dart-define=CITYCARE_API_URL=https://exemple/api/v1
```

En **développement** sur un téléphone physique, ne pas utiliser `127.0.0.1`
(c’est le téléphone, pas le PC). L’app prend l’IPv4 LAN de
`lib/app/dev_api_host.dart` (mettre à jour après `ipconfig` si le Wi‑Fi change).
`--dart-define=CITYCARE_API_URL=http://IP_LAN:8000/api/v1` reste un override.
Émulateur Android : `http://10.0.2.2:8000/api/v1`. Backend : `python -m app.run_api`
écoute `0.0.0.0:8000`. Autoriser TCP 8000 dans le pare-feu Windows.
`adb reverse tcp:8000 tcp:8000` est un bonus USB, pas la solution définitive.
`.\scripts\start_usb_dev.ps1` pour le mode USB local.

## Vérifications

```bash
flutter pub get
flutter analyze
flutter test
```
