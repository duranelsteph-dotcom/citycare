import 'package:flutter/material.dart';

import 'subscription_controller.dart';

class SubscriptionScope extends InheritedNotifier<SubscriptionController> {
  const SubscriptionScope({
    super.key,
    required SubscriptionController controller,
    required super.child,
  }) : super(notifier: controller);

  static SubscriptionController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SubscriptionScope>();
    assert(scope != null, 'SubscriptionScope introuvable');
    return scope!.notifier!;
  }

  static SubscriptionController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SubscriptionScope>()?.notifier;
  }
}
