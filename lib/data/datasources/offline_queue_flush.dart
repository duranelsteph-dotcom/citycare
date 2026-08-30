import 'dart:ui';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/config/api_config.dart';
import '../../core/errors/api_exception.dart';
import '../../domain/entities/alerts.dart';
import '../../domain/enums/citycare_enums.dart';
import '../../domain/repositories/alert_repository.dart';
import '../../domain/repositories/location_repository.dart';
import '../repositories/alert_repository_impl.dart';
import '../repositories/location_repository_impl.dart';
import 'alert_remote.dart';
import 'location_remote.dart';
import 'offline_queue.dart';
import 'offline_queue_store.dart';
import 'secure_token_store.dart';
import 'token_store.dart';

/// Pourquoi le flush n’a rien envoyé (cas attendus, pas une erreur).
enum OfflineFlushSkip {
  /// File vide : aucun GPS inventé, aucun appel réseau.
  emptyQueue,

  /// Pas de jeton : on ne touche pas à la file.
  noToken,
}

/// Compteur d’envois + motif de no-op. Jamais de point GPS fabriqué.
class OfflineFlushResult {
  const OfflineFlushResult({
    this.locationsSent = 0,
    this.sosSent = 0,
    this.skip,
  });

  const OfflineFlushResult.emptyQueue() : this(skip: OfflineFlushSkip.emptyQueue);

  const OfflineFlushResult.noToken() : this(skip: OfflineFlushSkip.noToken);

  final int locationsSent;
  final int sosSent;
  final OfflineFlushSkip? skip;

  bool get isNoOp => skip != null;
}

/// Même boucle que [LocationController.flushPending] : items déjà en file seulement.
Future<int> flushQueuedLocations({
  required OfflineQueue queue,
  required LocationRepository locations,
}) async {
  var sent = 0;
  final leftover = <Map<String, dynamic>>[];
  for (final item in [...queue.locations]) {
    try {
      await locations.publishPhoneFix(
        latitude: (item['latitude'] as num).toDouble(),
        longitude: (item['longitude'] as num).toDouble(),
        accuracy: (item['accuracy'] as num?)?.toDouble(),
        altitude: (item['altitude'] as num?)?.toDouble(),
        speed: (item['speed'] as num?)?.toDouble(),
        heading: (item['heading'] as num?)?.toDouble(),
        recordedAt: item['recorded_at'] == null ? null : DateTime.parse(item['recorded_at'] as String),
        batteryLevel: item['battery_level'] as int?,
      );
      sent += 1;
    } on ApiException catch (error) {
      if (error.isOffline) {
        leftover.add(item);
      }
    }
  }
  queue.locations
    ..clear()
    ..addAll(leftover);
  return sent;
}

/// Même boucle que [AlertController.flushPending] : SOS déjà en file seulement.
Future<int> flushQueuedSos({
  required OfflineQueue queue,
  required AlertRepository alerts,
  void Function(Alert alert)? onSent,
}) async {
  var sent = 0;
  final leftover = <Map<String, dynamic>>[];
  for (final item in [...queue.sos]) {
    try {
      final alert = await alerts.triggerSos(
        SosDraft(
          latitude: (item['latitude'] as num?)?.toDouble(),
          longitude: (item['longitude'] as num?)?.toDouble(),
          accuracy: (item['accuracy'] as num?)?.toDouble(),
          recordedAt: item['recorded_at'] == null ? null : DateTime.parse(item['recorded_at'] as String),
          description: item['description'] as String?,
          youngPersonId: item['young_person_id'] as String?,
          source: item['source'] == null ? null : AlertSourceApi.parse(item['source'] as String),
        ),
      );
      onSent?.call(alert);
      sent += 1;
    } on ApiException catch (error) {
      if (error.isOffline) {
        leftover.add(item);
      }
    }
  }
  queue.sos
    ..clear()
    ..addAll(leftover);
  return sent;
}

/// Flush partagé : premier plan et isolate Workmanager.
///
/// No-op si la file est vide ou s’il n’y a pas de jeton.
/// N’invente aucun GPS : n’envoie que les payloads déjà en file.
class OfflineQueueFlusher {
  OfflineQueueFlusher({
    required this.tokens,
    required this.locations,
    required this.alerts,
    this.persist,
  });

  final TokenStore tokens;
  final LocationRepository locations;
  final AlertRepository alerts;
  final Future<void> Function(OfflineQueue queue)? persist;

  Future<OfflineFlushResult> flushIfReady(OfflineQueue queue) async {
    if (!queue.hasPending) {
      return const OfflineFlushResult.emptyQueue();
    }
    final token = await tokens.read();
    if (token == null || token.isEmpty) {
      return const OfflineFlushResult.noToken();
    }
    final locationsSent = await flushQueuedLocations(queue: queue, locations: locations);
    final sosSent = await flushQueuedSos(queue: queue, alerts: alerts);
    await persist?.call(queue);
    return OfflineFlushResult(locationsSent: locationsSent, sosSent: sosSent);
  }
}

FlutterSecureStorage _secureStorage() {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );
}

/// Isolate de fond : recharge OfflineQueue + LocationRemote, puis flushIfReady.
///
/// Aucun nouveau relevé GPS ici — uniquement la file déjà persistée.
Future<OfflineFlushResult> runBackgroundOfflineFlush({
  TokenStore? tokens,
  OfflineQueue? queue,
  OfflineQueueStore? store,
  LocationRepository? locations,
  AlertRepository? alerts,
}) async {
  DartPluginRegistrant.ensureInitialized();
  await ApiConfig.bootstrap();
  final storage = _secureStorage();
  final resolvedTokens = tokens ?? SecureTokenStore(storage: storage);
  final resolvedQueue = queue ?? OfflineQueue();
  final resolvedStore = store ?? OfflineQueueStore(storage: storage);
  if (queue == null) {
    await resolvedStore.loadInto(resolvedQueue);
  }
  final resolvedLocations = locations ??
      LocationRepositoryImpl(LocationRemoteDataSource(tokenStore: resolvedTokens));
  final resolvedAlerts = alerts ?? AlertRepositoryImpl(AlertRemoteDataSource(tokenStore: resolvedTokens));
  return OfflineQueueFlusher(
    tokens: resolvedTokens,
    locations: resolvedLocations,
    alerts: resolvedAlerts,
    persist: resolvedStore.save,
  ).flushIfReady(resolvedQueue);
}
