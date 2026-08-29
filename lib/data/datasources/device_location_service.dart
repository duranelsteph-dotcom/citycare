import 'package:geolocator/geolocator.dart';

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

  LocationAccess _map(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
        return const LocationAccess(LocationAccessStatus.granted);
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
