import 'package:citycare/domain/entities/identity.dart';
import 'package:citycare/domain/enums/citycare_enums.dart';
import 'package:citycare/presentation/auth/auth_controller.dart';
import 'package:citycare/presentation/onboarding/onboarding_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('après permissions, le wizard visuel traceur / maison / lieu s’affiche', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthController(FakeAuthRepository())
      ..isRestoring = false
      ..user = UserAccount(
        id: '1',
        fullName: 'Marie',
        phone: '+237600000000',
        role: UserRole.parent,
        isActive: true,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
    await tester.pumpWidget(
      appWith(
        auth,
        onboarding: OnboardingController.memory(completed: true, setupCompleted: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('setup-onboarding-page')), findsOneWidget);
    expect(find.byKey(const Key('setup-tile-title')), findsOneWidget);
    expect(find.text('Avez-vous un traceur ?'), findsOneWidget);
    expect(find.text('Life360'), findsNothing);

    await tester.tap(find.byKey(const Key('setup-tile-yes')));
    await tester.pumpAndSettle();
    expect(find.text('Le connecter'), findsOneWidget);

    await tester.tap(find.byKey(const Key('setup-connect-later')));
    await tester.pumpAndSettle();
    expect(find.text('Partager votre position ?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('setup-location-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Est-ce bien votre maison ?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('setup-home-no')));
    await tester.pumpAndSettle();
    expect(find.text('Ajouter un nouveau lieu'), findsOneWidget);
    expect(find.text('École'), findsOneWidget);

    await tester.tap(find.byKey(const Key('setup-place-skip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('main-shell')), findsOneWidget);
  });

  testWidgets('sans setup, skip traceur ouvre le shell', (tester) async {
    final auth = AuthController(FakeAuthRepository())
      ..isRestoring = false
      ..user = UserAccount(
        id: '1',
        fullName: 'Marie',
        phone: '+237600000000',
        role: UserRole.parent,
        isActive: true,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
    final onboarding = OnboardingController.memory(completed: true, setupCompleted: false);
    await tester.pumpWidget(appWith(auth, onboarding: onboarding));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('setup-skip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('main-shell')), findsOneWidget);
    expect(onboarding.isSetupCompleted, isTrue);
  });

  testWidgets('sans kit : Non ouvre la boutique CityCare', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthController(FakeAuthRepository())
      ..isRestoring = false
      ..user = UserAccount(
        id: '1',
        fullName: 'Marie',
        phone: '+237600000000',
        role: UserRole.parent,
        isActive: true,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
    await tester.pumpWidget(
      appWith(
        auth,
        onboarding: OnboardingController.memory(completed: true, setupCompleted: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Avez-vous un traceur ?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('setup-tile-no')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('marketplace-page')), findsOneWidget);
    expect(find.textContaining('Kits GPS'), findsWidgets);
    expect(find.textContaining('Play Store'), findsNothing);
  });
}
