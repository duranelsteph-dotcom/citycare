import 'package:citycare/domain/entities/identity.dart';
import 'package:citycare/domain/enums/citycare_enums.dart';
import 'package:citycare/domain/repositories/auth_repository.dart';
import 'package:citycare/presentation/auth/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart';

/// Parcours soutenance : téléphone → mot de passe → OTP démo → shell.
void main() {
  testWidgets('login 3 étapes + OTP mock ouvre le shell', (tester) async {
    final user = UserAccount(
      id: '1',
      fullName: 'Marie Demo',
      phone: '+237699000001',
      role: UserRole.parent,
      isActive: true,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final repo = FakeAuthRepository(session: AuthSession(token: 'tok', user: user));
    final auth = AuthController(repo)..isRestoring = false;
    await tester.pumpWidget(appWith(auth));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(find.text('Entrez votre numéro de téléphone'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('auth-phone-field')), '699000001');
    await tester.tap(find.byKey(const Key('auth-phone-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Entrez votre mot de passe'), findsOneWidget);
    expect(find.text('+237699000001'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('auth-password-field')), 'motdepasse');
    await tester.ensureVisible(find.byKey(const Key('auth-login-submit')));
    await tester.tap(find.byKey(const Key('auth-login-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repo.lastLoginPhone, '+237699000001');
    expect(find.textContaining('Mode démo'), findsWidgets);
    expect(find.text('123456'), findsOneWidget);
    expect(find.text('Valider le code'), findsOneWidget);
    expect(find.textContaining('Aucun SMS'), findsWidgets);

    await tester.enterText(find.byKey(const Key('auth-otp-field')), '123456');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(auth.user?.fullName, 'Marie Demo');
    expect(auth.pendingChallenge, isNull);
    expect(find.byKey(const Key('main-shell')), findsOneWidget);
    expect(find.byKey(const Key('main-shell-nav')), findsOneWidget);
    expect(find.text('Accueil'), findsOneWidget);
  });
}
