/// Configuration de la carte. **Aucune clé d'API n'est écrite ici.**
///
/// La clé Google Maps est injectée depuis l'extérieur, jamais versionnée :
///
/// * côté Dart (pour savoir si la carte Google est utilisable) :
///   `--dart-define=CITYCARE_MAPS_API_KEY=VOTRE_CLE`
/// * côté Android (pour que le SDK natif la reçoive) : renseigner
///   `CITYCARE_MAPS_API_KEY` dans `android/secrets.properties`, fichier ignoré
///   par git. Voir `android/secrets.properties.example`.
///
/// Si la clé est absente, l'application ne plante pas : elle bascule sur la
/// carte OpenStreetMap déjà utilisée par le projet.
library;

import 'package:flutter/foundation.dart';

/// Fournisseur de carte effectivement utilisé à l'écran.
enum MapProvider {
  /// Google Maps : clé présente et plateforme supportée.
  google,

  /// OpenStreetMap via flutter_map : repli toujours disponible.
  openStreetMap,
}

class MapsConfig {
  const MapsConfig._();

  /// Valeur injectée au build. Chaîne vide si rien n'a été fourni.
  static const String _rawApiKey = String.fromEnvironment('CITYCARE_MAPS_API_KEY');

  /// La clé a-t-elle été fournie au build ?
  static bool get hasApiKey => _rawApiKey.trim().isNotEmpty;

  /// Plateformes sur lesquelles `google_maps_flutter` est embarqué dans ce
  /// projet. Sur les autres (bureau, tests widget), on reste sur OpenStreetMap
  /// pour ne jamais provoquer d'exception de plugin manquant.
  static bool get isGoogleMapsSupported {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Fournisseur retenu pour l'affichage.
  static MapProvider get provider =>
      hasApiKey && isGoogleMapsSupported ? MapProvider.google : MapProvider.openStreetMap;

  /// Explication affichée à l'utilisateur quand Google Maps n'est pas actif.
  /// `null` lorsque Google Maps est bien utilisé : rien à signaler.
  static String? get fallbackReason {
    if (provider == MapProvider.google) {
      return null;
    }
    if (!isGoogleMapsSupported) {
      return 'Carte OpenStreetMap — Google Maps n’est pas disponible sur cette plateforme. '
          'Toutes les positions et zones restent affichées.';
    }
    return 'Carte OpenStreetMap — la clé Google Maps n’est pas configurée. '
        'Toutes les positions et zones restent affichées. '
        'Pour activer Google Maps : renseigner android/secrets.properties puis lancer '
        'flutter run --dart-define=CITYCARE_MAPS_API_KEY=VOTRE_CLE.';
  }
}
