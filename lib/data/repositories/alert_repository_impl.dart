import '../../domain/entities/alerts.dart';
import '../../domain/repositories/alert_repository.dart';
import '../datasources/alert_remote.dart';

class AlertRepositoryImpl implements AlertRepository {
  AlertRepositoryImpl(this._remote);

  final AlertRemoteDataSource _remote;

  @override
  Future<Alert> acknowledge(String alertId) => _remote.acknowledge(alertId);

  @override
  Future<Alert> resolve(String alertId) => _remote.resolve(alertId);

  @override
  Future<Alert> cancel(String alertId) => _remote.cancel(alertId);

  @override
  Future<Alert> getById(String alertId) => _remote.getById(alertId);

  @override
  Future<List<Alert>> mineAsGuardian() => _remote.mineAsGuardian();

  @override
  Future<List<Alert>> mineAsYoung() => _remote.mineAsYoung();

  @override
  Future<Alert> triggerSos(SosDraft draft) => _remote.triggerSos(draft);
}
