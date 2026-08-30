import 'package:citycare/domain/entities/identity.dart';
import 'package:citycare/domain/enums/citycare_enums.dart';
import 'package:citycare/presentation/auth/auth_controller.dart';
import 'package:citycare/presentation/marketplace/marketplace_catalog.dart';
import 'package:citycare/presentation/marketplace/marketplace_controller.dart';
import 'package:citycare/presentation/marketplace/marketplace_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart';

void main() {
  test('catalogue : prix FCFA et format milliers', () {
    expect(formatFcfa(45000), '45 000');
    expect(formatFcfa(18500), '18 500');
    expect(marketplaceCatalog, isNotEmpty);
    expect(marketplaceCatalog.first.priceLabel, contains('FCFA'));
    expect(marketplaceProductById('kit-gps')?.name, contains('Kit GPS'));
  });

  test('contrôleur : commande stub sans paiement', () async {
    final shop = MarketplaceController.memory();
    expect(shop.isOrdered('kit-gps'), isFalse);
    final ok = await shop.recordOrder('kit-gps');
    expect(ok, isTrue);
    expect(shop.isOrdered('kit-gps'), isTrue);
    expect(MarketplaceController.stubMessage, contains('Aucun paiement'));
  });

  testWidgets('boutique : catalogue, Voir, Commander stub', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MarketplacePage()));
    await tester.pump();

    expect(find.byKey(const Key('marketplace-page')), findsOneWidget);
    expect(find.text('Kits GPS et traceurs'), findsOneWidget);
    expect(find.textContaining('aucun débit'), findsOneWidget);
    expect(find.byKey(const Key('marketplace-card-kit-gps')), findsOneWidget);
    expect(find.textContaining('45 000 FCFA'), findsOneWidget);
    expect(find.textContaining('Play Store'), findsNothing);

    await tester.tap(find.byKey(const Key('marketplace-voir-kit-gps')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('marketplace-product-kit-gps')), findsOneWidget);
    expect(find.text('Commander'), findsOneWidget);

    await tester.tap(find.byKey(const Key('marketplace-commander-kit-gps')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Déjà demandé'), findsOneWidget);
    expect(find.textContaining('Aucun paiement'), findsWidgets);
  });

  testWidgets('onglet Boutique visible depuis le shell', (tester) async {
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

    expect(find.text('Boutique'), findsWidgets);
    await tester.tap(find.descendant(
      of: find.byKey(const Key('main-shell-nav')),
      matching: find.text('Boutique'),
    ));
    await tester.pump();
    expect(find.byKey(const Key('marketplace-page')), findsOneWidget);
  });
}
