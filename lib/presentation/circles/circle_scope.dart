import 'package:flutter/material.dart';

import 'circle_controller.dart';

class CircleScope extends InheritedNotifier<CircleController> {
  const CircleScope({
    super.key,
    required CircleController controller,
    required super.child,
  }) : super(notifier: controller);

  static CircleController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CircleScope>();
    assert(scope != null, 'CircleScope introuvable');
    return scope!.notifier!;
  }
}
