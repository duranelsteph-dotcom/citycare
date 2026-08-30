import 'package:flutter/material.dart';

import 'marketplace_controller.dart';

class MarketplaceScope extends InheritedNotifier<MarketplaceController> {
  const MarketplaceScope({
    super.key,
    required MarketplaceController controller,
    required super.child,
  }) : super(notifier: controller);

  static MarketplaceController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MarketplaceScope>();
    assert(scope != null, 'MarketplaceScope introuvable');
    return scope!.notifier!;
  }

  static MarketplaceController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MarketplaceScope>()?.notifier;
  }
}
