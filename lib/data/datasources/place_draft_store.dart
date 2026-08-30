import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Brouillon de lieu saisi à l’installation, avant qu’un enfant soit rattaché.
class PlaceDraft {
  const PlaceDraft({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.kind = 'other',
  });

  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final String kind;

  Map<String, dynamic> toJson() => {
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'radius_meters': radiusMeters,
        'kind': kind,
      };

  factory PlaceDraft.fromJson(Map<String, dynamic> json) {
    return PlaceDraft(
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radiusMeters: (json['radius_meters'] as num).toDouble(),
      kind: json['kind'] as String? ?? 'other',
    );
  }
}

/// Persistance locale des lieux d’installation (pas un secret).
class PlaceDraftStore {
  PlaceDraftStore({SharedPreferences? prefs}) : _prefs = prefs;

  static const key = 'citycare_place_drafts_v1';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _instance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<List<PlaceDraft>> readAll() async {
    final prefs = await _instance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((item) => PlaceDraft.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> upsert(PlaceDraft draft) async {
    final current = await readAll();
    final next = [
      ...current.where((item) => item.kind != draft.kind || item.kind == 'other'),
      draft,
    ];
    final prefs = await _instance();
    await prefs.setString(key, jsonEncode(next.map((item) => item.toJson()).toList()));
  }
}
