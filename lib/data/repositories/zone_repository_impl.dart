import '../../domain/entities/zones.dart';
import '../../domain/repositories/zone_repository.dart';
import '../datasources/zone_remote.dart';

class ZoneRepositoryImpl implements ZoneRepository {
  ZoneRepositoryImpl(this._remote);

  final ZoneRemoteDataSource _remote;

  @override
  Future<SafetyZone> create(SafetyZoneDraft draft, {required String youngPersonId}) {
    return _remote.create(draft, youngPersonId: youngPersonId);
  }

  @override
  Future<void> delete(String zoneId) => _remote.delete(zoneId);

  @override
  Future<List<SafetyZone>> childZones(String youngPersonId) => _remote.childZones(youngPersonId);

  @override
  Future<List<SafetyZone>> myZones() => _remote.myZones();

  @override
  Future<SafetyZone> update(String zoneId, SafetyZoneDraft draft) => _remote.update(zoneId, draft);
}
