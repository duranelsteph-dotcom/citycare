import 'dart:async';

import 'package:citycare/core/errors/api_exception.dart';
import 'package:citycare/data/datasources/background_share_store.dart';
import 'package:citycare/data/datasources/device_battery_service.dart';
import 'package:citycare/data/datasources/device_location_service.dart';
import 'package:citycare/data/datasources/offline_queue.dart';
import 'package:citycare/data/datasources/offline_queue_flush.dart';
import 'package:citycare/domain/entities/location_access.dart';
import 'package:citycare/domain/entities/tracking.dart';
import 'package:citycare/domain/enums/citycare_enums.dart';
import 'package:citycare/presentation/location/location_controller.dart';
import 'package:citycare/presentation/map/member_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'widget_test.dart';

Position _fix({DateTime? recordedAt}) {
  return Position(
    latitude: 3.848,
    longitude: 11.502,
    timestamp: recordedAt ?? DateTime.utc(2026, 8, 30, 12, 0, 0),
    accuracy: 14,
    altitude: 750,
    altitudeAccuracy: 1,
    heading: 40,
    headingAccuracy: 1,
    speed: 0.8,
    speedAccuracy: 0.2,
  );
}

class _FixedBattery extends DeviceBatteryService {
  _FixedBattery(this.level);

  final int? level;

  @override
  Future<int?> currentLevel() async => sanitizeBatteryLevel(level);
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
      'recorded_at': recordedAt?.toUtc().toIso8601String(),
      if (batteryLevel != null) 'battery_level': batteryLevel,
    });
    return TrackerLocation(
      id: 'loc-${published.length}',
      youngPersonId: 'yp-1',
      source: LocationSource.phone,
      latitude: latitude,
      longitude: longitude,
      recordedAt: recordedAt ?? DateTime.utc(2026, 8, 30),
      batteryLevel: batteryLevel,
      isStale: false,
      ageSeconds: 0,
    );
  }
}

class _ScriptedDevice extends DeviceLocationService {
  _ScriptedDevice();

  final controller = StreamController<Position>.broadcast();

  @override
  Future<LocationAccess> requestBackgroundAccess() async {
    return const LocationAccess(LocationAccessStatus.granted, isAlways: true);
  }

  @override
  Stream<Position> watchPositions() => controller.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('payload : batterie présente seulement si lue', () {
    final without = phoneFixPayload(_fix());
    expect(without.containsKey('battery_level'), isFalse);

    final withLevel = phoneFixPayload(_fix(), batteryLevel: 72);
    expect(withLevel['battery_level'], 72);
    expect(withLevel['latitude'], 3.848);
    expect(withLevel['recorded_at'], '2026-08-30T12:00:00.000Z');
  });

  test('sanitize : hors plage ou null → omis, jamais 100 inventé', () {
    expect(sanitizeBatteryLevel(null), isNull);
    expect(sanitizeBatteryLevel(-1), isNull);
    expect(sanitizeBatteryLevel(101), isNull);
    expect(sanitizeBatteryLevel(0), 0);
    expect(sanitizeBatteryLevel(100), 100);
    expect(sanitizeBatteryLevel(72), 72);
  });

  test('libellés : téléphone ≠ kit, rien si lecture absente', () {
    final phone = TrackerLocation(
      id: 'p',
      youngPersonId: 'yp-1',
      source: LocationSource.phone,
      latitude: 3.8,
      longitude: 11.5,
      recordedAt: DateTime.utc(2026, 8, 30),
      batteryLevel: 72,
    );
    expect(phoneBatteryLabel(phone), 'Batterie : 72 %');
    expect(kitBatteryLabel(phone), isNull);
    expect(memberBatteryLabel(phone), 'Batterie : 72 %');

    final kit = TrackerLocation(
      id: 'k',
      youngPersonId: 'yp-1',
      source: LocationSource.iot,
      latitude: 3.8,
      longitude: 11.5,
      recordedAt: DateTime.utc(2026, 8, 30),
      batteryLevel: 41,
    );
    expect(kitBatteryLabel(kit), 'Batterie kit : 41 %');
    expect(phoneBatteryLabel(kit), isNull);
    expect(memberBatteryLabel(kit), 'Batterie kit : 41 %');

    final unknown = TrackerLocation(
      id: 'u',
      youngPersonId: 'yp-1',
      source: LocationSource.phone,
      latitude: 3.8,
      longitude: 11.5,
      recordedAt: DateTime.utc(2026, 8, 30),
    );
    expect(phoneBatteryLabel(unknown), isNull);
    expect(memberBatteryLabel(unknown), isNull);
  });

  test('flux arrière-plan : 72 % joint au point', () async {
    final repo = _RecordingLocations();
    final device = _ScriptedDevice();
    final controller = LocationController(
      repo,
      device: device,
      battery: _FixedBattery(72),
      backgroundStore: MemoryBackgroundShareStore(),
    );

    expect(await controller.setBackgroundSharing(true), isTrue);
    device.controller.add(_fix());
    await pumpEventQueue();

    expect(repo.published, hasLength(1));
    expect(repo.published.single['battery_level'], 72);
    expect(controller.latest?.batteryLevel, 72);
    await device.controller.close();
    controller.dispose();
  });

  test('flux arrière-plan : lecture nulle → champ omis, pas 100 %', () async {
    final repo = _RecordingLocations();
    final device = _ScriptedDevice();
    final controller = LocationController(
      repo,
      device: device,
      battery: _FixedBattery(null),
      backgroundStore: MemoryBackgroundShareStore(),
    );

    await controller.setBackgroundSharing(true);
    device.controller.add(_fix());
    await pumpEventQueue();

    expect(repo.published.single.containsKey('battery_level'), isFalse);
    expect(controller.latest?.batteryLevel, isNull);
    await device.controller.close();
    controller.dispose();
  });

  test('hors ligne : file conserve battery_level, flush le renvoie', () async {
    final repo = _RecordingLocations()..offline = true;
    final device = _ScriptedDevice();
    final controller = LocationController(
      repo,
      device: device,
      battery: _FixedBattery(64),
      backgroundStore: MemoryBackgroundShareStore(),
    );

    await controller.setBackgroundSharing(true);
    device.controller.add(_fix(recordedAt: DateTime.utc(2026, 8, 30, 7, 0, 0)));
    await pumpEventQueue();

    expect(controller.queue.locations.single['battery_level'], 64);
    expect(controller.queue.locations.single['recorded_at'], '2026-08-30T07:00:00.000Z');

    repo.offline = false;
    final sent = await flushQueuedLocations(queue: controller.queue, locations: repo);
    expect(sent, 1);
    expect(repo.published.single['battery_level'], 64);
    await device.controller.close();
    controller.dispose();
  });

  test('file sans batterie : flush n’invente pas 100 %', () async {
    final queue = OfflineQueue();
    queue.enqueueLocation({
      'latitude': 3.848,
      'longitude': 11.502,
      'recorded_at': '2026-08-30T07:00:00.000Z',
    });
    final repo = _RecordingLocations();
    final sent = await flushQueuedLocations(queue: queue, locations: repo);
    expect(sent, 1);
    expect(repo.published.single.containsKey('battery_level'), isFalse);
  });
}
