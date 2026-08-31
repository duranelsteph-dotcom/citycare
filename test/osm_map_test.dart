import 'package:citycare/presentation/location/location_controller.dart';
import 'package:citycare/presentation/location/location_map.dart';
import 'package:citycare/presentation/location/maps/osm_tiles.dart';
import 'package:citycare/core/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart';

void main() {
  test('User-Agent OSM identifie CityCare, pas flutter_map', () {
    expect(kCityCareOsmUserAgent, contains('CityCare'));
    expect(kCityCareOsmUserAgent, isNot(contains('flutter_map')));
    final headers = cityCareOsmHeaders();
    expect(headers['User-Agent'], kCityCareOsmUserAgent);
    expect(cityCareOsmHeaders()['User-Agent'], isNot(contains('flutter_map')));
  });

  test('en dev HTTP les tuiles passent par le proxy backend', () {
    ApiConfig.currentOverride = 'http://127.0.0.1:8000/api/v1';
    addTearDown(ApiConfig.resetForTests);
    expect(cityCareUsesBackendTileProxy, isTrue);
    expect(
      cityCarePrimaryTileUrl(),
      'http://127.0.0.1:8000/api/v1/map/tiles/{z}/{x}/{y}.png',
    );
    expect(cityCareFallbackTileUrl(), kOsmTileUrl);
  });

  test('sans GPS ni pastille : centre Yaoundé, pas un point inventé', () {
    const model = MapViewModel();
    expect(model.hasPoint, isFalse);
    expect(model.center, kDefaultMapCenter);
    expect(model.center.latitude, closeTo(3.8480, 0.001));
    expect(model.center.longitude, closeTo(11.5021, 0.001));
  });

  test('pastille connue primer sur Yaoundé', () {
    const model = MapViewModel(
      pins: [MapPin(latitude: 4.05, longitude: 9.70, isStale: true)],
    );
    expect(model.center.latitude, closeTo(4.05, 0.001));
    expect(model.hasPoint, isFalse);
  });

  test('404 API : lastKnown survit, pas un GPS live', () {
    final locations = LocationController(FakeLocationRepository());
    locations.lastKnownLatitude = 3.87;
    locations.lastKnownLongitude = 11.51;
    locations.latest = null;
    expect(locations.mapLatitude, 3.87);
    expect(locations.mapLongitude, 11.51);
    expect(locations.mapUsesLastKnownOnly, isTrue);
    expect(locations.mapPointIsStale, isTrue);
  });

  testWidgets('sans position : bandeau Yaoundé, pas un écran vide', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MapFallbackCenterBanner(usingLastKnown: false),
        ),
      ),
    );
    expect(find.byKey(const Key('map-fallback-center')), findsOneWidget);
    expect(find.textContaining('Yaoundé'), findsOneWidget);
    expect(find.textContaining('temps réel'), findsNothing);
    expect(find.textContaining('suivi en direct'), findsOneWidget);
  });

  testWidgets('tuiles KO : message + Réessayer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapTilesUnavailableBanner(onRetry: () {}),
        ),
      ),
    );
    expect(find.byKey(const Key('map-tiles-unavailable')), findsOneWidget);
    expect(find.byKey(const Key('map-tiles-retry')), findsOneWidget);
    expect(find.textContaining('OpenStreetMap'), findsOneWidget);
  });
}
