import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/entities/background_share.dart';
import '../../domain/entities/location_access.dart';

class DeviceLocationException implements Exception {
  const DeviceLocationException(this.message, {this.access});

  final String message;

  /// État d'accès à l'origine de l'échec, quand il est connu. Permet à l'écran
  /// de proposer la bonne action (redemander, ouvrir les réglages…) plutôt
  /// qu'un simple message d'erreur.
  final LocationAccess? access;

  @override
  String toString() => message;
}

/// Charge utile POST /locations — horodatage GPS conservé (pas Last Write Wins).
///
/// [batteryLevel] : batterie téléphone lue au moment du fix. Absente si null
/// (lecture ratée) — on n’envoie jamais un 100 % inventé.
Map<String, dynamic> phoneFixPayload(Position fix, {int? batteryLevel}) {
  return {
    'latitude': fix.latitude,
    'longitude': fix.longitude,
    'accuracy': fix.accuracy,
    'altitude': fix.altitude,
    'speed': (fix.speed.isNaN || fix.speed < 0) ? null : fix.speed,
    'heading': (fix.heading.isNaN || fix.heading < 0) ? null : fix.heading,
    'recorded_at': fix.timestamp.toUtc().toIso8601String(),
    if (batteryLevel != null) 'battery_level': batteryLevel,
  };
}

/// Réglages du flux GPS arrière-plan (filtre 40 m, service premier plan Android).
///
/// iOS : `allowBackgroundLocationUpdates` + `UIBackgroundModes` location.
/// Sans la capability « Background Modes → Location updates » cochée dans
/// Xcode, le flux iOS peut s’arrêter à la mise en arrière-plan.
LocationSettings backgroundLocationSettings({
  TargetPlatform? platform,
}) {
  final target = platform ?? defaultTargetPlatform;
  if (target == TargetPlatform.android) {
    return AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: kBackgroundDistanceFilterMeters,
      intervalDuration: kBackgroundAndroidInterval,
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'CityCare',
        notificationText: kBackgroundNotificationText,
        notificationChannelName: 'Partage de position',
        setOngoing: true,
        enableWakeLock: true,
      ),
    );
  }
  if (target == TargetPlatform.iOS || target == TargetPlatform.macOS) {
    return AppleSettings(
      accuracy: LocationAccuracy.high,
      activityType: ActivityType.otherNavigation,
      distanceFilter: kBackgroundDistanceFilterMeters,
      pauseLocationUpdatesAutomatically: true,
      showBackgroundLocationIndicator: true,
      allowBackgroundLocationUpdates: true,
    );
  }
  return const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: kBackgroundDistanceFilterMeters,
  );
}

/// GPS du téléphone (pas du kit IoT).
class DeviceLocationService {
  /// Lit l'état d'accès **sans rien demander à l'utilisateur**.
  ///
  /// Utilisé à l'ouverture d'un écran de carte : on affiche l'explication
  /// avant la boîte de dialogue système, pour qu'un parent comprenne pourquoi
  /// on lui demande sa position.
  Future<LocationAccess> checkAccess() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationAccess(LocationAccessStatus.serviceDisabled);
      }
      return _map(await Geolocator.checkPermission());
    } catch (_) {
      return const LocationAccess(LocationAccessStatus.unavailable);
    }
  }

  /// Déclenche la demande système si elle a encore une chance d'aboutir.
  ///
  /// Ne redemande jamais après un refus définitif : Android et iOS ignorent
  /// silencieusement une seconde demande, ce qui donnerait à l'utilisateur
  /// l'impression que le bouton est cassé.
  Future<LocationAccess> requestAccess() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationAccess(LocationAccessStatus.serviceDisabled);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return _map(permission);
    } catch (_) {
      return const LocationAccess(LocationAccessStatus.unavailable);
    }
  }

  /// Demande « toujours » après « pendant l’utilisation » (Android 10+ / iOS).
  ///
  /// Deux étapes : d’abord la permission premier plan, puis une seconde
  /// demande pour ACCESS_BACKGROUND_LOCATION. Si le système refuse encore,
  /// seul un passage par les réglages débloque.
  Future<LocationAccess> requestBackgroundAccess() async {
    final first = await requestAccess();
    if (!first.isGranted) {
      return first;
    }
    if (first.isAlways) {
      return first;
    }
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationAccess(LocationAccessStatus.serviceDisabled);
      }
      final permission = await Geolocator.requestPermission();
      return _map(permission);
    } catch (_) {
      return first;
    }
  }

  /// Ouvre les réglages de l'application (cas du refus définitif).
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  /// Ouvre les réglages de localisation du système (cas du GPS éteint).
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }

  /// Relève une position ponctuelle.
  ///
  /// Échoue avec un [DeviceLocationException] portant l'état d'accès, pour que
  /// l'écran puisse proposer l'action corrective adaptée.
  Future<Position> currentFix() async {
    final access = await requestAccess();
    if (!access.isGranted) {
      throw DeviceLocationException(_failureMessage(access), access: access);
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }

  /// Flux GPS réel (getPositionStream). Pas un Timer qui invente des points.
  ///
  /// Android : service premier plan + notification persistante.
  Stream<Position> watchPositions() {
    return Geolocator.getPositionStream(locationSettings: backgroundLocationSettings());
  }

  LocationAccess _map(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
        return const LocationAccess(LocationAccessStatus.granted, isAlways: true);
      case LocationPermission.whileInUse:
        return const LocationAccess(LocationAccessStatus.granted);
      case LocationPermission.denied:
        return const LocationAccess(LocationAccessStatus.denied);
      case LocationPermission.deniedForever:
        return const LocationAccess(LocationAccessStatus.deniedForever);
      case LocationPermission.unableToDetermine:
        return const LocationAccess(LocationAccessStatus.unavailable);
    }
  }

  String _failureMessage(LocationAccess access) {
    switch (access.status) {
      case LocationAccessStatus.serviceDisabled:
        return 'Activez la localisation de l’appareil.';
      case LocationAccessStatus.denied:
        return 'Autorisation de localisation refusée.';
      case LocationAccessStatus.deniedForever:
        return 'Localisation bloquée dans les réglages. CityCare ne peut pas la demander à nouveau.';
      case LocationAccessStatus.unavailable:
        return 'Localisation indisponible sur cet appareil.';
      case LocationAccessStatus.granted:
        return 'Localisation disponible.';
    }
  }
}
