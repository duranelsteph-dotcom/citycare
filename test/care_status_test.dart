import 'package:citycare/app/brand.dart';
import 'package:citycare/domain/entities/alerts.dart';
import 'package:citycare/domain/entities/location_access.dart';
import 'package:citycare/domain/entities/tracking.dart';
import 'package:citycare/domain/enums/citycare_enums.dart';
import 'package:citycare/presentation/alerts/alert_controller.dart';
import 'package:citycare/presentation/location/location_controller.dart';
import 'package:citycare/presentation/location/maps/map_data.dart';
import 'package:citycare/presentation/map/care_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart';

TrackerLocation _point({
  required bool stale,
  required int ageSeconds,
  String youngPersonId = 'yp-1',
}) {
  return TrackerLocation(
    id: 'loc-1',
    youngPersonId: youngPersonId,
    source: LocationSource.phone,
    latitude: 3.848,
    longitude: 11.502,
    recordedAt: DateTime.utc(2026, 8, 30, 12),
    isStale: stale,
    ageSeconds: ageSeconds,
  );
}

Alert _sos({
  String youngPersonId = 'yp-1',
  AlertStatus status = AlertStatus.active,
}) {
  final at = DateTime.utc(2026, 8, 30, 12);
  return Alert(
    id: 'sos-1',
    youngPersonId: youngPersonId,
    source: AlertSource.mobile,
    status: status,
    severity: AlertSeverity.critical,
    triggeredAt: at,
    createdAt: at,
    updatedAt: at,
  );
}

AppNotification _anomaly({
  required DateTime createdAt,
  String? youngPersonId = 'yp-1',
}) {
  return AppNotification(
    id: 'n-1',
    recipientUserId: 'g-1',
    notificationType: NotificationType.anomaly,
    title: 'Position GPS incohérente',
    body: 'Ce n’est pas une sortie de zone, pas un kidnapping.',
    isRead: false,
    createdAt: createdAt,
    context: NotificationContext(
      channel: 'IN_APP',
      target: 'MAP',
      isLivePosition: false,
      disclaimer: 'Pas un kidnapping confirmé.',
      youngPersonId: youngPersonId,
    ),
  );
}

void main() {
  test('Danger : SOS ouvert pour ce membre, pas un autre', () {
    final danger = resolveCareStatus(point: _point(stale: false, ageSeconds: 10), hasOpenSos: true);
    expect(danger.level, CareLevel.danger);
    expect(danger.shortLabel, 'Danger');
    expect(danger.reason, 'SOS actif');
    expect(danger.disclaimer, contains('kidnapping'));
    expect(danger.shortLabel, isNot(contains('sécurité absolue')));

    expect(memberHasOpenSos(alerts: [_sos()], youngPersonId: 'yp-1'), isTrue);
    expect(memberHasOpenSos(alerts: [_sos()], youngPersonId: 'yp-autre'), isFalse);
    expect(memberHasOpenSos(alerts: [_sos(status: AlertStatus.resolved)], youngPersonId: 'yp-1'), isFalse);
  });

  test('Attention : stale, GPS off, hors-ligne, file, anomalie Phase 17', () {
    expect(resolveCareStatus(point: _point(stale: true, ageSeconds: 600)).level, CareLevel.attention);
    expect(resolveCareStatus(point: _point(stale: false, ageSeconds: 400)).reason, 'Position ancienne');
    expect(resolveCareStatus(point: null).reason, 'Hors ligne');
    expect(resolveCareStatus(point: _point(stale: false, ageSeconds: 8), gpsOff: true).reason, 'GPS éteint');
    expect(
      resolveCareStatus(point: _point(stale: false, ageSeconds: 8), queueUnsynced: true).reason,
      'File non synchronisée',
    );
    expect(
      resolveCareStatus(point: _point(stale: false, ageSeconds: 8), hasRecentAnomaly: true).reason,
      'Anomalie récente',
    );
  });

  test('Sécurisé : position fraîche sans alerte — Position récente, pas une garantie', () {
    final secure = resolveCareStatus(point: _point(stale: false, ageSeconds: 12));
    expect(secure.level, CareLevel.secure);
    expect(secure.shortLabel, 'Position récente');
    expect(secure.levelLabel, 'Sécurisé');
    expect(secure.disclaimer, contains('pas une garantie de sécurité'));
    expect(secure.shortLabel, isNot(contains('en sécurité')));
    expect(secure.disclaimer, isNot(contains('temps réel')));
  });

  test('SOS l’emporte sur stale, file et anomalie', () {
    final status = resolveCareStatus(
      point: _point(stale: true, ageSeconds: 900),
      hasOpenSos: true,
      queueUnsynced: true,
      hasRecentAnomaly: true,
    );
    expect(status.level, CareLevel.danger);
  });

  test('ANOMALY Phase 17 : récente pour ce jeune seulement', () {
    final now = DateTime.utc(2026, 8, 30, 12);
    final recent = _anomaly(createdAt: now.subtract(const Duration(minutes: 20)));
    final old = _anomaly(createdAt: now.subtract(const Duration(hours: 8)));
    final other = _anomaly(createdAt: now.subtract(const Duration(minutes: 5)), youngPersonId: 'yp-2');

    expect(inboxHasRecentAnomaly(inbox: [recent], youngPersonId: 'yp-1', now: now), isTrue);
    expect(inboxHasRecentAnomaly(inbox: [old], youngPersonId: 'yp-1', now: now), isFalse);
    expect(inboxHasRecentAnomaly(inbox: [other], youngPersonId: 'yp-1', now: now), isFalse);
    expect(inboxHasRecentAnomaly(inbox: [recent], youngPersonId: 'yp-1', now: now), isNot(equals(false)));
  });

  test('file SOS locale : Danger pour soi, pas un statut synchronisé', () {
    final locations = LocationController(FakeLocationRepository());
    locations.queue.enqueueSos({'young_person_id': 'yp-1'});
    locations.latest = _point(stale: false, ageSeconds: 5);
    final status = careStatusForMember(
      point: locations.latest,
      youngPersonId: 'yp-1',
      isSelf: true,
      locations: locations,
    );
    expect(status.level, CareLevel.danger);
    expect(locations.hasPendingOffline, isTrue);
  });

  test('GPS éteint local : Attention même si le dernier point est frais', () {
    final locations = LocationController(FakeLocationRepository());
    locations.latest = _point(stale: false, ageSeconds: 8);
    locations.locationAccess = const LocationAccess(LocationAccessStatus.serviceDisabled);
    final status = careStatusForMember(
      point: locations.latest,
      youngPersonId: 'yp-1',
      isSelf: true,
      locations: locations,
    );
    expect(status.level, CareLevel.attention);
    expect(status.reason, 'GPS éteint');
    expect(deviceGpsOff(locations.locationAccess), isTrue);
  });

  test('couleurs unifiées : vert / ambre / rouge SOS', () {
    expect(careLevelColor(CareLevel.secure), CityCareBrand.safe);
    expect(careLevelColor(CareLevel.attention), CityCareBrand.amberDark);
    expect(careLevelColor(CareLevel.danger), CityCareBrand.sos);
    expect(mapPinColor(const MapPin(latitude: 3.8, longitude: 11.5, careLevel: CareLevel.danger)), CityCareBrand.sos);
    expect(mapPinColor(const MapPin(latitude: 3.8, longitude: 11.5, ageSeconds: 20)), CityCareBrand.safe);
  });

  testWidgets('badge unique : Position récente + disclaimer honnête', (tester) async {
    final status = resolveCareStatus(point: _point(stale: false, ageSeconds: 9));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CareStatusBadge(status: status, compact: false, showDisclaimer: true),
        ),
      ),
    );
    expect(find.byKey(const Key('care-status-badge')), findsOneWidget);
    expect(find.byKey(const Key('care-status-secure')), findsOneWidget);
    expect(find.textContaining('Sécurisé'), findsWidgets);
    expect(find.textContaining('Position récente'), findsWidgets);
    expect(find.textContaining('pas une garantie de sécurité'), findsOneWidget);
    expect(find.textContaining('en sécurité absolue'), findsNothing);
    expect(find.textContaining('temps réel'), findsNothing);
  });

  testWidgets('badge Danger pour SOS actif', (tester) async {
    final status = resolveCareStatus(hasOpenSos: true);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: CareStatusBadge(status: status))),
    );
    expect(find.byKey(const Key('care-status-danger')), findsOneWidget);
    expect(find.text('Danger'), findsOneWidget);
  });

  test('careStatusForMember relie alerts + ANOMALY inbox existants', () {
    final now = DateTime.utc(2026, 8, 30, 13);
    final alerts = AlertController(FakeAlertRepository())..items = [_sos()];
    final inbox = [
      _anomaly(createdAt: now.subtract(const Duration(minutes: 10))),
    ];
    final sos = careStatusForMember(
      point: _point(stale: false, ageSeconds: 4),
      youngPersonId: 'yp-1',
      alerts: alerts.items,
      inbox: inbox,
      now: now,
    );
    expect(sos.level, CareLevel.danger);

    final attention = careStatusForMember(
      point: _point(stale: false, ageSeconds: 4),
      youngPersonId: 'yp-1',
      alerts: const [],
      inbox: inbox,
      now: now,
    );
    expect(attention.level, CareLevel.attention);
    expect(attention.reason, 'Anomalie récente');
  });
}
