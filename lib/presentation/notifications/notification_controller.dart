import 'package:flutter/foundation.dart';

import '../../core/errors/api_exception.dart';
import '../../domain/entities/alerts.dart';
import '../../domain/repositories/notification_repository.dart';

class NotificationController extends ChangeNotifier {
  NotificationController(this._repository);

  final NotificationRepository _repository;

  List<AppNotification> items = [];
  bool isBusy = false;
  bool unreadOnly = false;
  String? errorMessage;

  int get unreadCount => items.where((item) => !item.isRead).length;

  Future<void> load({bool? unreadOnly}) async {
    if (unreadOnly != null) {
      this.unreadOnly = unreadOnly;
    }
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      items = await _repository.mine(unreadOnly: this.unreadOnly);
    } on ApiException catch (error) {
      errorMessage = error.message;
    } catch (_) {
      errorMessage = 'Notifications indisponibles pour le moment.';
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> open(AppNotification notification) async {
    if (notification.isRead) {
      return;
    }
    try {
      final updated = await _repository.markRead(notification.id);
      items = [for (final item in items) if (item.id == updated.id) updated else item];
      notifyListeners();
    } on ApiException catch (error) {
      errorMessage = error.message;
      notifyListeners();
    }
  }

  Future<void> markAllRead() async {
    try {
      await _repository.markAllRead();
      await load();
    } on ApiException catch (error) {
      errorMessage = error.message;
      notifyListeners();
    }
  }
}
