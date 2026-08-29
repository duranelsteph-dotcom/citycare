class PairingCode {
  const PairingCode({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;

  factory PairingCode.fromJson(Map<String, dynamic> json) {
    return PairingCode(
      code: json['code'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }
}

class GuardianPermissions {
  const GuardianPermissions({
    this.canViewLocation,
    this.canReceiveAlerts,
    this.canTriggerAlert,
    this.canReportMissing,
    this.canManageZones,
    this.canManageTracker,
  });

  final bool? canViewLocation;
  final bool? canReceiveAlerts;
  final bool? canTriggerAlert;
  final bool? canReportMissing;
  final bool? canManageZones;
  final bool? canManageTracker;

  Map<String, dynamic> toJson() {
    return {
      if (canViewLocation != null) 'can_view_location': canViewLocation,
      if (canReceiveAlerts != null) 'can_receive_alerts': canReceiveAlerts,
      if (canTriggerAlert != null) 'can_trigger_alert': canTriggerAlert,
      if (canReportMissing != null) 'can_report_missing': canReportMissing,
      if (canManageZones != null) 'can_manage_zones': canManageZones,
      if (canManageTracker != null) 'can_manage_tracker': canManageTracker,
    };
  }
}
