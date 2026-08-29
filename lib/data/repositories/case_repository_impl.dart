import '../../domain/entities/search.dart';
import '../../domain/repositories/case_repository.dart';
import '../datasources/case_remote.dart';

class CaseRepositoryImpl implements CaseRepository {
  CaseRepositoryImpl(this._remote);

  final CaseRemoteDataSource _remote;

  @override
  Future<MissingPersonCase> close(String caseId) => _remote.close(caseId);

  @override
  Future<MissingPersonCase> create(CaseDraft draft) => _remote.create(draft);

  @override
  Future<MissingPersonCase> getById(String caseId) => _remote.getById(caseId);

  @override
  Future<MissingPersonCase> markFound(String caseId) => _remote.markFound(caseId);

  @override
  Future<MissingPersonCase> startSearch(String caseId) => _remote.startSearch(caseId);

  @override
  Future<List<MissingPersonCase>> mineAsGuardian() => _remote.mineAsGuardian();

  @override
  Future<List<MissingPersonCase>> mineAsYoung() => _remote.mineAsYoung();

  @override
  Future<Trajectory> trajectory(String caseId) => _remote.trajectory(caseId);

  @override
  Future<SearchIntelligence> intelligence(String caseId) => _remote.intelligence(caseId);

  @override
  Future<SearchIntelligence> refreshIntelligence(String caseId) => _remote.refreshIntelligence(caseId);

  @override
  Future<AiAnalysis> aiAnalysis(String caseId) => _remote.aiAnalysis(caseId);

  @override
  Future<AiAnalysis> refreshAiAnalysis(String caseId) => _remote.refreshAiAnalysis(caseId);

  @override
  Future<List<SearchZone>> searchZones(String caseId) => _remote.searchZones(caseId);

  @override
  Future<List<Testimony>> testimonies(String caseId) => _remote.testimonies(caseId);

  @override
  Future<Testimony> submitTestimony(String caseId, TestimonyDraft draft) =>
      _remote.submitTestimony(caseId, draft);

  @override
  Future<Testimony> reviewTestimony(String caseId, String testimonyId) =>
      _remote.reviewTestimony(caseId, testimonyId);

  @override
  Future<Testimony> verifyTestimony(String caseId, String testimonyId) =>
      _remote.verifyTestimony(caseId, testimonyId);

  @override
  Future<Testimony> rejectTestimony(String caseId, String testimonyId) =>
      _remote.rejectTestimony(caseId, testimonyId);

  @override
  Future<List<Testimony>> refreshTestimonyConsistency(String caseId) =>
      _remote.refreshTestimonyConsistency(caseId);
}
