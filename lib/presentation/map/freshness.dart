import '../../domain/entities/tracking.dart';

/// Seuil backend [STALE_AFTER] (location_service) : 5 minutes.
const int kStaleAfterSeconds = 300;

/// Âge lisible : secondes, puis minutes, puis heures.
String formatAgeSeconds(int ageSeconds) {
  if (ageSeconds < 60) {
    return 'il y a $ageSeconds s';
  }
  final minutes = ageSeconds ~/ 60;
  if (minutes < 60) {
    return 'il y a $minutes min';
  }
  final hours = minutes ~/ 60;
  return 'il y a $hours h';
}

/// Une position est ancienne si le backend le dit, ou si l’âge dépasse 5 min.
bool locationLooksStale({required bool isStale, required int ageSeconds}) {
  return isStale || ageSeconds > kStaleAfterSeconds;
}

/// Fraîcheur honnête pour le sheet et les pastilles carte.
///
/// Jamais « temps réel » ni « en direct » : stale ou âge > seuil = dernière position connue.
String locationFreshnessLabel({required bool isStale, required int ageSeconds}) {
  final age = formatAgeSeconds(ageSeconds);
  if (locationLooksStale(isStale: isStale, ageSeconds: ageSeconds)) {
    return 'Dernière position : $age';
  }
  return 'Mis à jour $age';
}

/// Fraîcheur d’un point suivi. Absent = aucune position, pas un live.
String memberFreshnessLabel(TrackerLocation? point) {
  if (point == null) {
    return 'Aucune position connue';
  }
  return locationFreshnessLabel(isStale: point.isStale, ageSeconds: point.ageSeconds);
}
