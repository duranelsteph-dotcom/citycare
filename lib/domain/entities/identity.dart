import '../enums/citycare_enums.dart';

class UserAccount {
  const UserAccount({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.role,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.email,
    this.youngPersonId,
  });

  final String id;
  final String fullName;
  final String? email;
  final String phone;
  final UserRole role;
  final bool isActive;
  final String? youngPersonId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String,
      role: UserRoleApi.parse(json['role'] as String),
      isActive: json['is_active'] as bool,
      youngPersonId: json['young_person_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  UserAccount copyWith({String? fullName}) {
    return UserAccount(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email,
      phone: phone,
      role: role,
      isActive: isActive,
      youngPersonId: youngPersonId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class YoungPerson {
  const YoungPerson({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.createdAt,
    required this.updatedAt,
    this.birthDate,
    this.photoUrl,
    this.notes,
  });

  final String id;
  final String userId;
  final String displayName;
  final DateTime? birthDate;
  final String? photoUrl;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory YoungPerson.fromJson(Map<String, dynamic> json) {
    return YoungPerson(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String,
      birthDate: json['birth_date'] == null ? null : DateTime.parse(json['birth_date'] as String),
      photoUrl: json['photo_url'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class GuardianLink {
  const GuardianLink({
    required this.id,
    required this.guardianUserId,
    required this.youngPersonId,
    required this.relation,
    required this.status,
    required this.canViewLocation,
    required this.canReceiveAlerts,
    required this.canTriggerAlert,
    required this.canReportMissing,
    required this.canManageZones,
    required this.canManageTracker,
    this.guardianName,
    this.guardianPhone,
    this.youngDisplayName,
    this.youngPhone,
  });

  final String id;
  final String guardianUserId;
  final String youngPersonId;
  final GuardianRelation relation;
  final GuardianLinkStatus status;
  final bool canViewLocation;
  final bool canReceiveAlerts;
  final bool canTriggerAlert;
  final bool canReportMissing;
  final bool canManageZones;
  final bool canManageTracker;
  final String? guardianName;
  final String? guardianPhone;
  final String? youngDisplayName;
  final String? youngPhone;

  factory GuardianLink.fromJson(Map<String, dynamic> json) {
    return GuardianLink(
      id: json['id'] as String,
      guardianUserId: json['guardian_user_id'] as String,
      youngPersonId: json['young_person_id'] as String,
      relation: GuardianRelationApi.parse(json['relation'] as String),
      status: GuardianLinkStatusApi.parse(json['status'] as String),
      canViewLocation: json['can_view_location'] as bool,
      canReceiveAlerts: json['can_receive_alerts'] as bool,
      canTriggerAlert: json['can_trigger_alert'] as bool,
      canReportMissing: json['can_report_missing'] as bool,
      canManageZones: json['can_manage_zones'] as bool,
      canManageTracker: json['can_manage_tracker'] as bool,
      guardianName: json['guardian_name'] as String?,
      guardianPhone: json['guardian_phone'] as String?,
      youngDisplayName: json['young_display_name'] as String?,
      youngPhone: json['young_phone'] as String?,
    );
  }
}

class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.youngPersonId,
    required this.name,
    required this.phone,
    this.userId,
  });

  final String id;
  final String youngPersonId;
  final String name;
  final String phone;
  final String? userId;

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'] as String,
      youngPersonId: json['young_person_id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      userId: json['user_id'] as String?,
    );
  }
}
