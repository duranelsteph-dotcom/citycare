import 'dart:async';

import 'package:citycare/core/errors/api_exception.dart';
import 'package:citycare/data/datasources/device_location_service.dart';
import 'package:citycare/data/datasources/network.dart';
import 'package:citycare/domain/entities/alerts.dart';
import 'package:citycare/domain/entities/location_access.dart';
import 'package:citycare/domain/enums/citycare_enums.dart';
import 'package:citycare/domain/repositories/alert_repository.dart';
import 'package:citycare/presentation/alerts/alert_controller.dart';
import 'package:citycare/presentation/alerts/sos_errors.dart';
import 'package:citycare/presentation/auth/role_capabilities.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'widget_test.dart';

class _GpsDenied extends DeviceLocationService {
  @override
  Future<LocationAccess> requestAccess() async {
    return const LocationAccess(LocationAccessStatus.denied);
  }

  @override
  Future<Position> currentFix() async {
    throw const DeviceLocationException('GPS refusé');
  }
}

class _SosRepo extends FakeAlertRepository {
  SosDraft? last;
  Object? throwError;
  int calls = 0;

  @override
  Future<Alert> triggerSos(SosDraft draft) async {
    calls += 1;
    last = draft;
    final error = throwError;
    if (error != null) {
      throw error;
    }
    final at = DateTime.utc(2026, 8, 31);
    return Alert(
      id: 'sos-ok',
      youngPersonId: 'yp-1',
      source: draft.source ?? AlertSource.mobile,
      status: AlertStatus.active,
      severity: AlertSeverity.critical,
      triggeredAt: at,
      createdAt: at,
      updatedAt: at,
    );
  }
}

void main() {
  test('describeSosFailure ne masque jamais par « indisponible pour le moment »', () {
    expect(describeSosFailure(const ApiException('Serveur injoignable.', statusCode: 0)), contains('Serveur injoignable'));
    expect(describeSosFailure(const ApiException('Authentification requise', statusCode: 401)), 'Authentification requise');
    expect(describeSosFailure(const ApiException('Interdit', statusCode: 403)), 'Interdit');
    final offline = describeSosFailure(connectionFailure(TimeoutException('timed out')));
    expect(offline.toLowerCase(), contains('serveur injoignable'));
    expect(describeSosFailure(const FormatException('html')), contains('injoignable'));
    expect(describeSosFailure(const ApiException('Serveur injoignable.', statusCode: 0)), isNot(contains('pour le moment')));
    expect(roleShowsSos(UserRole.authority), isFalse);
  });

  test('SOS part sans GPS', () async {
    final repo = _SosRepo();
    final alerts = AlertController(repo, device: _GpsDenied());
    final ok = await alerts.triggerSos(description: 'test');
    expect(ok, isTrue);
    expect(repo.last, isNotNull);
    expect(repo.last!.latitude, isNull);
    expect(alerts.infoMessage, contains('sans GPS'));
    expect(alerts.errorMessage, isNull);
  });

  test('API 500 : message réel, pas « indisponible pour le moment »', () async {
    final repo = _SosRepo()..throwError = const ApiException('Impossible de joindre CityCare (500)', statusCode: 500);
    final alerts = AlertController(repo, device: _GpsDenied());
    final ok = await alerts.triggerSos();
    expect(ok, isFalse);
    expect(alerts.errorMessage, contains('500'));
    expect(alerts.errorMessage, isNot(contains('pour le moment')));
  });

  test('serveur injoignable : file locale + message réel', () async {
    final repo = _SosRepo()..throwError = const ApiException('Serveur injoignable (Connection refused).', statusCode: 0);
    final alerts = AlertController(repo, device: _GpsDenied());
    final ok = await alerts.triggerSos();
    expect(ok, isTrue);
    expect(alerts.queue.sos, isNotEmpty);
    expect(alerts.infoMessage, contains('Serveur injoignable'));
    expect(alerts.infoMessage, isNot(contains('pour le moment')));
    expect(repo.calls, 1);
  });

  test('401 : authentification, pas un silence', () async {
    final repo = _SosRepo()..throwError = const ApiException('Authentification requise', statusCode: 401);
    final alerts = AlertController(repo, device: _GpsDenied());
    final ok = await alerts.triggerSos();
    expect(ok, isFalse);
    expect(alerts.errorMessage, 'Authentification requise');
  });
}
