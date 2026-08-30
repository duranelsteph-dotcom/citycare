import 'dart:async';

import 'package:citycare/core/errors/api_exception.dart';
import 'package:citycare/data/datasources/background_share_store.dart';
import 'package:citycare/data/datasources/device_location_service.dart';
import 'package:citycare/domain/entities/background_share.dart';
import 'package:citycare/domain/entities/location_access.dart';
import 'package:citycare/domain/entities/tracking.dart';
import 'package:citycare/domain/enums/citycare_enums.dart';
import 'package:citycare/presentation/location/background_share_tile.dart';
import 'package:citycare/presentation/location/location_controller.dart';
import 'package:citycare/presentation/location/location_scope.dart';
import 'package:citycare/presentation/map/freshness.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'widget_test.dart';

Position _fix({
  double latitude = 3.848,
  double longitude = 11.502,
  DateTime? recordedAt,
  double speed = 1.2,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: recordedAt ?? DateTime.utc(2026, 8, 30, 11, 4, 12),
    accuracy: 18,
    altitude: 750,
    altitudeAccuracy: 1,
    heading: 90,
    headingAccuracy: 1,
    speed: speed,
    speedAccuracy: 0.5,
  );
}

class _RecordingLocations extends FakeLocationRepository {
  final published = <Map<String, dynamic>>[];
  bool offline = false;

  @override
  Future<TrackerLocation> publishPhoneFix({
    required double latitude,
    required double longitude,
    double? accuracy,
    double? altitude,
    double? speed,
    double? heading,
    DateTime? recordedAt,
    int? batteryLevel,
  }) async {
    if (offline) {
      throw const ApiException('Hors ligne', statusCode: 0);
    }
    published.add({
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'recorded_at': recordedAt?.toUtc().toIso8601String(),
      if (batteryLevel != null) 'battery_level': batteryLevel,
    });
    return TrackerLocation(
      id: 'loc-${published.length}',
      youngPersonId: 'yp-1',
      source: LocationSource.phone,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      recordedAt: recordedAt ?? DateTime.utc(2026, 8, 30),
      isStale: false,
      ageSeconds: 0,
    );
  }
}

class _ScriptedBackgroundDevice extends DeviceLocationService {
  _ScriptedBackgroundDevice(this.access);

  LocationAccess access;
  final controller = StreamController<Position>.broadcast();
  int backgroundRequests = 0;
  int streamStarts = 0;

  @override
  Future<LocationAccess> checkAccess() async => access;

  @override
  Future<LocationAccess> requestAccess() async => access;

  @override
  Future<LocationAccess> requestBackgroundAccess() async {
    backgroundRequests += 1;
    return access;
  }

  @override
  Stream<Position> watchPositions() {
    streamStarts += 1;
    return controller.stream;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('distanceFilter reste 30–50 m, pas 1 Hz', () {
    expect(kBackgroundDistanceFilterMeters, inInclusiveRange(30, 50));
    expect(kBackgroundAndroidInterval.inSeconds, greaterThanOrEqualTo(30));

    final android = backgroundLocationSettings(platform: TargetPlatform.android);
    expect(android.distanceFilter, kBackgroundDistanceFilterMeters);
    expect(android, isA<AndroidSettings>());
    final androidSettings = android as AndroidSettings;
    expect(androidSettings.intervalDuration, kBackgroundAndroidInterval);
    expect(androidSettings.foregroundNotificationConfig, isNotNull);
    expect(
      androidSettings.foregroundNotificationConfig!.notificationText,
      kBackgroundNotificationText,
    );

    final ios = backgroundLocationSettings(platform: TargetPlatform.iOS);
    expect(ios.distanceFilter, kBackgroundDistanceFilterMeters);
    expect(ios, isA<AppleSettings>());
    expect((ios as AppleSettings).allowBackgroundLocationUpdates, isTrue);
  });

  test('opt-in : états actif / refusé / GPS off / toujours manquant', () {
    const always = LocationAccess(LocationAccessStatus.granted, isAlways: true);
    const whileInUse = LocationAccess(LocationAccessStatus.granted);
    const denied = LocationAccess(LocationAccessStatus.denied);
    const gpsOff = LocationAccess(LocationAccessStatus.serviceDisabled);

    expect(BackgroundSharePolicy.canStart(always), isTrue);
    expect(BackgroundSharePolicy.canStart(whileInUse), isFalse);
    expect(BackgroundSharePolicy.canStart(denied), isFalse);

    expect(
      BackgroundSharePolicy.resolve(optIn: false, access: always, streamActive: true),
      BackgroundShareStatus.off,
    );
    expect(
      BackgroundSharePolicy.resolve(optIn: true, access: always, streamActive: true),
      BackgroundShareStatus.active,
    );
    expect(
      BackgroundSharePolicy.resolve(optIn: true, access: denied, streamActive: false),
      BackgroundShareStatus.denied,
    );
    expect(
      BackgroundSharePolicy.resolve(optIn: true, access: gpsOff, streamActive: false),
      BackgroundShareStatus.gpsOff,
    );
    expect(
      BackgroundSharePolicy.resolve(optIn: true, access: whileInUse, streamActive: false),
      BackgroundShareStatus.needsAlways,
    );

    for (final status in BackgroundShareStatus.values) {
      final label = BackgroundSharePolicy.statusLabel(status);
      expect(label.toLowerCase(), isNot(contains('en direct')));
      expect(label.toLowerCase(), isNot(contains('temps réel')));
    }
  });

  test('payload conserve l’horodatage GPS', () {
    final at = DateTime.utc(2026, 8, 30, 9, 15, 44);
    final payload = phoneFixPayload(_fix(recordedAt: at, speed: -1));
    expect(payload['latitude'], 3.848);
    expect(payload['longitude'], 11.502);
    expect(payload['recorded_at'], '2026-08-30T09:15:44.000Z');
    expect(payload['speed'], isNull);
    expect(payload['heading'], 90);
    expect(payload.containsKey('battery_level'), isFalse);
  });

  test('store mémoire persiste l’opt-in', () async {
    final store = MemoryBackgroundShareStore();
    expect(await store.readOptIn(), isFalse);
    await store.writeOptIn(true);
    expect(await store.readOptIn(), isTrue);
  });

  test('flux réel : opt-in + toujours envoie les points via le dépôt', () async {
    final repo = _RecordingLocations();
    final device = _ScriptedBackgroundDevice(
      const LocationAccess(LocationAccessStatus.granted, isAlways: true),
    );
    final store = MemoryBackgroundShareStore();
    final controller = LocationController(
      repo,
      device: device,
      backgroundStore: store,
    );

    expect(await controller.setBackgroundSharing(true), isTrue);
    expect(controller.backgroundOptIn, isTrue);
    expect(store.optIn, isTrue);
    expect(controller.backgroundStatus, BackgroundShareStatus.active);
    expect(controller.isBackgroundStreamActive, isTrue);
    expect(device.streamStarts, 1);

    device.controller.add(_fix());
    await pumpEventQueue();

    expect(repo.published, hasLength(1));
    expect(repo.published.first['recorded_at'], '2026-08-30T11:04:12.000Z');
    expect(controller.latest?.latitude, 3.848);

    await controller.setBackgroundSharing(false);
    expect(controller.backgroundOptIn, isFalse);
    expect(controller.isBackgroundStreamActive, isFalse);
    expect(controller.backgroundStatus, BackgroundShareStatus.off);
    await device.controller.close();
    controller.dispose();
  });

  test('opt-in + GPS off n’ouvre pas le flux', () async {
    final device = _ScriptedBackgroundDevice(
      const LocationAccess(LocationAccessStatus.serviceDisabled),
    );
    final controller = LocationController(
      _RecordingLocations(),
      device: device,
      backgroundStore: MemoryBackgroundShareStore(),
    );

    expect(await controller.setBackgroundSharing(true), isFalse);
    expect(controller.backgroundOptIn, isTrue);
    expect(controller.backgroundStatus, BackgroundShareStatus.gpsOff);
    expect(device.streamStarts, 0);
    controller.dispose();
  });

  test('opt-in + permission refusée n’ouvre pas le flux', () async {
    final device = _ScriptedBackgroundDevice(
      const LocationAccess(LocationAccessStatus.denied),
    );
    final controller = LocationController(
      _RecordingLocations(),
      device: device,
      backgroundStore: MemoryBackgroundShareStore(),
    );

    expect(await controller.setBackgroundSharing(true), isFalse);
    expect(controller.backgroundStatus, BackgroundShareStatus.denied);
    expect(device.streamStarts, 0);
    controller.dispose();
  });

  test('restauration : opt-in persisté relance le flux', () async {
    final device = _ScriptedBackgroundDevice(
      const LocationAccess(LocationAccessStatus.granted, isAlways: true),
    );
    final controller = LocationController(
      _RecordingLocations(),
      device: device,
      backgroundStore: MemoryBackgroundShareStore(optIn: true),
    );

    await controller.restoreBackgroundSharing();
    expect(controller.backgroundOptIn, isTrue);
    expect(controller.backgroundStatus, BackgroundShareStatus.active);
    expect(device.streamStarts, 1);
    controller.dispose();
  });

  test('hors ligne : le point va dans la file, horodatage conservé', () async {
    final repo = _RecordingLocations()..offline = true;
    final device = _ScriptedBackgroundDevice(
      const LocationAccess(LocationAccessStatus.granted, isAlways: true),
    );
    final controller = LocationController(
      repo,
      device: device,
      backgroundStore: MemoryBackgroundShareStore(),
    );

    await controller.setBackgroundSharing(true);
    device.controller.add(_fix(recordedAt: DateTime.utc(2026, 8, 29, 22, 1, 5)));
    await pumpEventQueue();

    expect(controller.queue.locations, hasLength(1));
    expect(controller.queue.locations.first['recorded_at'], '2026-08-29T22:01:05.000Z');
    expect(repo.published, isEmpty);
    await device.controller.close();
    controller.dispose();
  });

  test('fraîcheur stale n’affiche jamais en direct', () {
    expect(
      locationFreshnessLabel(isStale: true, ageSeconds: 600).toLowerCase(),
      isNot(contains('en direct')),
    );
    expect(
      locationFreshnessLabel(isStale: false, ageSeconds: 12).toLowerCase(),
      isNot(contains('en direct')),
    );
  });

  testWidgets('interrupteur affiche les états sans un suivi en direct', (tester) async {
    final controller = LocationController(
      _RecordingLocations(),
      device: _ScriptedBackgroundDevice(
        const LocationAccess(LocationAccessStatus.granted, isAlways: true),
      ),
      backgroundStore: MemoryBackgroundShareStore(),
    );
    await tester.pumpWidget(
      LocationScope(
        controller: controller,
        child: MaterialApp(
          theme: cityCareTestTheme(),
          home: const Scaffold(body: BackgroundShareTile()),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('background-share-switch')), findsOneWidget);
    expect(find.text('Partage en arrière-plan'), findsOneWidget);
    expect(find.textContaining('en direct'), findsNothing);
    expect(find.textContaining('Inactif'), findsOneWidget);

    await tester.tap(find.byKey(const Key('background-share-switch')));
    await tester.pumpAndSettle();

    expect(controller.backgroundOptIn, isTrue);
    expect(find.textContaining('Actif'), findsOneWidget);
    expect(find.textContaining('en direct'), findsNothing);
    controller.dispose();
  });
}
