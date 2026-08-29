import '../entities/tracking.dart';
import '../enums/citycare_enums.dart';

abstract class TrackerRepository {
  Future<List<GpsTracker>> mine();

  Future<List<GpsTracker>> forChild(String youngPersonId);

  Future<GpsTracker> register({String? youngPersonId, String label});

  Future<GpsTracker> update(
    String trackerId, {
    String? label,
    TrackingMode? trackingMode,
    bool? enabled,
  });

  Future<GpsTracker> rotateSecret(String trackerId);

  Future<void> delete(String trackerId);

  Future<List<TrackerEvent>> events(String trackerId, {int limit = 30});
}
