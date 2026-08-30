import 'package:citycare/core/auth/password_rules.dart';
import 'package:citycare/core/errors/api_exception.dart';
import 'package:citycare/data/datasources/device_location_service.dart';
import 'package:citycare/domain/entities/alerts.dart';
import 'package:citycare/domain/entities/identity.dart';
import 'package:citycare/domain/entities/location_access.dart';
import 'package:citycare/domain/enums/citycare_enums.dart';
import 'package:citycare/domain/repositories/alert_repository.dart';
import 'package:citycare/domain/repositories/auth_repository.dart';
import 'package:citycare/presentation/alerts/alert_controller.dart';
import 'package:citycare/presentation/alerts/alert_scope.dart';
import 'package:citycare/presentation/alerts/hold_sos_fab.dart';
import 'package:citycare/presentation/auth/auth_controller.dart';
import 'package:citycare/presentation/auth/auth_scope.dart';
import 'package:citycare/presentation/auth/otp_page.dart';
import 'package:citycare/presentation/auth/register_page.dart';
import 'package:citycare/presentation/auth/role_capabilities.dart';
import 'package:citycare/presentation/marketplace/marketplace_catalog.dart';
import 'package:citycare/presentation/marketplace/marketplace_controller.dart';
import 'package:citycare/presentation/marketplace/marketplace_product_page.dart';
import 'package:citycare/presentation/profile/subscription_controller.dart';
import 'package:citycare/presentation/profile/subscription_page.dart';
import 'package:citycare/presentation/profile/subscription_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'widget_test.dart';

UserAccount _user(UserRole role, {String id = 'u-1', String name = 'Poste'}) {
  return UserAccount(
    id: id,
    fullName: name,
    phone: '+23769900000$id',
    role: role,
    isActive: true,
    youngPersonId: role == UserRole.young ? 'yp-1' : null,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

AuthController _authFor(UserRole role, {String id = 'u-1', String name = 'Poste'}) {
  return AuthController(FakeAuthRepository())
    ..isRestoring = false
    ..user = _user(role, id: id, name: name);
}

void main() {
  test('règles mot de passe alignées Flutter / backend', () {
    expect(PasswordRules.isStrong('motdepasse'), isFalse);
    expect(PasswordRules.isStrong('VilleCare'), isFalse);
    expect(PasswordRules.isStrong('villecare1!'), isFalse);
    expect(PasswordRules.isStrong('VilleCare1!'), isTrue);
    expect(PasswordRules.validate('abc'), PasswordRules.message);
  });

  test('autorité sans SOS, proche et jeune avec SOS UI', () {
    expect(roleShowsSos(UserRole.authority), isFalse);
    expect(roleShowsSos(UserRole.young), isTrue);
    expect(roleShowsSos(UserRole.parent), isTrue);
    expect(roleShowsSos(UserRole.relative), isTrue);
    expect(roleCanTriggerSos(UserRole.authority), isFalse);
  });

  testWidgets('autorité : pas de FAB SOS, menu mission visible', (tester) async {
    await tester.pumpWidget(appWith(_authFor(UserRole.authority)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byKey(const Key('main-shell')), findsOneWidget);
    expect(find.byKey(const Key('sos-fab')), findsNothing);

    await tester.tap(find.text('Profil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('profile-authority-alerts'), skipOffstage: false), findsOneWidget);
    expect(find.byKey(const Key('profile-authority-cases'), skipOffstage: false), findsOneWidget);
    expect(find.byKey(const Key('profile-authority-notices'), skipOffstage: false), findsOneWidget);

    final profileScroll = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(find.text('Toutes les fonctions'), 240, scrollable: profileScroll);
    await tester.tap(find.text('Toutes les fonctions'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('role-home-authority-alerts')), findsOneWidget);
    expect(find.byKey(const Key('role-home-authority-cases')), findsOneWidget);
    expect(find.byKey(const Key('role-home-authority-notices')), findsOneWidget);
    expect(find.byKey(const Key('role-home-relative-new-notice')), findsNothing);
  });

  testWidgets('proche : avis de recherche sur le menu, pas caché', (tester) async {
    await tester.pumpWidget(appWith(_authFor(UserRole.relative, id: '3', name: 'Marc')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    await tester.tap(find.text('Profil'));
    await tester.pump();
    expect(find.byKey(const Key('profile-relative-new-notice'), skipOffstage: false), findsOneWidget);
    expect(find.text('Nouveau avis de recherche', skipOffstage: false), findsOneWidget);

    final profileScroll = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(find.text('Toutes les fonctions'), 240, scrollable: profileScroll);
    await tester.tap(find.text('Toutes les fonctions'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('role-home-relative-new-notice')), findsOneWidget);
    expect(find.text('Nouveau avis de recherche'), findsWidgets);
    expect(find.byKey(const Key('role-home-authority-alerts')), findsNothing);
  });

  testWidgets('jeune : FAB SOS toujours là', (tester) async {
    await tester.pumpWidget(appWith(_authFor(UserRole.young, id: '2', name: 'Amina')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byKey(const Key('sos-fab')), findsOneWidget);
  });

  testWidgets('OTP démo affiché et utilisable', (tester) async {
    final auth = AuthController(FakeAuthRepository())
      ..isRestoring = false
      ..pendingChallenge = const LoginChallenge(
        challengeId: 'challenge-demo',
        expiresIn: 300,
        otpDev: '123456',
      );
    await tester.pumpWidget(
      AuthScope(
        controller: auth,
        child: MaterialApp(theme: cityCareTestTheme(), home: const OtpPage()),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('auth-otp-dev-code')), findsOneWidget);
    expect(find.text('123456'), findsOneWidget);
    expect(find.byKey(const Key('auth-otp-use-dev')), findsOneWidget);
    expect(find.textContaining('Mode démo'), findsOneWidget);
  });

  testWidgets('inscription affiche la règle du mot de passe fort', (tester) async {
    final auth = AuthController(FakeAuthRepository())..isRestoring = false;
    await tester.pumpWidget(
      AuthScope(
        controller: auth,
        child: MaterialApp(theme: cityCareTestTheme(), home: const RegisterPage()),
      ),
    );
    await tester.pump();
    expect(find.text(PasswordRules.message, skipOffstage: false), findsWidgets);
  });

  testWidgets('abonnement : confirmation démo passe à Actif', (tester) async {
    final billing = SubscriptionController.memory();
    await tester.pumpWidget(
      SubscriptionScope(
        controller: billing,
        child: MaterialApp(theme: cityCareTestTheme(), home: const SubscriptionPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('Aucun abonnement actif'), findsOneWidget);
    await tester.tap(find.byKey(const Key('subscription-record')));
    await tester.pump();
    expect(find.byKey(const Key('subscription-confirm-demo')), findsOneWidget);
    await tester.tap(find.byKey(const Key('subscription-confirm-demo')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(billing.current.isActive, isTrue);
    expect(find.textContaining('Statut : Actif'), findsOneWidget);
  });

  testWidgets('boutique : paiement démo enregistre la commande', (tester) async {
    final shop = MarketplaceController.memory();
    final product = marketplaceCatalog.first;
    await tester.pumpWidget(
      MaterialApp(
        theme: cityCareTestTheme(),
        home: MarketplaceProductPage(product: product, controller: shop),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(Key('marketplace-commander-${product.id}')));
    await tester.pump();
    expect(find.byKey(Key('marketplace-confirm-demo-${product.id}')), findsOneWidget);
    await tester.tap(find.byKey(Key('marketplace-confirm-demo-${product.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(shop.isOrdered(product.id), isTrue);
    expect(find.text('Commande enregistrée'), findsOneWidget);
  });

  testWidgets('SOS affiche l’erreur réelle, pas un silence', (tester) async {
    final repo = _FailingAlerts();
    final auth = AuthController(FakeAuthRepository())
      ..isRestoring = false
      ..user = _user(UserRole.young, id: '2', name: 'Amina');
    await tester.pumpWidget(
      AuthScope(
        controller: auth,
        child: AlertScope(
          controller: AlertController(repo, device: _NoGps()),
          child: MaterialApp(
            theme: cityCareTestTheme(),
            home: Scaffold(
              floatingActionButton: HoldSosFab(
                role: UserRole.young,
                holdDuration: const Duration(milliseconds: 80),
                onShortPress: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.startGesture(tester.getCenter(find.byKey(const Key('sos-fab'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('Serveur injoignable'), findsWidgets);
  });
}

class _NoGps extends DeviceLocationService {
  @override
  Future<LocationAccess> requestAccess() async {
    return const LocationAccess(LocationAccessStatus.denied);
  }

  @override
  Future<Position> currentFix() async {
    throw const DeviceLocationException('Pas de GPS en test');
  }
}

class _FailingAlerts extends FakeAlertRepository {
  @override
  Future<Alert> triggerSos(SosDraft draft) async {
    throw const ApiException(
      'Serveur injoignable (Connection refused). Vérifiez que l’API tourne.',
      statusCode: 0,
    );
  }
}
