import 'location_access.dart';

/// Filtre GPS arrière-plan : 40 m, pas 1 Hz (batterie).
const int kBackgroundDistanceFilterMeters = 40;

/// Intervalle Android demandé au Fused Location Provider (indice, pas 1 Hz).
const Duration kBackgroundAndroidInterval = Duration(seconds: 45);

/// Texte exact de la notification persistante Android (service premier plan).
const String kBackgroundNotificationText = 'CityCare partage ta position';

/// État réel du partage arrière-plan — jamais « en direct ».
enum BackgroundShareStatus {
  /// L’utilisateur n’a pas activé l’opt-in.
  off,

  /// Opt-in + permission « toujours » + flux GPS ouvert.
  active,

  /// Opt-in, mais l’autorisation a été refusée (ou bloquée).
  denied,

  /// Opt-in, mais le GPS du téléphone est éteint.
  gpsOff,

  /// Opt-in, mais seulement « pendant l’utilisation » — insuffisant pour le fond.
  needsAlways,
}

/// Règles pures : opt-in, permissions, flux. Testable sans GPS matériel.
class BackgroundSharePolicy {
  const BackgroundSharePolicy._();

  static bool canStart(LocationAccess access) {
    return access.isGranted && access.isAlways;
  }

  static BackgroundShareStatus resolve({
    required bool optIn,
    required LocationAccess? access,
    required bool streamActive,
  }) {
    if (!optIn) {
      return BackgroundShareStatus.off;
    }
    if (access == null) {
      return BackgroundShareStatus.off;
    }
    switch (access.status) {
      case LocationAccessStatus.serviceDisabled:
        return BackgroundShareStatus.gpsOff;
      case LocationAccessStatus.denied:
      case LocationAccessStatus.deniedForever:
      case LocationAccessStatus.unavailable:
        return BackgroundShareStatus.denied;
      case LocationAccessStatus.granted:
        if (!access.isAlways) {
          return BackgroundShareStatus.needsAlways;
        }
        return streamActive ? BackgroundShareStatus.active : BackgroundShareStatus.needsAlways;
    }
  }

  /// Libellé honnête — jamais « en direct » ni « temps réel ».
  static String statusLabel(BackgroundShareStatus status) {
    switch (status) {
      case BackgroundShareStatus.off:
        return 'Inactif — le GPS ne tourne pas en arrière-plan.';
      case BackgroundShareStatus.active:
        return 'Actif — $kBackgroundNotificationText (notification persistante).';
      case BackgroundShareStatus.denied:
        return 'Permission refusée — ouvrez les réglages et choisissez « Toujours ».';
      case BackgroundShareStatus.gpsOff:
        return 'GPS éteint — activez la localisation du téléphone.';
      case BackgroundShareStatus.needsAlways:
        return 'Autorisation « pendant l’utilisation » seulement — le fond a besoin de « Toujours ».';
    }
  }
}
