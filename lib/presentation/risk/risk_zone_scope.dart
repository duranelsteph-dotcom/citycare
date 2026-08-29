import 'package:flutter/material.dart';

import 'risk_zone_controller.dart';

class RiskZoneScope extends InheritedNotifier<RiskZoneController> {
  const RiskZoneScope({
    super.key,
    required RiskZoneController controller,
    required super.child,
  }) : super(notifier: controller);

  static RiskZoneController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RiskZoneScope>();
    assert(scope != null, 'RiskZoneScope introuvable');
    return scope!.notifier!;
  }
}
