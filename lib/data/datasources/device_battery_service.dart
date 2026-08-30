import 'package:battery_plus/battery_plus.dart';

/// Batterie du téléphone (pas du kit IoT).
///
/// Une lecture ratée renvoie `null` : on n’invente jamais 100 %.
class DeviceBatteryService {
  DeviceBatteryService({Battery? battery}) : _battery = battery;

  final Battery? _battery;

  /// Pourcentage 0–100, ou null si le plugin échoue / renvoie hors plage.
  Future<int?> currentLevel() async {
    try {
      final level = await (_battery ?? Battery()).batteryLevel;
      return sanitizeBatteryLevel(level);
    } catch (_) {
      return null;
    }
  }
}

/// Accepte seulement un pourcentage réel. Hors 0–100 → omis.
int? sanitizeBatteryLevel(int? raw) {
  if (raw == null || raw < 0 || raw > 100) {
    return null;
  }
  return raw;
}
