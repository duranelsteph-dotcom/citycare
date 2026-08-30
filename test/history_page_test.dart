import 'package:citycare/core/errors/api_exception.dart';
import 'package:citycare/domain/entities/search.dart';
import 'package:citycare/domain/enums/citycare_enums.dart';
import 'package:citycare/presentation/location/history_page.dart';
import 'package:citycare/presentation/location/location_controller.dart';
import 'package:citycare/presentation/location/location_scope.dart';
import 'package:citycare/presentation/location/trip_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart';

TrajectoryPoint _point({
  required String id,
  required DateTime at,
  double lat = 3.848,
  double lng = 11.502,
}) {
  return TrajectoryPoint(
    locationId: id,
    latitude: lat,
    longitude: lng,
    recordedAt: at,
    source: LocationSource.phone,
  );
}

Trip _trip() {
  return Trip(
    id: 'loc-a:loc-c',
    startedAt: DateTime.utc(2026, 8, 30, 7, 12),
    endedAt: DateTime.utc(2026, 8, 30, 7, 47),
    distanceMeters: 2400,
    pointCount: 3,
    points: [
      _point(id: 'loc-a', at: DateTime.utc(2026, 8, 30, 7, 12)),
      _point(id: 'loc-b', at: DateTime.utc(2026, 8, 30, 7, 30), lat: 3.852, lng: 11.506),
      _point(id: 'loc-c', at: DateTime.utc(2026, 8, 30, 7, 47), lat: 3.856, lng: 11.510),
    ],
  );
}

class _TripsRepo extends FakeLocationRepository {
  TripPeriod? lastPeriod;
  DateTime? lastFrom;
  DateTime? lastTo;
  String? lastYoungId;

  @override
  Future<TripHistory> myTrips({TripPeriod? period, DateTime? from, DateTime? to, int limit = 1000}) async {
    lastPeriod = period;
    lastFrom = from;
    lastTo = to;
    return TripHistory(
      youngPersonId: 'yp-1',
      period: period?.apiValue ?? 'today',
      trips: [_trip()],
      tripCount: 1,
      pointCount: 3,
      disclaimer:
          'Historique de déplacements reconstruit. Ce n’est pas un rapport de conduite (vitesse max, distraction).',
    );
  }

  @override
  Future<TripHistory> childTrips(
    String youngPersonId, {
    TripPeriod? period,
    DateTime? from,
    DateTime? to,
    int limit = 1000,
  }) async {
    lastYoungId = youngPersonId;
    lastPeriod = period;
    lastFrom = from;
    lastTo = to;
    return TripHistory(
      youngPersonId: youngPersonId,
      access: 'PERMISSION',
      period: period?.apiValue ?? 'today',
      trips: [_trip()],
      tripCount: 1,
      pointCount: 3,
      disclaimer:
          'Historique de déplacements reconstruit. Ce n’est pas un rapport de conduite (vitesse max, distraction).',
    );
  }
}

class _ForbiddenTrips extends FakeLocationRepository {
  @override
  Future<TripHistory> childTrips(
    String youngPersonId, {
    TripPeriod? period,
    DateTime? from,
    DateTime? to,
    int limit = 1000,
  }) async {
    throw const ApiException('Le jeune n\'a pas autorisé le partage de sa position', statusCode: 403);
  }
}

Widget _harness({
  required LocationController location,
  String? youngPersonId,
  String? displayName,
}) {
  return LocationScope(
    controller: location,
    child: MaterialApp(
      theme: cityCareTestTheme(),
      home: HistoryPage(youngPersonId: youngPersonId, displayName: displayName),
    ),
  );
}

void main() {
  test('trip_copy affiche date, heures et distance sans conduite', () {
    final trip = _trip();
    expect(tripDateLabel(trip.startedAt), contains('août'));
    expect(tripWindowLabel(trip), contains('–'));
    expect(tripDistanceLabel(2400), '2.4 km');
    expect(tripDistanceLabel(180), '180 m');
    expect(tripDistanceLabel(0), 'Distance inconnue');
    expect(tripSubtitle(trip), contains('3 positions'));
  });

  testWidgets('history page lists trips with chips and no driving report', (tester) async {
    final repo = _TripsRepo();
    final location = LocationController(repo);
    await tester.pumpWidget(_harness(location: location, displayName: 'Amina'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Historique'), findsWidgets);
    expect(find.byKey(const Key('history-period-chips')), findsOneWidget);
    expect(find.text('Aujourd’hui'), findsOneWidget);
    expect(find.text('Hier'), findsOneWidget);
    expect(find.text('7 jours'), findsOneWidget);
    expect(find.text('Période'), findsOneWidget);
    expect(find.byKey(const Key('history-trip-list')), findsOneWidget);
    expect(find.textContaining('2.4 km'), findsOneWidget);
    expect(find.textContaining('3 positions'), findsOneWidget);
    expect(find.textContaining('rapport de conduite'), findsWidgets);
    expect(find.text('Vitesse max'), findsNothing);
    expect(find.text('Distrait'), findsNothing);
    expect(find.textContaining('Life360'), findsNothing);
  });

  testWidgets('history chips request yesterday then seven days', (tester) async {
    final repo = _TripsRepo();
    final location = LocationController(repo);
    await tester.pumpWidget(
      _harness(location: location, youngPersonId: 'yp-9', displayName: 'Amina'),
    );
    await tester.pumpAndSettle();
    expect(repo.lastYoungId, 'yp-9');
    expect(repo.lastPeriod, TripPeriod.today);

    await tester.tap(find.byKey(const Key('history-chip-yesterday')));
    await tester.pumpAndSettle();
    expect(repo.lastPeriod, TripPeriod.yesterday);

    await tester.tap(find.byKey(const Key('history-chip-last_7_days')));
    await tester.pumpAndSettle();
    expect(repo.lastPeriod, TripPeriod.last7Days);
  });

  testWidgets('history 403 shows permission message not empty list', (tester) async {
    final location = LocationController(_ForbiddenTrips());
    await tester.pumpWidget(
      _harness(location: location, youngPersonId: 'yp-x', displayName: 'Paul'),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('history-forbidden')), findsOneWidget);
    expect(find.textContaining('autorisé'), findsOneWidget);
    expect(find.byKey(const Key('history-trip-list')), findsNothing);
    expect(find.text('Vitesse max'), findsNothing);
  });

  test('controller loadMyTrips stores period and trips', () async {
    final repo = _TripsRepo();
    final location = LocationController(repo);
    final ok = await location.loadMyTrips(period: TripPeriod.last7Days);
    expect(ok, isTrue);
    expect(location.tripPeriod, TripPeriod.last7Days);
    expect(location.tripHistory?.tripCount, 1);
    expect(location.tripHistory?.trips.single.distanceMeters, 2400);
    expect(location.errorMessage, isNull);
  });

  testWidgets('opening a trip shows existing map without driving stats', (tester) async {
    final location = LocationController(_TripsRepo());
    await tester.pumpWidget(_harness(location: location, displayName: 'Amina'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('history-trip-loc-a:loc-c')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Trajet'), findsWidgets);
    expect(find.textContaining('pas un rapport de conduite'), findsWidgets);
    expect(find.text('Vitesse max'), findsNothing);
    expect(find.text('Distrait'), findsNothing);
  });
}
