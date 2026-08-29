import 'package:flutter/material.dart';

import 'notification_controller.dart';

class NotificationScope extends InheritedNotifier<NotificationController> {
  const NotificationScope({
    super.key,
    required NotificationController controller,
    required super.child,
  }) : super(notifier: controller);

  static NotificationController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<NotificationScope>();
    assert(scope != null, 'NotificationScope introuvable');
    return scope!.notifier!;
  }
}
