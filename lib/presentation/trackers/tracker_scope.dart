import 'package:flutter/material.dart';

import 'tracker_controller.dart';

class TrackerScope extends InheritedNotifier<TrackerController> {
  const TrackerScope({
    super.key,
    required TrackerController controller,
    required super.child,
  }) : super(notifier: controller);

  static TrackerController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TrackerScope>();
    assert(scope != null, 'TrackerScope introuvable');
    return scope!.notifier!;
  }
}
