import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:workmanager/workmanager.dart';

import 'app/citycare_app.dart';
import 'core/config/api_config.dart';
import 'data/datasources/alert_remote.dart';
import 'data/datasources/auth_remote.dart';
import 'data/datasources/case_remote.dart';
import 'data/datasources/circle_remote.dart';
import 'data/datasources/device_remote.dart';
import 'data/datasources/family_remote.dart';
import 'data/datasources/location_remote.dart';
import 'data/datasources/notification_remote.dart';
import 'data/datasources/background_share_store.dart';
import 'data/datasources/offline_queue.dart';
import 'data/datasources/offline_queue_flush.dart';
import 'data/datasources/offline_queue_store.dart';
import 'data/datasources/push_service.dart';
import 'data/datasources/risk_zone_remote.dart';
import 'data/datasources/secure_token_store.dart';
import 'data/datasources/marketplace_remote.dart';
import 'data/datasources/marketplace_store.dart';
import 'data/datasources/subscription_remote.dart';
import 'data/datasources/subscription_store.dart';
import 'data/datasources/tracker_remote.dart';
import 'data/datasources/zone_remote.dart';
import 'data/repositories/alert_repository_impl.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/case_repository_impl.dart';
import 'data/repositories/circle_repository_impl.dart';
import 'data/repositories/family_repository_impl.dart';
import 'data/repositories/location_repository_impl.dart';
import 'data/repositories/notification_repository_impl.dart';
import 'data/repositories/risk_zone_repository_impl.dart';
import 'data/repositories/tracker_repository_impl.dart';
import 'data/repositories/zone_repository_impl.dart';
import 'presentation/alerts/alert_controller.dart';
import 'presentation/auth/auth_controller.dart';
import 'presentation/cases/case_controller.dart';
import 'presentation/circles/circle_controller.dart';
import 'presentation/family/family_controller.dart';
import 'presentation/location/location_controller.dart';
import 'presentation/notifications/notification_controller.dart';
import 'presentation/onboarding/onboarding_controller.dart';
import 'presentation/marketplace/marketplace_controller.dart';
import 'presentation/profile/subscription_controller.dart';
import 'presentation/risk/risk_zone_controller.dart';
import 'presentation/trackers/tracker_controller.dart';
import 'presentation/zones/zone_controller.dart';

/// Nom unique Android WorkManager (périodique ≥ 15 min, imposé par l’OS).
const kOfflineFlushUniqueName = 'citycare-offline-queue-flush';

/// Nom de tâche reçu par [callbackDispatcher].
const kOfflineFlushTaskName = 'citycareOfflineQueueFlush';

/// Isolate de fond Workmanager. Doit rester top-level (AOT).
///
/// Android : WorkManager peut retarder ou grouper les runs (Doze, OEM).
/// iOS : on n’enregistre pas de périodique ici — BGTaskScheduler est
/// best-effort (souvent ~1×/jour) ; le flush reste au retour réseau / ouverture.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await runBackgroundOfflineFlush();
      return true;
    } catch (_) {
      return false;
    }
  });
}

/// Enregistre la tâche périodique Android uniquement.
Future<void> registerAndroidOfflineFlush() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return;
  }
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    kOfflineFlushUniqueName,
    kOfflineFlushTaskName,
    frequency: const Duration(minutes: 15),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    constraints: Constraints(networkType: NetworkType.connected),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  await ApiConfig.bootstrap();
  await registerAndroidOfflineFlush();
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );
  final tokens = SecureTokenStore(storage: storage);
  final queue = OfflineQueue();
  final queueStore = OfflineQueueStore(storage: storage);
  await queueStore.loadInto(queue);
  Future<void> persistQueue(OfflineQueue pending) => queueStore.save(pending);
  final auth = AuthController(
    AuthRepositoryImpl(
      remote: AuthRemoteDataSource(),
      tokenStore: tokens,
    ),
  );
  final family = FamilyController(
    FamilyRepositoryImpl(FamilyRemoteDataSource(tokenStore: tokens)),
  );
  final circles = CircleController(
    CircleRepositoryImpl(CircleRemoteDataSource(tokenStore: tokens)),
  );
  final location = LocationController(
    LocationRepositoryImpl(LocationRemoteDataSource(tokenStore: tokens)),
    queue: queue,
    persist: persistQueue,
    backgroundStore: SharedPreferencesBackgroundShareStore(),
  );
  final zones = ZoneController(
    ZoneRepositoryImpl(ZoneRemoteDataSource(tokenStore: tokens)),
  );
  final notifications = NotificationController(
    NotificationRepositoryImpl(NotificationRemoteDataSource(tokenStore: tokens)),
  );
  final riskZones = RiskZoneController(
    RiskZoneRepositoryImpl(RiskZoneRemoteDataSource(tokenStore: tokens)),
  );
  final alerts = AlertController(
    AlertRepositoryImpl(AlertRemoteDataSource(tokenStore: tokens)),
    queue: queue,
    persist: persistQueue,
  );
  final trackers = TrackerController(
    TrackerRepositoryImpl(TrackerRemoteDataSource(tokenStore: tokens)),
  );
  final cases = CaseController(
    CaseRepositoryImpl(CaseRemoteDataSource(tokenStore: tokens)),
  );
  final push = PushService(DeviceRemoteDataSource(tokenStore: tokens));
  push.onForegroundMessage = () {
    notifications.load();
  };
  final onboarding = OnboardingController(SharedPreferencesOnboardingStore());
  final subscription = SubscriptionController(
    store: SharedPreferencesSubscriptionStore(),
    remote: SubscriptionRemoteDataSource(tokenStore: tokens),
  );
  final marketplace = MarketplaceController(
    store: SharedPreferencesMarketplaceStore(),
    remote: MarketplaceRemoteDataSource(tokenStore: tokens),
  );
  auth.afterSessionChange = () async {
    if (auth.isAuthenticated) {
      // Le premier login laisse l’onboarding demander FCM lui-même.
      if (onboarding.isCompleted) {
        await push.syncToken();
      }
      await location.restoreBackgroundSharing();
    } else {
      await location.pauseBackgroundSharing();
      await push.clear();
    }
  };
  onboarding.onCompleted = () {
    if (auth.isAuthenticated) {
      push.syncToken();
    }
  };
  await Future.wait([
    auth.restoreSession(),
    onboarding.load(),
  ]);
  runApp(
    CityCareApp(
      auth: auth,
      family: family,
      circles: circles,
      location: location,
      zones: zones,
      notifications: notifications,
      riskZones: riskZones,
      alerts: alerts,
      trackers: trackers,
      cases: cases,
      onboarding: onboarding,
      subscription: subscription,
      marketplace: marketplace,
    ),
  );
}
