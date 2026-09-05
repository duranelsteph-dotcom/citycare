import 'package:citycare/app/citycare_app.dart';
import 'package:citycare/core/errors/api_exception.dart';
import 'package:citycare/domain/entities/alerts.dart';
import 'package:citycare/domain/entities/circle.dart';
import 'package:citycare/domain/entities/emergency.dart';
import 'package:citycare/domain/entities/family.dart';
import 'package:citycare/domain/entities/identity.dart';
import 'package:citycare/domain/entities/search.dart';
import 'package:citycare/domain/entities/tracking.dart';
import 'package:citycare/domain/enums/citycare_enums.dart';
import 'package:citycare/domain/entities/zones.dart';
import 'package:citycare/domain/repositories/alert_repository.dart';
import 'package:citycare/domain/repositories/auth_repository.dart';
import 'package:citycare/domain/repositories/case_repository.dart';
import 'package:citycare/domain/repositories/circle_repository.dart';
import 'package:citycare/domain/repositories/family_repository.dart';
import 'package:citycare/domain/repositories/location_repository.dart';
import 'package:citycare/domain/repositories/notification_repository.dart';
import 'package:citycare/domain/repositories/risk_zone_repository.dart';
import 'package:citycare/domain/repositories/tracker_repository.dart';
import 'package:citycare/domain/repositories/zone_repository.dart';
import 'package:citycare/presentation/alerts/alert_controller.dart';
import 'package:citycare/presentation/alerts/alert_scope.dart';
import 'package:citycare/presentation/alerts/sos_pages.dart';
import 'package:citycare/presentation/auth/auth_controller.dart';
import 'package:citycare/presentation/auth/auth_scope.dart';
import 'package:citycare/presentation/cases/case_controller.dart';
import 'package:citycare/presentation/cases/case_pages.dart';
import 'package:citycare/presentation/cases/case_scope.dart';
import 'package:citycare/presentation/circles/circle_controller.dart';
import 'package:citycare/presentation/family/children_page.dart';
import 'package:citycare/presentation/family/family_controller.dart';
import 'package:citycare/presentation/family/family_scope.dart';
import 'package:citycare/presentation/location/emergency_page.dart';
import 'package:citycare/data/datasources/device_location_service.dart';
import 'package:citycare/domain/entities/location_access.dart';
import 'package:geolocator/geolocator.dart';
import 'package:citycare/presentation/location/location_controller.dart';
import 'package:citycare/presentation/location/location_scope.dart';
import 'package:citycare/presentation/location/position_pages.dart';
import 'package:citycare/presentation/notifications/notification_controller.dart';
import 'package:citycare/presentation/notifications/notification_scope.dart';
import 'package:citycare/presentation/notifications/notifications_page.dart';
import 'package:citycare/presentation/onboarding/notification_permission.dart';
import 'package:citycare/presentation/onboarding/onboarding_controller.dart';
import 'package:citycare/presentation/onboarding/onboarding_page.dart';
import 'package:citycare/presentation/risk/risk_zone_controller.dart';
import 'package:citycare/presentation/risk/risk_zone_scope.dart';
import 'package:citycare/presentation/trackers/kit_detail_page.dart';
import 'package:citycare/presentation/trackers/kit_page.dart';
import 'package:citycare/presentation/trackers/tracker_controller.dart';
import 'package:citycare/presentation/trackers/tracker_scope.dart';
import 'package:citycare/presentation/splash/splash_page.dart';
import 'package:citycare/presentation/widgets/prevention_carousel.dart';
import 'package:citycare/presentation/zones/zone_controller.dart';
import 'package:citycare/presentation/zones/zone_pages.dart';
import 'package:citycare/presentation/zones/zone_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.session});

  AuthSession? session;
  String? token;
  String? lastLoginPhone;
  String? lastRegisterPhone;
  String? lastRegisterEmail;

  @override
  Future<void> clearToken() async => token = null;

  @override
  Future<LoginChallenge> login({required String phone, required String password}) async {
    lastLoginPhone = phone;
    return const LoginChallenge(challengeId: 'challenge-demo', expiresIn: 300, otpDev: '123456');
  }

  @override
  Future<AuthSession> verifyOtp({required String challengeId, required String code}) async {
    final current = session;
    if (current == null) {
      throw StateError('No session');
    }
    token = current.token;
    return current;
  }

  @override
  Future<LoginChallenge> resendOtp({required String challengeId}) async {
    return const LoginChallenge(challengeId: 'challenge-demo', expiresIn: 300, otpDev: '654321');
  }

  String? lastForgotPhone;
  String? lastResetPhone;
  String? lastResetCode;
  String? lastResetPassword;

  @override
  Future<PasswordResetChallenge> requestPasswordReset({required String phone}) async {
    lastForgotPhone = phone;
    return PasswordResetChallenge(
      expiresIn: 900,
      phone: phone,
      resetCodeDev: '654321',
      message: 'Aucun SMS n’est envoyé',
    );
  }

  @override
  Future<void> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    lastResetPhone = phone;
    lastResetCode = code;
    lastResetPassword = newPassword;
  }

  @override
  Future<UserAccount> me(String token) async {
    return session!.user;
  }

  String? lastUploadPath;

  @override
  Future<UserAccount> uploadPhoto({required String filePath}) async {
    lastUploadPath = filePath;
    final current = session?.user;
    if (current == null) {
      throw StateError('No session');
    }
    final updated = current.copyWith(photoUrl: '/static/uploads/test.jpg');
    session = AuthSession(token: session!.token, user: updated);
    return updated;
  }

  String? lastDeletePassword;
  bool deleteShouldFail = false;

  @override
  Future<void> deleteAccount({required String password}) async {
    lastDeletePassword = password;
    if (deleteShouldFail) {
      throw const ApiException('Mot de passe incorrect', statusCode: 403);
    }
  }

  @override
  Future<String?> readToken() async => token;

  @override
  Future<AuthSession> register({
    required String fullName,
    required String phone,
    required String password,
    required UserRole role,
    String? email,
  }) async {
    lastRegisterPhone = phone;
    lastRegisterEmail = email;
    final current = session;
    if (current == null) {
      throw StateError('No session');
    }
    token = current.token;
    return current;
  }

  @override
  Future<void> saveToken(String value) async => token = value;
}

class FakeCircleRepository implements CircleRepository {
  @override
  Future<Circle> create(String name) async => throw UnimplementedError();

  @override
  Future<Circle> getById(String circleId) async => throw UnimplementedError();

  @override
  Future<Circle> join(String code) async => throw UnimplementedError();

  @override
  Future<void> leave(String circleId) async {}

  @override
  Future<List<Circle>> list() async => [];

  @override
  Future<List<CircleMember>> members(String circleId) async => [];

  @override
  Future<String> regenerateInvite(String circleId) async => 'ABC234';

  @override
  Future<String> currentInvite(String circleId) async => 'ABC234';

  @override
  Future<void> removeMember(String circleId, String userId) async {}

  @override
  Future<Circle> rename(String circleId, String name) async => throw UnimplementedError();
}

class FakeFamilyRepository implements FamilyRepository {
  @override
  Future<GuardianLink> acceptLink(String linkId) async => throw UnimplementedError();

  @override
  Future<List<GuardianLink>> children() async => [];

  @override
  Future<PairingCode> createPairingCode() async =>
      PairingCode(code: '123456', expiresAt: DateTime.now().add(const Duration(minutes: 15)));

  @override
  Future<List<GuardianLink>> guardians() async => [];

  @override
  Future<GuardianLink> inviteByPhone(String phone, {GuardianRelation relation = GuardianRelation.parent}) async {
    throw UnimplementedError();
  }

  @override
  Future<GuardianLink> linkByCode(String code) async => throw UnimplementedError();

  @override
  Future<void> revokeLink(String linkId) async {}

  @override
  Future<UserAccount> updateMyName(String fullName) async => throw UnimplementedError();

  @override
  Future<GuardianLink> updatePermissions(String linkId, GuardianPermissions permissions) async {
    throw UnimplementedError();
  }

  @override
  Future<YoungPerson> updateYoungProfile({String? displayName, DateTime? birthDate, String? notes}) async {
    throw UnimplementedError();
  }

  @override
  Future<YoungPerson> youngProfile() async => YoungPerson(
        id: 'yp-1',
        userId: '2',
        displayName: 'Amina',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

  @override
  Future<List<EmergencyContact>> emergencyContacts() async => [];

  @override
  Future<EmergencyContact> addEmergencyContact({required String name, required String phone}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteEmergencyContact(String contactId) async {}
}

class FakeLocationRepository implements LocationRepository {
  @override
  Future<List<TrackerLocation>> childHistory(String youngPersonId, {int limit = 20}) async => [];

  @override
  Future<TrackerLocation> childLatest(String youngPersonId) async {
    throw const ApiException('Aucune position enregistrée', statusCode: 404);
  }

  @override
  Future<List<TrackerLocation>> myHistory({int limit = 20}) async => [];

  @override
  Future<TrackerLocation> myLatest() async {
    throw const ApiException('Aucune position enregistrée', statusCode: 404);
  }

  @override
  Future<LocationWatch> watchMine() async {
    try {
      final latest = await myLatest();
      return LocationWatch(
        latest: latest,
        pollAfterSeconds: 60,
        effectiveMode: TrackingMode.normal,
        access: 'SELF',
        message: 'pas un suivi en direct',
      );
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        return const LocationWatch(
          pollAfterSeconds: 60,
          effectiveMode: TrackingMode.normal,
          access: 'SELF',
          message: 'pas un suivi en direct',
        );
      }
      rethrow;
    }
  }

  @override
  Future<LocationWatch> watchChild(String youngPersonId) async {
    throw const ApiException('Le jeune n\'a pas autorisé le partage de sa position', statusCode: 403);
  }

  @override
  Future<List<PositionShare>> myShares() async => [];

  @override
  Future<List<PositionShare>> receivedShares() async => [];

  @override
  Future<PositionShare> createShare({required String targetUserId, int durationMinutes = 60}) async {
    throw UnimplementedError();
  }

  @override
  Future<PositionShare> revokeShare(String shareId) async {
    throw UnimplementedError();
  }

  @override
  Future<Trajectory> myTrajectory({int hours = 4, int limit = 100}) async {
    return const Trajectory(youngPersonId: 'yp-1', points: []);
  }

  @override
  Future<Trajectory> childTrajectory(String youngPersonId, {int hours = 4, int limit = 100}) async {
    throw const ApiException('Le jeune n\'a pas autorisé le partage de sa position', statusCode: 403);
  }

  @override
  Future<TripHistory> myTrips({TripPeriod? period, DateTime? from, DateTime? to, int limit = 1000}) async {
    return const TripHistory(youngPersonId: 'yp-1', trips: []);
  }

  @override
  Future<TripHistory> childTrips(
    String youngPersonId, {
    TripPeriod? period,
    DateTime? from,
    DateTime? to,
    int limit = 1000,
  }) async {
    throw const ApiException('Le jeune n\'a pas autorisé le partage de sa position', statusCode: 403);
  }

  @override
  Future<TrackerLocation> publishPhoneFix({
    required double latitude,
    required double longitude,
    double? accuracy,
    double? altitude,
    double? speed,
    double? heading,
    DateTime? recordedAt,
    int? batteryLevel,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<EmergencySnapshot> emergency(String youngPersonId) async {
    throw const ApiException('Le jeune n\'a pas autorisé le partage de sa position', statusCode: 403);
  }
}

class FakeZoneRepository implements ZoneRepository {
  @override
  Future<List<SafetyZone>> childZones(String youngPersonId) async => [];

  @override
  Future<SafetyZone> create(SafetyZoneDraft draft, {required String youngPersonId}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> delete(String zoneId) async {}

  @override
  Future<List<SafetyZone>> myZones() async => [];

  @override
  Future<SafetyZone> update(String zoneId, SafetyZoneDraft draft) async {
    throw UnimplementedError();
  }
}

class FakeNotificationRepository implements NotificationRepository {
  @override
  Future<AppNotification> markRead(String id) async {
    throw UnimplementedError();
  }

  @override
  Future<int> markAllRead() async => 0;

  @override
  Future<List<AppNotification>> mine({int limit = 50, bool unreadOnly = false}) async => [];
}

class FakeRiskZoneRepository implements RiskZoneRepository {
  @override
  Future<RiskIncident> addIncident(String zoneId, IncidentDraft draft) async {
    throw UnimplementedError();
  }

  @override
  Future<RiskZone> create(RiskZoneDraft draft) async {
    throw UnimplementedError();
  }

  @override
  Future<void> delete(String zoneId) async {}

  @override
  Future<List<RiskIncident>> incidents(String zoneId) async => [];

  @override
  Future<List<RiskZone>> list() async => [];

  @override
  Future<RiskZone> update(String zoneId, RiskZoneDraft draft) async {
    throw UnimplementedError();
  }
}

class FakeAlertRepository implements AlertRepository {
  @override
  Future<Alert> acknowledge(String alertId) async {
    throw UnimplementedError();
  }

  @override
  Future<Alert> resolve(String alertId) async {
    throw UnimplementedError();
  }

  @override
  Future<Alert> cancel(String alertId) async {
    throw UnimplementedError();
  }

  @override
  Future<Alert> getById(String alertId) async {
    throw UnimplementedError();
  }

  @override
  Future<List<Alert>> mineAsGuardian() async => [];

  @override
  Future<List<Alert>> mineAsYoung() async => [];

  @override
  Future<Alert> triggerSos(SosDraft draft) async {
    throw UnimplementedError();
  }
}

class _OpenSosRepository extends FakeAlertRepository {
  _OpenSosRepository(this.at);

  final DateTime at;

  @override
  Future<Alert> getById(String alertId) async {
    return Alert(
      id: alertId,
      youngPersonId: 'yp-1',
      source: AlertSource.mobile,
      status: AlertStatus.active,
      severity: AlertSeverity.critical,
      triggeredAt: at,
      createdAt: at,
      updatedAt: at,
      latitude: 3.848,
      longitude: 11.502,
      youngDisplayName: 'Amina',
    );
  }

  @override
  Future<List<Alert>> mineAsYoung() async => [];

  @override
  Future<List<Alert>> mineAsGuardian() async => [];
}

class FakeTrackerRepository implements TrackerRepository {
  @override
  Future<List<GpsTracker>> forChild(String youngPersonId) async => [];

  @override
  Future<List<GpsTracker>> mine() async => [];

  @override
  Future<GpsTracker> register({String? youngPersonId, String label = 'Kit CityCare'}) async {
    throw UnimplementedError();
  }

  @override
  Future<GpsTracker> update(
    String trackerId, {
    String? label,
    TrackingMode? trackingMode,
    bool? enabled,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<GpsTracker> rotateSecret(String trackerId) async {
    throw UnimplementedError();
  }

  @override
  Future<void> delete(String trackerId) async {
    throw UnimplementedError();
  }

  @override
  Future<List<TrackerEvent>> events(String trackerId, {int limit = 30}) async => [];
}

class FakeCaseRepository implements CaseRepository {
  @override
  Future<MissingPersonCase> close(String caseId) async {
    throw UnimplementedError();
  }

  @override
  Future<MissingPersonCase> create(CaseDraft draft) async {
    throw UnimplementedError();
  }

  @override
  Future<MissingPersonCase> getById(String caseId) async {
    throw UnimplementedError();
  }

  @override
  Future<MissingPersonCase> markFound(String caseId) async {
    throw UnimplementedError();
  }

  @override
  Future<MissingPersonCase> startSearch(String caseId) async {
    throw UnimplementedError();
  }

  @override
  Future<List<MissingPersonCase>> mineAsGuardian() async => [];

  @override
  Future<List<MissingPersonCase>> mineAsYoung() async => [];

  @override
  Future<Trajectory> trajectory(String caseId) async {
    throw UnimplementedError();
  }

  @override
  Future<SearchIntelligence> intelligence(String caseId) async {
    throw UnimplementedError();
  }

  @override
  Future<SearchIntelligence> refreshIntelligence(String caseId) async {
    throw UnimplementedError();
  }

  @override
  Future<AiAnalysis> aiAnalysis(String caseId) async {
    throw UnimplementedError();
  }

  @override
  Future<AiAnalysis> refreshAiAnalysis(String caseId) async {
    throw UnimplementedError();
  }

  @override
  Future<List<SearchZone>> searchZones(String caseId) async => [];

  @override
  Future<List<Testimony>> testimonies(String caseId) async => [];

  @override
  Future<Testimony> submitTestimony(String caseId, TestimonyDraft draft) async {
    throw UnimplementedError();
  }

  @override
  Future<Testimony> reviewTestimony(String caseId, String testimonyId) async {
    throw UnimplementedError();
  }

  @override
  Future<Testimony> verifyTestimony(String caseId, String testimonyId) async {
    throw UnimplementedError();
  }

  @override
  Future<Testimony> rejectTestimony(String caseId, String testimonyId) async {
    throw UnimplementedError();
  }

  @override
  Future<List<Testimony>> refreshTestimonyConsistency(String caseId) async => [];

  @override
  Future<MissingPersonCase> uploadPhoto(String caseId, String filePath) async {
    throw UnimplementedError();
  }

  @override
  Future<List<CaseEvent>> events(String caseId) async => [];

  @override
  Future<MissingPersonCase> acknowledge(String caseId) async {
    throw UnimplementedError();
  }

  @override
  Future<MissingPersonCase> markInfo(String caseId) async {
    throw UnimplementedError();
  }
}

/// InkSparkle casse le harness Windows (shader ink_sparkle.frag, Flutter 3.47).
ThemeData cityCareTestTheme() {
  return ThemeData(useMaterial3: true, splashFactory: InkRipple.splashFactory);
}

Widget appWith(
  AuthController auth, {
  FamilyController? family,
  CircleController? circles,
  LocationController? location,
  NotificationController? notifications,
  OnboardingController? onboarding,
  NotificationPermissionClient? notificationPermission,
  Duration splashHold = Duration.zero,
}) {
  return CityCareApp(
    auth: auth,
    family: family ?? FamilyController(FakeFamilyRepository()),
    circles: circles ?? CircleController(FakeCircleRepository()),
    location: location ?? LocationController(FakeLocationRepository()),
    zones: ZoneController(FakeZoneRepository()),
    notifications: notifications ?? NotificationController(FakeNotificationRepository()),
    riskZones: RiskZoneController(FakeRiskZoneRepository()),
    alerts: AlertController(FakeAlertRepository()),
    trackers: TrackerController(FakeTrackerRepository()),
    cases: CaseController(FakeCaseRepository()),
    // Les tests existants visent MainShell : flag déjà vu.
    onboarding: onboarding ?? OnboardingController.memory(completed: true),
    notificationPermission: notificationPermission ?? _SilentNotifications(),
    // 5 s réelles seulement dans les tests splash dédiés (fake async).
    splashHold: splashHold,
  );
}

class _SilentNotifications implements NotificationPermissionClient {
  @override
  Future<NotificationAccess> check() async {
    return const NotificationAccess(NotificationAccessStatus.denied);
  }

  @override
  Future<NotificationAccess> request() async {
    return const NotificationAccess(NotificationAccessStatus.denied);
  }
}

class _ScriptedNotifications implements NotificationPermissionClient {
  _ScriptedNotifications(this.access);

  NotificationAccess access;
  int requests = 0;

  @override
  Future<NotificationAccess> check() async => access;

  @override
  Future<NotificationAccess> request() async {
    requests += 1;
    return access;
  }
}

class _ScriptedLocationDevice extends DeviceLocationService {
  _ScriptedLocationDevice(this.access);

  LocationAccess access;
  int requests = 0;
  int appSettings = 0;
  int locationSettings = 0;

  @override
  Future<LocationAccess> checkAccess() async => access;

  @override
  Future<LocationAccess> requestAccess() async {
    requests += 1;
    return access;
  }

  @override
  Future<bool> openAppSettings() async {
    appSettings += 1;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettings += 1;
    return true;
  }

  @override
  Future<LocationAccess> requestBackgroundAccess() async {
    requests += 1;
    return access;
  }

  @override
  Stream<Position> watchPositions() => const Stream.empty();
}

UserAccount _parentMarie() {
  return UserAccount(
    id: '1',
    fullName: 'Marie',
    phone: '+237600000000',
    role: UserRole.parent,
    isActive: true,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  testWidgets('splash affiche le logo citycare pendant la restauration', (tester) async {
    final auth = AuthController(FakeAuthRepository())..isRestoring = true;
    await tester.pumpWidget(appWith(auth));
    await tester.pump();

    expect(find.byKey(const Key('splash-page')), findsOneWidget);
    expect(find.text('citycare'), findsOneWidget);
    expect(find.text('Ici, on veille'), findsOneWidget);
    expect(find.text('Bienvenue'), findsOneWidget);
    expect(find.text('Prévention, alerte et assistance'), findsOneWidget);
    expect(find.text('Prévention'), findsOneWidget);
    expect(find.text('Alerte SOS'), findsOneWidget);
    expect(find.textContaining('Restauration'), findsOneWidget);
    expect(find.text('Se connecter'), findsNothing);
    expect(find.text('Créer un compte'), findsNothing);
    expect(find.text('Lire les conseils de prévention'), findsNothing);
  });

  testWidgets('splash widget sans timer : layout violet, aucun CTA', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashPage()));
    await tester.pump();

    expect(find.byKey(const Key('splash-page')), findsOneWidget);
    expect(find.text('citycare'), findsOneWidget);
    expect(find.text('Ici, on veille'), findsOneWidget);
    expect(find.text('Bienvenue'), findsOneWidget);
    expect(find.text('Prévention, alerte et assistance'), findsOneWidget);
    expect(find.text('Prévention'), findsOneWidget);
    expect(find.text('SOS'), findsOneWidget);
    expect(find.text('Alerte SOS'), findsOneWidget);
    expect(find.text('Se connecter'), findsNothing);
    expect(find.text('Créer un compte'), findsNothing);
    expect(find.text('Lire les conseils de prévention'), findsNothing);
  });

  testWidgets('splash tient exactement 5 s puis Welcome avec boutons', (tester) async {
    final auth = AuthController(FakeAuthRepository())..isRestoring = false;
    await tester.pumpWidget(appWith(auth, splashHold: kSplashHold));
    await tester.pump();

    expect(find.byKey(const Key('splash-page')), findsOneWidget);
    expect(find.text('Bienvenue'), findsOneWidget);
    expect(find.text('Se connecter'), findsNothing);

    // 4,999 s : toujours le splash (pas 5 s réelles — fake async).
    await tester.pump(const Duration(seconds: 4, milliseconds: 999));
    expect(find.byKey(const Key('splash-page')), findsOneWidget);
    expect(find.text('Se connecter'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('splash-page')), findsNothing);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Créer un compte'), findsOneWidget);
    expect(find.text('Lire les conseils de prévention'), findsOneWidget);
    expect(find.byType(PreventionCarousel), findsOneWidget);
  });

  testWidgets('splash 5 s puis MainShell si session déjà ouverte', (tester) async {
    final auth = AuthController(FakeAuthRepository())
      ..isRestoring = false
      ..user = _parentMarie();
    await tester.pumpWidget(appWith(auth, splashHold: kSplashHold));
    await tester.pump();

    expect(find.byKey(const Key('splash-page')), findsOneWidget);
    expect(find.byKey(const Key('main-shell')), findsNothing);

    await tester.pump(kSplashHold);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('splash-page')), findsNothing);
    expect(find.byKey(const Key('main-shell')), findsOneWidget);
    expect(find.text('Se connecter'), findsNothing);
  });

  testWidgets('welcome carousel shows three prevention scenes', (tester) async {
    final auth = AuthController(FakeAuthRepository())..isRestoring = false;
    await tester.pumpWidget(appWith(auth));
    await tester.pumpAndSettle();

    expect(PreventionCarousel.slides, hasLength(3));
    expect(find.byKey(const Key('prevention-carousel')), findsOneWidget);
    expect(find.byKey(const Key('prevention-dot-0')), findsOneWidget);
    expect(find.byKey(const Key('prevention-dot-1')), findsOneWidget);
    expect(find.byKey(const Key('prevention-dot-2')), findsOneWidget);
    expect(find.text(PreventionCarousel.slides[0].title), findsOneWidget);
    expect(find.text('Life360'), findsNothing);
    expect(find.text('citycare'), findsWidgets);

    await tester.tap(find.byKey(const Key('prevention-dot-1')));
    await tester.pumpAndSettle();
    expect(find.text(PreventionCarousel.slides[1].title), findsOneWidget);

    await tester.tap(find.byKey(const Key('prevention-dot-2')));
    await tester.pumpAndSettle();
    expect(find.text(PreventionCarousel.slides[2].title), findsOneWidget);
  });

  testWidgets('login screen validates empty phone', (tester) async {
    final auth = AuthController(FakeAuthRepository())..isRestoring = false;
    await tester.pumpWidget(appWith(auth));
    await tester.pumpAndSettle();

    expect(find.text('citycare'), findsWidgets);
    expect(find.byType(PreventionCarousel), findsOneWidget);
    expect(find.text(PreventionCarousel.slides[0].title), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Créer un compte'), findsOneWidget);
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();

    expect(find.text('Entrez votre numéro de téléphone'), findsOneWidget);
    expect(find.text('+237'), findsOneWidget);
    expect(find.text('6 XX XX XX XX'), findsOneWidget);
    expect(find.textContaining('Conditions d’utilisation'), findsOneWidget);
    expect(find.textContaining('CityCare'), findsWidgets);
    expect(find.text('Life360'), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('auth-phone-continue')));
    await tester.tap(find.byKey(const Key('auth-phone-continue')));
    await tester.pump();

    expect(find.text('Entrez un numéro de téléphone valide'), findsOneWidget);
  });

  testWidgets('login then shows demo OTP code', (tester) async {
    final user = UserAccount(
      id: '1',
      fullName: 'Marie',
      phone: '+237699000001',
      role: UserRole.parent,
      isActive: true,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final repo = FakeAuthRepository(session: AuthSession(token: 'tok', user: user));
    final auth = AuthController(repo)..isRestoring = false;
    await tester.pumpWidget(appWith(auth));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('auth-phone-field')), '699000001');
    await tester.tap(find.byKey(const Key('auth-phone-continue')));
    await tester.pumpAndSettle();

    expect(find.text('Entrez votre mot de passe'), findsOneWidget);
    expect(find.text('+237699000001'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('auth-password-field')), 'motdepasse');
    await tester.ensureVisible(find.byKey(const Key('auth-login-submit')));
    await tester.tap(find.byKey(const Key('auth-login-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repo.lastLoginPhone, '+237699000001');
    expect(find.textContaining('Mode démo'), findsWidgets);
    expect(find.text('123456'), findsOneWidget);
    expect(find.text('Valider le code'), findsOneWidget);
  });

  testWidgets('forgot password shows demo code then new password', (tester) async {
    final repo = FakeAuthRepository();
    final auth = AuthController(repo)..isRestoring = false;
    await tester.pumpWidget(appWith(auth));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('auth-phone-field')), '699000001');
    await tester.tap(find.byKey(const Key('auth-phone-continue')));
    await tester.pumpAndSettle();

    expect(find.text('Mot de passe oublié'), findsOneWidget);
    await tester.tap(find.byKey(const Key('auth-forgot-link')));
    await tester.pumpAndSettle();

    expect(find.text('Mot de passe oublié'), findsWidgets);
    await tester.ensureVisible(find.byKey(const Key('auth-forgot-phone-continue')));
    await tester.tap(find.byKey(const Key('auth-forgot-phone-continue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repo.lastForgotPhone, '+237699000001');
    expect(find.textContaining('Mode démo'), findsWidgets);
    expect(find.byKey(const Key('auth-forgot-demo-code')), findsOneWidget);
    expect(find.text('654321'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('auth-forgot-code-field')), '654321');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(const Key('auth-forgot-new-password')), findsOneWidget);
    expect(find.text('Nouveau mot de passe'), findsWidgets);
    await tester.enterText(find.byKey(const Key('auth-forgot-new-password')), 'Nouveaupass1!');
    await tester.enterText(find.byKey(const Key('auth-forgot-confirm-password')), 'Nouveaupass1!');
    await tester.ensureVisible(find.byKey(const Key('auth-forgot-submit')));
    await tester.tap(find.byKey(const Key('auth-forgot-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repo.lastResetPhone, '+237699000001');
    expect(repo.lastResetCode, '654321');
    expect(repo.lastResetPassword, 'Nouveaupass1!');
    expect(find.textContaining('Mot de passe mis à jour'), findsWidgets);
  });

  testWidgets('register screen shows optional email and Cameroon dial', (tester) async {
    final auth = AuthController(FakeAuthRepository())..isRestoring = false;
    await tester.pumpWidget(appWith(auth));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Créer un compte'));
    await tester.pumpAndSettle();

    expect(find.text('Créer un compte'), findsWidgets);
    expect(find.text('+237', skipOffstage: false), findsOneWidget);
    expect(find.text('E-mail (facultatif)', skipOffstage: false), findsOneWidget);
    expect(find.textContaining('Conditions d’utilisation', skipOffstage: false), findsOneWidget);
    expect(find.text('Mot de passe fort', skipOffstage: false), findsOneWidget);
    expect(find.text('Life360'), findsNothing);
  });

  testWidgets('logged in parent sees map shell', (tester) async {
    final user = UserAccount(
      id: '1',
      fullName: 'Marie',
      phone: '+237600000000',
      role: UserRole.parent,
      isActive: true,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final auth = AuthController(FakeAuthRepository())
      ..isRestoring = false
      ..user = user;
    await tester.pumpWidget(appWith(auth));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('main-shell')), findsOneWidget);
    expect(find.text('Accueil'), findsOneWidget);
    expect(find.text('Membres'), findsOneWidget);
    expect(find.text('Alertes'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
    expect(find.byKey(const Key('sos-fab')), findsOneWidget);
    expect(find.text('SOS'), findsWidgets);
    expect(find.text('Aucun jeune rattaché'), findsOneWidget);

    await tester.tap(find.text('Membres'));
    await tester.pump();
    expect(find.text('Mes enfants / jeunes'), findsOneWidget);

    await tester.tap(find.text('Alertes'));
    await tester.pump();
    expect(find.text('Alertes SOS'), findsOneWidget);

    await tester.tap(find.text('Profil'));
    await tester.pump();
    expect(find.text('Bonjour Marie'), findsOneWidget);
    expect(find.text('Partage en arrière-plan'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -480));
    await tester.pump();
    expect(find.text('Zones à risque'), findsOneWidget);
    expect(find.text('Dossiers de disparition'), findsOneWidget);

    await tester.tap(find.text('Toutes les fonctions'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Toutes les fonctions'), findsWidgets);
    expect(find.text('Notifications'), findsWidgets);
    final menuScroll = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(find.text('Alertes SOS'), 240, scrollable: menuScroll);
    expect(find.text('Alertes SOS'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Zones de sécurité'), 240, scrollable: menuScroll);
    expect(find.text('Zones de sécurité'), findsOneWidget);
  });

  testWidgets('logged in young sees map shell', (tester) async {
    final user = UserAccount(
      id: '2',
      fullName: 'Amina',
      phone: '+237600000001',
      role: UserRole.young,
      isActive: true,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final auth = AuthController(FakeAuthRepository())
      ..isRestoring = false
      ..user = user;
    await tester.pumpWidget(appWith(auth));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('main-shell')), findsOneWidget);
    expect(find.text('Accueil'), findsOneWidget);
    expect(find.text('Membres'), findsOneWidget);
    expect(find.text('Alertes'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
    expect(find.byKey(const Key('sos-fab')), findsOneWidget);
    expect(find.text('SOS'), findsWidgets);
    expect(find.text('Ma position'), findsOneWidget);

    await tester.tap(find.text('Membres'));
    await tester.pump();
    expect(find.text('Contacts de confiance'), findsOneWidget);

    await tester.tap(find.text('Alertes'));
    await tester.pump();
    expect(find.text('Notifications'), findsOneWidget);

    await tester.tap(find.text('Profil'));
    await tester.pump();
    expect(find.text('Bonjour Amina'), findsOneWidget);
    final profileScroll = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(find.text('Mon kit IoT'), 240, scrollable: profileScroll);
    expect(find.text('Mon kit IoT'), findsOneWidget);
    expect(find.text('Mon profil'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Dossiers de disparition'), 240, scrollable: profileScroll);
    expect(find.text('Dossiers de disparition'), findsOneWidget);

    await tester.tap(find.text('Toutes les fonctions'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('SOS'), findsWidgets);
    final youngScroll = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(find.text('Ma position'), 240, scrollable: youngScroll);
    expect(find.text('Ma position'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Mes zones de sécurité'), 240, scrollable: youngScroll);
    expect(find.text('Mes zones de sécurité'), findsOneWidget);
  });

  testWidgets('parent map sheet lists child with honest freshness', (tester) async {
    final user = UserAccount(
      id: '1',
      fullName: 'Marie',
      phone: '+237600000000',
      role: UserRole.parent,
      isActive: true,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final auth = AuthController(FakeAuthRepository())
      ..isRestoring = false
      ..user = user;
    await tester.pumpWidget(
      appWith(
        auth,
        family: FamilyController(_OneChildFamily()),
        location: LocationController(_ChildWatchLocation()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byKey(const Key('map-member-sheet')), findsOneWidget);
    expect(find.text('Amina'), findsWidgets);
    expect(find.textContaining('Dernière position : il y a 10 min'), findsWidgets);
    expect(find.byKey(const Key('map-pin-callout-young-yp-1')), findsOneWidget);
    expect(find.textContaining('Batterie kit : 41 %'), findsWidgets);
    expect(find.textContaining('temps réel'), findsNothing);
    expect(find.text('Membres'), findsOneWidget);

    await tester.tap(find.byTooltip('Position et trajectoire'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Position · Amina'), findsOneWidget);
  });

  testWidgets('young map sheet shows self and guardians', (tester) async {
    final user = UserAccount(
      id: '2',
      fullName: 'Amina',
      phone: '+237600000001',
      role: UserRole.young,
      isActive: true,
      youngPersonId: 'yp-1',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final auth = AuthController(FakeAuthRepository())
      ..isRestoring = false
      ..user = user;
    await tester.pumpWidget(
      appWith(
        auth,
        family: FamilyController(_YoungWithGuardian()),
        location: LocationController(_FixedLocationRepository(
          TrackerLocation(
            id: 'loc-self',
            youngPersonId: 'yp-1',
            source: LocationSource.phone,
            latitude: 3.848,
            longitude: 11.502,
            recordedAt: DateTime.utc(2026, 8, 29, 21),
            isStale: false,
            ageSeconds: 20,
          ),
        )),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byKey(const Key('map-member-sheet')), findsOneWidget);
    expect(find.text('Amina'), findsWidgets);
    expect(find.text('Ma position'), findsOneWidget);
    expect(find.text('Marie', skipOffstage: false), findsWidgets);
    expect(find.textContaining('Mis à jour il y a 20 s'), findsWidgets);
    expect(find.byKey(const Key('map-pin-callout-self-2')), findsOneWidget);
    expect(find.textContaining('Partage on'), findsWidgets);
    expect(find.textContaining('temps réel'), findsNothing);

    await tester.tap(find.text('Membres'));
    await tester.pump();
    expect(find.text('Contacts de confiance'), findsOneWidget);
  });

  testWidgets('stale location is labelled as not current on the map page', (tester) async {
    final point = TrackerLocation(
      id: 'loc-1',
      youngPersonId: 'yp-1',
      source: LocationSource.phone,
      latitude: 3.848,
      longitude: 11.502,
      recordedAt: DateTime.utc(2026, 8, 28, 3),
      isStale: true,
      ageSeconds: 600,
    );
    await tester.pumpWidget(
      RiskZoneScope(
        controller: RiskZoneController(FakeRiskZoneRepository()),
        child: ZoneScope(
          controller: ZoneController(FakeZoneRepository()),
          child: LocationScope(
            controller: LocationController(_FixedLocationRepository(point)),
            child: const MaterialApp(home: MyPositionPage()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('pas la position actuelle'), findsWidgets);
    expect(find.textContaining('suivi en direct'), findsWidgets);
  });

  testWidgets('SOS page says it is not a confirmed kidnapping', (tester) async {
    await tester.pumpWidget(
      AlertScope(
        controller: AlertController(FakeAlertRepository()),
        child: const MaterialApp(home: SosPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('kidnapping confirmé'), findsWidgets);
    expect(find.textContaining('notification push'), findsOneWidget);
    expect(find.text('SOS discret'), findsOneWidget);
    expect(find.text('SOS vocal'), findsOneWidget);
  });

  testWidgets('SOS detail can close without claiming kidnapping', (tester) async {
    final user = UserAccount(
      id: '1',
      fullName: 'Marie',
      phone: '+237600000000',
      role: UserRole.parent,
      isActive: true,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final auth = AuthController(FakeAuthRepository())
      ..isRestoring = false
      ..user = user;
    final at = DateTime.utc(2026, 8, 24, 15, 52);
    await tester.pumpWidget(
      AuthScope(
        controller: auth,
        child: AlertScope(
          controller: AlertController(_OpenSosRepository(at)),
          child: const MaterialApp(home: SosDetailPage(alertId: 'sos-1')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Clore le SOS'), findsOneWidget);
    expect(find.textContaining('n’est pas un kidnapping confirmé'), findsWidgets);
    expect(find.text('Prendre en compte'), findsOneWidget);
  });

  testWidgets('emergency mode page is last known not live', (tester) async {
    await tester.pumpWidget(
      LocationScope(
        controller: LocationController(_EmergencyLocationRepository()),
        child: const MaterialApp(
          home: EmergencyModePage(youngPersonId: 'yp-1', displayName: 'Amina'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('MODE URGENCE'), findsWidgets);
    expect(find.textContaining('pas un suivi en direct'), findsWidgets);
    expect(find.textContaining('kidnapping confirmé'), findsWidgets);
    expect(find.textContaining('Batterie kit'), findsOneWidget);
    expect(find.textContaining('Connexion avec le kit perdue'), findsWidgets);
    expect(find.textContaining('Traces kit'), findsOneWidget);
    expect(find.textContaining('pas la position actuelle'), findsWidgets);
  });

  testWidgets('lost kit is labelled last-known not current', (tester) async {
    await tester.pumpWidget(
      TrackerScope(
        controller: TrackerController(_LostKitRepository()),
        child: const MaterialApp(home: KitPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('Connexion avec le kit perdue'), findsWidgets);
    expect(find.textContaining('Dernière position connue'), findsWidgets);
    expect(find.textContaining('pas actuelle'), findsWidgets);
  });

  testWidgets('kit event history is a dated trace not live', (tester) async {
    final repo = _LostKitRepository();
    final kits = TrackerController(repo);
    kits.items = await repo.mine();
    kits.events = await repo.events('kit-1');
    await tester.pumpWidget(
      TrackerScope(
        controller: kits,
        child: const MaterialApp(home: KitDetailPage(trackerId: 'kit-1')),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Historique kit'), findsOneWidget);
    expect(find.textContaining('Connexion avec le kit perdue'), findsWidgets);
    expect(find.textContaining('pas la position actuelle'), findsWidgets);
  });

  testWidgets('parent child card has trajectory and search shortcuts', (tester) async {
    await tester.pumpWidget(
      FamilyScope(
        controller: FamilyController(_OneChildFamily()),
        child: TrackerScope(
          controller: TrackerController(FakeTrackerRepository()),
          child: LocationScope(
            controller: LocationController(FakeLocationRepository()),
            child: const MaterialApp(home: ChildrenPage()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Amina'), findsOneWidget);
    expect(find.text('Trajectoire'), findsOneWidget);
    expect(find.text('Recherche'), findsOneWidget);
    expect(find.textContaining('pas un suivi en direct'), findsWidgets);
  });

  testWidgets('parent child card shows limited share not live gps', (tester) async {
    await tester.pumpWidget(
      FamilyScope(
        controller: FamilyController(_OneChildFamily()),
        child: TrackerScope(
          controller: TrackerController(FakeTrackerRepository()),
          child: LocationScope(
            controller: LocationController(_ShareInboxLocation()),
            child: const MaterialApp(home: ChildrenPage()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('Partage limité'), findsOneWidget);
    expect(find.textContaining('pas un GPS continu'), findsOneWidget);
  });

  testWidgets('zones page labels last-known occupancy as active safety zone', (tester) async {
    await tester.pumpWidget(
      ZoneScope(
        controller: ZoneController(_InsideZoneRepository()),
        child: const MaterialApp(home: SafetyZonesPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('École'), findsOneWidget);
    expect(find.textContaining('Zone de sécurité active'), findsOneWidget);
    expect(find.textContaining('pas actuelle'), findsOneWidget);
  });

  testWidgets('notifications inbox is in-app and opens as last-known not live', (tester) async {
    final user = UserAccount(
      id: '1',
      fullName: 'Marie',
      phone: '+237600000000',
      role: UserRole.parent,
      isActive: true,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final auth = AuthController(FakeAuthRepository())
      ..isRestoring = false
      ..user = user;
    await tester.pumpWidget(
      AuthScope(
        controller: auth,
        child: NotificationScope(
          controller: NotificationController(_GeofenceInboxRepository()),
          child: const MaterialApp(home: NotificationsPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('push FCM'), findsWidgets);
    expect(find.textContaining('kidnapping confirmé'), findsWidgets);
    expect(find.text('Sortie de zone'), findsOneWidget);
    expect(find.textContaining('École'), findsOneWidget);
    expect(find.textContaining('pas actuelle'), findsWidgets);
  });

  testWidgets('anomaly inbox shows rules not kidnapping', (tester) async {
    final user = UserAccount(
      id: '1',
      fullName: 'Marie',
      phone: '+237600000000',
      role: UserRole.parent,
      isActive: true,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final auth = AuthController(FakeAuthRepository())
      ..isRestoring = false
      ..user = user;
    await tester.pumpWidget(
      AuthScope(
        controller: auth,
        child: NotificationScope(
          controller: NotificationController(_AnomalyInboxRepository()),
          child: const MaterialApp(home: NotificationsPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Anomalie détectée'), findsOneWidget);
    expect(find.textContaining('Arrêt prolongé'), findsWidgets);
    expect(find.textContaining('machine learning'), findsWidgets);
    expect(find.textContaining('kidnapping confirmé'), findsWidgets);
    expect(find.textContaining('Random Forest'), findsNothing);
  });

  testWidgets('map banner shows recent anomaly without claiming kidnapping', (tester) async {
    final auth = AuthController(FakeAuthRepository())
      ..isRestoring = false
      ..user = _parentMarie();
    final inbox = NotificationController(_AnomalyInboxRepository());
    await tester.pumpWidget(appWith(auth, notifications: inbox));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byKey(const Key('map-anomaly-banner')), findsOneWidget);
    expect(find.textContaining('Anomalie détectée'), findsWidgets);
    expect(find.textContaining('pas de ML'), findsWidgets);
    expect(find.textContaining('kidnapping confirmé'), findsWidgets);
  });

  testWidgets('open case can start a search without claiming kidnapping', (tester) async {
    final user = UserAccount(
      id: '1',
      fullName: 'Marie',
      phone: '+237600000000',
      role: UserRole.parent,
      isActive: true,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final auth = AuthController(FakeAuthRepository())
      ..isRestoring = false
      ..user = user;
    final at = DateTime.utc(2026, 8, 24, 15, 52);
    final item = MissingPersonCase(
      id: 'case-1',
      youngPersonId: 'yp-1',
      reportedByUserId: '1',
      occurredAt: at,
      status: CaseStatus.open,
      priority: CasePriority.medium,
      createdAt: at,
      updatedAt: at,
      youngDisplayName: 'Amina',
      snapshot: const {
        'disclaimer': 'Ce n’est pas un kidnapping confirmé.',
      },
    );
    final caseController = CaseController(_OpenCaseRepository(item))..current = item;
    await tester.pumpWidget(
      AuthScope(
        controller: auth,
        child: FamilyScope(
          controller: FamilyController(_OneChildFamily()),
          child: CaseScope(
            controller: caseController,
            child: const MaterialApp(home: CaseDetailPage(caseId: 'case-1')),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final scroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Démarrer la recherche'), 200, scrollable: scroll);

    expect(find.text('Démarrer la recherche'), findsOneWidget);
    expect(find.textContaining('n’est pas un kidnapping confirmé'), findsWidgets);
    expect(find.text('Marquer comme retrouvé'), findsOneWidget);
  });

  testWidgets('onboarding never replaces welcome before login', (tester) async {
    final auth = AuthController(FakeAuthRepository())..isRestoring = false;
    await tester.pumpWidget(appWith(auth, onboarding: OnboardingController.memory()));
    await tester.pumpAndSettle();

    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-page')), findsNothing);
    expect(find.byKey(const Key('main-shell')), findsNothing);
  });

  testWidgets('first session shows onboarding then skip reaches shell', (tester) async {
    final store = MemoryOnboardingStore();
    final onboarding = OnboardingController(store)
      ..isLoading = false
      ..isCompleted = false;
    final auth = AuthController(FakeAuthRepository())
      ..isRestoring = false
      ..user = _parentMarie();
    await tester.pumpWidget(
      appWith(
        auth,
        onboarding: onboarding,
        location: LocationController(
          FakeLocationRepository(),
          device: _ScriptedLocationDevice(const LocationAccess(LocationAccessStatus.denied)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('onboarding-page')), findsOneWidget);
    expect(find.byKey(const Key('main-shell')), findsNothing);
    expect(OnboardingPage.slides, hasLength(3));
    expect(find.text('Pourquoi la localisation ?'), findsOneWidget);
    expect(find.text('Passer'), findsOneWidget);
    expect(find.text('Life360'), findsNothing);

    await tester.tap(find.byKey(const Key('onboarding-skip')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('setup-onboarding-page')), findsOneWidget);
    expect(find.text('Avez-vous un traceur ?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('setup-skip')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('main-shell')), findsOneWidget);
    expect(find.byKey(const Key('onboarding-page')), findsNothing);
    expect(onboarding.isCompleted, isTrue);
    expect(onboarding.isSetupCompleted, isTrue);
    expect(store.completed, isTrue);
  });

  testWidgets('onboarding location allow calls requestAccess', (tester) async {
    final device = _ScriptedLocationDevice(const LocationAccess(LocationAccessStatus.denied));
    final auth = AuthController(FakeAuthRepository())
      ..isRestoring = false
      ..user = _parentMarie();
    await tester.pumpWidget(
      appWith(
        auth,
        onboarding: OnboardingController.memory(),
        location: LocationController(FakeLocationRepository(), device: device),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('onboarding-allow-location')), findsOneWidget);
    device.access = const LocationAccess(LocationAccessStatus.granted);
    await tester.tap(find.byKey(const Key('onboarding-allow-location')));
    await tester.pumpAndSettle();

    expect(device.requests, 1);
    expect(find.text('Localisation autorisée'), findsWidgets);
  });

  testWidgets('onboarding denied forever opens app settings', (tester) async {
    final device = _ScriptedLocationDevice(
      const LocationAccess(LocationAccessStatus.deniedForever),
    );
    final auth = AuthController(FakeAuthRepository())
      ..isRestoring = false
      ..user = _parentMarie();
    await tester.pumpWidget(
      appWith(
        auth,
        onboarding: OnboardingController.memory(),
        location: LocationController(FakeLocationRepository(), device: device),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Localisation bloquée dans les réglages'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-open-settings')), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-open-settings')));
    await tester.pumpAndSettle();

    expect(device.appSettings, 1);
    expect(device.requests, 0);
  });

  testWidgets('onboarding GPS off opens location settings', (tester) async {
    final device = _ScriptedLocationDevice(
      const LocationAccess(LocationAccessStatus.serviceDisabled),
    );
    final auth = AuthController(FakeAuthRepository())
      ..isRestoring = false
      ..user = _parentMarie();
    await tester.pumpWidget(
      appWith(
        auth,
        onboarding: OnboardingController.memory(),
        location: LocationController(FakeLocationRepository(), device: device),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('La localisation du téléphone est éteinte'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-open-settings')));
    await tester.pumpAndSettle();

    expect(device.locationSettings, 1);
    expect(device.requests, 0);
  });

  testWidgets('onboarding notifications allow calls FCM client', (tester) async {
    final notif = _ScriptedNotifications(
      const NotificationAccess(NotificationAccessStatus.denied),
    );
    final auth = AuthController(FakeAuthRepository())
      ..isRestoring = false
      ..user = _parentMarie();
    await tester.pumpWidget(
      appWith(
        auth,
        onboarding: OnboardingController.memory(),
        notificationPermission: notif,
        location: LocationController(
          FakeLocationRepository(),
          device: _ScriptedLocationDevice(const LocationAccess(LocationAccessStatus.denied)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('onboarding-dot-1')));
    await tester.pumpAndSettle();

    expect(find.text('Pourquoi les notifications ?'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-allow-notifications')), findsOneWidget);
    notif.access = const NotificationAccess(NotificationAccessStatus.granted);
    await tester.tap(find.byKey(const Key('onboarding-allow-notifications')));
    await tester.pumpAndSettle();

    expect(notif.requests, 1);
    expect(find.text('Notifications autorisées'), findsWidgets);
  });

  testWidgets('onboarding background slide is honest then finishes', (tester) async {
    final store = MemoryOnboardingStore();
    final onboarding = OnboardingController(store)
      ..isLoading = false
      ..isCompleted = false;
    final auth = AuthController(FakeAuthRepository())
      ..isRestoring = false
      ..user = _parentMarie();
    await tester.pumpWidget(
      appWith(
        auth,
        onboarding: onboarding,
        location: LocationController(
          FakeLocationRepository(),
          device: _ScriptedLocationDevice(const LocationAccess(LocationAccessStatus.denied)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('onboarding-dot-2')));
    await tester.pumpAndSettle();

    expect(find.text('Localisation en arrière-plan'), findsOneWidget);
    expect(find.textContaining('optionnel'), findsWidgets);
    expect(find.textContaining('pas encore actif'), findsNothing);
    expect(find.textContaining('Partage en arrière-plan'), findsWidgets);
    expect(find.textContaining('Rien n’est activé en secret'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-finish')), findsOneWidget);
    expect(find.byKey(const Key('onboarding-allow-location')), findsNothing);

    await tester.tap(find.byKey(const Key('onboarding-finish')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('setup-onboarding-page')), findsOneWidget);
    await tester.tap(find.byKey(const Key('setup-skip')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('main-shell')), findsOneWidget);
    expect(onboarding.isCompleted, isTrue);
    expect(onboarding.isSetupCompleted, isTrue);
  });
}

class _EmergencyLocationRepository extends FakeLocationRepository {
  @override
  Future<EmergencySnapshot> emergency(String youngPersonId) async {
    return EmergencySnapshot(
      youngPersonId: youngPersonId,
      displayName: 'Amina',
      effectiveMode: TrackingMode.emergency,
      isLive: false,
      access: 'EMERGENCY',
      disclaimer:
          'MODE URGENCE. Dernière position connue, pas un suivi en direct, pas un kidnapping confirmé.',
      lastKnown: TrackerLocation(
        id: 'loc-e',
        youngPersonId: youngPersonId,
        source: LocationSource.phone,
        latitude: 3.848,
        longitude: 11.502,
        recordedAt: DateTime.utc(2026, 8, 28, 6),
        isStale: true,
        ageSeconds: 120,
        batteryLevel: 41,
      ),
      lastCommunicationAt: DateTime.utc(2026, 8, 28, 6),
      batteryLevel: 41,
      kitStatus: 'SIGNAL_LOST',
      kitLabel: 'Kit CityCare',
      kitEvents: [
        TrackerEvent(
          id: 'evt-lost',
          youngPersonId: youngPersonId,
          eventType: TrackerEventType.signalLost,
          recordedAt: DateTime.utc(2026, 8, 28, 6),
        ),
      ],
    );
  }
}

class _FixedLocationRepository extends FakeLocationRepository {
  _FixedLocationRepository(this.point);

  final TrackerLocation point;

  @override
  Future<TrackerLocation> myLatest() async => point;

  @override
  Future<List<TrackerLocation>> myHistory({int limit = 20}) async => [point];
}

class _ChildWatchLocation extends FakeLocationRepository {
  @override
  Future<LocationWatch> watchChild(String youngPersonId) async {
    return LocationWatch(
      latest: TrackerLocation(
        id: 'loc-child',
        youngPersonId: youngPersonId,
        source: LocationSource.iot,
        latitude: 3.868,
        longitude: 11.518,
        recordedAt: DateTime.utc(2026, 8, 29, 20),
        batteryLevel: 41,
        isStale: true,
        ageSeconds: 600,
      ),
      pollAfterSeconds: 60,
      effectiveMode: TrackingMode.normal,
      access: 'PERMISSION',
      message: 'Dernière position connue, pas un suivi en direct.',
    );
  }
}

class _YoungWithGuardian extends FakeFamilyRepository {
  @override
  Future<List<GuardianLink>> guardians() async => [
        const GuardianLink(
          id: 'l-g',
          guardianUserId: 'g-1',
          youngPersonId: 'yp-1',
          relation: GuardianRelation.parent,
          status: GuardianLinkStatus.active,
          canViewLocation: true,
          canReceiveAlerts: true,
          canTriggerAlert: false,
          canReportMissing: true,
          canManageZones: true,
          canManageTracker: true,
          guardianName: 'Marie',
        ),
      ];
}

class _OneChildFamily extends FakeFamilyRepository {
  @override
  Future<List<GuardianLink>> children() async => [
        const GuardianLink(
          id: 'l-1',
          guardianUserId: 'g-1',
          youngPersonId: 'yp-1',
          relation: GuardianRelation.parent,
          status: GuardianLinkStatus.active,
          canViewLocation: false,
          canReceiveAlerts: true,
          canTriggerAlert: false,
          canReportMissing: true,
          canManageZones: true,
          canManageTracker: true,
          youngDisplayName: 'Amina',
          youngPhone: '+237699000002',
        ),
      ];
}

class _ShareInboxLocation extends FakeLocationRepository {
  @override
  Future<List<PositionShare>> receivedShares() async => [
        PositionShare(
          id: 's-1',
          youngPersonId: 'yp-1',
          targetUserId: 'g-1',
          startsAt: DateTime.utc(2026, 8, 29, 8),
          expiresAt: DateTime.utc(2026, 8, 29, 16),
          isRevoked: false,
          isActive: true,
          youngDisplayName: 'Amina',
        ),
      ];
}

class _OpenCaseRepository extends FakeCaseRepository {
  _OpenCaseRepository(this.item);

  final MissingPersonCase item;

  @override
  Future<MissingPersonCase> getById(String caseId) async => item;

  @override
  Future<Trajectory> trajectory(String caseId) async {
    throw const ApiException('pas un suivi en direct', statusCode: 403);
  }

  @override
  Future<SearchIntelligence> intelligence(String caseId) async {
    throw const ApiException('pas un kidnapping confirmé', statusCode: 404);
  }

  @override
  Future<AiAnalysis> aiAnalysis(String caseId) async {
    throw const ApiException('pas un modèle entraîné', statusCode: 404);
  }
}

class _LostKitRepository extends FakeTrackerRepository {
  @override
  Future<List<GpsTracker>> mine() async => [
        GpsTracker(
          id: 'kit-1',
          youngPersonId: 'yp-1',
          deviceUid: 'CCKIT-TEST',
          label: 'Bracelet démo',
          status: TrackerStatus.signalLost,
          trackingMode: TrackingMode.normal,
          batteryLevel: 71,
          lastSeenAt: DateTime.utc(2026, 8, 24, 15, 54),
        ),
      ];

  @override
  Future<List<TrackerEvent>> events(String trackerId, {int limit = 30}) async => [
        TrackerEvent(
          id: 'ev-1',
          youngPersonId: 'yp-1',
          trackerId: trackerId,
          eventType: TrackerEventType.signalLost,
          recordedAt: DateTime.utc(2026, 8, 24, 15, 54),
        ),
      ];
}

class _InsideZoneRepository extends FakeZoneRepository {
  @override
  Future<List<SafetyZone>> myZones() async => [
        const SafetyZone(
          id: 'zone-1',
          youngPersonId: 'yp-1',
          name: 'École',
          latitude: 3.868,
          longitude: 11.521,
          radiusMeters: 300,
          isActive: true,
          accuracyToleranceMeters: 40,
          minExitDurationSeconds: 0,
          insideOnLastFix: true,
        ),
      ];
}

class _AnomalyInboxRepository extends FakeNotificationRepository {
  @override
  Future<List<AppNotification>> mine({int limit = 50, bool unreadOnly = false}) async => [
        AppNotification(
          id: 'n-ano',
          recipientUserId: '1',
          notificationType: NotificationType.anomaly,
          title: 'Anomalie détectée',
          body:
              'Anomalie détectée (MEDIUM) concernant Amina.\n'
              '- Arrêt prolongé inhabituel (~24 min) hors zone de sécurité.\n'
              'Règles métier, pas de machine learning. Ce n’est pas un kidnapping confirmé.',
          isRead: false,
          createdAt: DateTime.now().toUtc().subtract(const Duration(minutes: 8)),
          context: const NotificationContext(
            channel: 'IN_APP',
            target: 'MAP',
            youngPersonId: 'yp-1',
            youngDisplayName: 'Amina',
            latitude: 3.848,
            longitude: 11.502,
            isLivePosition: false,
            disclaimer:
                'Inbox dans l’application, plus un push FCM si un jeton appareil est enregistré. '
                'Ce n’est pas un kidnapping confirmé.',
          ),
        ),
      ];
}

class _GeofenceInboxRepository extends FakeNotificationRepository {
  @override
  Future<List<AppNotification>> mine({int limit = 50, bool unreadOnly = false}) async => [
        AppNotification(
          id: 'n-1',
          recipientUserId: '1',
          notificationType: NotificationType.geofenceExit,
          title: 'Sortie de zone',
          body: 'Amina a quitté la zone « École » à 15:20. Ceci n’est pas un kidnapping.',
          isRead: false,
          createdAt: DateTime.utc(2026, 8, 24, 14, 20),
          context: const NotificationContext(
            channel: 'IN_APP',
            target: 'MAP',
            youngPersonId: 'yp-1',
            youngDisplayName: 'Amina',
            latitude: 3.873,
            longitude: 11.521,
            zoneName: 'École',
            isLivePosition: false,
            disclaimer:
                'Inbox dans l’application seulement, pas de notification push. Ce n’est pas un kidnapping confirmé.',
          ),
        ),
      ];
}
