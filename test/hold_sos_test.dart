import 'package:citycare/data/datasources/device_location_service.dart';
import 'package:citycare/domain/entities/location_access.dart';
import 'package:citycare/domain/entities/alerts.dart';
import 'package:citycare/domain/entities/identity.dart';
import 'package:citycare/domain/enums/citycare_enums.dart';
import 'package:citycare/domain/repositories/alert_repository.dart';
import 'package:citycare/presentation/alerts/alert_controller.dart';
import 'package:citycare/presentation/alerts/alert_scope.dart';
import 'package:citycare/presentation/alerts/hold_sos_fab.dart';
import 'package:citycare/presentation/auth/auth_controller.dart';
import 'package:citycare/presentation/auth/auth_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'widget_test.dart';

class _RecordingAlerts extends FakeAlertRepository {
  SosDraft? last;
  String? cancelledId;

  @override
  Future<Alert> triggerSos(SosDraft draft) async {
    last = draft;
    final at = DateTime.utc(2026, 8, 30);
    return Alert(
      id: 'sos-hold',
      youngPersonId: 'yp-1',
      source: draft.source ?? AlertSource.mobile,
      status: AlertStatus.active,
      severity: AlertSeverity.critical,
      triggeredAt: at,
      createdAt: at,
      updatedAt: at,
    );
  }

  @override
  Future<Alert> cancel(String alertId) async {
    cancelledId = alertId;
    final at = DateTime.utc(2026, 8, 30);
    return Alert(
      id: alertId,
      youngPersonId: 'yp-1',
      source: AlertSource.mobile,
      status: AlertStatus.cancelled,
      severity: AlertSeverity.critical,
      triggeredAt: at,
      createdAt: at,
      updatedAt: at,
    );
  }
}

AuthController _amina() {
  return AuthController(FakeAuthRepository())
    ..isRestoring = false
    ..user = UserAccount(
      id: '2',
      fullName: 'Amina',
      phone: '+237600000001',
      role: UserRole.young,
      isActive: true,
      youngPersonId: 'yp-1',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
}

Widget _fabApp({
  required _RecordingAlerts repo,
  required AuthController auth,
  VoidCallback? onShortPress,
  Duration hold = const Duration(milliseconds: 80),
}) {
  return AuthScope(
    controller: auth,
    child: AlertScope(
      controller: AlertController(repo, device: _InstantLocation()),
      child: MaterialApp(
        theme: cityCareTestTheme(),
        home: Scaffold(
          floatingActionButton: HoldSosFab(
            role: UserRole.young,
            holdDuration: hold,
            onShortPress: onShortPress ?? () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('FAB SOS est un cercle, l’appui court n’envoie pas', (tester) async {
    final repo = _RecordingAlerts();
    var short = 0;
    await tester.pumpWidget(
      _fabApp(repo: repo, auth: _amina(), onShortPress: () => short += 1),
    );
    await tester.pump();

    expect(find.byKey(const Key('sos-fab')), findsOneWidget);
    expect(find.text('SOS'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sos-fab')));
    await tester.pump();
    expect(short, 1);
    expect(repo.last, isNull);
  });

  testWidgets('maintien du FAB SOS déclenche l’envoi', (tester) async {
    final repo = _RecordingAlerts();
    await tester.pumpWidget(_fabApp(repo: repo, auth: _amina()));
    await tester.pump();

    await tester.startGesture(tester.getCenter(find.byKey(const Key('sos-fab'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(repo.last, isNotNull);
    expect(repo.last!.description, contains('maintenu'));
    expect(find.textContaining('SOS envoyé'), findsWidgets);
    expect(find.byKey(const Key('sos-cancel')), findsOneWidget);
  });

  testWidgets('Annuler pendant le maintien n’envoie pas', (tester) async {
    final repo = _RecordingAlerts();
    await tester.pumpWidget(
      _fabApp(repo: repo, auth: _amina(), hold: const Duration(milliseconds: 400)),
    );
    await tester.pump();

    await tester.startGesture(tester.getCenter(find.byKey(const Key('sos-fab'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byKey(const Key('sos-cancel')), findsOneWidget);

    await tester.tap(find.byKey(const Key('sos-cancel')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repo.last, isNull);
    expect(find.textContaining('SOS envoyé'), findsNothing);
  });

  testWidgets('Annuler après envoi appelle l’API cancel', (tester) async {
    final repo = _RecordingAlerts();
    await tester.pumpWidget(_fabApp(repo: repo, auth: _amina()));
    await tester.pump();

    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('sos-fab'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pump();

    expect(repo.last, isNotNull);
    expect(find.byKey(const Key('sos-cancel')), findsOneWidget);

    await tester.tap(find.byKey(const Key('sos-cancel')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(repo.cancelledId, 'sos-hold');
    expect(find.textContaining('SOS annulé'), findsOneWidget);
  });
}

class _InstantLocation extends DeviceLocationService {
  @override
  Future<LocationAccess> requestAccess() async {
    return const LocationAccess(LocationAccessStatus.denied);
  }

  @override
  Future<Position> currentFix() async {
    throw const DeviceLocationException('Pas de GPS en test');
  }
}
