/// RÃ¨gles dâ€™URL API en dÃ©veloppement. Aucun secret. Testable sans plugin.
library;

/// Ã‰mulateur Android -> hÃ´te du PC (pas 127.0.0.1 dans lâ€™Ã©mulateur).
const kAndroidEmulatorApiUrl = 'http://10.0.2.2:8000/api/v1';

/// Loopback : navigateur / adb reverse / simulateur iOS. Pas un tÃ©lÃ©phone Wi-Fi.
const kLoopbackApiUrl = 'http://127.0.0.1:8000/api/v1';

/// ClÃ© SharedPreferences : derniÃ¨re URL qui a rÃ©ellement rÃ©pondu.
const kWorkingApiUrlPrefKey = 'citycare_working_api_url_v2';

/// Adresse par dÃ©faut du partage de connexion Windows (Mobile Hotspot).
const kWindowsHotspotHost = '192.168.137.1';

bool isLoopbackHost(String host) {
  return host == '127.0.0.1' || host == 'localhost' || host == '::1';
}

/// 10.0.2.2 nâ€™existe que dans lâ€™Ã©mulateur Android.
bool isEmulatorOnlyHost(String host) => host == '10.0.2.2';

/// Hotspot Windows : le tÃ©lÃ©phone nâ€™y a une route que sâ€™il y est connectÃ©.
bool isWindowsHotspotHost(String host) => host == kWindowsHotspotHost;

bool isPrivateLanHost(String host) {
  final parts = host.split('.');
  if (parts.length != 4) {
    return false;
  }
  final nums = <int>[];
  for (final part in parts) {
    final value = int.tryParse(part);
    if (value == null || value < 0 || value > 255) {
      return false;
    }
    nums.add(value);
  }
  final a = nums[0];
  final b = nums[1];
  if (a == 10) {
    return host != '10.0.2.2';
  }
  if (a == 192 && b == 168) {
    return true;
  }
  if (a == 172 && b >= 16 && b <= 31) {
    return true;
  }
  return false;
}

String normalizeApiUrl(String raw) {
  var url = raw.trim();
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  return url;
}

String? hostOfApiUrl(String url) {
  try {
    final host = Uri.parse(url).host;
    return host.isEmpty ? null : host;
  } catch (_) {
    return null;
  }
}

bool isHttpsProductionUrl(String url) => url.trim().toLowerCase().startsWith('https://');

/// HÃ´te que le tÃ©lÃ©phone physique ne peut pas joindre (loopback ou 10.0.2.2).
bool isUnreachableFromPhysicalDevice(String url) {
  final host = hostOfApiUrl(url);
  if (host == null) {
    return true;
  }
  return isLoopbackHost(host) || isEmulatorOnlyHost(host);
}

/// Cache mort : hotspot Windows mÃ©morisÃ© alors que le tÃ©lÃ©phone nâ€™y est pas.
bool isDeadRememberedApiUrl(String url) {
  final host = hostOfApiUrl(url);
  if (host == null || host.isEmpty) {
    return true;
  }
  return isWindowsHotspotHost(host);
}

bool isNoRouteToHostError(Object error) {
  final detail = error.toString().toLowerCase();
  return detail.contains('no route to host') ||
      detail.contains('errno = 113') ||
      detail.contains('errno=113') ||
      detail.contains('os error: 113');
}

bool isConnectionResetError(Object error) {
  final detail = error.toString().toLowerCase();
  return detail.contains('connection reset') ||
      detail.contains('connection closed') ||
      detail.contains('errno = 104') ||
      detail.contains('errno=104') ||
      detail.contains('os error: 104');
}

bool isTransientNetworkError(Object error) {
  return isNoRouteToHostError(error) || isConnectionResetError(error);
}

bool isNgrokOrTunnelUrl(String url) {
  final host = hostOfApiUrl(url)?.toLowerCase() ?? '';
  return host.contains('ngrok') || host.endsWith('.trycloudflare.com');
}

bool shouldRetryAfterNetworkError({
  required String failedUrl,
  required Object error,
}) {
  final detail = error.toString().toLowerCase();
  final refused = detail.contains('connection refused') ||
      detail.contains('failed host lookup') ||
      detail.contains('timed out') ||
      detail.contains('timeout') ||
      detail.contains('network is unreachable') ||
      detail.contains('os error: 111') ||
      detail.contains('errno = 111') ||
      isTransientNetworkError(error);
  if (!refused) {
    return false;
  }
  final host = hostOfApiUrl(failedUrl);
  if (host == null) {
    return true;
  }
  return isLoopbackHost(host) || isEmulatorOnlyHost(host) || isPrivateLanHost(host);
}

/// Prochain candidat aprÃ¨s un Ã©chec, ou null si plus rien Ã  essayer.
String? nextFallbackAfter(String failedUrl, List<String> candidates) {
  if (candidates.isEmpty) {
    return null;
  }
  final failed = normalizeApiUrl(failedUrl);
  final index = candidates.indexOf(failed);
  if (index < 0) {
    for (final url in candidates) {
      if (url != failed) {
        return url;
      }
    }
    return null;
  }
  if (index + 1 >= candidates.length) {
    return null;
  }
  return candidates[index + 1];
}

/// PremiÃ¨re URL dont le health a rÃ©ussi. Un hÃ´te Â« no route Â» nâ€™est jamais choisi.
String? firstHealthyApiUrl(
  List<String> candidates,
  bool Function(String url) isHealthy,
) {
  for (final url in candidates) {
    if (isHealthy(url)) {
      return url;
    }
  }
  return null;
}

bool _usableLanOverride(String url, {required bool isWeb, required bool isEmulator}) {
  if (url.isEmpty) {
    return false;
  }
  final host = hostOfApiUrl(url);
  if (host == null || isWindowsHotspotHost(host)) {
    return false;
  }
  if (isWeb || isEmulator) {
    return !isLoopbackHost(host);
  }
  return !isUnreachableFromPhysicalDevice(url);
}

bool _usableRemembered(String? url, {required bool isWeb, required bool isEmulator}) {
  if (url == null || url.isEmpty) {
    return false;
  }
  if (isDeadRememberedApiUrl(url)) {
    return false;
  }
  if (isWeb || isEmulator) {
    return true;
  }
  return !isUnreachableFromPhysicalDevice(url);
}

/// Health-check : USB reverse, LAN Wiâ€‘Fi, hotspot seulement en dernier.
List<String> healthProbeCandidates({
  required String lanApiUrl,
  String? hotspotApiUrl,
  String? tunnelApiUrl,
  required bool isAndroid,
  required bool isEmulator,
  required bool isWeb,
  String fromEnv = '',
}) {
  final env = normalizeApiUrl(fromEnv);
  if (env.isNotEmpty && isHttpsProductionUrl(env)) {
    return [env];
  }

  final tunnel = normalizeApiUrl(tunnelApiUrl ?? '');
  if (tunnel.isNotEmpty && isHttpsProductionUrl(tunnel)) {
    return [tunnel];
  }

  final out = <String>[];
  void add(String? url) {
    if (url == null || url.isEmpty) {
      return;
    }
    final normalized = normalizeApiUrl(url);
    if (normalized.isEmpty || out.contains(normalized)) {
      return;
    }
    out.add(normalized);
  }

  if (isWeb) {
    add(kLoopbackApiUrl);
    add(lanApiUrl);
    return out;
  }

  if (isAndroid && isEmulator) {
    add(kAndroidEmulatorApiUrl);
    add(lanApiUrl);
    add(kLoopbackApiUrl);
    return out;
  }

  add(kLoopbackApiUrl);
  add(hotspotApiUrl);
  if (_usableLanOverride(env, isWeb: false, isEmulator: false)) {
    add(env);
  }
  add(lanApiUrl);
  return out;
}

/// Ordre dâ€™essai : reverse USB, LAN, cache LAN, hotspot jamais en premier.
List<String> devApiUrlCandidates({
  required String fromEnv,
  required bool isAndroid,
  required bool isEmulator,
  required bool isWeb,
  required String lanApiUrl,
  String? hotspotApiUrl,
  String? tunnelApiUrl,
  String? remembered,
}) {
  final env = normalizeApiUrl(fromEnv);
  if (env.isNotEmpty && isHttpsProductionUrl(env)) {
    return [env];
  }

  final tunnel = normalizeApiUrl(tunnelApiUrl ?? '');
  if (tunnel.isNotEmpty && isHttpsProductionUrl(tunnel)) {
    return [tunnel];
  }

  final out = <String>[];
  void add(String? url) {
    if (url == null || url.isEmpty) {
      return;
    }
    final normalized = normalizeApiUrl(url);
    if (normalized.isEmpty || out.contains(normalized)) {
      return;
    }
    out.add(normalized);
  }

  if (isWeb) {
    if (_usableLanOverride(env, isWeb: true, isEmulator: false)) {
      add(env);
    }
    if (_usableRemembered(remembered, isWeb: true, isEmulator: false)) {
      add(remembered);
    }
    add(kLoopbackApiUrl);
    add(lanApiUrl);
    add(hotspotApiUrl);
    return out;
  }

  if (isAndroid && isEmulator) {
    if (_usableLanOverride(env, isWeb: false, isEmulator: true)) {
      add(env);
    }
    if (_usableRemembered(remembered, isWeb: false, isEmulator: true)) {
      add(remembered);
    }
    add(kAndroidEmulatorApiUrl);
    add(lanApiUrl);
    add(kLoopbackApiUrl);
    return out;
  }

  // Téléphone physique : tunnel ngrok, adb reverse, hotspot Windows, puis Wi-Fi PC.
  add(kLoopbackApiUrl);
  add(hotspotApiUrl);
  if (_usableLanOverride(env, isWeb: false, isEmulator: false)) {
    add(env);
  }
  add(lanApiUrl);
  if (_usableRemembered(remembered, isWeb: false, isEmulator: false)) {
    add(remembered);
  }
  if (isAndroid) {
    add(kAndroidEmulatorApiUrl);
  }
  return out;
}
