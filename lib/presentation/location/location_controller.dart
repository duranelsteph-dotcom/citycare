import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/errors/api_exception.dart';
import '../../data/datasources/background_share_store.dart';
import '../../data/datasources/device_battery_service.dart';
import '../../data/datasources/device_location_service.dart';
import '../../data/datasources/offline_queue.dart';
import '../../data/datasources/offline_queue_flush.dart';
import '../../domain/entities/background_share.dart';
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
    DeviceBatteryService? battery,
    OfflineQueue? queue,
    BackgroundShareStore? backgroundStore,
    this.persist,
  })  : _device = device ?? DeviceLocationService(),
        _battery = battery ?? DeviceBatteryService(),
        queue = queue ?? OfflineQueue(),
        _backgroundStore = backgroundStore ?? MemoryBackgroundShareStore();

  final LocationRepository _repository;
  final DeviceLocationService _device;
  final DeviceBatteryService _battery;
  final OfflineQueue queue;
  final BackgroundShareStore _backgroundStore;
  final Future<void> Function(OfflineQueue queue)? persist;

  StreamSubscription<Position>? _backgroundSub;
  bool _publishingBackgroundFix = false;
  Position? _pendingBackgroundFix;

  Future<void> _persist() async {
    await persist?.call(queue);
  }

  TrackerLocation? latest;
  List<TrackerLocation> history = [];
  Trajectory? trajectory;
  TripHistory? tripHistory;
  TripPeriod tripPeriod = TripPeriod.today;
  DateTime? tripFrom;
  DateTime? tripTo;
  List<PositionShare> shares = [];
  List<PositionShare> receivedShares = [];

  /// Dernières positions connues des jeunes liés, pour la carte famille.
  /// Une entrée absente signifie « pas d’accès » ou « aucune position ».
  final Map<String, TrackerLocation> familyLatest = {};
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

  /// Opt-in utilisateur « Partage en arrière-plan » (persisté, pas un secret).
  bool backgroundOptIn = false;

  /// État affiché (actif / permission / GPS). Jamais « en direct ».
  BackgroundShareStatus backgroundStatus = BackgroundShareStatus.off;

  bool get isBackgroundStreamActive => _backgroundSub != null;

  /// File encore à envoyer (positions + SOS). Ne pas afficher « synchronisé ».
  bool get hasPendingOffline => queue.hasPending;

  /// Point local ou file de positions : pas encore côté serveur.
  bool get hasUnsyncedLocations => unsyncedFix != null || queue.locations.isNotEmpty;

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

  /// Position ponctuelle, ou `null` si le GPS refuse / échoue (pas inventée).
  Future<Position?> tryCurrentFix() async {
    try {
      final fix = await _device.currentFix();
      unsyncedFix = fix;
      notifyListeners();
      return fix;
    } catch (_) {
      return null;
    }
  }

  /// Relit l’opt-in persisté et relance le flux si les permissions tiennent.
  Future<void> restoreBackgroundSharing() async {
    backgroundOptIn = await _backgroundStore.readOptIn();
    if (!backgroundOptIn) {
      backgroundStatus = BackgroundShareStatus.off;
      notifyListeners();
      return;
    }
    await _startBackgroundStream(persistOptIn: false);
  }

  /// Interrupteur profil : active ou coupe le flux GPS réel.
  Future<bool> setBackgroundSharing(bool enabled) async {
    if (!enabled) {
      await pauseBackgroundSharing(persistOptIn: true);
      return true;
    }
    return _startBackgroundStream(persistOptIn: true);
  }

  /// Coupe le flux (logout, GPS off). [persistOptIn] false garde le choix.
  Future<void> pauseBackgroundSharing({bool persistOptIn = false}) async {
    await _backgroundSub?.cancel();
    _backgroundSub = null;
    _pendingBackgroundFix = null;
    if (persistOptIn) {
      backgroundOptIn = false;
      await _backgroundStore.writeOptIn(false);
    }
    backgroundStatus = BackgroundSharePolicy.resolve(
      optIn: backgroundOptIn,
      access: locationAccess,
      streamActive: false,
    );
    notifyListeners();
  }

  Future<bool> _startBackgroundStream({required bool persistOptIn}) async {
    isRequestingLocationAccess = true;
    notifyListeners();
    try {
      if (persistOptIn) {
        backgroundOptIn = true;
        await _backgroundStore.writeOptIn(true);
      }
      final access = await _device.requestBackgroundAccess();
      locationAccess = access;
      if (!BackgroundSharePolicy.canStart(access)) {
        await _backgroundSub?.cancel();
        _backgroundSub = null;
        backgroundStatus = BackgroundSharePolicy.resolve(
          optIn: backgroundOptIn,
          access: access,
          streamActive: false,
        );
        return false;
      }
      if (_backgroundSub != null) {
        backgroundStatus = BackgroundShareStatus.active;
        return true;
      }
      // Flux GPS matériel — pas un Timer qui invente des coordonnées.
      _backgroundSub = _device.watchPositions().listen(
        _onBackgroundFix,
        onError: _onBackgroundStreamError,
        cancelOnError: false,
      );
      backgroundStatus = BackgroundShareStatus.active;
      return true;
    } finally {
      isRequestingLocationAccess = false;
      notifyListeners();
    }
  }

  void _onBackgroundStreamError(Object error) {
    if (error is LocationServiceDisabledException) {
      locationAccess = const LocationAccess(LocationAccessStatus.serviceDisabled);
      backgroundStatus = BackgroundShareStatus.gpsOff;
      notifyListeners();
    }
  }

  Future<void> _onBackgroundFix(Position fix) async {
    if (_publishingBackgroundFix) {
      _pendingBackgroundFix = fix;
      return;
    }
    _publishingBackgroundFix = true;
    try {
      await _publishDeviceFix(fix, refreshHistory: false);
      final leftover = _pendingBackgroundFix;
      _pendingBackgroundFix = null;
      if (leftover != null) {
        await _publishDeviceFix(leftover, refreshHistory: false);
      }
    } on DeviceLocationException catch (error) {
      errorMessage = error.message;
      locationAccess = error.access ?? locationAccess;
      notifyListeners();
    } on ApiException catch (error) {
      if (!error.isOffline) {
        errorMessage = error.message;
        notifyListeners();
      }
    } catch (_) {
      // Un point manqué n’arrête pas le flux GPS.
    } finally {
      _publishingBackgroundFix = false;
    }
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
      await _publishDeviceFix(fix, refreshHistory: true);
    });
  }

  /// Même API / même file que le bouton manuel. Horodatage GPS conservé.
  ///
  /// Batterie lue au moment du fix (premier plan et flux Phase 12).
  /// Si la lecture échoue, le champ est omis — pas un 100 % inventé.
  Future<void> _publishDeviceFix(Position fix, {required bool refreshHistory}) async {
    unsyncedFix = fix;
    final batteryLevel = await _battery.currentLevel();
    final payload = phoneFixPayload(fix, batteryLevel: batteryLevel);
    try {
      latest = await _repository.publishPhoneFix(
        latitude: fix.latitude,
        longitude: fix.longitude,
        accuracy: fix.accuracy,
        altitude: fix.altitude,
        speed: (fix.speed.isNaN || fix.speed < 0) ? null : fix.speed,
        heading: (fix.heading.isNaN || fix.heading < 0) ? null : fix.heading,
        recordedAt: fix.timestamp,
        batteryLevel: batteryLevel,
      );
      unsyncedFix = null;
    } on ApiException catch (error) {
      if (error.isOffline) {
        queue.enqueueLocation(payload);
        await _persist();
        errorMessage =
            'Position enregistrée sur l’appareil. Synchronisation plus tard. '
            'L’heure du téléphone est conservée — pas Last Write Wins, pas la position actuelle.';
        notifyListeners();
        return;
      }
      rethrow;
    }
    if (!refreshHistory) {
      notifyListeners();
      return;
    }
    history = await _repository.myHistory();
    try {
      trajectory = await _repository.myTrajectory();
    } on ApiException {
      trajectory = null;
    }
  }

  Future<int> flushPending() async {
    final sent = await flushQueuedLocations(queue: queue, locations: _repository);
    await _persist();
    notifyListeners();
    return sent;
  }

  Future<bool> loadMyTrips({TripPeriod? period, DateTime? from, DateTime? to}) {
    return _run(() async {
      if (period != null) {
        tripPeriod = period;
      }
      tripFrom = from;
      tripTo = to;
      tripHistory = await _repository.myTrips(
        period: tripPeriod == TripPeriod.custom ? null : tripPeriod,
        from: from,
        to: to,
      );
    });
  }

  Future<bool> loadChildTrips(String youngPersonId, {TripPeriod? period, DateTime? from, DateTime? to}) {
    return _run(() async {
      if (period != null) {
        tripPeriod = period;
      }
      tripFrom = from;
      tripTo = to;
      try {
        tripHistory = await _repository.childTrips(
          youngPersonId,
          period: tripPeriod == TripPeriod.custom ? null : tripPeriod,
          from: from,
          to: to,
        );
      } on ApiException catch (error) {
        tripHistory = null;
        if (error.statusCode == 403 || error.statusCode == 404) {
          errorMessage = error.message;
          return;
        }
        rethrow;
      }
    });
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

  /// Charge les pastilles de plusieurs jeunes sans écraser [latest].
  ///
  /// Un 403/404 sur un enfant est ignoré : les autres pastilles restent
  /// affichables. Ce n’est pas un GPS continu.
  Future<bool> loadFamilyLatest(Iterable<String> youngPersonIds) {
    return _run(() async {
      final next = <String, TrackerLocation>{};
      for (final id in youngPersonIds) {
        try {
          final watch = await _repository.watchChild(id);
          final point = watch.latest;
          if (point != null) {
            next[id] = point;
          }
        } on ApiException catch (error) {
          if (error.statusCode == 403 || error.statusCode == 404) {
            continue;
          }
          rethrow;
        }
      }
      familyLatest
        ..clear()
        ..addAll(next);
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

  @override
  void dispose() {
    _backgroundSub?.cancel();
    _backgroundSub = null;
    super.dispose();
  }
}
