import '../entities/circle.dart';

abstract class CircleRepository {
  Future<List<Circle>> list();

  Future<Circle> create(String name);

  Future<Circle> getById(String circleId);

  Future<Circle> rename(String circleId, String name);

  Future<Circle> join(String code);

  Future<void> leave(String circleId);

  Future<List<CircleMember>> members(String circleId);

  Future<void> removeMember(String circleId, String userId);

  Future<String> regenerateInvite(String circleId);

  /// Code actuel (GET). Ne régénère pas.
  Future<String> currentInvite(String circleId);
}
