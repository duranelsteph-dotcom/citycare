/// État de l'accès à la localisation de l'appareil.
///
/// Cette description est volontairement indépendante de `geolocator` : la
/// couche présentation raisonne sur ces valeurs, pas sur le plugin.
enum LocationAccessStatus {
  /// L'application peut lire la position.
  granted,

  /// Le service de localisation du téléphone est éteint (GPS coupé).
  /// L'autorisation de l'application n'est pas en cause.
  serviceDisabled,

  /// L'utilisateur a refusé, mais on peut redemander.
  denied,

  /// Refus définitif : seul un passage par les réglages système débloque.
  deniedForever,

  /// État indéterminable (plateforme non supportée, erreur du système).
  unavailable,
}

/// Résultat d'une vérification d'accès à la localisation.
class LocationAccess {
  const LocationAccess(this.status, {this.isPrecise = true});

  final LocationAccessStatus status;

  /// `false` lorsque l'utilisateur n'a accordé qu'une position approximative
  /// (Android 12+ « position approximative »). CityCare fonctionne quand même,
  /// mais la précision affichée sur la carte est plus large.
  final bool isPrecise;

  static const LocationAccess granted = LocationAccess(LocationAccessStatus.granted);

  bool get isGranted => status == LocationAccessStatus.granted;

  /// Une nouvelle demande système a-t-elle une chance d'aboutir ?
  bool get canAskAgain => status == LocationAccessStatus.denied;

  /// Faut-il envoyer l'utilisateur dans les réglages de l'application ?
  bool get needsAppSettings => status == LocationAccessStatus.deniedForever;

  /// Faut-il envoyer l'utilisateur dans les réglages de localisation système ?
  bool get needsLocationSettings => status == LocationAccessStatus.serviceDisabled;
}
