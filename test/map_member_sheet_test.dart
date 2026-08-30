import 'package:citycare/app/brand.dart';
import 'package:citycare/domain/entities/alerts.dart';
import 'package:citycare/domain/entities/identity.dart';
import 'package:citycare/domain/entities/tracking.dart';
import 'package:citycare/domain/enums/citycare_enums.dart';
import 'package:citycare/presentation/auth/auth_controller.dart';
import 'package:citycare/presentation/family/family_controller.dart';
import 'package:citycare/presentation/location/location_controller.dart';
import 'package:citycare/presentation/location/maps/map_data.dart';
import 'package:citycare/presentation/location/maps/map_pin_marker.dart';
import 'package:citycare/presentation/map/member_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart';

void main() {
  test('initiales sans inventer une photo', () {
    expect(memberInitials('Amina'), 'A');
    expect(memberInitials('Marie Parent'), 'MP');
    expect(memberInitials('  '), '?');
  });

  test('fraîcheur honnête : jamais temps réel si stale ou absente', () {
    expect(memberFreshnessLabel(null), 'Aucune position connue');
    expect(memberFreshnessLabel(null), isNot(contains('temps réel')));

    final stale = TrackerLocation(
      id: 'loc-1',
      youngPersonId: 'yp-1',
      source: LocationSource.phone,
      latitude: 3.848,
      longitude: 11.502,
      recordedAt: DateTime.utc(2026, 8, 29, 20),
      isStale: true,
      ageSeconds: 600,
    );
    expect(memberFreshnessLabel(stale), 'Dernière position : il y a 10 min');
    expect(memberFreshnessLabel(stale), isNot(contains('temps réel')));
    expect(memberFreshnessLabel(stale), isNot(contains('en direct')));

    final fresh = TrackerLocation(
      id: 'loc-2',
      youngPersonId: 'yp-1',
      source: LocationSource.phone,
      latitude: 3.848,
      longitude: 11.502,
      recordedAt: DateTime.utc(2026, 8, 29, 21),
      isStale: false,
      ageSeconds: 12,
    );
    expect(memberFreshnessLabel(fresh), 'Mis à jour il y a 12 s');
    expect(memberFreshnessLabel(fresh), isNot(contains('temps réel')));

    final oldWithoutFlag = TrackerLocation(
      id: 'loc-3',
      youngPersonId: 'yp-1',
      source: LocationSource.phone,
      latitude: 3.848,
      longitude: 11.502,
      recordedAt: DateTime.utc(2026, 8, 29, 19),
      isStale: false,
      ageSeconds: 400,
    );
    expect(memberFreshnessLabel(oldWithoutFlag), 'Dernière position : il y a 6 min');
    expect(memberFreshnessLabel(oldWithoutFlag), isNot(contains('temps réel')));
    expect(locationLooksStale(isStale: false, ageSeconds: 400), isTrue);
    expect(locationLooksStale(isStale: false, ageSeconds: 12), isFalse);
  });

  test('statut partage / GPS / hors-ligne', () {
    expect(
      memberStatusLabel(sharingOn: true, point: null),
      'Partage on · Hors ligne',
    );
    expect(
      memberStatusLabel(
        sharingOn: false,
        point: TrackerLocation(
          id: 'loc-1',
          youngPersonId: 'yp-1',
          source: LocationSource.phone,
          latitude: 3.8,
          longitude: 11.5,
          recordedAt: DateTime.utc(2026, 8, 29),
          isStale: false,
          ageSeconds: 8,
        ),
      ),
      'Partage off · GPS',
    );
  });

  test('batterie kit et téléphone : libellés distincts, rien si absente', () {
    final phone = TrackerLocation(
      id: 'loc-p',
      youngPersonId: 'yp-1',
      source: LocationSource.phone,
      latitude: 3.8,
      longitude: 11.5,
      recordedAt: DateTime.utc(2026, 8, 29),
      batteryLevel: 88,
    );
    expect(kitBatteryLabel(phone), isNull);
    expect(phoneBatteryLabel(phone), 'Batterie : 88 %');
    expect(memberBatteryLabel(phone), 'Batterie : 88 %');

    final kit = TrackerLocation(
      id: 'loc-k',
      youngPersonId: 'yp-1',
      source: LocationSource.iot,
      latitude: 3.8,
      longitude: 11.5,
      recordedAt: DateTime.utc(2026, 8, 29),
      batteryLevel: 41,
    );
    expect(kitBatteryLabel(kit), 'Batterie kit : 41 %');
    expect(phoneBatteryLabel(kit), isNull);
    expect(memberBatteryLabel(kit), 'Batterie kit : 41 %');

    final phoneUnknown = TrackerLocation(
      id: 'loc-u',
      youngPersonId: 'yp-1',
      source: LocationSource.phone,
      latitude: 3.8,
      longitude: 11.5,
      recordedAt: DateTime.utc(2026, 8, 29),
    );
    expect(phoneBatteryLabel(phoneUnknown), isNull);
    expect(memberBatteryLabel(phoneUnknown), isNull);
  });

  test('liste parent : jeunes liés + partages, pas de self', () {
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
    locations.familyLatest['yp-1'] = TrackerLocation(
      id: 'loc-1',
      youngPersonId: 'yp-1',
      source: LocationSource.iot,
      latitude: 3.848,
      longitude: 11.502,
      recordedAt: DateTime.utc(2026, 8, 29, 20),
      batteryLevel: 37,
      isStale: true,
      ageSeconds: 180,
    );

    final rows = mapMembersForGuardian(family: family, locations: locations);
    expect(rows, hasLength(1));
    expect(rows.first.name, 'Amina');
    expect(rows.first.sharingOn, isTrue);
    expect(rows.first.hasPin, isTrue);
    expect(memberFreshnessLabel(rows.first.point), 'Dernière position : il y a 3 min');
    expect(kitBatteryLabel(rows.first.point), 'Batterie kit : 37 %');
  });

  test('liste jeune : self + gardiens, sans GPS inventé pour le parent', () {
    final user = UserAccount(
      id: '2',
      fullName: 'Amina',
      phone: '+237600000001',
      role: UserRole.young,
      isActive: true,
      youngPersonId: 'yp-1',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final family = FamilyController(FakeFamilyRepository())
      ..links = const [
        GuardianLink(
          id: 'l-g',
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
          guardianName: 'Marie',
        ),
      ];
    final locations = LocationController(FakeLocationRepository());

    final rows = mapMembersForYoung(user: user, family: family, locations: locations);
    expect(rows, hasLength(2));
    expect(rows.first.kind, MapMemberKind.self);
    expect(rows.first.name, 'Amina');
    expect(rows.last.kind, MapMemberKind.guardian);
    expect(rows.last.name, 'Marie');
    expect(rows.last.hasPin, isFalse);
    expect(rows.last.sharingOn, isTrue);
  });

  testWidgets('accueil carte : moitié carte, moitié groupe de confiance', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final auth = AuthController(FakeAuthRepository())
      ..isRestoring = false
      ..user = UserAccount(
        id: '1',
        fullName: 'Marie Demo',
        phone: '+237699000001',
        role: UserRole.parent,
        isActive: true,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
    await tester.pumpWidget(appWith(auth));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byKey(const Key('map-home-map-half')), findsOneWidget);
    expect(find.byKey(const Key('map-home-list-half')), findsOneWidget);
    expect(find.byKey(const Key('map-member-sheet')), findsOneWidget);
    expect(find.text('Groupe de confiance'), findsOneWidget);

    final mapHalf = tester.getSize(find.byKey(const Key('map-home-map-half')));
    final listHalf = tester.getSize(find.byKey(const Key('map-home-list-half')));
    expect((mapHalf.height - listHalf.height).abs(), lessThan(8));
    expect(mapHalf.height, greaterThan(200));
  });

  testWidgets('sheet parent affiche avatar, statut et fraîcheur', (tester) async {
    final stale = TrackerLocation(
      id: 'loc-1',
      youngPersonId: 'yp-1',
      source: LocationSource.iot,
      latitude: 3.848,
      longitude: 11.502,
      recordedAt: DateTime.utc(2026, 8, 29, 20),
      batteryLevel: 22,
      isStale: true,
      ageSeconds: 600,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapMembersSheet(
            members: [
              MapMemberRow(
                id: 'young-yp-1',
                name: 'Amina',
                kind: MapMemberKind.young,
                point: stale,
                sharingOn: true,
                youngPersonId: 'yp-1',
                canOpenDetail: true,
              ),
            ],
            selectedId: null,
            onSelect: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('map-member-sheet')), findsOneWidget);
    expect(find.text('Amina'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.textContaining('Partage on'), findsOneWidget);
    expect(find.byKey(const Key('care-status-attention')), findsOneWidget);
    expect(find.text('Attention'), findsOneWidget);
    expect(find.textContaining('Dernière position : il y a 10 min'), findsOneWidget);
    expect(find.textContaining('Batterie kit : 22 %'), findsOneWidget);
    expect(find.textContaining('temps réel'), findsNothing);
    expect(find.text('Groupe de confiance'), findsOneWidget);
  });

  testWidgets('sheet affiche Batterie : 72 % pour un point téléphone', (tester) async {
    final phone = TrackerLocation(
      id: 'loc-p',
      youngPersonId: 'yp-1',
      source: LocationSource.phone,
      latitude: 3.848,
      longitude: 11.502,
      recordedAt: DateTime.utc(2026, 8, 30, 12),
      batteryLevel: 72,
      isStale: false,
      ageSeconds: 20,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapMembersSheet(
            members: [
              MapMemberRow(
                id: 'self-2',
                name: 'Amina',
                kind: MapMemberKind.self,
                point: phone,
                sharingOn: true,
                canOpenDetail: true,
              ),
            ],
            selectedId: null,
            onSelect: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Batterie : 72 %'), findsOneWidget);
    expect(find.textContaining('Batterie kit'), findsNothing);
    expect(find.textContaining('100 %'), findsNothing);
  });

  testWidgets('sheet n’invente pas une batterie téléphone absente', (tester) async {
    final phone = TrackerLocation(
      id: 'loc-p',
      youngPersonId: 'yp-1',
      source: LocationSource.phone,
      latitude: 3.848,
      longitude: 11.502,
      recordedAt: DateTime.utc(2026, 8, 30, 12),
      isStale: false,
      ageSeconds: 20,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapMembersSheet(
            members: [
              MapMemberRow(
                id: 'self-2',
                name: 'Amina',
                kind: MapMemberKind.self,
                point: phone,
                sharingOn: true,
              ),
            ],
            selectedId: null,
            onSelect: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Batterie'), findsNothing);
    expect(find.textContaining('100 %'), findsNothing);
  });

  test('pins parent : jeunes seulement, fraîcheur alignée sur le sheet', () {
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
    locations.familyLatest['yp-1'] = TrackerLocation(
      id: 'loc-1',
      youngPersonId: 'yp-1',
      source: LocationSource.iot,
      latitude: 3.848,
      longitude: 11.502,
      recordedAt: DateTime.utc(2026, 8, 29, 20),
      isStale: true,
      ageSeconds: 600,
    );

    final pins = mapPinsForGuardian(family: family, locations: locations);
    expect(pins, hasLength(1));
    expect(pins.first.label, 'Amina');
    expect(pins.first.looksStale, isTrue);
    expect(pins.first.freshnessCaption, memberFreshnessLabel(locations.familyLatest['yp-1']));
    expect(pins.first.freshnessCaption, isNot(contains('temps réel')));
    expect(mapPinColor(pins.first), CityCareBrand.amberDark);
  });

  test('pin jeune : self seulement, violet si frais', () {
    final user = UserAccount(
      id: '2',
      fullName: 'Amina',
      phone: '+237600000001',
      role: UserRole.young,
      isActive: true,
      youngPersonId: 'yp-1',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final locations = LocationController(FakeLocationRepository());
    locations.latest = TrackerLocation(
      id: 'loc-self',
      youngPersonId: 'yp-1',
      source: LocationSource.phone,
      latitude: 3.848,
      longitude: 11.502,
      recordedAt: DateTime.utc(2026, 8, 29, 21),
      isStale: false,
      ageSeconds: 20,
    );

    final pins = mapPinsForYoung(user: user, locations: locations);
    expect(pins, hasLength(1));
    expect(pins.first.id, 'self-2');
    expect(pins.first.label, 'Amina');
    expect(pins.first.looksStale, isFalse);
    expect(pins.first.freshnessCaption, 'Mis à jour il y a 20 s');
    expect(pins.first.freshnessCaption, isNot(contains('temps réel')));
    expect(pins.first.batteryCaption, isNull);
    expect(mapPinColor(pins.first), CityCareBrand.safe);
  });

  test('pin moi : nom et durée pour un parent s’il a déjà un point', () {
    final user = UserAccount(
      id: '1',
      fullName: 'Duranel',
      phone: '+237699000001',
      role: UserRole.parent,
      isActive: true,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final locations = LocationController(FakeLocationRepository());
    locations.latest = TrackerLocation(
      id: 'loc-self',
      youngPersonId: 'yp-1',
      source: LocationSource.phone,
      latitude: 3.848,
      longitude: 11.502,
      recordedAt: DateTime.utc(2026, 8, 30, 12),
      isStale: false,
      ageSeconds: 240,
    );

    final pin = mapPinForSelf(user: user, locations: locations);
    expect(pin, isNotNull);
    expect(pin!.id, 'self-1');
    expect(pin.label, 'Duranel');
    expect(pin.freshnessCaption, 'Mis à jour il y a 4 min');
    expect(pin.freshnessCaption, isNot(contains('temps réel')));
    expect(pin.freshnessCaption, isNot(contains('en direct')));
  });

  test('pin moi : absent si aucune position connue', () {
    final user = UserAccount(
      id: '1',
      fullName: 'Duranel',
      phone: '+237699000001',
      role: UserRole.parent,
      isActive: true,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final locations = LocationController(FakeLocationRepository());
    expect(mapPinForSelf(user: user, locations: locations), isNull);
  });

  test('pin jeune : Batterie : 72 % si le point téléphone l’a', () {
    final user = UserAccount(
      id: '2',
      fullName: 'Amina',
      phone: '+237600000001',
      role: UserRole.young,
      isActive: true,
      youngPersonId: 'yp-1',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final locations = LocationController(FakeLocationRepository());
    locations.latest = TrackerLocation(
      id: 'loc-self',
      youngPersonId: 'yp-1',
      source: LocationSource.phone,
      latitude: 3.848,
      longitude: 11.502,
      recordedAt: DateTime.utc(2026, 8, 30, 12),
      batteryLevel: 72,
      isStale: false,
      ageSeconds: 20,
    );

    final pins = mapPinsForYoung(user: user, locations: locations);
    expect(pins.single.batteryCaption, 'Batterie : 72 %');
  });

  test('pin : âge > 5 min sans flag stale reste ambre, jamais temps réel', () {
    const pin = MapPin(
      latitude: 3.85,
      longitude: 11.5,
      label: 'Amina',
      id: 'young-yp-1',
      isStale: false,
      ageSeconds: 400,
    );
    expect(pin.looksStale, isTrue);
    expect(pin.freshnessCaption, 'Dernière position : il y a 6 min');
    expect(pin.freshnessCaption, isNot(contains('temps réel')));
    expect(mapPinColor(pin), CityCareBrand.amberDark);
  });

  test('pin SOS : rouge Danger, pas un stale déguisé en urgence', () {
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
    locations.familyLatest['yp-1'] = TrackerLocation(
      id: 'loc-1',
      youngPersonId: 'yp-1',
      source: LocationSource.phone,
      latitude: 3.848,
      longitude: 11.502,
      recordedAt: DateTime.utc(2026, 8, 30, 12),
      isStale: false,
      ageSeconds: 15,
    );
    final at = DateTime.utc(2026, 8, 30, 12);
    final pins = mapPinsForGuardian(
      family: family,
      locations: locations,
      alerts: [
        Alert(
          id: 'sos-1',
          youngPersonId: 'yp-1',
          source: AlertSource.mobile,
          status: AlertStatus.active,
          severity: AlertSeverity.critical,
          triggeredAt: at,
          createdAt: at,
          updatedAt: at,
        ),
      ],
    );
    expect(pins.single.careLevel, CareLevel.danger);
    expect(mapPinColor(pins.single), CityCareBrand.sos);
    expect(pins.single.careCaption, 'Danger');
  });

  testWidgets('callout pin : nom + fraîcheur stale ambre, jamais temps réel', (tester) async {
    const stale = MapPin(
      latitude: 3.848,
      longitude: 11.502,
      label: 'Amina',
      id: 'young-yp-1',
      isStale: true,
      ageSeconds: 600,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: MapPinMarker(pin: stale))),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('map-pin-callout-young-yp-1')), findsOneWidget);
    expect(find.text('Amina'), findsOneWidget);
    expect(find.text('Attention'), findsOneWidget);
    expect(find.text('Dernière position : il y a 10 min'), findsOneWidget);
    expect(find.textContaining('temps réel'), findsNothing);
    final icon = tester.widget<Icon>(find.byIcon(Icons.location_on));
    expect(icon.color, CityCareBrand.amberDark);
  });

  testWidgets('callout pin : frais violet, Mis à jour', (tester) async {
    const fresh = MapPin(
      latitude: 3.848,
      longitude: 11.502,
      label: 'Amina',
      id: 'self-2',
      isStale: false,
      ageSeconds: 20,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: MapPinMarker(pin: fresh))),
      ),
    );
    await tester.pump();

    expect(find.byType(MapPinMarker), findsOneWidget);
    expect(find.text('Amina'), findsOneWidget);
    expect(find.text('Position récente'), findsOneWidget);
    expect(find.text('Mis à jour il y a 20 s'), findsOneWidget);
    expect(find.textContaining('temps réel'), findsNothing);
    final icon = tester.widget<Icon>(find.byIcon(Icons.location_on));
    expect(icon.color, CityCareBrand.safe);
  });

  testWidgets('callout pin : Batterie : 72 % si connue', (tester) async {
    const withBattery = MapPin(
      latitude: 3.848,
      longitude: 11.502,
      label: 'Amina',
      id: 'self-2',
      isStale: false,
      ageSeconds: 20,
      batteryCaption: 'Batterie : 72 %',
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: MapPinMarker(pin: withBattery))),
      ),
    );
    await tester.pump();

    expect(find.text('Batterie : 72 %'), findsOneWidget);
    expect(find.textContaining('Batterie kit'), findsNothing);
    expect(find.textContaining('100 %'), findsNothing);
  });

  testWidgets('accueil carte : raccourcis blancs sans overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final overflows = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.toString();
      if (text.toLowerCase().contains('overflowed')) {
        overflows.add(text);
      }
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);

    final auth = AuthController(FakeAuthRepository())
      ..isRestoring = false
      ..user = UserAccount(
        id: '1',
        fullName: 'Marie Demo',
        phone: '+237699000001',
        role: UserRole.parent,
        isActive: true,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
    await tester.pumpWidget(appWith(auth));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byKey(const Key('map-shortcut-grid')), findsOneWidget);
    expect(find.byKey(const Key('map-shortcut-invite')), findsOneWidget);
    expect(find.byKey(const Key('map-shortcut-zones')), findsOneWidget);
    expect(find.byKey(const Key('map-shortcut-prevention')), findsOneWidget);
    expect(find.byKey(const Key('map-shortcut-marketplace')), findsOneWidget);
    expect(overflows, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pin + bulle tient dans la hauteur marqueur', (tester) async {
    const pin = MapPin(
      latitude: 3.848,
      longitude: 11.502,
      label: 'Steph',
      id: 'self-1',
      isStale: true,
      ageSeconds: 120,
      batteryCaption: 'Batterie : 72 %',
    );
    final overflows = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().toLowerCase().contains('overflowed')) {
        overflows.add(details.toString());
      }
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: mapPinMarkerWidth(pin),
              height: mapPinMarkerHeight(pin),
              child: const MapPinMarker(pin: pin),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Steph'), findsOneWidget);
    expect(overflows, isEmpty);
    expect(tester.takeException(), isNull);
  });

}
