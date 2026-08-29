import '../entities/zones.dart';

class SafetyZoneDraft {
  const SafetyZoneDraft({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.schedules,
    this.isActive = true,
  });

  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final bool isActive;
  final List<ScheduleDraft> schedules;

  Map<String, dynamic> toJson({String? youngPersonId}) {
    return {
      if (youngPersonId != null) 'young_person_id': youngPersonId,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius_meters': radiusMeters,
      'is_active': isActive,
      'schedules': schedules.map((item) => item.toJson()).toList(),
    };
  }
}

class ScheduleDraft {
  const ScheduleDraft({required this.weekday, required this.startTime, required this.endTime});

  final int weekday;
  final String startTime;
  final String endTime;

  Map<String, dynamic> toJson() => {
        'weekday': weekday,
        'start_time': startTime,
        'end_time': endTime,
      };
}

abstract class ZoneRepository {
  Future<List<SafetyZone>> myZones();

  Future<List<SafetyZone>> childZones(String youngPersonId);

  Future<SafetyZone> create(SafetyZoneDraft draft, {required String youngPersonId});

  Future<SafetyZone> update(String zoneId, SafetyZoneDraft draft);

  Future<void> delete(String zoneId);
}
