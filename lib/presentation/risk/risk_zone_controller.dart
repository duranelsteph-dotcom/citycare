import 'package:flutter/foundation.dart';

import '../../core/errors/api_exception.dart';
import '../../domain/entities/zones.dart';
import '../../domain/repositories/risk_zone_repository.dart';

class RiskZoneController extends ChangeNotifier {
  RiskZoneController(this._repository);

  final RiskZoneRepository _repository;

  List<RiskZone> zones = [];
  bool isBusy = false;
  String? errorMessage;

  Future<void> load() async {
    await _run(() async {
      zones = await _repository.list();
    });
  }

  Future<bool> create(RiskZoneDraft draft) {
    return _run(() async {
      await _repository.create(draft);
      zones = await _repository.list();
    });
  }

  Future<bool> update(String zoneId, RiskZoneDraft draft) {
    return _run(() async {
      await _repository.update(zoneId, draft);
      zones = await _repository.list();
    });
  }

  Future<bool> delete(String zoneId) {
    return _run(() async {
      await _repository.delete(zoneId);
      zones = zones.where((zone) => zone.id != zoneId).toList();
    });
  }

  Future<bool> addIncident(String zoneId, IncidentDraft draft) {
    return _run(() async {
      await _repository.addIncident(zoneId, draft);
      zones = await _repository.list();
    });
  }

  Future<bool> _run(Future<void> Function() action) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on ApiException catch (error) {
      errorMessage = error.message;
      return false;
    } catch (_) {
      errorMessage = 'Zones à risque indisponibles pour le moment.';
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }
}
