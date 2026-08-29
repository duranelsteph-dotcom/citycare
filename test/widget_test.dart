import 'package:citycare/app/citycare_app.dart';
import 'package:citycare/core/errors/api_exception.dart';
import 'package:citycare/domain/entities/alerts.dart';
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
import 'package:citycare/presentation/family/children_page.dart';
import 'package:citycare/presentation/family/family_controller.dart';
import 'package:citycare/presentation/family/family_scope.dart';
import 'package:citycare/presentation/location/emergency_page.dart';
import 'package:citycare/presentation/location/location_controller.dart';
import 'package:citycare/presentation/location/location_scope.dart';
import 'package:citycare/presentation/location/position_pages.dart';
import 'package:citycare/presentation/notifications/notification_controller.dart';
import 'package:citycare/presentation/notifications/notification_scope.dart';
import 'package:citycare/presentation/notifications/notifications_page.dart';
import 'package:citycare/presentation/risk/risk_zone_controller.dart';
import 'package:citycare/presentation/risk/risk_zone_scope.dart';
import 'package:citycare/presentation/trackers/kit_detail_page.dart';
import 'package:citycare/presentation/trackers/kit_page.dart';
import 'package:citycare/presentation/trackers/tracker_controller.dart';
import 'package:citycare/presentation/trackers/tracker_scope.dart';
import 'package:citycare/presentation/zones/zone_controller.dart';
import 'package:citycare/presentation/zones/zone_pages.dart';
import 'package:citycare/presentation/zones/zone_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.session});

  AuthSession? session;
  String? token;

  @override
  Future<void> clearToken() async => token = null;

  @override
  Future<AuthSession> login({required String phone, required String password}) async {
    final current = session;
    if (current == null) {
      throw StateError('No session');
    }
    token = current.token;
    return current;
  }

  @override
  Future<UserAccount> me(String token) async {
    return session!.user;
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
    return login(phone: phone, password: password);
  }

  @override
  Future<void> saveToken(String value) async => token = value;
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
  Future<YoungPerson> youngProfile() async => throw UnimplementedError();

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
  Future<TrackerLocation> publishPhoneFix({
    required double latitude,
    required double longitude,
    double? accuracy,
    double? altitude,
    double? speed,
    double? heading,
    DateTime? recordedAt,
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
}

Widget appWith(AuthController auth) {
  return CityCareApp(
    auth: auth,
    family: FamilyController(FakeFamilyRepository()),
    location: LocationController(FakeLocationRepository()),
    zones: ZoneController(FakeZoneRepository()),
    notifications: NotificationController(FakeNotificationRepository()),
    riskZones: RiskZoneController(FakeRiskZoneRepository()),
    alerts: AlertController(FakeAlertRepository()),
    trackers: TrackerController(FakeTrackerRepository()),
    cases: CaseController(FakeCaseRepository()),
  );
}

void main() {
  testWidgets('login screen validates empty phone', (tester) async {
    final auth = AuthController(FakeAuthRepository())..isRestoring = false;
    await tester.pumpWidget(appWith(auth));
    await tester.pumpAndSettle();

    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.textContaining('jeton'), findsOneWidget);
    expect(find.textContaining('HTTPS'), findsOneWidget);
    await tester.tap(find.text('Se connecter'));
    await tester.pump();

    expect(find.text('Entrez un numéro de téléphone valide'), findsOneWidget);
  });

  testWidgets('logged in parent sees role home', (tester) async {
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
    await tester.pumpAndSettle();

    expect(find.text('Bonjour Marie'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Zones à risque'), findsOneWidget);
    expect(find.text('Alertes SOS'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Dossiers de disparition'), 200);
    expect(find.text('Dossiers de disparition'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Zones de sécurité'), 200);
    expect(find.text('Zones de sécurité'), findsOneWidget);
  });

  testWidgets('logged in young sees position entry', (tester) async {
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
    await tester.pumpAndSettle();

    expect(find.text('Zones à risque'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('SOS'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Mon kit IoT'), 200);
    expect(find.text('Mon kit IoT'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Ma position'), 200);
    expect(find.text('Ma position'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Mes zones de sécurité'), 200);
    expect(find.text('Mes zones de sécurité'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Dossiers de disparition'), 200);
    expect(find.text('Dossiers de disparition'), findsOneWidget);
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
    await tester.pumpWidget(
      AuthScope(
        controller: auth,
        child: FamilyScope(
          controller: FamilyController(_OneChildFamily()),
          child: CaseScope(
            controller: CaseController(_OpenCaseRepository(item)),
            child: const MaterialApp(home: CaseDetailPage(caseId: 'case-1')),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Démarrer la recherche'), findsOneWidget);
    expect(find.textContaining('n’est pas un kidnapping confirmé'), findsWidgets);
    expect(find.text('Marquer comme retrouvé'), findsOneWidget);
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
