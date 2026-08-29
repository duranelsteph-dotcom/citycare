import '../enums/citycare_enums.dart';
import 'alerts.dart';
import 'search.dart';
import 'tracking.dart';

class EmergencySnapshot {
  const EmergencySnapshot({
    required this.youngPersonId,
    required this.displayName,
    required this.effectiveMode,
    required this.isLive,
    required this.access,
    required this.disclaimer,
    this.lastKnown,
    this.lastCommunicationAt,
    this.batteryLevel,
    this.kitStatus,
    this.kitLabel,
    this.openSos,
    this.openCaseId,
    this.trajectory,
    this.searchZones = const [],
    this.kitEvents = const [],
    this.testimonyCount = 0,
  });

  final String youngPersonId;
  final String displayName;
  final TrackingMode effectiveMode;
  final TrackerLocation? lastKnown;
  final DateTime? lastCommunicationAt;
  final int? batteryLevel;
  final String? kitStatus;
  final String? kitLabel;
  final Alert? openSos;
  final String? openCaseId;
  final Trajectory? trajectory;
  final List<SearchZone> searchZones;
  final List<TrackerEvent> kitEvents;
  final int testimonyCount;
  final bool isLive;
  final String access;
  final String disclaimer;

  factory EmergencySnapshot.fromJson(Map<String, dynamic> json) {
    return EmergencySnapshot(
      youngPersonId: json['young_person_id'] as String,
      displayName: json['display_name'] as String,
      effectiveMode: TrackingModeApi.parse(json['effective_mode'] as String),
      lastKnown: json['last_known'] == null
          ? null
          : TrackerLocation.fromJson(json['last_known'] as Map<String, dynamic>),
      lastCommunicationAt: json['last_communication_at'] == null
          ? null
          : DateTime.parse(json['last_communication_at'] as String),
      batteryLevel: json['battery_level'] as int?,
      kitStatus: json['kit_status'] as String?,
      kitLabel: json['kit_label'] as String?,
      openSos: json['open_sos'] == null ? null : Alert.fromJson(json['open_sos'] as Map<String, dynamic>),
      openCaseId: json['open_case_id'] as String?,
      trajectory: json['trajectory'] == null
          ? null
          : Trajectory.fromJson(json['trajectory'] as Map<String, dynamic>),
      searchZones: (json['search_zones'] as List<dynamic>? ?? [])
          .map((item) => SearchZone.fromJson(item as Map<String, dynamic>))
          .toList(),
      kitEvents: (json['kit_events'] as List<dynamic>? ?? [])
          .map((item) => TrackerEvent.fromJson(item as Map<String, dynamic>))
          .toList(),
      testimonyCount: json['testimony_count'] as int? ?? 0,
      isLive: json['is_live'] as bool? ?? false,
      access: json['access'] as String? ?? 'EMERGENCY',
      disclaimer: json['disclaimer'] as String? ??
          'MODE URGENCE. Dernière position connue, pas un suivi en direct, pas un kidnapping confirmé.',
    );
  }
}
