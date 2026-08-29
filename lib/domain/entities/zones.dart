class SafetyZoneSchedule {
  const SafetyZoneSchedule({
    required this.id,
    required this.zoneId,
    required this.weekday,
    required this.startTime,
    required this.endTime,
  });

  final String id;
  final String zoneId;

  /// 0 = Monday … 6 = Sunday.
  final int weekday;
  final String startTime;
  final String endTime;

  bool get crossesMidnight => endTime.compareTo(startTime) <= 0;

  factory SafetyZoneSchedule.fromJson(Map<String, dynamic> json) {
    return SafetyZoneSchedule(
      id: json['id'] as String,
      zoneId: json['zone_id'] as String,
      weekday: json['weekday'] as int,
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
    );
  }
}

class SafetyZone {
  const SafetyZone({
    required this.id,
    required this.youngPersonId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.isActive,
    required this.accuracyToleranceMeters,
    required this.minExitDurationSeconds,
    this.schedules = const [],
    this.scheduleActiveNow = false,
    this.insideOnLastFix = false,
  });

  final String id;
  final String youngPersonId;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final bool isActive;
  final double accuracyToleranceMeters;
  final int minExitDurationSeconds;
  final List<SafetyZoneSchedule> schedules;
  final bool scheduleActiveNow;
  final bool insideOnLastFix;

  factory SafetyZone.fromJson(Map<String, dynamic> json) {
    return SafetyZone(
      id: json['id'] as String,
      youngPersonId: json['young_person_id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radiusMeters: (json['radius_meters'] as num).toDouble(),
      isActive: json['is_active'] as bool,
      accuracyToleranceMeters: (json['accuracy_tolerance_meters'] as num).toDouble(),
      minExitDurationSeconds: json['min_exit_duration_seconds'] as int,
      scheduleActiveNow: json['schedule_active_now'] as bool? ?? false,
      insideOnLastFix: json['inside_on_last_fix'] as bool? ?? false,
      schedules: (json['schedules'] as List<dynamic>? ?? [])
          .map((item) => SafetyZoneSchedule.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RiskZone {
  const RiskZone({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.isActive,
    required this.incidentCount,
    this.typicalStartHour,
    this.typicalEndHour,
    this.isHourActiveNow = false,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final bool isActive;
  final int incidentCount;
  final int? typicalStartHour;
  final int? typicalEndHour;
  final bool isHourActiveNow;

  factory RiskZone.fromJson(Map<String, dynamic> json) {
    return RiskZone(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radiusMeters: (json['radius_meters'] as num).toDouble(),
      isActive: json['is_active'] as bool,
      incidentCount: json['incident_count'] as int,
      typicalStartHour: json['typical_start_hour'] as int?,
      typicalEndHour: json['typical_end_hour'] as int?,
      isHourActiveNow: json['is_hour_active_now'] as bool? ?? false,
    );
  }
}

class RiskIncident {
  const RiskIncident({
    required this.id,
    required this.title,
    required this.latitude,
    required this.longitude,
    required this.occurredAt,
    required this.count,
    this.riskZoneId,
    this.description,
    this.source,
  });

  final String id;
  final String? riskZoneId;
  final String title;
  final String? description;
  final double latitude;
  final double longitude;
  final DateTime occurredAt;
  final String? source;
  final int count;

  factory RiskIncident.fromJson(Map<String, dynamic> json) {
    return RiskIncident(
      id: json['id'] as String,
      riskZoneId: json['risk_zone_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      source: json['source'] as String?,
      count: json['count'] as int,
    );
  }
}
