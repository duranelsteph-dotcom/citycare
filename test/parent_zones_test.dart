import 'package:citycare/domain/entities/identity.dart';
import 'package:citycare/domain/enums/citycare_enums.dart';
import 'package:citycare/presentation/family/family_controller.dart';
import 'package:citycare/presentation/family/family_scope.dart';
import 'package:citycare/presentation/zones/parent_zones_hub.dart';
import 'package:citycare/presentation/zones/zone_controller.dart';
import 'package:citycare/presentation/zones/zone_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart';

void main() {
  testWidgets('hub parent liste l’enfant et propose d’ajouter un lieu', (tester) async {
    await tester.pumpWidget(
      FamilyScope(
        controller: FamilyController(_OneChildFamily()),
        child: ZoneScope(
          controller: ZoneController(FakeZoneRepository()),
          child: MaterialApp(theme: cityCareTestTheme(), home: const ParentZonesHubPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('parent-zones-hub')), findsOneWidget);
    expect(find.text('Amina'), findsWidgets);
    expect(find.text('Ajouter un lieu'), findsOneWidget);
    expect(find.text('Voir les zones'), findsOneWidget);
  });

  testWidgets('carte enfant ouvre les zones éditables', (tester) async {
    await tester.pumpWidget(
      FamilyScope(
        controller: FamilyController(_OneChildFamily()),
        child: ZoneScope(
          controller: ZoneController(FakeZoneRepository()),
          child: MaterialApp(theme: cityCareTestTheme(), home: const ParentZonesHubPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Voir les zones'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byKey(const Key('safety-zones-page')), findsOneWidget);
    expect(find.textContaining('Amina'), findsWidgets);
  });
}

class _OneChildFamily extends FakeFamilyRepository {
  @override
  Future<List<GuardianLink>> children() async => [
        const GuardianLink(
          id: 'l-1',
          guardianUserId: 'g-1',
          youngPersonId: 'yp-1',
          relation: GuardianRelation.parent,
          status: GuardianLinkStatus.active,
          canViewLocation: true,
          canReceiveAlerts: true,
          canTriggerAlert: false,
          canReportMissing: true,
          canManageZones: true,
          canManageTracker: true,
          youngDisplayName: 'Amina',
        ),
      ];
}
