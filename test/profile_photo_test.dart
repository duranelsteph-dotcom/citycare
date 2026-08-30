import 'package:citycare/core/config/api_config.dart';
import 'package:citycare/domain/entities/circle.dart';
import 'package:citycare/domain/entities/identity.dart';
import 'package:citycare/domain/entities/tracking.dart';
import 'package:citycare/domain/enums/citycare_enums.dart';
import 'package:citycare/presentation/auth/auth_controller.dart';
import 'package:citycare/presentation/location/location_controller.dart';
import 'package:citycare/presentation/map/member_sheet.dart';
import 'package:citycare/presentation/profile/profile_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart';

UserAccount _marie({String? photoUrl}) {
  return UserAccount(
    id: '1',
    fullName: 'Marie Parent',
    phone: '+237600000000',
    role: UserRole.parent,
    isActive: true,
    photoUrl: photoUrl,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  test('resolveMediaUrl compose avec l’origine de baseUrl', () {
    expect(ApiConfig.resolveMediaUrl(null), isNull);
    expect(ApiConfig.resolveMediaUrl(''), isNull);
    expect(
      ApiConfig.resolveMediaUrl('https://cdn.example/a.jpg'),
      'https://cdn.example/a.jpg',
    );
    final resolved = ApiConfig.resolveMediaUrl('/static/uploads/a.jpg');
    expect(resolved, isNotNull);
    expect(resolved, endsWith('/static/uploads/a.jpg'));
    expect(resolved, isNot(contains('/api/v1/static')));
  });

  test('membres cercle : photoUrl déjà présent est recopié', () {
    final user = _marie();
    final locations = LocationController(FakeLocationRepository());
    final members = [
      CircleMember(
        userId: '1',
        fullName: 'Marie Parent',
        userRole: UserRole.parent,
        circleRole: CircleRole.owner,
        joinedAt: DateTime.utc(2026, 8, 29),
        photoUrl: '/static/uploads/marie.jpg',
        canViewLocation: false,
      ),
      CircleMember(
        userId: '2',
        fullName: 'Amina',
        userRole: UserRole.young,
        circleRole: CircleRole.member,
        joinedAt: DateTime.utc(2026, 8, 29),
        youngPersonId: 'yp-1',
        photoUrl: '/static/uploads/amina.jpg',
        canViewLocation: true,
      ),
    ];
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

    final rows = mapMembersForCircle(user: user, members: members, locations: locations);
    expect(rows[0].photoUrl, '/static/uploads/marie.jpg');
    expect(rows[1].photoUrl, '/static/uploads/amina.jpg');

    final pins = mapPinsForCircle(user: user, members: members, locations: locations);
    expect(pins, hasLength(1));
    expect(pins.first.photoUrl, '/static/uploads/amina.jpg');
  });

  testWidgets('avatar sans photo : initiales, pas de NetworkImage inventée', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ProfileAvatar(name: 'Marie Parent')),
      ),
    );
    expect(find.text('MP'), findsOneWidget);
    expect(find.byType(CircleAvatar), findsOneWidget);
  });

  testWidgets('onglet Profil : avatar cliquable ouvre galerie et caméra', (tester) async {
    final auth = AuthController(FakeAuthRepository())
      ..isRestoring = false
      ..user = _marie();
    await tester.pumpWidget(appWith(auth));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-avatar')), findsOneWidget);
    expect(find.text('MP'), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile-avatar')));
    await tester.pumpAndSettle();

    expect(find.text('Galerie'), findsOneWidget);
    expect(find.text('Appareil photo'), findsOneWidget);
    expect(find.byKey(const Key('profile-photo-gallery')), findsOneWidget);
    expect(find.byKey(const Key('profile-photo-camera')), findsOneWidget);
  });
}
