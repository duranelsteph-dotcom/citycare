import '../../domain/entities/tracking.dart';
import '../../domain/enums/citycare_enums.dart';
import '../../domain/repositories/tracker_repository.dart';
import '../datasources/tracker_remote.dart';

class TrackerRepositoryImpl implements TrackerRepository {
  TrackerRepositoryImpl(this._remote);

  final TrackerRemoteDataSource _remote;

  @override
  Future<List<GpsTracker>> forChild(String youngPersonId) => _remote.forChild(youngPersonId);

  @override
  Future<List<GpsTracker>> mine() => _remote.mine();

  @override
  Future<GpsTracker> register({String? youngPersonId, String label = 'Kit CityCare'}) {
    return _remote.register(youngPersonId: youngPersonId, label: label);
  }

  @override
  Future<GpsTracker> update(
    String trackerId, {
    String? label,
    TrackingMode? trackingMode,
    bool? enabled,
  }) {
    return _remote.update(trackerId, label: label, trackingMode: trackingMode, enabled: enabled);
  }

  @override
  Future<GpsTracker> rotateSecret(String trackerId) => _remote.rotateSecret(trackerId);

  @override
  Future<void> delete(String trackerId) => _remote.delete(trackerId);

  @override
  Future<List<TrackerEvent>> events(String trackerId, {int limit = 30}) {
    return _remote.events(trackerId, limit: limit);
  }
}
