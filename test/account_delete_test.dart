import 'package:citycare/app/brand.dart';
import 'package:citycare/domain/entities/identity.dart';
import 'package:citycare/domain/enums/citycare_enums.dart';
import 'package:citycare/domain/repositories/auth_repository.dart';
import 'package:citycare/presentation/auth/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart';

UserAccount _marie() {
  return UserAccount(
    id: '1',
    fullName: 'Marie Parent',
    phone: '+237600000000',
    role: UserRole.parent,
    isActive: true,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

Future<void> _openProfile(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.person_outline));
  await tester.pumpAndSettle();
  final scroll = find.byType(Scrollable).last;
  await tester.scrollUntilVisible(
    find.byKey(const Key('profile-delete-account')),
    240,
    scrollable: scroll,
  );
  // Remonter un peu : le bouton ne doit pas rester sous la barre d’onglets.
  await tester.drag(scroll, const Offset(0, -120));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('profil : bouton rouge ouvre le dialogue mot de passe', (tester) async {
    final auth = AuthController(FakeAuthRepository())
      ..isRestoring = false
      ..user = _marie();
    await tester.pumpWidget(appWith(auth));
    await tester.pumpAndSettle();
    await _openProfile(tester);

    final deleteButton = tester.widget<TextButton>(find.byKey(const Key('profile-delete-account')));
    expect(deleteButton.style?.foregroundColor?.resolve({}), CityCareBrand.sos);
    expect(find.text('Supprimer mon compte'), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile-delete-account')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-delete-dialog')), findsOneWidget);
    expect(find.byKey(const Key('profile-delete-password')), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);
  });

  testWidgets('annuler le dialogue reste sur le profil', (tester) async {
    final auth = AuthController(FakeAuthRepository())
      ..isRestoring = false
      ..user = _marie();
    await tester.pumpWidget(appWith(auth));
    await tester.pumpAndSettle();
    await _openProfile(tester);

    await tester.tap(find.byKey(const Key('profile-delete-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-delete-cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-delete-dialog')), findsNothing);
    expect(find.byKey(const Key('main-shell')), findsOneWidget);
    expect(find.byKey(const Key('profile-delete-account')), findsOneWidget);
    expect(auth.user, isNotNull);
  });

  testWidgets('mauvais mot de passe : reste connecté, dialogue ouvert', (tester) async {
    final repo = FakeAuthRepository()..deleteShouldFail = true;
    final auth = AuthController(repo)
      ..isRestoring = false
      ..user = _marie();
    await tester.pumpWidget(appWith(auth));
    await tester.pumpAndSettle();
    await _openProfile(tester);

    await tester.tap(find.byKey(const Key('profile-delete-account')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('profile-delete-password')), 'incorrect1');
    await tester.tap(find.byKey(const Key('profile-delete-confirm')));
    await tester.pumpAndSettle();

    expect(repo.lastDeletePassword, 'incorrect1');
    expect(find.text('Mot de passe incorrect'), findsOneWidget);
    expect(auth.user, isNotNull);
    expect(find.byKey(const Key('main-shell')), findsOneWidget);
  });

  testWidgets('succès : jetons effacés, retour Welcome', (tester) async {
    final user = _marie();
    final repo = FakeAuthRepository(session: AuthSession(token: 'tok', user: user))
      ..token = 'tok';
    final auth = AuthController(repo)
      ..isRestoring = false
      ..user = user;
    await tester.pumpWidget(appWith(auth));
    await tester.pumpAndSettle();
    await _openProfile(tester);

    await tester.tap(find.byKey(const Key('profile-delete-account')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('profile-delete-password')), 'motdepasse');
    await tester.tap(find.byKey(const Key('profile-delete-confirm')));
    await tester.pumpAndSettle();

    expect(repo.lastDeletePassword, 'motdepasse');
    expect(repo.token, isNull);
    expect(auth.user, isNull);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.byKey(const Key('main-shell')), findsNothing);
  });
}
