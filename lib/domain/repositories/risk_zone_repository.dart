import '../entities/zones.dart';

class RiskZoneDraft {
  const RiskZoneDraft({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.isActive = true,
    this.typicalStartHour,
    this.typicalEndHour,
  });

  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final bool isActive;
  final int? typicalStartHour;
  final int? typicalEndHour;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius_meters': radiusMeters,
      'is_active': isActive,
      'typical_start_hour': typicalStartHour,
      'typical_end_hour': typicalEndHour,
    };
  }
}

class IncidentDraft {
  const IncidentDraft({required this.title, this.description, this.source, this.count = 1});

  final String title;
  final String? description;
  final String? source;
  final int count;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'source': source,
      'count': count,
    };
  }
}

abstract class RiskZoneRepository {
  Future<List<RiskZone>> list();

  Future<RiskZone> create(RiskZoneDraft draft);

  Future<RiskZone> update(String zoneId, RiskZoneDraft draft);

  Future<void> delete(String zoneId);

  Future<List<RiskIncident>> incidents(String zoneId);

  Future<RiskIncident> addIncident(String zoneId, IncidentDraft draft);
}
