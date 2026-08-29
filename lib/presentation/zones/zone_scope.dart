import 'package:flutter/material.dart';

import 'zone_controller.dart';

class ZoneScope extends InheritedNotifier<ZoneController> {
  const ZoneScope({
    super.key,
    required ZoneController controller,
    required super.child,
  }) : super(notifier: controller);

  static ZoneController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ZoneScope>();
    assert(scope != null, 'ZoneScope introuvable');
    return scope!.notifier!;
  }
}
