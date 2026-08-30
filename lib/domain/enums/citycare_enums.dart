enum UserRole { young, parent, relative, authority }

enum GuardianRelation { parent, relative, other }

enum GuardianLinkStatus { pending, active, revoked }

enum CircleRole { owner, member }

enum AlertStatus { created, active, acknowledged, inProgress, resolved, cancelled }

enum AlertSource { mobile, iot, relative, voice, system }

enum AlertSeverity { low, medium, high, critical }

enum LocationSource { phone, iot }

enum TrackerStatus { active, inactive, lowBattery, signalLost, removed }

enum TrackerEventType {
  location,
  sos,
  geofenceExit,
  geofenceEnter,
  signalLost,
  signalRestored,
  deviceRemoved,
  lowBattery,
  riskZoneEnter,
  anomaly,
}

enum CaseStatus { open, searching, found, closed }

enum CasePriority { low, medium, high }

enum TestimonyStatus { submitted, underReview, verified, rejected }

enum SearchZoneKind { probableDisplacement, prioritySearch }

enum SearchPriority { low, medium, high }

enum RiskLevel { low, medium, high }

enum ConsistencyLevel { low, medium, high }

enum NotificationType {
  sos,
  geofenceExit,
  lowBattery,
  signalLost,
  riskZoneEnter,
  anomaly,
  deviceRemoved,
  positionShare,
  missingCase,
  searchUpdate,
  testimony,
}

enum TrackingMode { normal, surveillance, emergency, powerSave }

extension UserRoleApi on UserRole {
  String get apiValue => switch (this) {
        UserRole.young => 'YOUNG',
        UserRole.parent => 'PARENT',
        UserRole.relative => 'RELATIVE',
        UserRole.authority => 'AUTHORITY',
      };

  static UserRole parse(String value) => switch (value) {
        'YOUNG' => UserRole.young,
        'PARENT' => UserRole.parent,
        'RELATIVE' => UserRole.relative,
        'AUTHORITY' => UserRole.authority,
        _ => throw FormatException('Unknown UserRole: $value'),
      };
}

extension GuardianRelationApi on GuardianRelation {
  String get apiValue => switch (this) {
        GuardianRelation.parent => 'PARENT',
        GuardianRelation.relative => 'RELATIVE',
        GuardianRelation.other => 'OTHER',
      };

  static GuardianRelation parse(String value) => switch (value) {
        'PARENT' => GuardianRelation.parent,
        'RELATIVE' => GuardianRelation.relative,
        'OTHER' => GuardianRelation.other,
        _ => throw FormatException('Unknown GuardianRelation: $value'),
      };
}

extension CircleRoleApi on CircleRole {
  String get apiValue => switch (this) {
        CircleRole.owner => 'OWNER',
        CircleRole.member => 'MEMBER',
      };

  static CircleRole parse(String value) => switch (value) {
        'OWNER' => CircleRole.owner,
        'MEMBER' => CircleRole.member,
        _ => throw FormatException('Unknown CircleRole: $value'),
      };
}

extension GuardianLinkStatusApi on GuardianLinkStatus {
  String get apiValue => switch (this) {
        GuardianLinkStatus.pending => 'PENDING',
        GuardianLinkStatus.active => 'ACTIVE',
        GuardianLinkStatus.revoked => 'REVOKED',
      };

  static GuardianLinkStatus parse(String value) => switch (value) {
        'PENDING' => GuardianLinkStatus.pending,
        'ACTIVE' => GuardianLinkStatus.active,
        'REVOKED' => GuardianLinkStatus.revoked,
        _ => throw FormatException('Unknown GuardianLinkStatus: $value'),
      };
}

extension AlertStatusApi on AlertStatus {
  String get apiValue => switch (this) {
        AlertStatus.created => 'CREATED',
        AlertStatus.active => 'ACTIVE',
        AlertStatus.acknowledged => 'ACKNOWLEDGED',
        AlertStatus.inProgress => 'IN_PROGRESS',
        AlertStatus.resolved => 'RESOLVED',
        AlertStatus.cancelled => 'CANCELLED',
      };

  static AlertStatus parse(String value) => switch (value) {
        'CREATED' => AlertStatus.created,
        'ACTIVE' => AlertStatus.active,
        'ACKNOWLEDGED' => AlertStatus.acknowledged,
        'IN_PROGRESS' => AlertStatus.inProgress,
        'RESOLVED' => AlertStatus.resolved,
        'CANCELLED' => AlertStatus.cancelled,
        _ => throw FormatException('Unknown AlertStatus: $value'),
      };
}

extension AlertSourceApi on AlertSource {
  String get apiValue => switch (this) {
        AlertSource.mobile => 'MOBILE',
        AlertSource.iot => 'IOT',
        AlertSource.relative => 'RELATIVE',
        AlertSource.voice => 'VOICE',
        AlertSource.system => 'SYSTEM',
      };

  static AlertSource parse(String value) => switch (value) {
        'MOBILE' => AlertSource.mobile,
        'IOT' => AlertSource.iot,
        'RELATIVE' => AlertSource.relative,
        'VOICE' => AlertSource.voice,
        'SYSTEM' => AlertSource.system,
        _ => throw FormatException('Unknown AlertSource: $value'),
      };
}

extension AlertSeverityApi on AlertSeverity {
  String get apiValue => name.toUpperCase();

  static AlertSeverity parse(String value) => switch (value) {
        'LOW' => AlertSeverity.low,
        'MEDIUM' => AlertSeverity.medium,
        'HIGH' => AlertSeverity.high,
        'CRITICAL' => AlertSeverity.critical,
        _ => throw FormatException('Unknown AlertSeverity: $value'),
      };
}

extension LocationSourceApi on LocationSource {
  String get apiValue => switch (this) {
        LocationSource.phone => 'PHONE',
        LocationSource.iot => 'IOT',
      };

  static LocationSource parse(String value) => switch (value) {
        'PHONE' => LocationSource.phone,
        'IOT' => LocationSource.iot,
        _ => throw FormatException('Unknown LocationSource: $value'),
      };
}

extension TrackerStatusApi on TrackerStatus {
  String get apiValue => switch (this) {
        TrackerStatus.active => 'ACTIVE',
        TrackerStatus.inactive => 'INACTIVE',
        TrackerStatus.lowBattery => 'LOW_BATTERY',
        TrackerStatus.signalLost => 'SIGNAL_LOST',
        TrackerStatus.removed => 'REMOVED',
      };

  static TrackerStatus parse(String value) => switch (value) {
        'ACTIVE' => TrackerStatus.active,
        'INACTIVE' => TrackerStatus.inactive,
        'LOW_BATTERY' => TrackerStatus.lowBattery,
        'SIGNAL_LOST' => TrackerStatus.signalLost,
        'REMOVED' => TrackerStatus.removed,
        _ => throw FormatException('Unknown TrackerStatus: $value'),
      };
}

extension TrackerEventTypeApi on TrackerEventType {
  String get apiValue => switch (this) {
        TrackerEventType.location => 'LOCATION',
        TrackerEventType.sos => 'SOS',
        TrackerEventType.geofenceExit => 'GEOFENCE_EXIT',
        TrackerEventType.geofenceEnter => 'GEOFENCE_ENTER',
        TrackerEventType.signalLost => 'SIGNAL_LOST',
        TrackerEventType.signalRestored => 'SIGNAL_RESTORED',
        TrackerEventType.deviceRemoved => 'DEVICE_REMOVED',
        TrackerEventType.lowBattery => 'LOW_BATTERY',
        TrackerEventType.riskZoneEnter => 'RISK_ZONE_ENTER',
        TrackerEventType.anomaly => 'ANOMALY',
      };

  static TrackerEventType parse(String value) => switch (value) {
        'LOCATION' => TrackerEventType.location,
        'SOS' => TrackerEventType.sos,
        'GEOFENCE_EXIT' => TrackerEventType.geofenceExit,
        'GEOFENCE_ENTER' => TrackerEventType.geofenceEnter,
        'SIGNAL_LOST' => TrackerEventType.signalLost,
        'SIGNAL_RESTORED' => TrackerEventType.signalRestored,
        'DEVICE_REMOVED' => TrackerEventType.deviceRemoved,
        'LOW_BATTERY' => TrackerEventType.lowBattery,
        'RISK_ZONE_ENTER' => TrackerEventType.riskZoneEnter,
        'ANOMALY' => TrackerEventType.anomaly,
        _ => throw FormatException('Unknown TrackerEventType: $value'),
      };
}

extension CaseStatusApi on CaseStatus {
  String get apiValue => name.toUpperCase();

  static CaseStatus parse(String value) => switch (value) {
        'OPEN' => CaseStatus.open,
        'SEARCHING' => CaseStatus.searching,
        'FOUND' => CaseStatus.found,
        'CLOSED' => CaseStatus.closed,
        _ => throw FormatException('Unknown CaseStatus: $value'),
      };
}

extension CasePriorityApi on CasePriority {
  String get apiValue => name.toUpperCase();

  static CasePriority parse(String value) => switch (value) {
        'LOW' => CasePriority.low,
        'MEDIUM' => CasePriority.medium,
        'HIGH' => CasePriority.high,
        _ => throw FormatException('Unknown CasePriority: $value'),
      };
}

extension TestimonyStatusApi on TestimonyStatus {
  String get apiValue => switch (this) {
        TestimonyStatus.submitted => 'SUBMITTED',
        TestimonyStatus.underReview => 'UNDER_REVIEW',
        TestimonyStatus.verified => 'VERIFIED',
        TestimonyStatus.rejected => 'REJECTED',
      };

  static TestimonyStatus parse(String value) => switch (value) {
        'SUBMITTED' => TestimonyStatus.submitted,
        'UNDER_REVIEW' => TestimonyStatus.underReview,
        'VERIFIED' => TestimonyStatus.verified,
        'REJECTED' => TestimonyStatus.rejected,
        _ => throw FormatException('Unknown TestimonyStatus: $value'),
      };
}

extension SearchZoneKindApi on SearchZoneKind {
  String get apiValue => switch (this) {
        SearchZoneKind.probableDisplacement => 'PROBABLE_DISPLACEMENT',
        SearchZoneKind.prioritySearch => 'PRIORITY_SEARCH',
      };

  static SearchZoneKind parse(String value) => switch (value) {
        'PROBABLE_DISPLACEMENT' => SearchZoneKind.probableDisplacement,
        'PRIORITY_SEARCH' => SearchZoneKind.prioritySearch,
        _ => throw FormatException('Unknown SearchZoneKind: $value'),
      };
}

extension SearchPriorityApi on SearchPriority {
  String get apiValue => name.toUpperCase();

  static SearchPriority parse(String value) => switch (value) {
        'LOW' => SearchPriority.low,
        'MEDIUM' => SearchPriority.medium,
        'HIGH' => SearchPriority.high,
        _ => throw FormatException('Unknown SearchPriority: $value'),
      };
}

extension RiskLevelApi on RiskLevel {
  String get apiValue => name.toUpperCase();

  static RiskLevel parse(String value) => switch (value) {
        'LOW' => RiskLevel.low,
        'MEDIUM' => RiskLevel.medium,
        'HIGH' => RiskLevel.high,
        _ => throw FormatException('Unknown RiskLevel: $value'),
      };
}

extension ConsistencyLevelApi on ConsistencyLevel {
  String get apiValue => name.toUpperCase();

  static ConsistencyLevel parse(String value) => switch (value) {
        'LOW' => ConsistencyLevel.low,
        'MEDIUM' => ConsistencyLevel.medium,
        'HIGH' => ConsistencyLevel.high,
        _ => throw FormatException('Unknown ConsistencyLevel: $value'),
      };
}

extension NotificationTypeApi on NotificationType {
  String get apiValue => switch (this) {
        NotificationType.sos => 'SOS',
        NotificationType.geofenceExit => 'GEOFENCE_EXIT',
        NotificationType.lowBattery => 'LOW_BATTERY',
        NotificationType.signalLost => 'SIGNAL_LOST',
        NotificationType.riskZoneEnter => 'RISK_ZONE_ENTER',
        NotificationType.anomaly => 'ANOMALY',
        NotificationType.deviceRemoved => 'DEVICE_REMOVED',
        NotificationType.positionShare => 'POSITION_SHARE',
        NotificationType.missingCase => 'MISSING_CASE',
        NotificationType.searchUpdate => 'SEARCH_UPDATE',
        NotificationType.testimony => 'TESTIMONY',
      };

  static NotificationType parse(String value) => switch (value) {
        'SOS' => NotificationType.sos,
        'GEOFENCE_EXIT' => NotificationType.geofenceExit,
        'LOW_BATTERY' => NotificationType.lowBattery,
        'SIGNAL_LOST' => NotificationType.signalLost,
        'RISK_ZONE_ENTER' => NotificationType.riskZoneEnter,
        'ANOMALY' => NotificationType.anomaly,
        'DEVICE_REMOVED' => NotificationType.deviceRemoved,
        'POSITION_SHARE' => NotificationType.positionShare,
        'MISSING_CASE' => NotificationType.missingCase,
        'SEARCH_UPDATE' => NotificationType.searchUpdate,
        'TESTIMONY' => NotificationType.testimony,
        _ => throw FormatException('Unknown NotificationType: $value'),
      };
}

extension TrackingModeApi on TrackingMode {
  String get apiValue => switch (this) {
        TrackingMode.normal => 'NORMAL',
        TrackingMode.surveillance => 'SURVEILLANCE',
        TrackingMode.emergency => 'EMERGENCY',
        TrackingMode.powerSave => 'POWER_SAVE',
      };

  static TrackingMode parse(String value) => switch (value) {
        'NORMAL' => TrackingMode.normal,
        'SURVEILLANCE' => TrackingMode.surveillance,
        'EMERGENCY' => TrackingMode.emergency,
        'POWER_SAVE' => TrackingMode.powerSave,
        _ => throw FormatException('Unknown TrackingMode: $value'),
      };
}
