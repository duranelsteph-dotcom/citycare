import '../enums/citycare_enums.dart';

/// Cercle nommé (style Life360) : grouping d'utilisateurs, pas un GuardianLink.
class Circle {
  const Circle({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.createdByUserId,
    required this.myRole,
    required this.memberCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String inviteCode;
  final String createdByUserId;
  final CircleRole myRole;
  final int memberCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isOwner => myRole == CircleRole.owner;

  factory Circle.fromJson(Map<String, dynamic> json) {
    return Circle(
      id: json['id'] as String,
      name: json['name'] as String,
      inviteCode: json['invite_code'] as String,
      createdByUserId: json['created_by_user_id'] as String,
      myRole: CircleRoleApi.parse(json['my_role'] as String),
      memberCount: json['member_count'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Circle copyWith({String? name, String? inviteCode, CircleRole? myRole, int? memberCount}) {
    return Circle(
      id: id,
      name: name ?? this.name,
      inviteCode: inviteCode ?? this.inviteCode,
      createdByUserId: createdByUserId,
      myRole: myRole ?? this.myRole,
      memberCount: memberCount ?? this.memberCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// Membre d'un cercle. [canViewLocation] relit GuardianLink, le cercle ne l'accorde pas.
class CircleMember {
  const CircleMember({
    required this.userId,
    required this.fullName,
    required this.userRole,
    required this.circleRole,
    required this.joinedAt,
    required this.canViewLocation,
    this.youngPersonId,
    this.photoUrl,
    this.guardianLinkId,
  });

  final String userId;
  final String fullName;
  final UserRole userRole;
  final CircleRole circleRole;
  final DateTime joinedAt;
  final String? youngPersonId;
  final String? photoUrl;
  final bool canViewLocation;
  final String? guardianLinkId;

  factory CircleMember.fromJson(Map<String, dynamic> json) {
    return CircleMember(
      userId: json['user_id'] as String,
      fullName: json['full_name'] as String,
      userRole: UserRoleApi.parse(json['user_role'] as String),
      circleRole: CircleRoleApi.parse(json['circle_role'] as String),
      joinedAt: DateTime.parse(json['joined_at'] as String),
      youngPersonId: json['young_person_id'] as String?,
      photoUrl: json['photo_url'] as String?,
      canViewLocation: json['can_view_location'] as bool? ?? false,
      guardianLinkId: json['guardian_link_id'] as String?,
    );
  }
}
