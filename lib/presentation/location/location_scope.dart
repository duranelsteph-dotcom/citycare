import 'package:flutter/material.dart';

import 'location_controller.dart';

class LocationScope extends InheritedNotifier<LocationController> {
  const LocationScope({
    super.key,
    required LocationController controller,
    required super.child,
  }) : super(notifier: controller);

  static LocationController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocationScope>();
    assert(scope != null, 'LocationScope introuvable');
    return scope!.notifier!;
  }
}
