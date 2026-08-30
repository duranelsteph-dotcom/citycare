import 'package:flutter/material.dart';

import '../presentation/alerts/alert_controller.dart';
import '../presentation/alerts/alert_scope.dart';
import '../presentation/auth/auth_controller.dart';
import '../presentation/auth/auth_scope.dart';
import '../presentation/auth/welcome_page.dart';
import '../presentation/cases/case_controller.dart';
import '../presentation/cases/case_scope.dart';
import '../presentation/circles/circle_controller.dart';
import '../presentation/circles/circle_scope.dart';
import '../presentation/family/family_controller.dart';
import '../presentation/family/family_scope.dart';
import '../presentation/location/location_controller.dart';
import '../presentation/location/location_scope.dart';
import '../presentation/notifications/notification_controller.dart';
import '../presentation/notifications/notification_scope.dart';
import '../presentation/onboarding/notification_permission.dart';
import '../presentation/onboarding/onboarding_controller.dart';
import '../presentation/onboarding/onboarding_page.dart';
import '../presentation/onboarding/onboarding_scope.dart';
import '../presentation/onboarding/setup_onboarding_page.dart';
import '../presentation/marketplace/marketplace_controller.dart';
import '../presentation/marketplace/marketplace_scope.dart';
import '../presentation/profile/subscription_controller.dart';
import '../presentation/profile/subscription_scope.dart';
import '../presentation/risk/risk_zone_controller.dart';
import '../presentation/risk/risk_zone_scope.dart';
import '../presentation/shell/main_shell.dart';
import '../presentation/splash/splash_page.dart';
import '../presentation/trackers/tracker_controller.dart';
import '../presentation/trackers/tracker_scope.dart';
import '../presentation/zones/zone_controller.dart';
import '../presentation/zones/zone_scope.dart';
import 'theme.dart';

class CityCareApp extends StatelessWidget {
  CityCareApp({
    super.key,
    required this.auth,
    required this.family,
    required this.circles,
    required this.location,
    required this.zones,
    required this.notifications,
    required this.riskZones,
    required this.alerts,
    required this.trackers,
    required this.cases,
    required this.onboarding,
    SubscriptionController? subscription,
    MarketplaceController? marketplace,
    this.notificationPermission,
    this.splashHold = kSplashHold,
  })  : subscription = subscription ?? SubscriptionController.memory(),
        marketplace = marketplace ?? MarketplaceController.memory();

  final AuthController auth;
  final FamilyController family;
  final CircleController circles;
  final LocationController location;
  final ZoneController zones;
  final NotificationController notifications;
  final RiskZoneController riskZones;
  final AlertController alerts;
  final TrackerController trackers;
  final CaseController cases;
  final OnboardingController onboarding;
  final SubscriptionController subscription;
  final MarketplaceController marketplace;

  /// Dialogue FCM réel en production ; un double en tests.
  final NotificationPermissionClient? notificationPermission;

  /// Durée du splash Flutter. 5 s en prod ; `Duration.zero` dans les tests
  /// qui ne vérifient pas le minuteur (2FA, onboarding, shell).
  final Duration splashHold;

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      controller: auth,
      child: FamilyScope(
        controller: family,
        child: CircleScope(
          controller: circles,
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
                      child: OnboardingScope(
                        controller: onboarding,
                        child: SubscriptionScope(
                          controller: subscription,
                          child: MarketplaceScope(
                            controller: marketplace,
                            child: MaterialApp(
                          title: 'CityCare',
                          debugShowCheckedModeBanner: false,
                          theme: CityCareTheme.light(),
                          darkTheme: CityCareTheme.dark(),
                          // Le thème suit le réglage du téléphone : une recherche
                          // se déclenche souvent la nuit, écran au minimum.
                          themeMode: ThemeMode.system,
                          home: _LaunchGate(
                            auth: auth,
                            onboarding: onboarding,
                            splashHold: splashHold,
                            notificationPermission: notificationPermission,
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
        ),
        ),
      ),
    ),
    );
  }
}

/// Garde le splash violet [splashHold] secondes, puis route selon la session.
///
/// Restauration / onboarding encore en cours : on reste sur le splash.
/// Connecté + onboarding vu → [MainShell]. Connecté sans onboarding →
/// [OnboardingPage]. Sinon [WelcomePage] (CTA Se connecter / Créer un compte).
class _LaunchGate extends StatefulWidget {
  const _LaunchGate({
    required this.auth,
    required this.onboarding,
    required this.splashHold,
    this.notificationPermission,
  });

  final AuthController auth;
  final OnboardingController onboarding;
  final Duration splashHold;
  final NotificationPermissionClient? notificationPermission;

  @override
  State<_LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<_LaunchGate> {
  bool _holdElapsed = false;

  void _markHoldElapsed() {
    if (!mounted || _holdElapsed) {
      return;
    }
    setState(() => _holdElapsed = true);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.auth,
      builder: (context, _) {
        return ListenableBuilder(
          listenable: widget.onboarding,
          builder: (context, _) {
            final waiting = !_holdElapsed ||
                widget.auth.isRestoring ||
                widget.onboarding.isLoading;
            if (waiting) {
              return SplashPage(
                hold: widget.splashHold,
                onFinished: _markHoldElapsed,
                message: widget.auth.isRestoring
                    ? 'Restauration de votre session sécurisée…'
                    : widget.onboarding.isLoading
                        ? 'Préparation…'
                        : null,
              );
            }
            if (!widget.auth.isAuthenticated) {
              // Accueil hero (photos + CTA). Le 2FA reste sur LoginPage → OtpPage.
              return const WelcomePage();
            }
            if (!widget.onboarding.isCompleted) {
              // Première session, ou flag absent au prochain login.
              return OnboardingPage(
                notificationPermission: widget.notificationPermission,
              );
            }
            if (!widget.onboarding.isSetupCompleted) {
              return const SetupOnboardingPage();
            }
            return const MainShell();
          },
        );
      },
    );
  }
}
