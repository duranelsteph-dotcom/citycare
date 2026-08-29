import 'package:flutter/material.dart';

import 'case_controller.dart';

class CaseScope extends InheritedNotifier<CaseController> {
  const CaseScope({
    super.key,
    required CaseController controller,
    required super.child,
  }) : super(notifier: controller);

  static CaseController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CaseScope>();
    assert(scope != null, 'CaseScope introuvable');
    return scope!.notifier!;
  }
}
