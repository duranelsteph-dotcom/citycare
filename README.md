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

## URL du backend

```bash
flutter run --dart-define=CITYCARE_API_URL=https://exemple/api/v1
```

## Vérifications

```bash
flutter pub get
flutter analyze
flutter test
```
