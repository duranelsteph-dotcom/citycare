import '../../domain/entities/zones.dart';
import '../../domain/repositories/risk_zone_repository.dart';
import '../datasources/risk_zone_remote.dart';

class RiskZoneRepositoryImpl implements RiskZoneRepository {
  RiskZoneRepositoryImpl(this._remote);

  final RiskZoneRemoteDataSource _remote;

  @override
  Future<RiskIncident> addIncident(String zoneId, IncidentDraft draft) => _remote.addIncident(zoneId, draft);

  @override
  Future<RiskZone> create(RiskZoneDraft draft) => _remote.create(draft);

  @override
  Future<void> delete(String zoneId) => _remote.delete(zoneId);

  @override
  Future<List<RiskIncident>> incidents(String zoneId) => _remote.incidents(zoneId);

  @override
  Future<List<RiskZone>> list() => _remote.list();

  @override
  Future<RiskZone> update(String zoneId, RiskZoneDraft draft) => _remote.update(zoneId, draft);
}
