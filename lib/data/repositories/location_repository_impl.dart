import '../../domain/entities/emergency.dart';
import '../../domain/entities/search.dart';
import '../../domain/entities/tracking.dart';
import '../../domain/repositories/location_repository.dart';
import '../datasources/location_remote.dart';

class LocationRepositoryImpl implements LocationRepository {
  LocationRepositoryImpl(this._remote);

  final LocationRemoteDataSource _remote;

  @override
  Future<TrackerLocation> childLatest(String youngPersonId) => _remote.childLatest(youngPersonId);

  @override
  Future<List<TrackerLocation>> childHistory(String youngPersonId, {int limit = 20}) {
    return _remote.childHistory(youngPersonId, limit: limit);
  }

  @override
  Future<TrackerLocation> myLatest() => _remote.myLatest();

  @override
  Future<List<TrackerLocation>> myHistory({int limit = 20}) => _remote.myHistory(limit: limit);

  @override
  Future<LocationWatch> watchMine() => _remote.watchMine();

  @override
  Future<LocationWatch> watchChild(String youngPersonId) => _remote.watchChild(youngPersonId);

  @override
  Future<List<PositionShare>> myShares() => _remote.myShares();

  @override
  Future<List<PositionShare>> receivedShares() => _remote.receivedShares();

  @override
  Future<PositionShare> createShare({required String targetUserId, int durationMinutes = 60}) {
    return _remote.createShare(targetUserId: targetUserId, durationMinutes: durationMinutes);
  }

  @override
  Future<PositionShare> revokeShare(String shareId) => _remote.revokeShare(shareId);

  @override
  Future<Trajectory> myTrajectory({int hours = 4, int limit = 100}) {
    return _remote.myTrajectory(hours: hours, limit: limit);
  }

  @override
  Future<Trajectory> childTrajectory(String youngPersonId, {int hours = 4, int limit = 100}) {
    return _remote.childTrajectory(youngPersonId, hours: hours, limit: limit);
  }

  @override
  Future<TripHistory> myTrips({TripPeriod? period, DateTime? from, DateTime? to, int limit = 1000}) {
    return _remote.myTrips(period: period, from: from, to: to, limit: limit);
  }

  @override
  Future<TripHistory> childTrips(
    String youngPersonId, {
    TripPeriod? period,
    DateTime? from,
    DateTime? to,
    int limit = 1000,
  }) {
    return _remote.childTrips(youngPersonId, period: period, from: from, to: to, limit: limit);
  }

  @override
  Future<EmergencySnapshot> emergency(String youngPersonId) => _remote.emergency(youngPersonId);

  @override
  Future<TrackerLocation> publishPhoneFix({
    required double latitude,
    required double longitude,
    double? accuracy,
    double? altitude,
    double? speed,
    double? heading,
    DateTime? recordedAt,
    int? batteryLevel,
  }) {
    return _remote.publishPhoneFix(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      altitude: altitude,
      speed: speed,
      heading: heading,
      recordedAt: recordedAt,
      batteryLevel: batteryLevel,
    );
  }
}
