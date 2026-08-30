import 'package:flutter/material.dart';

import 'alert_controller.dart';

class AlertScope extends InheritedNotifier<AlertController> {
  const AlertScope({
    super.key,
    required AlertController controller,
    required super.child,
  }) : super(notifier: controller);

  static AlertController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AlertScope>();
    assert(scope != null, 'AlertScope introuvable');
    return scope!.notifier!;
  }

  /// Absent hors du shell (tests de pages isolées).
  static AlertController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AlertScope>()?.notifier;
  }
}
