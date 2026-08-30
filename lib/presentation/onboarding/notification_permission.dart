import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// État de l’autorisation de notifications, indépendant de FCM.
enum NotificationAccessStatus {
  granted,
  denied,
  deniedForever,
  unavailable,
}

class NotificationAccess {
  const NotificationAccess(this.status);

  final NotificationAccessStatus status;

  bool get isGranted => status == NotificationAccessStatus.granted;

  bool get canAskAgain => status == NotificationAccessStatus.denied;

  bool get needsAppSettings => status == NotificationAccessStatus.deniedForever;
}

/// Demande réelle des notifications — pas un mock.
///
/// La production passe par [FcmNotificationPermissionClient]
/// (`FirebaseMessaging.requestPermission`). Les tests injectent un double.
abstract class NotificationPermissionClient {
  Future<NotificationAccess> check();

  Future<NotificationAccess> request();
}

/// Appelle le dialogue système FCM déjà utilisé par [PushService.syncToken].
class FcmNotificationPermissionClient implements NotificationPermissionClient {
  const FcmNotificationPermissionClient();

  Future<FirebaseMessaging?> _messaging() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      return FirebaseMessaging.instance;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<NotificationAccess> check() async {
    final messaging = await _messaging();
    if (messaging == null) {
      return const NotificationAccess(NotificationAccessStatus.unavailable);
    }
    try {
      return _map(await messaging.getNotificationSettings());
    } catch (_) {
      return const NotificationAccess(NotificationAccessStatus.unavailable);
    }
  }

  @override
  Future<NotificationAccess> request() async {
    final messaging = await _messaging();
    if (messaging == null) {
      return const NotificationAccess(NotificationAccessStatus.unavailable);
    }
    try {
      // Même appel que le service push existant — dialogue système réel.
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return _map(settings);
    } catch (_) {
      return const NotificationAccess(NotificationAccessStatus.unavailable);
    }
  }

  NotificationAccess _map(NotificationSettings settings) {
    switch (settings.authorizationStatus) {
      case AuthorizationStatus.authorized:
      case AuthorizationStatus.provisional:
        return const NotificationAccess(NotificationAccessStatus.granted);
      case AuthorizationStatus.denied:
        // iOS ne redemande plus. Android 13+ non plus après « Ne plus demander ».
        // On propose les réglages plutôt que de faire semblant qu’un second
        // tap suffira toujours.
        return const NotificationAccess(NotificationAccessStatus.deniedForever);
      case AuthorizationStatus.notDetermined:
        return const NotificationAccess(NotificationAccessStatus.denied);
    }
  }
}
