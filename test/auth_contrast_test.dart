import 'package:citycare/app/theme.dart';
import 'package:citycare/presentation/auth/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart';

void main() {
  testWidgets('saisie login : texte foncé sur fond clair', (tester) async {
    final auth = AuthController(FakeAuthRepository())..isRestoring = false;
    await tester.pumpWidget(
      Theme(
        data: CityCareTheme.dark(),
        child: appWith(auth),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();

    final phone = tester.widget<TextField>(find.byKey(const Key('auth-phone-field')));
    expect(phone.style?.color, isNotNull);
    expect(phone.style!.color!.computeLuminance(), lessThan(0.4));
    expect(phone.cursorColor, isNotNull);
  });

  testWidgets('mot de passe : texte foncé même si le thème système est sombre', (tester) async {
    final auth = AuthController(FakeAuthRepository())..isRestoring = false;
    await tester.pumpWidget(appWith(auth));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('auth-phone-field')), '699000001');
    await tester.tap(find.byKey(const Key('auth-phone-continue')));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('auth-password-field')),
        matching: find.byType(TextField),
      ),
    );
    expect(field.style?.color, isNotNull);
    expect(field.style!.color!.computeLuminance(), lessThan(0.4));
  });
}
