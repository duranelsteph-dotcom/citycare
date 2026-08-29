import '../entities/emergency.dart';
import '../entities/search.dart';
import '../entities/tracking.dart';

abstract class LocationRepository {
  Future<TrackerLocation> publishPhoneFix({
    required double latitude,
    required double longitude,
    double? accuracy,
    double? altitude,
    double? speed,
    double? heading,
    DateTime? recordedAt,
  });

  Future<TrackerLocation> myLatest();

  Future<List<TrackerLocation>> myHistory({int limit = 20});

  Future<TrackerLocation> childLatest(String youngPersonId);

  Future<List<TrackerLocation>> childHistory(String youngPersonId, {int limit = 20});

  Future<LocationWatch> watchMine();

  Future<LocationWatch> watchChild(String youngPersonId);

  Future<List<PositionShare>> myShares();

  Future<List<PositionShare>> receivedShares();

  Future<PositionShare> createShare({required String targetUserId, int durationMinutes = 60});

  Future<PositionShare> revokeShare(String shareId);

  Future<Trajectory> myTrajectory({int hours = 4, int limit = 100});

  Future<Trajectory> childTrajectory(String youngPersonId, {int hours = 4, int limit = 100});

  Future<EmergencySnapshot> emergency(String youngPersonId);
}
