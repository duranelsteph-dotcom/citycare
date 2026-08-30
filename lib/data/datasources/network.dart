import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../app/dev_api_host.dart';
import '../../core/config/api_config.dart';
import '../../core/config/dev_api_resolver.dart';
import '../../core/errors/api_exception.dart';

const kHttpTimeout = Duration(seconds: 12);

const offlineException = ApiException(
  'Hors ligne. Enregistrement local : l’heure du téléphone est conservée. '
  'Ce n’est pas Last Write Wins, pas un suivi en direct.',
  statusCode: 0,
);

/// Timeout, USB / adb reverse, API arrêtée : message réel, pas un silence.
ApiException connectionFailure(Object error) {
  final detail = error.toString();
  final usb = detail.toLowerCase().contains('connection refused') ||
      detail.toLowerCase().contains('failed host lookup') ||
      detail.toLowerCase().contains('timed out') ||
      detail.toLowerCase().contains('network is unreachable') ||
      isNoRouteToHostError(error) ||
      error is TimeoutException;
  if (usb) {
    return ApiException(
      'Serveur injoignable ($detail). '
      'Téléphone et PC doivent être sur le même Wi-Fi. '
      'API : python -m app.run_api (0.0.0.0:$kDevLanPort), pas seulement 127.0.0.1. '
      'URL attendue : $kDevLanApiUrl. '
      'Si l’IP a changé : ipconfig, puis mettre à jour lib/app/dev_api_host.dart '
      'ou Additional run args --dart-define=CITYCARE_API_URL=http://IP:8000/api/v1. '
      'Pare-feu Windows : autoriser TCP $kDevLanPort. '
      'USB en plus : adb reverse tcp:8000 tcp:8000. '
      'Émulateur : 10.0.2.2:8000.',
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
/// [send] doit reconstruire l’URI avec [ApiConfig.baseUrl] / [ApiConfig.uri]
/// à chaque appel (pas une Uri figée avant le retry).
Future<http.Response> guardedHttp(
  Future<http.Response> Function() send, {
  Duration timeout = kHttpTimeout,
}) async {
  Object lastError = 'réseau';
  final tried = <String>{};
  while (true) {
    final used = ApiConfig.baseUrl;
    try {
      final response = await send().timeout(timeout);
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
    if (!shouldRetryAfterNetworkError(failedUrl: used, error: lastError)) {
      throw connectionFailure(lastError);
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