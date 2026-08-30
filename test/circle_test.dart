import 'package:citycare/domain/entities/circle.dart';
import 'package:citycare/domain/entities/identity.dart';
import 'package:citycare/domain/entities/tracking.dart';
import 'package:citycare/domain/enums/citycare_enums.dart';
import 'package:citycare/presentation/circles/circle_controller.dart';
import 'package:citycare/presentation/circles/circle_invite_page.dart';
import 'package:citycare/presentation/circles/circle_invite_share.dart';
import 'package:citycare/presentation/circles/circle_scope.dart';
import 'package:citycare/presentation/circles/create_circle_sheet.dart';
import 'package:citycare/presentation/circles/join_circle_page.dart';
import 'package:citycare/presentation/family/family_controller.dart';
import 'package:citycare/presentation/location/location_controller.dart';
import 'package:citycare/presentation/map/member_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart';

class _JoinCircleRepository extends FakeCircleRepository {
  String? lastCode;
  Circle? lastJoined;

  @override
  Future<Circle> join(String code) async {
    lastCode = code;
    lastJoined = Circle(
      id: 'c-join',
      name: 'Famille Demo',
      inviteCode: code,
      createdByUserId: '1',
      myRole: CircleRole.member,
      memberCount: 2,
      createdAt: DateTime.utc(2026, 8, 29),
      updatedAt: DateTime.utc(2026, 8, 29),
    );
    return lastJoined!;
  }

  @override
  Future<List<Circle>> list() async => [if (lastJoined != null) lastJoined!];

  @override
  Future<List<CircleMember>> members(String circleId) async => [
        CircleMember(
          userId: '2',
          fullName: 'Amina',
          userRole: UserRole.young,
          circleRole: CircleRole.member,
          joinedAt: DateTime.utc(2026, 8, 29),
          canViewLocation: false,
        ),
      ];
}

class _MemoryCircleRepository extends FakeCircleRepository {
  Circle? lastCreated;

  @override
  Future<Circle> create(String name) async {
    lastCreated = Circle(
      id: 'c-1',
      name: name,
      inviteCode: 'AB3DEF',
      createdByUserId: '1',
      myRole: CircleRole.owner,
      memberCount: 1,
      createdAt: DateTime.utc(2026, 8, 29),
      updatedAt: DateTime.utc(2026, 8, 29),
    );
    return lastCreated!;
  }

  @override
  Future<List<Circle>> list() async => [if (lastCreated != null) lastCreated!];

  @override
  Future<String> currentInvite(String circleId) async => lastCreated?.inviteCode ?? 'AB3DEF';

  @override
  Future<List<CircleMember>> members(String circleId) async => [
        CircleMember(
          userId: '1',
          fullName: 'Marie',
          userRole: UserRole.parent,
          circleRole: CircleRole.owner,
          joinedAt: DateTime.utc(2026, 8, 29),
          canViewLocation: false,
        ),
      ];
}

void main() {
  testWidgets('feuille créer : nom + Continuer, pas tracker Life360', (tester) async {
    final circles = CircleController(_MemoryCircleRepository());
    await tester.pumpWidget(
      CircleScope(
        controller: circles,
        child: MaterialApp(
          theme: cityCareTestTheme(),
          home: const Scaffold(body: CreateCircleSheet()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Personnalisez votre Cercle'), findsOneWidget);
    expect(find.text('Continuer'), findsOneWidget);
    expect(find.textContaining('tracker Life360'), findsNothing);
    expect(find.textContaining('Life360'), findsNothing);

    await tester.enterText(find.byKey(const Key('circle-name-field')), 'Famille Steph');
    await tester.tap(find.byKey(const Key('circle-continue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Famille Steph'), findsOneWidget);
    expect(find.text('AB3DEF'), findsOneWidget);
    expect(find.text('Copier'), findsOneWidget);
    expect(find.text('Partager'), findsOneWidget);
    expect(find.byKey(const Key('circle-invite-qr')), findsOneWidget);
    expect(find.text('Associer un kit'), findsOneWidget);
  });

  test('texte de partage = code, pas un deep link', () {
    expect(circleShareText('ab3def'), 'Rejoins mon cercle CityCare : AB3DEF');
    expect(circleQrPayload('ab 3d ef'), 'AB3DEF');
  });

  testWidgets('page invitation : gros code, Copier, Partager, QR', (tester) async {
    final circles = CircleController(_MemoryCircleRepository())
      ..selected = Circle(
        id: 'c-1',
        name: 'Famille Steph',
        inviteCode: 'AB3DEF',
        createdByUserId: '1',
        myRole: CircleRole.owner,
        memberCount: 1,
        createdAt: DateTime.utc(2026, 8, 29),
        updatedAt: DateTime.utc(2026, 8, 29),
      );
    String? shared;
    String? copied;
    debugCircleShareOverride = (text) async => shared = text;
    debugCircleCopyOverride = (text) async => copied = text;
    addTearDown(() {
      debugCircleShareOverride = null;
      debugCircleCopyOverride = null;
    });

    await tester.pumpWidget(
      CircleScope(
        controller: circles,
        child: MaterialApp(
          theme: cityCareTestTheme(),
          home: const CircleInvitePage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Partager le code'), findsOneWidget);
    expect(find.text('AB3DEF'), findsOneWidget);
    expect(find.text('Copier'), findsOneWidget);
    expect(find.text('Partager'), findsOneWidget);
    expect(find.byKey(const Key('circle-invite-qr')), findsOneWidget);
    expect(find.text('Générer un nouveau code'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('circle-invite-share')));
    await tester.tap(find.byKey(const Key('circle-invite-share')));
    await tester.pump();
    expect(shared, 'Rejoins mon cercle CityCare : AB3DEF');

    await tester.ensureVisible(find.byKey(const Key('circle-invite-copy')));
    await tester.tap(find.byKey(const Key('circle-invite-copy')));
    await tester.pump();
    expect(copied, 'AB3DEF');
    expect(find.text('Code copié'), findsOneWidget);
  });

  testWidgets('rejoindre : code 6 caractères rejoint le cercle', (tester) async {
    final repo = _JoinCircleRepository();
    final circles = CircleController(repo);
    await tester.pumpWidget(
      CircleScope(
        controller: circles,
        child: MaterialApp(
          theme: cityCareTestTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const Key('open-join'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const JoinCirclePage()),
                ),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-join')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('join-circle-boxes')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('join-circle-code-field')), 'ab3def');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(repo.lastCode, 'AB3DEF');
    expect(circles.selected?.name, 'Famille Demo');
    expect(find.text('Ouvrir'), findsOneWidget);
  });

  testWidgets('rejoindre : 6 cases', (tester) async {
    await tester.pumpWidget(
      CircleScope(
        controller: CircleController(FakeCircleRepository()),
        child: MaterialApp(
          theme: cityCareTestTheme(),
          home: const JoinCirclePage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('join-circle-boxes')), findsOneWidget);
    expect(find.text('Rejoindre un cercle'), findsOneWidget);
    expect(find.text('Rejoindre'), findsOneWidget);
  });

  test('membres cercle : position seulement si GuardianLink déjà vrai', () {
    final user = UserAccount(
      id: 'g-1',
      fullName: 'Marie',
      phone: '+237600000000',
      role: UserRole.parent,
      isActive: true,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final locations = LocationController(FakeLocationRepository());
    locations.familyLatest['yp-1'] = TrackerLocation(
      id: 'loc-1',
      youngPersonId: 'yp-1',
      source: LocationSource.phone,
      latitude: 3.848,
      longitude: 11.502,
      recordedAt: DateTime.utc(2026, 8, 29, 20),
      isStale: false,
      ageSeconds: 20,
    );
    final members = [
      CircleMember(
        userId: 'g-1',
        fullName: 'Marie',
        userRole: UserRole.parent,
        circleRole: CircleRole.owner,
        joinedAt: DateTime.utc(2026, 8, 29),
        canViewLocation: false,
      ),
      CircleMember(
        userId: '2',
        fullName: 'Amina',
        userRole: UserRole.young,
        circleRole: CircleRole.member,
        joinedAt: DateTime.utc(2026, 8, 29),
        youngPersonId: 'yp-1',
        canViewLocation: false,
      ),
      CircleMember(
        userId: '3',
        fullName: 'Léa',
        userRole: UserRole.young,
        circleRole: CircleRole.member,
        joinedAt: DateTime.utc(2026, 8, 29),
        youngPersonId: 'yp-2',
        canViewLocation: true,
      ),
    ];
    locations.familyLatest['yp-2'] = TrackerLocation(
      id: 'loc-2',
      youngPersonId: 'yp-2',
      source: LocationSource.phone,
      latitude: 3.85,
      longitude: 11.51,
      recordedAt: DateTime.utc(2026, 8, 29, 21),
      isStale: false,
      ageSeconds: 8,
    );

    final rows = mapMembersForCircle(user: user, members: members, locations: locations);
    expect(rows, hasLength(3));
    expect(rows[0].kind, MapMemberKind.self);
    expect(rows[1].name, 'Amina');
    expect(rows[1].hasPin, isFalse);
    expect(rows[1].sharingOn, isFalse);
    expect(rows[2].name, 'Léa');
    expect(rows[2].hasPin, isTrue);
    expect(rows[2].sharingOn, isTrue);

    final pins = mapPinsForCircle(user: user, members: members, locations: locations);
    expect(pins, hasLength(1));
    expect(pins.first.label, 'Léa');
  });

  test('liste GuardianLink inchangée sans cercle sélectionné', () {
    final family = FamilyController(FakeFamilyRepository())
      ..links = const [
        GuardianLink(
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
    final locations = LocationController(FakeLocationRepository());
    final rows = mapMembersForGuardian(family: family, locations: locations);
    expect(rows.single.name, 'Amina');
  });
}
