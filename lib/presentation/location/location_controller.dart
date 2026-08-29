import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/errors/api_exception.dart';
import '../../data/datasources/device_location_service.dart';
import '../../data/datasources/offline_queue.dart';
import '../../domain/entities/emergency.dart';
import '../../domain/entities/location_access.dart';
import '../../domain/entities/search.dart';
import '../../domain/entities/tracking.dart';
import '../../domain/enums/citycare_enums.dart';
import '../../domain/repositories/location_repository.dart';

class LocationController extends ChangeNotifier {
  LocationController(
    this._repository, {
    DeviceLocationService? device,
    OfflineQueue? queue,
    this.persist,
  })  : _device = device ?? DeviceLocationService(),
        queue = queue ?? OfflineQueue();

  final LocationRepository _repository;
  final DeviceLocationService _device;
  final OfflineQueue queue;
  final Future<void> Function(OfflineQueue queue)? persist;

  Future<void> _persist() async {
    await persist?.call(queue);
  }

  TrackerLocation? latest;
  List<TrackerLocation> history = [];
  Trajectory? trajectory;
  List<PositionShare> shares = [];
  List<PositionShare> receivedShares = [];
  Position? unsyncedFix;
  bool isBusy = false;
  String? errorMessage;
  int pollAfterSeconds = 60;
  TrackingMode effectiveMode = TrackingMode.normal;
  String access = 'SELF';
  String watchMessage = '';
  EmergencySnapshot? emergency;

  /// Dernier état connu de l'autorisation de localisation.
  /// `null` tant qu'aucune vérification n'a été faite.
  LocationAccess? locationAccess;

  /// Vraie pendant l'affichage de la boîte de dialogue système.
  bool isRequestingLocationAccess = false;

  /// Lit l'état d'accès sans afficher de demande système.
  Future<LocationAccess> refreshLocationAccess() async {
    final access = await _device.checkAccess();
    locationAccess = access;
    notifyListeners();
    return access;
  }

  /// Demande l'autorisation à l'utilisateur, puis met à jour l'état affiché.
  Future<LocationAccess> requestLocationAccess() async {
    isRequestingLocationAccess = true;
    notifyListeners();
    try {
      final access = await _device.requestAccess();
      locationAccess = access;
      return access;
    } finally {
      isRequestingLocationAccess = false;
      notifyListeners();
    }
  }

  /// Ouvre les réglages de localisation du système (GPS éteint).
  Future<void> openLocationSettings() async {
    await _device.openLocationSettings();
  }

  /// Ouvre les réglages de l'application (refus définitif).
  Future<void> openAppSettings() async {
    await _device.openAppSettings();
  }

  Future<void> loadMine() => watchMine(busy: true);

  Future<void> loadChild(String youngPersonId) => watchChild(youngPersonId, busy: true);

  Future<void> watchMine({bool busy = true}) {
    return _run(() async {
      final watch = await _repository.watchMine();
      _applyWatch(watch);
      history = await _repository.myHistory();
      try {
        trajectory = await _repository.myTrajectory();
      } on ApiException {
        trajectory = null;
      }
    }, busy: busy);
  }

  Future<void> watchChild(String youngPersonId, {bool busy = true}) {
    return _run(() async {
      final watch = await _repository.watchChild(youngPersonId);
      _applyWatch(watch);
      try {
        history = await _repository.childHistory(youngPersonId);
      } on ApiException catch (error) {
        if (error.statusCode == 404) {
          history = [];
        } else {
          rethrow;
        }
      }
      try {
        trajectory = await _repository.childTrajectory(youngPersonId);
      } on ApiException catch (error) {
        if (error.statusCode == 403 || error.statusCode == 404) {
          trajectory = null;
        } else {
          rethrow;
        }
      }
    }, busy: busy);
  }

  void _applyWatch(LocationWatch watch) {
    latest = watch.latest;
    pollAfterSeconds = watch.pollAfterSeconds;
    effectiveMode = watch.effectiveMode;
    access = watch.access;
    watchMessage = watch.message;
  }

  Future<bool> captureAndPublish() async {
    return _run(() async {
      final fix = await _device.currentFix();
      unsyncedFix = fix;
      final payload = <String, dynamic>{
        'latitude': fix.latitude,
        'longitude': fix.longitude,
        'accuracy': fix.accuracy,
        'altitude': fix.altitude,
        'speed': (fix.speed.isNaN || fix.speed < 0) ? null : fix.speed,
        'heading': (fix.heading.isNaN || fix.heading < 0) ? null : fix.heading,
        'recorded_at': fix.timestamp.toUtc().toIso8601String(),
      };
      try {
        latest = await _repository.publishPhoneFix(
          latitude: fix.latitude,
          longitude: fix.longitude,
          accuracy: fix.accuracy,
          altitude: fix.altitude,
          speed: (fix.speed.isNaN || fix.speed < 0) ? null : fix.speed,
          heading: (fix.heading.isNaN || fix.heading < 0) ? null : fix.heading,
          recordedAt: fix.timestamp,
        );
        unsyncedFix = null;
      } on ApiException catch (error) {
        if (error.isOffline) {
          queue.enqueueLocation(payload);
          await _persist();
          errorMessage =
              'Position enregistrée sur l’appareil. Synchronisation plus tard. '
              'L’heure du téléphone est conservée — pas Last Write Wins, pas la position actuelle.';
          return;
        }
        rethrow;
      }
      history = await _repository.myHistory();
      try {
        trajectory = await _repository.myTrajectory();
      } on ApiException {
        trajectory = null;
      }
    });
  }

  Future<int> flushPending() async {
    var sent = 0;
    final leftover = <Map<String, dynamic>>[];
    for (final item in [...queue.locations]) {
      try {
        await _repository.publishPhoneFix(
          latitude: (item['latitude'] as num).toDouble(),
          longitude: (item['longitude'] as num).toDouble(),
          accuracy: (item['accuracy'] as num?)?.toDouble(),
          altitude: (item['altitude'] as num?)?.toDouble(),
          speed: (item['speed'] as num?)?.toDouble(),
          heading: (item['heading'] as num?)?.toDouble(),
          recordedAt: item['recorded_at'] == null ? null : DateTime.parse(item['recorded_at'] as String),
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
    await _persist();
    notifyListeners();
    return sent;
  }

  Future<bool> loadEmergency(String youngPersonId) {
    return _run(() async {
      emergency = await _repository.emergency(youngPersonId);
    });
  }

  Future<bool> loadMyShares() {
    return _run(() async {
      shares = await _repository.myShares();
    });
  }

  Future<bool> loadReceivedShares() {
    return _run(() async {
      receivedShares = await _repository.receivedShares();
    });
  }

  PositionShare? receivedShareFor(String youngPersonId) {
    for (final share in receivedShares) {
      if (share.youngPersonId == youngPersonId && share.isActive) {
        return share;
      }
    }
    return null;
  }

  Future<bool> shareWith({required String targetUserId, int durationMinutes = 60}) {
    return _run(() async {
      await _repository.createShare(targetUserId: targetUserId, durationMinutes: durationMinutes);
      shares = await _repository.myShares();
    });
  }

  Future<bool> revokeShare(String shareId) {
    return _run(() async {
      await _repository.revokeShare(shareId);
      shares = await _repository.myShares();
    });
  }

  Future<bool> _run(Future<void> Function() action, {bool busy = true}) async {
    if (busy) {
      isBusy = true;
    }
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on DeviceLocationException catch (error) {
      errorMessage = error.message;
      // On mémorise la cause exacte pour que l'écran propose la bonne action
      // (redemander l'autorisation, ouvrir les réglages…) au lieu d'un simple
      // message d'échec.
      locationAccess = error.access ?? locationAccess;
      return false;
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        latest = null;
        return true;
      }
      errorMessage = error.message;
      return false;
    } catch (_) {
      errorMessage = 'Position indisponible pour le moment.';
      return false;
    } finally {
      if (busy) {
        isBusy = false;
      }
      notifyListeners();
    }
  }
}
