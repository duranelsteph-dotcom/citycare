import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app/citycare_app.dart';
import 'data/datasources/alert_remote.dart';
import 'data/datasources/auth_remote.dart';
import 'data/datasources/case_remote.dart';
import 'data/datasources/device_remote.dart';
import 'data/datasources/family_remote.dart';
import 'data/datasources/location_remote.dart';
import 'data/datasources/notification_remote.dart';
import 'data/datasources/offline_queue.dart';
import 'data/datasources/offline_queue_store.dart';
import 'data/datasources/push_service.dart';
import 'data/datasources/risk_zone_remote.dart';
import 'data/datasources/secure_token_store.dart';
import 'data/datasources/tracker_remote.dart';
import 'data/datasources/zone_remote.dart';
import 'data/repositories/alert_repository_impl.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/case_repository_impl.dart';
import 'data/repositories/family_repository_impl.dart';
import 'data/repositories/location_repository_impl.dart';
import 'data/repositories/notification_repository_impl.dart';
import 'data/repositories/risk_zone_repository_impl.dart';
import 'data/repositories/tracker_repository_impl.dart';
import 'data/repositories/zone_repository_impl.dart';
import 'presentation/alerts/alert_controller.dart';
import 'presentation/auth/auth_controller.dart';
import 'presentation/cases/case_controller.dart';
import 'presentation/family/family_controller.dart';
import 'presentation/location/location_controller.dart';
import 'presentation/notifications/notification_controller.dart';
import 'presentation/risk/risk_zone_controller.dart';
import 'presentation/trackers/tracker_controller.dart';
import 'presentation/zones/zone_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
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
  final location = LocationController(
    LocationRepositoryImpl(LocationRemoteDataSource(tokenStore: tokens)),
    queue: queue,
    persist: persistQueue,
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
  auth.afterSessionChange = () async {
    if (auth.isAuthenticated) {
      await push.syncToken();
    } else {
      await push.clear();
    }
  };
  await auth.restoreSession();
  runApp(
    CityCareApp(
      auth: auth,
      family: family,
      location: location,
      zones: zones,
      notifications: notifications,
      riskZones: riskZones,
      alerts: alerts,
      trackers: trackers,
      cases: cases,
    ),
  );
}
