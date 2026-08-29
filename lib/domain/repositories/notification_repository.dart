import '../entities/alerts.dart';

abstract class NotificationRepository {
  Future<List<AppNotification>> mine({int limit = 50, bool unreadOnly = false});

  Future<AppNotification> markRead(String id);

  Future<int> markAllRead();
}
