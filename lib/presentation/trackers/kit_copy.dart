import '../../domain/entities/tracking.dart';
import '../../domain/enums/citycare_enums.dart';
import '../auth/role_labels.dart';

String knownClock(DateTime? at) {
  if (at == null) {
    return 'inconnue';
  }
  final local = at.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// Copie honnête : perte de signal / retrait / batterie = dernière info, pas l’état actuel.
String kitStatusHeadline(GpsTracker kit) {
  final clock = knownClock(kit.lastSeenAt);
  return switch (kit.status) {
    TrackerStatus.signalLost =>
      'Connexion avec le kit perdue. Dernière position connue : $clock. '
          'Dernière communication connue — pas actuelle, pas un suivi en direct.',
    TrackerStatus.removed =>
      'Le kit a signalé un retrait. Dernière communication : $clock — pas un suivi en direct.',
    TrackerStatus.lowBattery =>
      'Batterie kit faible (dernière info ${kit.batteryLevel == null ? 'inconnue' : '${kit.batteryLevel} %'}). '
          'Pas la batterie actuelle.',
    TrackerStatus.inactive => 'Kit désactivé. Le SOS du kit est refusé.',
    TrackerStatus.active => trackerStatusLabel(kit.status),
  };
}

String childKitLine(GpsTracker kit) {
  final battery = kit.batteryLevel == null ? '' : ' · ${kit.batteryLevel} %';
  return '${kit.label}$battery · ${trackerStatusLabel(kit.status)} — dernière info, pas actuelle';
}

String kitEventLine(TrackerEvent event) {
  final clock = knownClock(event.recordedAt);
  return switch (event.eventType) {
    TrackerEventType.signalLost =>
      'Connexion avec le kit perdue à $clock. Dernière info — pas la position actuelle.',
    TrackerEventType.deviceRemoved =>
      'Retrait du kit enregistré à $clock. Trace, pas un suivi en direct.',
    TrackerEventType.lowBattery =>
      'Batterie faible signalée à $clock — pas la batterie actuelle.',
    TrackerEventType.signalRestored =>
      'Connexion rétablie à $clock. Dernière communication connue, pas un GPS continu.',
    _ => '${trackerEventTypeLabel(event.eventType)} à $clock — trace, pas un suivi en direct.',
  };
}
