import 'dart:convert';

import '../enums/citycare_enums.dart';

class Alert {
  const Alert({
    required this.id,
    required this.youngPersonId,
    required this.source,
    required this.status,
    required this.severity,
    required this.triggeredAt,
    required this.createdAt,
    required this.updatedAt,
    this.triggeredByUserId,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.batteryLevel,
    this.trackerStatus,
    this.description,
    this.lastKnownLatitude,
    this.lastKnownLongitude,
    this.lastKnownAt,
    this.youngDisplayName,
  });

  final String id;
  final String youngPersonId;
  final String? triggeredByUserId;
  final AlertSource source;
  final AlertStatus status;
  final AlertSeverity severity;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final DateTime triggeredAt;
  final int? batteryLevel;
  final String? trackerStatus;
  final String? description;
  final double? lastKnownLatitude;
  final double? lastKnownLongitude;
  final DateTime? lastKnownAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? youngDisplayName;

  bool get isOpen =>
      status == AlertStatus.created ||
      status == AlertStatus.active ||
      status == AlertStatus.acknowledged ||
      status == AlertStatus.inProgress;

  bool get hasPoint => latitude != null && longitude != null;

  bool get positionLooksStale {
    final knownAt = lastKnownAt;
    if (!hasPoint || knownAt == null) {
      return false;
    }
    return triggeredAt.difference(knownAt).abs() > const Duration(minutes: 5);
  }

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'] as String,
      youngPersonId: json['young_person_id'] as String,
      triggeredByUserId: json['triggered_by_user_id'] as String?,
      source: AlertSourceApi.parse(json['source'] as String),
      status: AlertStatusApi.parse(json['status'] as String),
      severity: AlertSeverityApi.parse(json['severity'] as String),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      triggeredAt: DateTime.parse(json['triggered_at'] as String),
      batteryLevel: json['battery_level'] as int?,
      trackerStatus: json['tracker_status'] as String?,
      description: json['description'] as String?,
      lastKnownLatitude: (json['last_known_latitude'] as num?)?.toDouble(),
      lastKnownLongitude: (json['last_known_longitude'] as num?)?.toDouble(),
      lastKnownAt: json['last_known_at'] == null ? null : DateTime.parse(json['last_known_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      youngDisplayName: json['young_display_name'] as String?,
    );
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientUserId,
    required this.notificationType,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.alertId,
    this.caseId,
    this.payload,
    this.context,
  });

  final String id;
  final String recipientUserId;
  final NotificationType notificationType;
  final String title;
  final String body;
  final bool isRead;
  final String? alertId;
  final String? caseId;
  final String? payload;
  final NotificationContext? context;
  final DateTime createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      recipientUserId: json['recipient_user_id'] as String,
      notificationType: NotificationTypeApi.parse(json['notification_type'] as String),
      title: json['title'] as String,
      body: json['body'] as String,
      isRead: json['is_read'] as bool,
      alertId: json['alert_id'] as String?,
      caseId: json['case_id'] as String?,
      payload: json['payload'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      context: json['context'] is Map<String, dynamic>
          ? NotificationContext.fromJson(json['context'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic>? get payloadMap {
    if (payload == null || payload!.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(payload!);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  String? get youngPersonId => context?.youngPersonId ?? payloadMap?['young_person_id'] as String?;

  String? get youngDisplayName => context?.youngDisplayName ?? payloadMap?['young_display_name'] as String?;

  String get target {
    final fromContext = context?.target;
    if (fromContext != null && fromContext.isNotEmpty) {
      return fromContext;
    }
    return switch (notificationType) {
      NotificationType.sos => 'SOS',
      NotificationType.geofenceExit || NotificationType.riskZoneEnter || NotificationType.anomaly => 'MAP',
      NotificationType.lowBattery || NotificationType.signalLost || NotificationType.deviceRemoved => 'KIT',
      NotificationType.positionShare => 'SHARE',
      NotificationType.missingCase || NotificationType.searchUpdate || NotificationType.testimony => 'CASE',
    };
  }
}

class NotificationContext {
  const NotificationContext({
    required this.channel,
    required this.target,
    required this.isLivePosition,
    required this.disclaimer,
    this.youngPersonId,
    this.youngDisplayName,
    this.latitude,
    this.longitude,
    this.zoneName,
  });

  final String channel;
  final String target;
  final String? youngPersonId;
  final String? youngDisplayName;
  final double? latitude;
  final double? longitude;
  final String? zoneName;
  final bool isLivePosition;
  final String disclaimer;

  factory NotificationContext.fromJson(Map<String, dynamic> json) {
    return NotificationContext(
      channel: json['channel'] as String? ?? 'IN_APP',
      target: json['target'] as String? ?? 'INBOX',
      youngPersonId: json['young_person_id'] as String?,
      youngDisplayName: json['young_display_name'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      zoneName: json['zone_name'] as String?,
      isLivePosition: json['is_live_position'] as bool? ?? false,
      disclaimer: json['disclaimer'] as String? ??
          'Inbox dans l’application, plus un push FCM si un jeton appareil est enregistré. '
              'Ce n’est pas un kidnapping confirmé.',
    );
  }
}
