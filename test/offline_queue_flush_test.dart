import 'package:citycare/data/datasources/offline_queue.dart';
import 'package:citycare/data/datasources/offline_queue_flush.dart';
import 'package:citycare/data/datasources/token_store.dart';
import 'package:citycare/domain/entities/alerts.dart';
import 'package:citycare/domain/entities/tracking.dart';
import 'package:citycare/domain/enums/citycare_enums.dart';
import 'package:citycare/domain/repositories/alert_repository.dart';
import 'package:citycare/presentation/location/location_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart';

class _RecordingLocations extends FakeLocationRepository {
  final published = <Map<String, dynamic>>[];

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
      isStale: false,
      ageSeconds: 0,
    );
  }
}

class _RecordingAlerts extends FakeAlertRepository {
  final drafts = <SosDraft>[];

  @override
  Future<Alert> triggerSos(SosDraft draft) async {
    drafts.add(draft);
    final at = draft.recordedAt ?? DateTime.utc(2026, 8, 30);
    return Alert(
      id: 'sos-${drafts.length}',
      youngPersonId: draft.youngPersonId ?? 'yp-1',
      source: draft.source ?? AlertSource.mobile,
      status: AlertStatus.active,
      severity: AlertSeverity.critical,
      triggeredAt: at,
      createdAt: at,
      updatedAt: at,
    );
  }
}

class _CountingStore {
  int saves = 0;

  Future<void> save(OfflineQueue queue) async {
    saves += 1;
  }
}

OfflineQueue _queuedLocation() {
  final queue = OfflineQueue();
  queue.enqueueLocation({
    'latitude': 3.848,
    'longitude': 11.502,
    'recorded_at': '2026-08-30T07:00:00.000Z',
  });
  return queue;
}

void main() {
  test('callback no-op si queue vide', () async {
    final tokens = MemoryTokenStore();
    await tokens.save('tok');
    final locations = _RecordingLocations();
    final alerts = _RecordingAlerts();
    final store = _CountingStore();
    final result = await OfflineQueueFlusher(
      tokens: tokens,
      locations: locations,
      alerts: alerts,
      persist: store.save,
    ).flushIfReady(OfflineQueue());

    expect(result.isNoOp, isTrue);
    expect(result.skip, OfflineFlushSkip.emptyQueue);
    expect(locations.published, isEmpty);
    expect(alerts.drafts, isEmpty);
    expect(store.saves, 0);
  });

  test('callback no-op si pas de token', () async {
    final locations = _RecordingLocations();
    final alerts = _RecordingAlerts();
    final store = _CountingStore();
    final queue = _queuedLocation();
    queue.enqueueSos({'description': 'SOS local', 'recorded_at': '2026-08-30T07:02:00.000Z'});
    final result = await OfflineQueueFlusher(
      tokens: MemoryTokenStore(),
      locations: locations,
      alerts: alerts,
      persist: store.save,
    ).flushIfReady(queue);

    expect(result.isNoOp, isTrue);
    expect(result.skip, OfflineFlushSkip.noToken);
    expect(locations.published, isEmpty);
    expect(alerts.drafts, isEmpty);
    expect(store.saves, 0);
    expect(queue.pendingCount, 2);
  });

  test('callback no-op si jeton vide', () async {
    final tokens = MemoryTokenStore();
    await tokens.save('');
    final locations = _RecordingLocations();
    final result = await OfflineQueueFlusher(
      tokens: tokens,
      locations: locations,
      alerts: _RecordingAlerts(),
    ).flushIfReady(_queuedLocation());

    expect(result.skip, OfflineFlushSkip.noToken);
    expect(locations.published, isEmpty);
  });

  test('flush envoie les items déjà en file, horodatage conservé', () async {
    final tokens = MemoryTokenStore();
    await tokens.save('tok');
    final locations = _RecordingLocations();
    final alerts = _RecordingAlerts();
    final store = _CountingStore();
    final queue = _queuedLocation();
    queue.enqueueSos({
      'description': 'SOS local',
      'recorded_at': '2026-08-30T07:02:00.000Z',
    });

    final result = await OfflineQueueFlusher(
      tokens: tokens,
      locations: locations,
      alerts: alerts,
      persist: store.save,
    ).flushIfReady(queue);

    expect(result.isNoOp, isFalse);
    expect(result.locationsSent, 1);
    expect(result.sosSent, 1);
    expect(locations.published.single['recorded_at'], '2026-08-30T07:00:00.000Z');
    expect(alerts.drafts.single.description, 'SOS local');
    expect(queue.hasPending, isFalse);
    expect(store.saves, 1);
  });

  test('flush renvoie battery_level déjà en file, n’invente pas 100 %', () async {
    final tokens = MemoryTokenStore();
    await tokens.save('tok');
    final locations = _RecordingLocations();
    final queue = OfflineQueue();
    queue.enqueueLocation({
      'latitude': 3.848,
      'longitude': 11.502,
      'recorded_at': '2026-08-30T07:00:00.000Z',
      'battery_level': 72,
    });
    queue.enqueueLocation({
      'latitude': 3.849,
      'longitude': 11.503,
      'recorded_at': '2026-08-30T07:01:00.000Z',
    });

    final result = await OfflineQueueFlusher(
      tokens: tokens,
      locations: locations,
      alerts: _RecordingAlerts(),
    ).flushIfReady(queue);

    expect(result.locationsSent, 2);
    expect(locations.published.first['battery_level'], 72);
    expect(locations.published.last.containsKey('battery_level'), isFalse);
  });

  test('file non vide : pas un statut synchronisé', () {
    final controller = LocationController(FakeLocationRepository(), queue: _queuedLocation());
    expect(controller.hasPendingOffline, isTrue);
    expect(controller.hasUnsyncedLocations, isTrue);
    expect(controller.unsyncedFix, isNull);
  });
}
