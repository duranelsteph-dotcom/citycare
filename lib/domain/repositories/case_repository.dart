import '../entities/search.dart';

class CaseDraft {
  const CaseDraft({
    required this.youngPersonId,
    this.description,
    this.clothing,
    this.circumstances,
    this.lastSeenBy,
  });

  final String youngPersonId;
  final String? description;
  final String? clothing;
  final String? circumstances;
  final String? lastSeenBy;

  Map<String, dynamic> toJson() {
    return {
      'young_person_id': youngPersonId,
      if (description != null && description!.isNotEmpty) 'description': description,
      if (clothing != null && clothing!.isNotEmpty) 'clothing': clothing,
      if (circumstances != null && circumstances!.isNotEmpty) 'circumstances': circumstances,
      if (lastSeenBy != null && lastSeenBy!.isNotEmpty) 'last_seen_by': lastSeenBy,
    };
  }
}

abstract class CaseRepository {
  Future<MissingPersonCase> create(CaseDraft draft);

  Future<List<MissingPersonCase>> mineAsYoung();

  Future<List<MissingPersonCase>> mineAsGuardian();

  Future<MissingPersonCase> getById(String caseId);

  Future<MissingPersonCase> markFound(String caseId);

  Future<MissingPersonCase> startSearch(String caseId);

  Future<MissingPersonCase> close(String caseId);

  Future<Trajectory> trajectory(String caseId);

  Future<SearchIntelligence> intelligence(String caseId);

  Future<SearchIntelligence> refreshIntelligence(String caseId);

  Future<AiAnalysis> aiAnalysis(String caseId);

  Future<AiAnalysis> refreshAiAnalysis(String caseId);

  Future<List<SearchZone>> searchZones(String caseId);

  Future<List<Testimony>> testimonies(String caseId);

  Future<Testimony> submitTestimony(String caseId, TestimonyDraft draft);

  Future<Testimony> reviewTestimony(String caseId, String testimonyId);

  Future<Testimony> verifyTestimony(String caseId, String testimonyId);

  Future<Testimony> rejectTestimony(String caseId, String testimonyId);

  Future<List<Testimony>> refreshTestimonyConsistency(String caseId);
}

class TestimonyDraft {
  const TestimonyDraft({
    required this.description,
    required this.latitude,
    required this.longitude,
    this.observedAt,
    this.photoUrl,
  });

  final String description;
  final double latitude;
  final double longitude;
  final DateTime? observedAt;
  final String? photoUrl;

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      if (observedAt != null) 'observed_at': observedAt!.toUtc().toIso8601String(),
      if (photoUrl != null && photoUrl!.isNotEmpty) 'photo_url': photoUrl,
    };
  }
}
