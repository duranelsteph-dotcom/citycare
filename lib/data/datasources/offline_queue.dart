import 'dart:convert';

/// File d'attente hors ligne. Le serveur reste la source de vérité.
/// Les horodatages client sont conservés (pas Last Write Wins).
class OfflineQueue {
  final List<Map<String, dynamic>> locations = [];
  final List<Map<String, dynamic>> sos = [];

  int get pendingCount => locations.length + sos.length;

  bool get hasPending => pendingCount > 0;

  void enqueueLocation(Map<String, dynamic> payload) {
    locations.add(Map<String, dynamic>.from(payload));
  }

  void enqueueSos(Map<String, dynamic> payload) {
    sos.add(Map<String, dynamic>.from(payload));
  }

  String encode() {
    return jsonEncode({'locations': locations, 'sos': sos});
  }

  void loadFrom(String? raw) {
    locations.clear();
    sos.clear();
    if (raw == null || raw.isEmpty) {
      return;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return;
    }
    final loc = decoded['locations'];
    final alerts = decoded['sos'];
    if (loc is List) {
      locations.addAll(loc.whereType<Map>().map((item) => Map<String, dynamic>.from(item)));
    }
    if (alerts is List) {
      sos.addAll(alerts.whereType<Map>().map((item) => Map<String, dynamic>.from(item)));
    }
  }
}
