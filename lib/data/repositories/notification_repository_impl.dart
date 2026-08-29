import '../../domain/entities/alerts.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/notification_remote.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl(this._remote);

  final NotificationRemoteDataSource _remote;

  @override
  Future<AppNotification> markRead(String id) => _remote.markRead(id);

  @override
  Future<int> markAllRead() => _remote.markAllRead();

  @override
  Future<List<AppNotification>> mine({int limit = 50, bool unreadOnly = false}) {
    return _remote.mine(limit: limit, unreadOnly: unreadOnly);
  }
}
