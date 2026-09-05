import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../app/dev_api_host.dart';
import '../../core/config/api_config.dart';
import '../../core/config/dev_api_resolver.dart';
import '../../core/errors/api_exception.dart';

/// Timeout LAN / USB (réponse rapide attendue).
const kHttpTimeout = Duration(seconds: 12);

/// Render free : cold start 30–60 s + bcrypt login ~3 s.
const kProductionHttpTimeout = Duration(seconds: 90);

const int kProductionSameUrlRetries = 2;

const offlineException = ApiException(
  'Hors ligne. Enregistrement local : l’heure du téléphone est conservée. '
  'Ce n’est pas Last Write Wins, pas un suivi en direct.',
  statusCode: 0,
);

Duration httpTimeoutFor(String apiUrl) {
  if (isHttpsProductionUrl(apiUrl) || ApiConfig.productionApiUrl.isNotEmpty) {
    return kProductionHttpTimeout;
  }
  return kHttpTimeout;
}

bool isTimeoutNetworkError(Object error) {
  if (error is TimeoutException) {
    return true;
  }
  final detail = error.toString().toLowerCase();
  return detail.contains('timed out') || detail.contains('timeout');
}

/// En-têtes requis pour ngrok (plan gratuit) et autres tunnels HTTPS.
Map<String, String> cityCareApiHeaders([Map<String, String>? extra]) {
  final headers = <String, String>{};
  if (isNgrokOrTunnelUrl(ApiConfig.baseUrl)) {
    headers['ngrok-skip-browser-warning'] = 'true';
  }
  if (extra != null) {
    headers.addAll(extra);
  }
  return headers;
}

/// Timeout, USB / adb reverse, API arrêtée : message réel, pas un silence.
ApiException connectionFailure(Object error) {
  final detail = error.toString();
  final usb = detail.toLowerCase().contains('connection refused') ||
      detail.toLowerCase().contains('failed host lookup') ||
      detail.toLowerCase().contains('timed out') ||
      detail.toLowerCase().contains('network is unreachable') ||
      isNoRouteToHostError(error) ||
      isConnectionResetError(error) ||
      error is TimeoutException;
  if (usb) {
    final prod = ApiConfig.productionApiUrl;
    if (prod.isNotEmpty) {
      return ApiException(
        'Serveur injoignable ($detail). '
        'Vérifiez Internet (4G/Wi‑Fi) et que l’API répond : $prod/health. '
        'Sur Render free, la première requête peut prendre ~1 min (réveil).',
        statusCode: 0,
      );
    }
    final hint = isConnectionResetError(error)
        ? 'Connexion coupée (IP Wi-Fi ou hotspot). Utilisez un tunnel ngrok : '
            'scripts/start_dev_tunnel.ps1 — ou USB + adb reverse tcp:8000 tcp:8000.'
        : isNgrokOrTunnelUrl(ApiConfig.baseUrl)
            ? 'Vérifiez que ngrok tourne (scripts/start_ngrok.ps1) et que tunnel_api_url.dart est à jour.'
            : 'Téléphone et PC sur le même Wi-Fi, ou USB + adb reverse, ou tunnel ngrok.';
    return ApiException(
      'Serveur injoignable ($detail). $hint '
      'API : python -m app.run_api (0.0.0.0:$kDevLanPort). '
      'URL USB : http://127.0.0.1:$kDevLanPort/api/v1. '
      'Hotspot Windows : http://$kDevHotspotHost:$kDevLanPort/api/v1. '
      'Wi-Fi PC : $kDevLanApiUrl. '
      'Pare-feu : autoriser TCP $kDevLanPort.',
      statusCode: 0,
    );
  }
  return ApiException(
    'Réseau indisponible ($detail). ${offlineException.message}',
    statusCode: 0,
  );
}

/// Envoie [send] ; si 127.0.0.1 refuse, réessaie l’hôte LAN et mémorise.
///
/// Sur HTTPS production (Render) : retente la **même** URL après reset / timeout
/// (cold start), sans basculer vers LAN / USB / Cloudflare.
///
/// [send] doit reconstruire l’URI avec [ApiConfig.baseUrl] / [ApiConfig.uri]
/// à chaque appel (pas une Uri figée avant le retry).
Future<http.Response> guardedHttp(
  Future<http.Response> Function() send, {
  Duration? timeout,
}) async {
  Object lastError = 'réseau';
  final tried = <String>{};
  var productionAttempts = 0;
  while (true) {
    final used = ApiConfig.baseUrl;
    final effectiveTimeout = timeout ?? httpTimeoutFor(used);
    try {
      final response = await send().timeout(effectiveTimeout);
      final host = hostOfApiUrl(used);
      if (host == null || !isWindowsHotspotHost(host)) {
        await ApiConfig.persistWorking(used);
      } else {
        ApiConfig.currentOverride = used;
      }
      return response;
    } on TimeoutException catch (error) {
      lastError = error;
    } on SocketException catch (error) {
      lastError = error;
    } on http.ClientException catch (error) {
      lastError = error;
    }

    final productionHost = isHttpsProductionUrl(used);
    final transient = isTransientNetworkError(lastError) || isTimeoutNetworkError(lastError);
    if (productionHost && transient && productionAttempts < kProductionSameUrlRetries) {
      productionAttempts++;
      await Future<void>.delayed(Duration(seconds: 2 * productionAttempts));
      continue;
    }

    if (!shouldRetryAfterNetworkError(failedUrl: used, error: lastError)) {
      throw connectionFailure(lastError);
    }
    final failedHost = hostOfApiUrl(used);
    if (failedHost != null &&
        isPrivateLanHost(failedHost) &&
        !isLoopbackHost(failedHost) &&
        !isWindowsHotspotHost(failedHost)) {
      await ApiConfig.clearPersistedUrl();
    }
    tried.add(used);
    final next = ApiConfig.promoteNextAfterFailure();
    if (next == null || tried.contains(next)) {
      throw connectionFailure(lastError);
    }
  }
}

/// Un essai, puis un retry court. Le SOS ne doit pas mourir au 1er timeout USB.
Future<T> withOneRetry<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on ApiException catch (error) {
    if (!error.isOffline) {
      rethrow;
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return action();
  }
}
