import 'package:flutter/material.dart';

import 'family_controller.dart';

class FamilyScope extends InheritedNotifier<FamilyController> {
  const FamilyScope({
    super.key,
    required FamilyController controller,
    required super.child,
  }) : super(notifier: controller);

  static FamilyController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<FamilyScope>();
    assert(scope != null, 'FamilyScope introuvable');
    return scope!.notifier!;
  }

  static FamilyController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<FamilyScope>()?.notifier;
  }
}
