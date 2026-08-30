import 'package:citycare/domain/entities/identity.dart';
import 'package:citycare/domain/entities/subscription.dart';
import 'package:citycare/domain/enums/citycare_enums.dart';
import 'package:citycare/presentation/auth/auth_controller.dart';
import 'package:citycare/presentation/profile/subscription_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart';

void main() {
  testWidgets('profil parent affiche l’offre annuelle FCFA', (tester) async {
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
    await tester.pumpWidget(appWith(auth));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Profil'));
    await tester.pump();
    expect(find.byKey(const Key('profile-subscription')), findsOneWidget);
    expect(find.textContaining('12 000 FCFA'), findsWidgets);

    await tester.tap(find.byKey(const Key('profile-subscription')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('subscription-page')), findsOneWidget);
    expect(find.textContaining('FCFA'), findsWidgets);
    expect(find.textContaining('Aucun paiement'), findsWidgets);

    await tester.tap(find.byKey(const Key('subscription-record')));
    await tester.pumpAndSettle();
    expect(find.text('Déjà enregistré'), findsOneWidget);
  });

  test('contrôleur mémoire enregistre l’intention sans paiement', () async {
    final billing = SubscriptionController.memory();
    expect(billing.current.isRecorded, isFalse);
    expect(CareSubscription.annualAmount, 12000);
    expect(CareSubscription.annualCurrency, 'XAF');
    final ok = await billing.recordAnnualIntent();
    expect(ok, isTrue);
    expect(billing.current.isRecorded, isTrue);
    expect(billing.current.message, contains('Aucun paiement'));
  });
}
