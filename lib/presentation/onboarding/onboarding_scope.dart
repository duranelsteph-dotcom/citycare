import 'package:flutter/material.dart';

import 'onboarding_controller.dart';

class OnboardingScope extends InheritedNotifier<OnboardingController> {
  const OnboardingScope({
    super.key,
    required OnboardingController controller,
    required super.child,
  }) : super(notifier: controller);

  static OnboardingController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<OnboardingScope>();
    assert(scope != null, 'OnboardingScope introuvable');
    return scope!.notifier!;
  }
}
