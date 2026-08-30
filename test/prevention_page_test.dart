import 'package:citycare/app/brand.dart';
import 'package:citycare/app/theme.dart';
import 'package:citycare/presentation/prevention/prevention_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('prévention : fond blanc + violet même en thème sombre', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CityCareTheme.dark(),
        darkTheme: CityCareTheme.dark(),
        themeMode: ThemeMode.dark,
        home: const PreventionPage(),
      ),
    );
    await tester.pump();

    expect(find.text('Lire les conseils de prévention'), findsOneWidget);
    expect(find.text('Trois réflexes qui protègent'), findsOneWidget);
    expect(find.textContaining('trajet connu'), findsOneWidget);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, Colors.white);

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, CityCareBrand.violet);
  });
}
