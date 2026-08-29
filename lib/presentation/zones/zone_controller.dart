import 'package:flutter/foundation.dart';

import '../../core/errors/api_exception.dart';
import '../../domain/entities/zones.dart';
import '../../domain/repositories/zone_repository.dart';

class ZoneController extends ChangeNotifier {
  ZoneController(this._repository);

  final ZoneRepository _repository;

  List<SafetyZone> zones = [];
  bool isBusy = false;
  String? errorMessage;
  String? loadedYoungPersonId;

  Future<void> loadMine() async {
    loadedYoungPersonId = null;
    await _run(() async {
      zones = await _repository.myZones();
    });
  }

  Future<void> loadChild(String youngPersonId) async {
    loadedYoungPersonId = youngPersonId;
    await _run(() async {
      zones = await _repository.childZones(youngPersonId);
    });
  }

  Future<bool> create(SafetyZoneDraft draft, {required String youngPersonId}) {
    return _run(() async {
      await _repository.create(draft, youngPersonId: youngPersonId);
      zones = await _repository.childZones(youngPersonId);
    });
  }

  Future<bool> update(String zoneId, SafetyZoneDraft draft) {
    return _run(() async {
      await _repository.update(zoneId, draft);
      if (loadedYoungPersonId == null) {
        zones = await _repository.myZones();
      } else {
        zones = await _repository.childZones(loadedYoungPersonId!);
      }
    });
  }

  Future<bool> delete(String zoneId) {
    return _run(() async {
      await _repository.delete(zoneId);
      zones = zones.where((zone) => zone.id != zoneId).toList();
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
      errorMessage = 'Zones indisponibles pour le moment.';
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }
}
