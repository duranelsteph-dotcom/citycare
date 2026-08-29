import 'package:flutter/material.dart';

import '../presentation/alerts/alert_controller.dart';
import '../presentation/alerts/alert_scope.dart';
import '../presentation/auth/auth_controller.dart';
import '../presentation/auth/auth_scope.dart';
import '../presentation/auth/login_page.dart';
import '../presentation/cases/case_controller.dart';
import '../presentation/cases/case_scope.dart';
import '../presentation/family/family_controller.dart';
import '../presentation/family/family_scope.dart';
import '../presentation/location/location_controller.dart';
import '../presentation/location/location_scope.dart';
import '../presentation/notifications/notification_controller.dart';
import '../presentation/notifications/notification_scope.dart';
import '../presentation/risk/risk_zone_controller.dart';
import '../presentation/risk/risk_zone_scope.dart';
import '../presentation/shell/role_home_page.dart';
import '../presentation/splash/splash_page.dart';
import '../presentation/trackers/tracker_controller.dart';
import '../presentation/trackers/tracker_scope.dart';
import '../presentation/zones/zone_controller.dart';
import '../presentation/zones/zone_scope.dart';
import 'theme.dart';

class CityCareApp extends StatelessWidget {
  const CityCareApp({
    super.key,
    required this.auth,
    required this.family,
    required this.location,
    required this.zones,
    required this.notifications,
    required this.riskZones,
    required this.alerts,
    required this.trackers,
    required this.cases,
  });

  final AuthController auth;
  final FamilyController family;
  final LocationController location;
  final ZoneController zones;
  final NotificationController notifications;
  final RiskZoneController riskZones;
  final AlertController alerts;
  final TrackerController trackers;
  final CaseController cases;

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      controller: auth,
      child: FamilyScope(
        controller: family,
        child: LocationScope(
          controller: location,
          child: ZoneScope(
            controller: zones,
            child: RiskZoneScope(
              controller: riskZones,
              child: AlertScope(
                controller: alerts,
                child: TrackerScope(
                  controller: trackers,
                  child: CaseScope(
                    controller: cases,
                    child: NotificationScope(
                      controller: notifications,
                      child: MaterialApp(
                        title: 'CityCare',
                        debugShowCheckedModeBanner: false,
                        theme: CityCareTheme.light(),
                        darkTheme: CityCareTheme.dark(),
                        // Le thème suit le réglage du téléphone : une recherche
                        // se déclenche souvent la nuit, écran au minimum.
                        themeMode: ThemeMode.system,
                        home: ListenableBuilder(
                          listenable: auth,
                          builder: (context, _) {
                            if (auth.isRestoring) {
                              return const SplashPage(message: 'Restauration de votre session sécurisée…');
                            }
                            if (!auth.isAuthenticated) {
                              return const LoginPage();
                            }
                            return const RoleHomePage();
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
