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
import '../../app/production_api_url.dart';
import '../../app/tunnel_api_url.dart';
import 'dev_api_resolver.dart';

/// Canal natif : empreinte émulateur Android (goldfish / ranchu / generic).
const kDeviceKindChannel = MethodChannel('citycare/device');

class ApiConfig {
  ApiConfig._();

  /// URL forcée après un failover (127.0.0.1 refusé -> LAN).
  static String? currentOverride;

  /// Dernière URL qui a marché (rechargée au bootstrap).
  static String? rememberedUrl;

  /// URL saisie manuellement (écran dev) — prioritaire après redémarrage PC.
  static String? manualApiUrl;

  /// Tests unitaires : ignore l’URL Render pour exercer les fallbacks LAN/USB.
  static bool forceDevUrlsForTests = false;

  /// true = émulateur Android. null = pas encore interrogé.
  static bool? isEmulator;

  /// Tests : court-circuite le GET /health (évite le réseau réel).
  static Future<bool> Function(String url)? healthProbeOverride;

  static const Duration healthProbeTimeout = Duration(seconds: 2);

  /// Réveil Render free (cold start) avant le premier POST /auth/login.
  static const Duration productionHealthProbeTimeout = Duration(seconds: 90);

  static const String fromEnvironment = String.fromEnvironment('CITYCARE_API_URL');

  /// URL HTTPS de production : dart-define, sinon constante compilée.
  static String get productionApiUrl {
    if (forceDevUrlsForTests && !kReleaseMode) {
      return '';
    }
    final env = normalizeApiUrl(fromEnvironment);
    if (env.isNotEmpty && isHttpsProductionUrl(env)) {
      return env;
    }
    final baked = normalizeApiUrl(kProductionApiUrl);
    if (baked.isNotEmpty && isHttpsProductionUrl(baked)) {
      return baked;
    }
    // Release : toujours Render, jamais une URL vide (évite le fallback LAN).
    if (kReleaseMode) {
      return 'https://citycare-gp0y.onrender.com/api/v1';
    }
    return '';
  }

  static bool get isProductionBuild => kReleaseMode || productionApiUrl.isNotEmpty;

  static bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Candidats stables (sans le cache) pour le retry.
  static List<String> get candidates {
    final prod = productionApiUrl;
    if (prod.isNotEmpty) {
      return [prod];
    }
    // Release : aucun candidat LAN / USB / tunnel.
    if (kReleaseMode) {
      return const ['https://citycare-gp0y.onrender.com/api/v1'];
    }
    return devApiUrlCandidates(
      fromEnv: fromEnvironment,
      isAndroid: _isAndroid,
      isEmulator: isEmulator ?? false,
      isWeb: kIsWeb,
      lanApiUrl: kDevLanApiUrl,
      hotspotApiUrl: kDevHotspotApiUrl,
      tunnelApiUrl: kTunnelApiUrl,
      manualApiUrl: manualApiUrl,
      remembered: rememberedUrl,
    );
  }

  /// URL active : en release = Render uniquement (jamais localhost / LAN / ngrok).
  static String get baseUrl {
    final prod = productionApiUrl;
    if (prod.isNotEmpty) {
      return prod;
    }
    if (kReleaseMode) {
      return 'https://citycare-gp0y.onrender.com/api/v1';
    }
    if (currentOverride != null && currentOverride!.isNotEmpty) {
      return currentOverride!;
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
    final prod = productionApiUrl;
    if (prod.isNotEmpty) {
      currentOverride = prod;
      rememberedUrl = null;
      manualApiUrl = null;
      // Efface d’anciennes URLs LAN/USB/ngrok mémorisées sur le téléphone.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(kWorkingApiUrlPrefKey);
        await prefs.remove(kManualApiUrlPrefKey);
      } catch (_) {}
      // Réveille Render avant le login (évite Connection reset / timeout 12 s).
      await _wakeProductionApi(prod);
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final manual = prefs.getString(kManualApiUrlPrefKey);
      if (manual != null && manual.isNotEmpty) {
        manualApiUrl = normalizeApiUrl(manual);
      }
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
  /// En production : réveille Render (même URL, timeout long).
  static Future<void> selectReachableBaseUrl({http.Client? client}) async {
    final prod = productionApiUrl;
    if (prod.isNotEmpty) {
      currentOverride = prod;
      await _wakeProductionApi(prod, client: client);
      return;
    }
    if (kReleaseMode) {
      currentOverride = 'https://citycare-gp0y.onrender.com/api/v1';
      await _wakeProductionApi(currentOverride!, client: client);
      return;
    }
    final urls = healthProbeCandidates(
      fromEnv: fromEnvironment,
      isAndroid: _isAndroid,
      isEmulator: isEmulator ?? false,
      isWeb: kIsWeb,
      lanApiUrl: kDevLanApiUrl,
      hotspotApiUrl: kDevHotspotApiUrl,
      tunnelApiUrl: kTunnelApiUrl,
      manualApiUrl: manualApiUrl,
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
    // Aucun /health : ne pas réutiliser un cache LAN mort (IP Wi-Fi changée, etc.).
    currentOverride = null;
    if (rememberedUrl != null) {
      rememberedUrl = null;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(kWorkingApiUrlPrefKey);
      } catch (_) {}
    }
  }

  static Future<bool> _healthOk(
    String url, {
    http.Client? client,
    Duration? timeout,
  }) async {
    if (healthProbeOverride != null) {
      return healthProbeOverride!(url);
    }
    final owned = client == null;
    final httpClient = client ?? http.Client();
    try {
      final uri = Uri.parse('${normalizeApiUrl(url)}/health');
      final headers = isNgrokOrTunnelUrl(url)
          ? const {'ngrok-skip-browser-warning': 'true'}
          : const <String, String>{};
      final response = await httpClient
          .get(uri, headers: headers)
          .timeout(timeout ?? healthProbeTimeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    } finally {
      if (owned) {
        httpClient.close();
      }
    }
  }

  /// Best-effort : GET /health avec timeout long (Render free cold start).
  static Future<void> _wakeProductionApi(String url, {http.Client? client}) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      if (await _healthOk(
        url,
        client: client,
        timeout: productionHealthProbeTimeout,
      )) {
        return;
      }
      await Future<void>.delayed(Duration(seconds: 2 * (attempt + 1)));
    }
  }

  /// Passe à l’URL suivante après un refus (127.0.0.1 sur le téléphone, etc.).
  static String? promoteNextAfterFailure() {
    // Release / prod Render : jamais de bascule vers LAN, USB ou ngrok.
    if (kReleaseMode || productionApiUrl.isNotEmpty) {
      currentOverride = productionApiUrl.isNotEmpty
          ? productionApiUrl
          : 'https://citycare-gp0y.onrender.com/api/v1';
      return null;
    }
    final next = nextFallbackAfter(baseUrl, candidates);
    currentOverride = next;
    return next;
  }

  static Future<void> clearPersistedUrl() async {
    currentOverride = null;
    rememberedUrl = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kWorkingApiUrlPrefKey);
    } catch (_) {}
  }

  /// Teste /health puis enregistre l’URL manuelle (sans rebuild APK).
  static Future<bool> applyManualApiUrl(String raw) async {
    var normalized = normalizeApiUrl(raw);
    if (normalized.isEmpty) {
      return false;
    }
    if (!normalized.endsWith('/api/v1')) {
      normalized = '$normalized/api/v1';
    }
    if (!await _healthOk(normalized)) {
      return false;
    }
    manualApiUrl = normalized;
    currentOverride = normalized;
    await persistWorking(normalized);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kManualApiUrlPrefKey, normalized);
    } catch (_) {}
    return true;
  }

  static Future<void> clearManualApiUrl() async {
    manualApiUrl = null;
    await clearPersistedUrl();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kManualApiUrlPrefKey);
    } catch (_) {}
    await selectReachableBaseUrl();
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
    manualApiUrl = null;
    isEmulator = null;
    healthProbeOverride = null;
    forceDevUrlsForTests = true;
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