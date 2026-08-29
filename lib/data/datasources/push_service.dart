import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'device_remote.dart';

@pragma('vm:entry-point')
Future<void> cityCareFirebaseBackground(RemoteMessage message) async {
  // Le bandeau système affiche le payload notification. L'inbox reste la source de vérité.
}

class PushService {
  PushService(this._remote);

  final DeviceRemoteDataSource _remote;
  VoidCallback? onForegroundMessage;
  String? _token;
  String? _platform;
  bool _ready = false;
  bool _listenersBound = false;

  bool get isReady => _ready;

  Future<void> syncToken() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      FirebaseMessaging.onBackgroundMessage(cityCareFirebaseBackground);
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      if (!kIsWeb && Platform.isIOS) {
        await messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
      }
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) {
        _ready = false;
        return;
      }
      _platform = _platformName();
      await _remote.register(token: token, platform: _platform!);
      _token = token;
      _ready = true;
      if (!_listenersBound) {
        _listenersBound = true;
        messaging.onTokenRefresh.listen((value) async {
          _token = value;
          if (_platform != null) {
            await _remote.register(token: value, platform: _platform!);
          }
        });
        FirebaseMessaging.onMessage.listen((_) {
          onForegroundMessage?.call();
        });
      }
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> clear() async {
    final token = _token;
    final platform = _platform;
    _token = null;
    _ready = false;
    if (token == null || platform == null) {
      return;
    }
    try {
      await _remote.unregister(token: token, platform: platform);
    } catch (_) {
      // Déconnexion locale même si l'API est injoignable.
    }
  }

  String _platformName() {
    if (kIsWeb) {
      return 'WEB';
    }
    if (Platform.isIOS) {
      return 'IOS';
    }
    return 'ANDROID';
  }
}
