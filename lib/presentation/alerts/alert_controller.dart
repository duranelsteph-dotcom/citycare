import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/errors/api_exception.dart';
import '../../data/datasources/device_location_service.dart';
import '../../data/datasources/offline_queue.dart';
import '../../domain/entities/alerts.dart';
import '../../domain/enums/citycare_enums.dart';
import '../../domain/repositories/alert_repository.dart';

class AlertController extends ChangeNotifier {
  AlertController(
    this._repository, {
    DeviceLocationService? device,
    OfflineQueue? queue,
    this.persist,
  })  : _device = device ?? DeviceLocationService(),
        queue = queue ?? OfflineQueue();

  final AlertRepository _repository;
  final DeviceLocationService _device;
  final OfflineQueue queue;
  final Future<void> Function(OfflineQueue queue)? persist;

  Future<void> _persist() async {
    await persist?.call(queue);
  }

  List<Alert> items = [];
  Alert? current;
  bool isBusy = false;
  String? errorMessage;
  String? infoMessage;

  Alert? get openSos {
    for (final item in items) {
      if (item.isOpen) {
        return item;
      }
    }
    return current?.isOpen == true ? current : null;
  }

  Future<void> loadMineAsYoung() async {
    await _run(() async {
      items = await _repository.mineAsYoung();
      current = openSos;
    });
  }

  Future<void> loadMineAsGuardian() async {
    await _run(() async {
      items = await _repository.mineAsGuardian();
    });
  }

  Future<void> loadOne(String alertId) async {
    await _run(() async {
      current = await _repository.getById(alertId);
    });
  }

  Future<bool> triggerSos({String? youngPersonId, String? description, AlertSource? source}) {
    return _run(() async {
      infoMessage = null;
      Position? fix;
      try {
        fix = await _device.currentFix();
      } on DeviceLocationException catch (error) {
        // Le SOS part quand même : mieux vaut une alerte sans lieu que pas
        // d'alerte. On dit précisément ce qui manque et pourquoi.
        infoMessage = 'SOS sans GPS : ${error.message} '
            'L’alerte partira sans lieu. Ce n’est pas un suivi en direct.';
      } catch (_) {
        infoMessage = 'SOS sans GPS. Ce n’est pas un suivi en direct.';
      }
      final draft = SosDraft(
        latitude: fix?.latitude,
        longitude: fix?.longitude,
        accuracy: fix?.accuracy,
        recordedAt: fix?.timestamp,
        description: description,
        youngPersonId: youngPersonId,
        source: source,
      );
      try {
        current = await _repository.triggerSos(draft);
      } on ApiException catch (error) {
        if (error.isOffline) {
          queue.enqueueSos(draft.toJson());
          await _persist();
          infoMessage =
              'SOS enregistré sur l’appareil. Envoi quand le réseau reviendra. '
              'Pas encore transmis aux contacts, pas un kidnapping confirmé.';
          return;
        }
        rethrow;
      }
      items = [current!, ...items.where((item) => item.id != current!.id)];
      if (fix != null) {
        infoMessage = 'SOS envoyé avec la position du téléphone. Pas un suivi en direct, pas un kidnapping confirmé.';
      }
    });
  }

  Future<int> flushPending() async {
    var sent = 0;
    final leftover = <Map<String, dynamic>>[];
    for (final item in [...queue.sos]) {
      try {
        current = await _repository.triggerSos(
          SosDraft(
            latitude: (item['latitude'] as num?)?.toDouble(),
            longitude: (item['longitude'] as num?)?.toDouble(),
            accuracy: (item['accuracy'] as num?)?.toDouble(),
            recordedAt: item['recorded_at'] == null ? null : DateTime.parse(item['recorded_at'] as String),
            description: item['description'] as String?,
            youngPersonId: item['young_person_id'] as String?,
            source: item['source'] == null ? null : AlertSourceApi.parse(item['source'] as String),
          ),
        );
        sent += 1;
      } on ApiException catch (error) {
        if (error.isOffline) {
          leftover.add(item);
        }
      }
    }
    queue.sos
      ..clear()
      ..addAll(leftover);
    await _persist();
    notifyListeners();
    return sent;
  }

  Future<bool> cancel(String alertId) {
    return _run(() async {
      current = await _repository.cancel(alertId);
      items = [for (final item in items) if (item.id == current!.id) current! else item];
    });
  }

  Future<bool> acknowledge(String alertId) {
    return _run(() async {
      current = await _repository.acknowledge(alertId);
      items = [for (final item in items) if (item.id == current!.id) current! else item];
    });
  }

  Future<bool> resolve(String alertId) {
    return _run(() async {
      current = await _repository.resolve(alertId);
      items = [for (final item in items) if (item.id == current!.id) current! else item];
    });
  }

  Future<bool> _run(Future<void> Function() action) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on DeviceLocationException catch (error) {
      errorMessage = error.message;
      return false;
    } on ApiException catch (error) {
      errorMessage = error.message;
      return false;
    } catch (_) {
      errorMessage = 'SOS indisponible pour le moment.';
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }
}
