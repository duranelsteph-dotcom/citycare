/// URL du backend. Aucun secret ici.
/// En production, passer --dart-define=CITYCARE_API_URL=https://... (HTTPS).
/// En local, dart-define reste un override. 127.0.0.1 n’est plus le seul défaut
/// : un téléphone physique utilise l’IP LAN (voir lib/app/dev_api_host.dart).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/dev_api_host.dart';
import 'dev_api_resolver.dart';

/// Canal natif : empreinte émulateur Android (goldfish / ranchu / generic).
const kDeviceKindChannel = MethodChannel('citycare/device');

class ApiConfig {
  ApiConfig._();

  /// URL forcée après un failover (127.0.0.1 refusé -> LAN).
  static String? currentOverride;

  /// Dernière URL qui a marché (rechargée au bootstrap).
  static String? rememberedUrl;

  /// true = émulateur Android. null = pas encore interrogé.
  static bool? isEmulator;

  /// Tests : court-circuite le GET /health (évite le réseau réel).
  static Future<bool> Function(String url)? healthProbeOverride;

  static const Duration healthProbeTimeout = Duration(seconds: 2);

  static const String fromEnvironment = String.fromEnvironment('CITYCARE_API_URL');

  static bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Candidats stables (sans le cache) pour le retry.
  static List<String> get candidates {
    return devApiUrlCandidates(
      fromEnv: fromEnvironment,
      isAndroid: _isAndroid,
      isEmulator: isEmulator ?? false,
      isWeb: kIsWeb,
      lanApiUrl: kDevLanApiUrl,
      hotspotApiUrl: kDevHotspotApiUrl,
    );
  }

  static String get baseUrl {
    final override = currentOverride ?? rememberedUrl;
    if (override != null && override.isNotEmpty) {
      return override;
    }
    final list = candidates;
    if (list.isEmpty) {
      return kDevLanApiUrl;
    }
    return list.first;
  }

  /// Origine HTTP (sans /api/v1) pour composer une URL de fichier statique.
  static String get origin {
    final url = baseUrl;
    const suffix = '/api/v1';
    if (url.endsWith(suffix)) {
      return url.substring(0, url.length - suffix.length);
    }
    return url;
  }

  /// Transforme `/static/uploads/…` en URL absolue. Laisse passer http(s).
  static String? resolveMediaUrl(String? path) {
    if (path == null || path.isEmpty) {
      return null;
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return path.startsWith('/') ? '$origin$path' : '$origin/$path';
  }

  static Uri uri(String path) => Uri.parse('$baseUrl$path');

  /// Charge le cache + détecte l’émulateur. À appeler au démarrage.
  static Future<void> bootstrap() async {
    isEmulator = await detectAndroidEmulator();
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(kWorkingApiUrlPrefKey);
      if (saved != null && saved.isNotEmpty) {
        final normalized = normalizeApiUrl(saved);
        if (isDeadRememberedApiUrl(normalized)) {
          rememberedUrl = null;
          await prefs.remove(kWorkingApiUrlPrefKey);
        } else if ((isEmulator ?? false) || kIsWeb || !isUnreachableFromPhysicalDevice(normalized)) {
          rememberedUrl = normalized;
        }
      }
    } catch (_) {
      // Tests / isolate sans plugin : on garde les candidats statiques.
    }
    await selectReachableBaseUrl();
  }

  /// Health-check : reverse, LAN, hotspot seulement si /health répond.
  static Future<void> selectReachableBaseUrl({http.Client? client}) async {
    if (isHttpsProductionUrl(fromEnvironment)) {
      return;
    }
    final urls = healthProbeCandidates(
      fromEnv: fromEnvironment,
      isAndroid: _isAndroid,
      isEmulator: isEmulator ?? false,
      isWeb: kIsWeb,
      lanApiUrl: kDevLanApiUrl,
      hotspotApiUrl: kDevHotspotApiUrl,
    );
    for (final url in urls) {
      if (await _healthOk(url, client: client)) {
        currentOverride = url;
        final host = hostOfApiUrl(url);
        if (host != null && isWindowsHotspotHost(host)) {
          // Session seulement : ne pas recharger un hotspot mort au prochain lancement.
          rememberedUrl = null;
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove(kWorkingApiUrlPrefKey);
          } catch (_) {}
        } else {
          await persistWorking(url);
        }
        return;
      }
    }
    if (rememberedUrl != null && isDeadRememberedApiUrl(rememberedUrl!)) {
      rememberedUrl = null;
    }
  }

  static Future<bool> _healthOk(String url, {http.Client? client}) async {
    if (healthProbeOverride != null) {
      return healthProbeOverride!(url);
    }
    final owned = client == null;
    final httpClient = client ?? http.Client();
    try {
      final uri = Uri.parse('${normalizeApiUrl(url)}/health');
      final response = await httpClient.get(uri).timeout(healthProbeTimeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    } finally {
      if (owned) {
        httpClient.close();
      }
    }
  }

  /// Passe à l’URL suivante après un refus (127.0.0.1 sur le téléphone, etc.).
  static String? promoteNextAfterFailure() {
    final next = nextFallbackAfter(baseUrl, candidates);
    currentOverride = next;
    return next;
  }

  static Future<void> persistWorking(String url) async {
    final normalized = normalizeApiUrl(url);
    currentOverride = normalized;
    final host = hostOfApiUrl(normalized);
    if (host != null && isWindowsHotspotHost(host)) {
      rememberedUrl = null;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(kWorkingApiUrlPrefKey);
      } catch (_) {}
      return;
    }
    rememberedUrl = normalized;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kWorkingApiUrlPrefKey, normalized);
    } catch (_) {
      // Pas bloquant : la session en mémoire suffit jusqu’au prochain lancement.
    }
  }

  static void resetForTests() {
    currentOverride = null;
    rememberedUrl = null;
    isEmulator = null;
    healthProbeOverride = null;
  }
}

/// Empreinte Android (generic / emulator / goldfish / ranchu). false hors Android.
Future<bool> detectAndroidEmulator() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return false;
  }
  try {
    final value = await kDeviceKindChannel.invokeMethod<bool>('isEmulator');
    return value ?? false;
  } catch (_) {
    return false;
  }
}