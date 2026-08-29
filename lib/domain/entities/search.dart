import '../enums/citycare_enums.dart';

class MissingPersonCase {
  const MissingPersonCase({
    required this.id,
    required this.youngPersonId,
    required this.reportedByUserId,
    required this.occurredAt,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    this.lastKnownLatitude,
    this.lastKnownLongitude,
    this.lastKnownAt,
    this.description,
    this.clothing,
    this.circumstances,
    this.lastSeenBy,
    this.photoUrl,
    this.snapshot,
    this.youngDisplayName,
    this.reporterName,
  });

  final String id;
  final String youngPersonId;
  final String reportedByUserId;
  final DateTime occurredAt;
  final double? lastKnownLatitude;
  final double? lastKnownLongitude;
  final DateTime? lastKnownAt;
  final String? description;
  final String? clothing;
  final String? circumstances;
  final String? lastSeenBy;
  final String? photoUrl;
  final Map<String, dynamic>? snapshot;
  final CaseStatus status;
  final CasePriority priority;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? youngDisplayName;
  final String? reporterName;

  bool get isOpen => status == CaseStatus.open || status == CaseStatus.searching;

  bool get lastKnownLooksStale {
    final lastKnown = snapshot?['last_known'];
    if (lastKnown is Map && lastKnown['is_stale'] == true) {
      return true;
    }
    return false;
  }

  factory MissingPersonCase.fromJson(Map<String, dynamic> json) {
    final rawSnapshot = json['snapshot'];
    return MissingPersonCase(
      id: json['id'] as String,
      youngPersonId: json['young_person_id'] as String,
      reportedByUserId: json['reported_by_user_id'] as String,
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      lastKnownLatitude: (json['last_known_latitude'] as num?)?.toDouble(),
      lastKnownLongitude: (json['last_known_longitude'] as num?)?.toDouble(),
      lastKnownAt: json['last_known_at'] == null ? null : DateTime.parse(json['last_known_at'] as String),
      description: json['description'] as String?,
      clothing: json['clothing'] as String?,
      circumstances: json['circumstances'] as String?,
      lastSeenBy: json['last_seen_by'] as String?,
      photoUrl: json['photo_url'] as String?,
      snapshot: rawSnapshot is Map ? Map<String, dynamic>.from(rawSnapshot) : null,
      status: CaseStatusApi.parse(json['status'] as String),
      priority: CasePriorityApi.parse(json['priority'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      youngDisplayName: json['young_display_name'] as String?,
      reporterName: json['reporter_name'] as String?,
    );
  }
}

class Testimony {
  const Testimony({
    required this.id,
    required this.caseId,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.observedAt,
    required this.status,
    this.submittedByUserId,
    this.photoUrl,
    this.consistency,
    this.consistencyNote,
    this.submitterName,
    this.disclaimer =
        'Témoignage humain. Ce n’est pas un kidnapping confirmé, pas une preuve.',
  });

  final String id;
  final String caseId;
  final String? submittedByUserId;
  final String description;
  final double latitude;
  final double longitude;
  final DateTime observedAt;
  final String? photoUrl;
  final TestimonyStatus status;
  final ConsistencyLevel? consistency;
  final String? consistencyNote;
  final String? submitterName;
  final String disclaimer;

  bool get isOpen => status == TestimonyStatus.submitted || status == TestimonyStatus.underReview;

  factory Testimony.fromJson(Map<String, dynamic> json) {
    return Testimony(
      id: json['id'] as String,
      caseId: json['case_id'] as String,
      submittedByUserId: json['submitted_by_user_id'] as String?,
      description: json['description'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      observedAt: DateTime.parse(json['observed_at'] as String),
      photoUrl: json['photo_url'] as String?,
      status: TestimonyStatusApi.parse(json['status'] as String),
      consistency: json['consistency'] == null
          ? null
          : ConsistencyLevelApi.parse(json['consistency'] as String),
      consistencyNote: json['consistency_note'] as String?,
      submitterName: json['submitter_name'] as String?,
      disclaimer: json['disclaimer'] as String? ??
          'Témoignage humain. Ce n’est pas un kidnapping confirmé, pas une preuve.',
    );
  }
}

class SearchZone {
  const SearchZone({
    required this.id,
    required this.caseId,
    required this.kind,
    required this.priority,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.radiusMeters,
    required this.explanation,
    required this.computedAt,
    this.disclaimer =
        'Zone de recherche estimée. Ce n’est pas la position actuelle, pas un kidnapping confirmé.',
  });

  final String id;
  final String caseId;
  final SearchZoneKind kind;
  final SearchPriority priority;
  final double centerLatitude;
  final double centerLongitude;
  final double radiusMeters;
  final String explanation;
  final DateTime computedAt;
  final String disclaimer;

  bool get isProbable => kind == SearchZoneKind.probableDisplacement;

  bool get isPriority => kind == SearchZoneKind.prioritySearch;

  int get priorityRank => switch (priority) {
        SearchPriority.high => 0,
        SearchPriority.medium => 1,
        SearchPriority.low => 2,
      };

  factory SearchZone.fromJson(Map<String, dynamic> json) {
    return SearchZone(
      id: json['id'] as String,
      caseId: json['case_id'] as String,
      kind: SearchZoneKindApi.parse(json['kind'] as String),
      priority: SearchPriorityApi.parse(json['priority'] as String),
      centerLatitude: (json['center_latitude'] as num).toDouble(),
      centerLongitude: (json['center_longitude'] as num).toDouble(),
      radiusMeters: (json['radius_meters'] as num).toDouble(),
      explanation: json['explanation'] as String,
      computedAt: DateTime.parse(json['computed_at'] as String),
      disclaimer: json['disclaimer'] as String? ??
          'Zone de recherche estimée. Ce n’est pas la position actuelle, pas un kidnapping confirmé.',
    );
  }
}

class RiskAnalysis {
  const RiskAnalysis({
    required this.id,
    required this.youngPersonId,
    required this.riskLevel,
    required this.explanation,
    required this.method,
    required this.createdAt,
    this.caseId,
    this.factors,
  });

  final String id;
  final String? caseId;
  final String youngPersonId;
  final RiskLevel riskLevel;
  final String explanation;
  final String? factors;
  final String method;
  final DateTime createdAt;

  factory RiskAnalysis.fromJson(Map<String, dynamic> json) {
    return RiskAnalysis(
      id: json['id'] as String,
      caseId: json['case_id'] as String?,
      youngPersonId: json['young_person_id'] as String,
      riskLevel: RiskLevelApi.parse(json['risk_level'] as String),
      explanation: json['explanation'] as String,
      factors: json['factors'] as String?,
      method: json['method'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class SearchIntelligence {
  const SearchIntelligence({
    required this.id,
    required this.youngPersonId,
    required this.riskLevel,
    required this.explanation,
    required this.method,
    required this.createdAt,
    required this.updatedAt,
    required this.factors,
    required this.disclaimer,
    this.caseId,
    this.hasSearchZone = false,
  });

  final String id;
  final String? caseId;
  final String youngPersonId;
  final RiskLevel riskLevel;
  final String explanation;
  final String method;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> factors;
  final bool hasSearchZone;
  final String disclaimer;

  int get score => (factors['score'] as num?)?.toInt() ?? 0;

  double? get crudeRangeMeters => (factors['crude_range_meters'] as num?)?.toDouble();

  List<Map<String, dynamic>> get contributors {
    final raw = factors['contributors'];
    if (raw is! List) {
      return const [];
    }
    return [
      for (final item in raw)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  factory SearchIntelligence.fromJson(Map<String, dynamic> json) {
    final rawFactors = json['factors'];
    return SearchIntelligence(
      id: json['id'] as String,
      caseId: json['case_id'] as String?,
      youngPersonId: json['young_person_id'] as String,
      riskLevel: RiskLevelApi.parse(json['risk_level'] as String),
      explanation: json['explanation'] as String,
      method: json['method'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      factors: rawFactors is Map ? Map<String, dynamic>.from(rawFactors) : const {},
      hasSearchZone: json['has_search_zone'] as bool? ?? false,
      disclaimer: json['disclaimer'] as String? ??
          'Aide à la décision par règles. Ce n’est pas un kidnapping confirmé.',
    );
  }
}

class AiAnalysis {
  const AiAnalysis({
    required this.id,
    required this.youngPersonId,
    required this.riskLevel,
    required this.explanation,
    required this.method,
    required this.createdAt,
    required this.updatedAt,
    required this.factors,
    required this.disclaimer,
    this.caseId,
    this.trainedModel = false,
  });

  final String id;
  final String? caseId;
  final String youngPersonId;
  final RiskLevel riskLevel;
  final String explanation;
  final String method;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> factors;
  final bool trainedModel;
  final String disclaimer;

  int get score => (factors['score'] as num?)?.toInt() ?? 0;

  int get maxScore => (factors['max_score'] as num?)?.toInt() ?? 15;

  Map<String, Map<String, dynamic>> get dimensions {
    final raw = factors['dimensions'];
    if (raw is! Map) {
      return const {};
    }
    return {
      for (final entry in raw.entries)
        if (entry.value is Map)
          entry.key.toString(): Map<String, dynamic>.from(entry.value as Map),
    };
  }

  factory AiAnalysis.fromJson(Map<String, dynamic> json) {
    final rawFactors = json['factors'];
    return AiAnalysis(
      id: json['id'] as String,
      caseId: json['case_id'] as String?,
      youngPersonId: json['young_person_id'] as String,
      riskLevel: RiskLevelApi.parse(json['risk_level'] as String),
      explanation: json['explanation'] as String,
      method: json['method'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      factors: rawFactors is Map ? Map<String, dynamic>.from(rawFactors) : const {},
      trainedModel: json['trained_model'] as bool? ?? false,
      disclaimer: json['disclaimer'] as String? ??
          'Analyse IA par règles. Ce n’est pas un kidnapping confirmé, pas un modèle entraîné.',
    );
  }
}

class Incident {
  const Incident({
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

  factory Incident.fromJson(Map<String, dynamic> json) {
    return Incident(
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

class TrajectoryPoint {
  const TrajectoryPoint({
    required this.locationId,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    required this.source,
    this.speed,
    this.heading,
    this.gapAfter = false,
  });

  final String locationId;
  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final double? speed;
  final double? heading;
  final LocationSource source;
  final bool gapAfter;

  factory TrajectoryPoint.fromJson(Map<String, dynamic> json) {
    return TrajectoryPoint(
      locationId: json['location_id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      speed: (json['speed'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      source: LocationSourceApi.parse(json['source'] as String),
      gapAfter: json['gap_after'] as bool? ?? false,
    );
  }
}

class Trajectory {
  const Trajectory({
    required this.youngPersonId,
    required this.points,
    this.access = 'SELF',
    this.pointCount = 0,
    this.gapCount = 0,
    this.distanceMeters = 0,
    this.startedAt,
    this.endedAt,
    this.gapThresholdSeconds = 600,
    this.disclaimer =
        'Trajectoire reconstruite à partir des positions enregistrées. Ce n’est pas un suivi en direct.',
  });

  final String youngPersonId;
  final List<TrajectoryPoint> points;
  final String access;
  final int pointCount;
  final int gapCount;
  final double distanceMeters;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int gapThresholdSeconds;
  final String disclaimer;

  factory Trajectory.fromJson(Map<String, dynamic> json) {
    return Trajectory(
      youngPersonId: json['young_person_id'] as String,
      points: (json['points'] as List<dynamic>)
          .map((item) => TrajectoryPoint.fromJson(item as Map<String, dynamic>))
          .toList(),
      access: json['access'] as String? ?? 'SELF',
      pointCount: json['point_count'] as int? ?? 0,
      gapCount: json['gap_count'] as int? ?? 0,
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0,
      startedAt: json['started_at'] == null ? null : DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] == null ? null : DateTime.parse(json['ended_at'] as String),
      gapThresholdSeconds: json['gap_threshold_seconds'] as int? ?? 600,
      disclaimer: json['disclaimer'] as String? ??
          'Trajectoire reconstruite à partir des positions enregistrées. Ce n’est pas un suivi en direct.',
    );
  }
}
