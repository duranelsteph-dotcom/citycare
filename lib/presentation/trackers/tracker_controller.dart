import 'package:flutter/foundation.dart';

import '../../core/errors/api_exception.dart';
import '../../domain/entities/tracking.dart';
import '../../domain/enums/citycare_enums.dart';
import '../../domain/repositories/tracker_repository.dart';

class TrackerController extends ChangeNotifier {
  TrackerController(this._repository);

  final TrackerRepository _repository;

  List<GpsTracker> items = [];
  GpsTracker? lastCreated;
  bool isBusy = false;
  String? errorMessage;
  String? loadedYoungPersonId;
  Map<String, GpsTracker?> summaries = {};
  List<TrackerEvent> events = [];

  GpsTracker? byId(String trackerId) {
    for (final kit in items) {
      if (kit.id == trackerId) {
        return kit;
      }
    }
    return null;
  }

  Future<void> loadMine() async {
    loadedYoungPersonId = null;
    await _run(() async {
      items = await _repository.mine();
    });
  }

  Future<void> loadChild(String youngPersonId) async {
    loadedYoungPersonId = youngPersonId;
    await _run(() async {
      items = await _repository.forChild(youngPersonId);
    });
  }

  Future<void> loadSummaries(List<String> youngPersonIds) async {
    final next = <String, GpsTracker?>{};
    for (final id in youngPersonIds) {
      try {
        final kits = await _repository.forChild(id);
        GpsTracker? chosen;
        for (final kit in kits) {
          if (kit.status != TrackerStatus.inactive) {
            chosen = kit;
            break;
          }
        }
        next[id] = chosen ?? (kits.isEmpty ? null : kits.first);
      } on ApiException {
        next[id] = null;
      }
    }
    summaries = next;
    notifyListeners();
  }

  Future<bool> register({String? youngPersonId, String label = 'Kit CityCare'}) {
    return _run(() async {
      lastCreated = await _repository.register(youngPersonId: youngPersonId, label: label);
      await _reload();
    });
  }

  Future<bool> update(
    String trackerId, {
    String? label,
    TrackingMode? trackingMode,
    bool? enabled,
  }) {
    return _run(() async {
      await _repository.update(trackerId, label: label, trackingMode: trackingMode, enabled: enabled);
      await _reload();
    });
  }

  Future<bool> rotateSecret(String trackerId) {
    return _run(() async {
      lastCreated = await _repository.rotateSecret(trackerId);
      await _reload();
    });
  }

  Future<bool> delete(String trackerId) {
    return _run(() async {
      await _repository.delete(trackerId);
      items = items.where((kit) => kit.id != trackerId).toList();
    });
  }

  Future<void> loadEvents(String trackerId) {
    return _run(() async {
      events = await _repository.events(trackerId);
    });
  }

  Future<void> _reload() async {
    if (loadedYoungPersonId == null) {
      items = await _repository.mine();
    } else {
      items = await _repository.forChild(loadedYoungPersonId!);
    }
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
      errorMessage = 'Kit IoT indisponible pour le moment.';
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }
}
