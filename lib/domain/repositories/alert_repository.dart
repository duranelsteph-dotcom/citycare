import '../entities/alerts.dart';
import '../enums/citycare_enums.dart';

class SosDraft {
  const SosDraft({
    this.latitude,
    this.longitude,
    this.accuracy,
    this.recordedAt,
    this.description,
    this.youngPersonId,
    this.source,
  });

  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final DateTime? recordedAt;
  final String? description;
  final String? youngPersonId;
  final AlertSource? source;

  Map<String, dynamic> toJson() {
    return {
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (accuracy != null) 'accuracy': accuracy,
      if (recordedAt != null) 'recorded_at': recordedAt!.toUtc().toIso8601String(),
      if (description != null) 'description': description,
      if (youngPersonId != null) 'young_person_id': youngPersonId,
      if (source != null) 'source': source!.apiValue,
    };
  }
}

abstract class AlertRepository {
  Future<Alert> triggerSos(SosDraft draft);

  Future<List<Alert>> mineAsYoung();

  Future<List<Alert>> mineAsGuardian();

  Future<Alert> getById(String alertId);

  Future<Alert> cancel(String alertId);

  Future<Alert> acknowledge(String alertId);

  Future<Alert> resolve(String alertId);
}
