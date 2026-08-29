import '../enums/citycare_enums.dart';

class GpsTracker {
  const GpsTracker({
    required this.id,
    required this.youngPersonId,
    required this.deviceUid,
    required this.label,
    required this.status,
    required this.trackingMode,
    this.batteryLevel,
    this.signalStrength,
    this.lastSeenAt,
    this.lastLatitude,
    this.lastLongitude,
    this.firmwareVersion,
    this.youngDisplayName,
    this.deviceSecret,
  });

  final String id;
  final String youngPersonId;
  final String deviceUid;
  final String label;
  final TrackerStatus status;
  final TrackingMode trackingMode;
  final int? batteryLevel;
  final int? signalStrength;
  final DateTime? lastSeenAt;
  final double? lastLatitude;
  final double? lastLongitude;
  final String? firmwareVersion;
  final String? youngDisplayName;
  /// Présent uniquement à la création. Jamais renvoyé ensuite.
  final String? deviceSecret;

  bool get isEnabled => status != TrackerStatus.inactive;

  factory GpsTracker.fromJson(Map<String, dynamic> json) {
    return GpsTracker(
      id: json['id'] as String,
      youngPersonId: json['young_person_id'] as String,
      deviceUid: json['device_uid'] as String,
      label: json['label'] as String,
      status: TrackerStatusApi.parse(json['status'] as String),
      trackingMode: TrackingModeApi.parse(json['tracking_mode'] as String),
      batteryLevel: json['battery_level'] as int?,
      signalStrength: json['signal_strength'] as int?,
      lastSeenAt: json['last_seen_at'] == null ? null : DateTime.parse(json['last_seen_at'] as String),
      lastLatitude: (json['last_latitude'] as num?)?.toDouble(),
      lastLongitude: (json['last_longitude'] as num?)?.toDouble(),
      firmwareVersion: json['firmware_version'] as String?,
      youngDisplayName: json['young_display_name'] as String?,
      deviceSecret: json['device_secret'] as String?,
    );
  }
}

class TrackerLocation {
  const TrackerLocation({
    required this.id,
    required this.youngPersonId,
    required this.source,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.trackerId,
    this.accuracy,
    this.altitude,
    this.speed,
    this.heading,
    this.batteryLevel,
    this.signalStrength,
    this.isStale = false,
    this.ageSeconds = 0,
  });

  final String id;
  final String? trackerId;
  final String youngPersonId;
  final LocationSource source;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? altitude;
  final double? speed;
  final double? heading;
  final DateTime recordedAt;
  final int? batteryLevel;
  final int? signalStrength;
  final bool isStale;
  final int ageSeconds;

  factory TrackerLocation.fromJson(Map<String, dynamic> json) {
    return TrackerLocation(
      id: json['id'] as String,
      trackerId: json['tracker_id'] as String?,
      youngPersonId: json['young_person_id'] as String,
      source: LocationSourceApi.parse(json['source'] as String),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      batteryLevel: json['battery_level'] as int?,
      signalStrength: json['signal_strength'] as int?,
      isStale: json['is_stale'] as bool? ?? false,
      ageSeconds: json['age_seconds'] as int? ?? 0,
    );
  }
}

class TrackerEvent {
  const TrackerEvent({
    required this.id,
    required this.youngPersonId,
    required this.eventType,
    required this.recordedAt,
    this.trackerId,
    this.latitude,
    this.longitude,
    this.payload,
  });

  final String id;
  final String? trackerId;
  final String youngPersonId;
  final TrackerEventType eventType;
  final DateTime recordedAt;
  final double? latitude;
  final double? longitude;
  final String? payload;

  factory TrackerEvent.fromJson(Map<String, dynamic> json) {
    return TrackerEvent(
      id: json['id'] as String,
      trackerId: json['tracker_id'] as String?,
      youngPersonId: json['young_person_id'] as String,
      eventType: TrackerEventTypeApi.parse(json['event_type'] as String),
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      payload: json['payload'] as String?,
    );
  }
}

class PositionShare {
  const PositionShare({
    required this.id,
    required this.youngPersonId,
    required this.targetUserId,
    required this.startsAt,
    required this.isRevoked,
    required this.isActive,
    this.expiresAt,
    this.revokedAt,
    this.targetDisplayName,
    this.youngDisplayName,
  });

  final String id;
  final String youngPersonId;
  final String targetUserId;
  final DateTime startsAt;
  final DateTime? expiresAt;
  final bool isRevoked;
  final DateTime? revokedAt;
  final bool isActive;
  final String? targetDisplayName;
  final String? youngDisplayName;

  factory PositionShare.fromJson(Map<String, dynamic> json) {
    return PositionShare(
      id: json['id'] as String,
      youngPersonId: json['young_person_id'] as String,
      targetUserId: json['target_user_id'] as String,
      startsAt: DateTime.parse(json['starts_at'] as String),
      expiresAt: json['expires_at'] == null ? null : DateTime.parse(json['expires_at'] as String),
      isRevoked: json['is_revoked'] as bool,
      revokedAt: json['revoked_at'] == null ? null : DateTime.parse(json['revoked_at'] as String),
      isActive: json['is_active'] as bool? ?? false,
      targetDisplayName: json['target_display_name'] as String?,
      youngDisplayName: json['young_display_name'] as String?,
    );
  }
}

class LocationWatch {
  const LocationWatch({
    required this.pollAfterSeconds,
    required this.effectiveMode,
    required this.access,
    this.latest,
    this.staleAfterSeconds = 300,
    this.message = '',
  });

  final TrackerLocation? latest;
  final int pollAfterSeconds;
  final TrackingMode effectiveMode;
  final String access;
  final int staleAfterSeconds;
  final String message;

  factory LocationWatch.fromJson(Map<String, dynamic> json) {
    return LocationWatch(
      latest: json['latest'] == null ? null : TrackerLocation.fromJson(json['latest'] as Map<String, dynamic>),
      pollAfterSeconds: json['poll_after_seconds'] as int,
      effectiveMode: TrackingModeApi.parse(json['effective_mode'] as String),
      access: json['access'] as String,
      staleAfterSeconds: json['stale_after_seconds'] as int? ?? 300,
      message: json['message'] as String? ?? '',
    );
  }
}
