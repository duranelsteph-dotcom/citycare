import 'package:citycare/domain/entities/identity.dart';
import 'package:citycare/domain/enums/citycare_enums.dart';
import 'package:citycare/presentation/auth/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart';

UserAccount _marie() {
  return UserAccount(
    id: '1',
    fullName: 'Marie Demo',
    phone: '+237699000001',
    role: UserRole.parent,
    isActive: true,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

/// Navigation soutenance : 5 onglets + catalogue « Toutes les fonctions ».
void main() {
  testWidgets('shell : Accueil Membres Alertes Boutique Profil', (tester) async {
    final auth = AuthController(FakeAuthRepository())
      ..isRestoring = false
      ..user = _marie();
    await tester.pumpWidget(appWith(auth));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byKey(const Key('main-shell')), findsOneWidget);
    expect(find.byKey(const Key('main-shell-nav')), findsOneWidget);
    expect(find.text('Accueil'), findsOneWidget);
    expect(find.text('Membres'), findsOneWidget);
    expect(find.text('Alertes'), findsOneWidget);
    expect(find.text('Boutique'), findsWidgets);
    expect(find.text('Profil'), findsOneWidget);
    expect(find.byKey(const Key('sos-fab')), findsOneWidget);

    await tester.tap(find.text('Membres'));
    await tester.pump();
    expect(find.text('Mes enfants / jeunes'), findsOneWidget);

    await tester.tap(find.descendant(
      of: find.byKey(const Key('main-shell-nav')),
      matching: find.text('Boutique'),
    ));
    await tester.pump();
    expect(find.byKey(const Key('marketplace-page')), findsOneWidget);
    expect(find.textContaining('Kits GPS'), findsWidgets);
    expect(find.textContaining('FCFA'), findsWidgets);

    await tester.tap(find.text('Alertes'));
    await tester.pump();
    expect(find.text('Alertes SOS'), findsOneWidget);
    expect(find.byKey(const Key('sos-disclaimer')), findsOneWidget);
    expect(find.textContaining('kidnapping confirmé'), findsWidgets);

    await tester.tap(find.text('Profil'));
    await tester.pump();
    expect(find.text('Bonjour Marie Demo'), findsOneWidget);
    final profileScroll = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(find.text('Toutes les fonctions'), 240, scrollable: profileScroll);

    await tester.tap(find.text('Toutes les fonctions'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('toutes-fonctions-page')), findsOneWidget);
    expect(find.byKey(const Key('toutes-fonctions-intro')), findsOneWidget);
    expect(find.textContaining('Catalogue groupé'), findsOneWidget);
    expect(find.textContaining('kidnapping confirmé'), findsWidgets);
    final menuScroll = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(find.text('Alertes SOS'), 240, scrollable: menuScroll);
    expect(find.text('Alertes SOS'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Créer un cercle'), 240, scrollable: menuScroll);
    expect(find.text('Rejoindre un cercle'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Zones de sécurité'), 240, scrollable: menuScroll);
  });
}
