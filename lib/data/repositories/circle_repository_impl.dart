import '../../domain/entities/circle.dart';
import '../../domain/repositories/circle_repository.dart';
import '../datasources/circle_remote.dart';

class CircleRepositoryImpl implements CircleRepository {
  CircleRepositoryImpl(this._remote);

  final CircleRemoteDataSource _remote;

  @override
  Future<Circle> create(String name) => _remote.create(name);

  @override
  Future<Circle> getById(String circleId) => _remote.getById(circleId);

  @override
  Future<Circle> join(String code) => _remote.join(code);

  @override
  Future<void> leave(String circleId) => _remote.leave(circleId);

  @override
  Future<List<Circle>> list() => _remote.list();

  @override
  Future<List<CircleMember>> members(String circleId) => _remote.members(circleId);

  @override
  Future<String> regenerateInvite(String circleId) => _remote.regenerateInvite(circleId);

  @override
  Future<String> currentInvite(String circleId) => _remote.currentInvite(circleId);

  @override
  Future<void> removeMember(String circleId, String userId) => _remote.removeMember(circleId, userId);

  @override
  Future<Circle> rename(String circleId, String name) => _remote.rename(circleId, name);
}
