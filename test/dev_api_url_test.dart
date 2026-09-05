import 'package:citycare/app/dev_api_host.dart';
import 'package:citycare/core/config/api_config.dart';
import 'package:citycare/core/config/dev_api_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(ApiConfig.resetForTests);

  test('loopback et 10.0.2.2 sont injoignables depuis un tÃ©lÃ©phone physique', () {
    expect(isLoopbackHost('127.0.0.1'), isTrue);
    expect(isLoopbackHost('localhost'), isTrue);
    expect(isEmulatorOnlyHost('10.0.2.2'), isTrue);
    expect(isUnreachableFromPhysicalDevice('http://127.0.0.1:8000/api/v1'), isTrue);
    expect(isUnreachableFromPhysicalDevice('http://10.0.2.2:8000/api/v1'), isTrue);
    expect(isUnreachableFromPhysicalDevice('http://10.5.48.255:8000/api/v1'), isFalse);
    expect(isPrivateLanHost('10.5.48.255'), isTrue);
    expect(isPrivateLanHost('192.168.137.1'), isTrue);
    expect(isPrivateLanHost('10.0.2.2'), isFalse);
    expect(isWindowsHotspotHost('192.168.137.1'), isTrue);
    expect(isWindowsHotspotHost('10.5.48.255'), isFalse);
  });

  test('Ã©mulateur Android : 10.0.2.2 dâ€™abord, pas 127.0.0.1 seul', () {
    final urls = devApiUrlCandidates(
      fromEnv: '',
      isAndroid: true,
      isEmulator: true,
      isWeb: false,
      lanApiUrl: kDevLanApiUrl,
      hotspotApiUrl: kDevHotspotApiUrl,
    );
    expect(urls.first, kAndroidEmulatorApiUrl);
    expect(urls, contains(kDevLanApiUrl));
    expect(urls, contains(kLoopbackApiUrl));
  });

  test('tÃ©lÃ©phone physique : reverse dâ€™abord, dart-define 127.0.0.1 ignorÃ© comme override', () {
    final urls = devApiUrlCandidates(
      fromEnv: 'http://127.0.0.1:8000/api/v1',
      isAndroid: true,
      isEmulator: false,
      isWeb: false,
      lanApiUrl: kDevLanApiUrl,
      hotspotApiUrl: kDevHotspotApiUrl,
    );
    expect(urls.first, kLoopbackApiUrl);
    expect(urls, contains(kDevLanApiUrl));
    expect(urls, contains(kDevHotspotApiUrl));
    expect(urls.indexOf(kDevLanApiUrl), lessThan(urls.indexOf(kDevHotspotApiUrl)));
    expect(urls.first, isNot(kDevHotspotApiUrl));
  });

  test('dart-define LAN est un candidat, jamais derriÃ¨re le hotspot', () {
    const override = 'http://192.168.1.40:8000/api/v1';
    final urls = devApiUrlCandidates(
      fromEnv: override,
      isAndroid: true,
      isEmulator: false,
      isWeb: false,
      lanApiUrl: kDevLanApiUrl,
      hotspotApiUrl: kDevHotspotApiUrl,
    );
    expect(urls, contains(override));
    expect(urls.indexOf(override), lessThan(urls.indexOf(kDevHotspotApiUrl)));
    expect(urls.first, isNot(kDevHotspotApiUrl));
  });

  test('HTTPS production : pas de repli LAN', () {
    const prod = 'https://api.citycare.example/api/v1';
    final urls = devApiUrlCandidates(
      fromEnv: prod,
      isAndroid: true,
      isEmulator: false,
      isWeb: false,
      lanApiUrl: kDevLanApiUrl,
    );
    expect(urls, [prod]);
  });

  test('production HTTPS : timeout long et reset transient détecté', () {
    expect(isHttpsProductionUrl('https://citycare-gp0y.onrender.com/api/v1'), isTrue);
    expect(
      isConnectionResetError(
        'ClientException: Connection reset by peer, uri=https://citycare-gp0y.onrender.com/api/v1/auth/login',
      ),
      isTrue,
    );
    // Pas de bascule LAN : le retry même-URL est dans guardedHttp, pas ici.
    expect(
      shouldRetryAfterNetworkError(
        failedUrl: 'https://citycare-gp0y.onrender.com/api/v1',
        error: 'SocketException: Connection reset by peer',
      ),
      isFalse,
    );
  });

  test('retry : 127.0.0.1 refusÃ© -> LAN', () {
    final candidates = <String>[kLoopbackApiUrl, kDevLanApiUrl];
    expect(nextFallbackAfter(kLoopbackApiUrl, candidates), kDevLanApiUrl);
    expect(nextFallbackAfter(kDevLanApiUrl, candidates), isNull);
    expect(
      shouldRetryAfterNetworkError(
        failedUrl: kLoopbackApiUrl,
        error: 'ClientException with SocketException: Connection refused errno = 111',
      ),
      isTrue,
    );
  });

  test('no route to host (hotspot) dÃ©clenche un retry, pas hors-ligne immÃ©diat', () {
    const error =
        'ClientException with SocketException: No route to host (OS Error: No route to host, errno = 113)';
    expect(isNoRouteToHostError(error), isTrue);
    expect(
      shouldRetryAfterNetworkError(failedUrl: kDevHotspotApiUrl, error: error),
      isTrue,
    );
    expect(nextFallbackAfter(kDevHotspotApiUrl, [kLoopbackApiUrl, kDevLanApiUrl, kDevHotspotApiUrl]), isNull);
    expect(nextFallbackAfter(kDevHotspotApiUrl, [kLoopbackApiUrl, kDevLanApiUrl]), kLoopbackApiUrl);
  });

  test('hotspot 192.168.137.1 jamais en premier, cache mort ignorÃ©', () {
    expect(isDeadRememberedApiUrl(kDevHotspotApiUrl), isTrue);
    expect(isDeadRememberedApiUrl(kDevLanApiUrl), isFalse);
    final urls = devApiUrlCandidates(
      fromEnv: kDevHotspotApiUrl,
      isAndroid: true,
      isEmulator: false,
      isWeb: false,
      lanApiUrl: kDevLanApiUrl,
      hotspotApiUrl: kDevHotspotApiUrl,
      remembered: kDevHotspotApiUrl,
    );
    expect(urls.first, isNot(kDevHotspotApiUrl));
    expect(urls.first, kLoopbackApiUrl);
    expect(urls, contains(kDevLanApiUrl));
    expect(urls.indexOf(kDevLanApiUrl), lessThan(urls.indexOf(kDevHotspotApiUrl)));
  });

  test('health-check : reverse, puis LAN, hotspot seulement si OK', () {
    final order = healthProbeCandidates(
      fromEnv: kDevLanApiUrl,
      isAndroid: true,
      isEmulator: false,
      isWeb: false,
      lanApiUrl: kDevLanApiUrl,
      hotspotApiUrl: kDevHotspotApiUrl,
    );
    expect(order.first, kLoopbackApiUrl);
    expect(order, contains(kDevLanApiUrl));
    expect(order.indexOf(kDevHotspotApiUrl), greaterThan(order.indexOf(kDevLanApiUrl)));
    expect(firstHealthyApiUrl(order, (url) => url == kDevLanApiUrl), kDevLanApiUrl);
    expect(firstHealthyApiUrl(order, (url) => url == kDevHotspotApiUrl), kDevHotspotApiUrl);
    expect(firstHealthyApiUrl(order, (_) => false), isNull);
  });

  test('fichier hÃ´te LAN nâ€™est pas 127.0.0.1 ni le hotspot', () {
    expect(kDevLanHost, isNot('127.0.0.1'));
    expect(kDevLanHost, isNot('localhost'));
    expect(kDevLanHost, isNot(kDevHotspotHost));
    expect(kDevLanHost, '10.5.50.210');
    expect(isPrivateLanHost(kDevLanHost), isTrue);
    expect(kDevLanApiUrl, 'http://$kDevLanHost:$kDevLanPort/api/v1');
  });

  test('URL manuelle dev prioritaire sur tunnel compile-time', () {
    const manual = 'https://fresh-tunnel.trycloudflare.com/api/v1';
    const stale = 'https://dead-tunnel.trycloudflare.com/api/v1';
    final urls = devApiUrlCandidates(
      fromEnv: '',
      isAndroid: true,
      isEmulator: false,
      isWeb: false,
      lanApiUrl: kDevLanApiUrl,
      hotspotApiUrl: kDevHotspotApiUrl,
      tunnelApiUrl: stale,
      manualApiUrl: manual,
    );
    expect(urls.first, manual);
  });

  test('applyManualApiUrl enregistre après health OK', () async {
    SharedPreferences.setMockInitialValues({});
    const manual = 'https://live.trycloudflare.com/api/v1';
    ApiConfig.healthProbeOverride = (url) async => url == manual;
    final ok = await ApiConfig.applyManualApiUrl(manual);
    expect(ok, isTrue);
    expect(ApiConfig.manualApiUrl, manual);
    expect(ApiConfig.baseUrl, manual);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kManualApiUrlPrefKey), manual);
  });

  test('ApiConfig rejette HTTP local comme URL de production', () {
    expect(isHttpsProductionUrl('https://api.example.com/api/v1'), isTrue);
    expect(isHttpsProductionUrl('http://127.0.0.1:8000/api/v1'), isFalse);
    expect(isHttpsProductionUrl('http://10.5.50.210:8000/api/v1'), isFalse);
  });

  test('bootstrap invalide le cache 192.168.137.1 et choisit le LAN sain', () async {
    SharedPreferences.setMockInitialValues({
      kWorkingApiUrlPrefKey: kDevHotspotApiUrl,
    });
    ApiConfig.healthProbeOverride = (url) async => url == kDevLanApiUrl;
    await ApiConfig.bootstrap();
    expect(ApiConfig.rememberedUrl, kDevLanApiUrl);
    expect(ApiConfig.currentOverride, kDevLanApiUrl);
    expect(ApiConfig.baseUrl, kDevLanApiUrl);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kWorkingApiUrlPrefKey), kDevLanApiUrl);
  });

  test('persistWorking refuse de mÃ©moriser le hotspot', () async {
    SharedPreferences.setMockInitialValues({});
    await ApiConfig.persistWorking(kDevHotspotApiUrl);
    expect(ApiConfig.currentOverride, kDevHotspotApiUrl);
    expect(ApiConfig.rememberedUrl, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kWorkingApiUrlPrefKey), isNull);
  });
}
