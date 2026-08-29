import '../../domain/enums/citycare_enums.dart';

String roleLabel(UserRole role) {
  return switch (role) {
    UserRole.young => 'Jeune',
    UserRole.parent => 'Parent / tuteur',
    UserRole.relative => 'Proche autorisé',
    UserRole.authority => 'Autorité',
  };
}

String roleHomeMessage(UserRole role) {
  return switch (role) {
    UserRole.young =>
      'Vous pouvez envoyer un SOS, votre position, et un partage limité. Un SOS n’est pas un kidnapping confirmé.',
    UserRole.parent =>
      'Rattachez un jeune, définissez des zones, et recevez SOS ou partages. Ce n’est pas un kidnapping confirmé, pas un GPS continu.',
    UserRole.relative =>
      'Un jeune peut vous autoriser comme proche. Vos permissions restent limitées et explicites.',
    UserRole.authority =>
      'Vous pouvez déclarer des zones à risque pour la prévention. Ce n’est pas un kidnapping confirmé.',
  };
}

String relationLabel(GuardianRelation relation) {
  return switch (relation) {
    GuardianRelation.parent => 'Parent',
    GuardianRelation.relative => 'Proche',
    GuardianRelation.other => 'Autre',
  };
}

String alertSourceLabel(AlertSource source) {
  return switch (source) {
    AlertSource.mobile => 'Téléphone',
    AlertSource.iot => 'Kit IoT',
    AlertSource.relative => 'Proche',
    AlertSource.voice => 'Voix',
    AlertSource.system => 'Système',
  };
}

String alertStatusLabel(AlertStatus status) {
  return switch (status) {
    AlertStatus.created => 'Créée',
    AlertStatus.active => 'Active',
    AlertStatus.acknowledged => 'Prise en compte',
    AlertStatus.inProgress => 'En cours',
    AlertStatus.resolved => 'Résolue',
    AlertStatus.cancelled => 'Annulée',
  };
}

String linkStatusLabel(GuardianLinkStatus status) {
  return switch (status) {
    GuardianLinkStatus.pending => 'En attente',
    GuardianLinkStatus.active => 'Actif',
    GuardianLinkStatus.revoked => 'Révoqué',
  };
}

String trackerStatusLabel(TrackerStatus status) {
  return switch (status) {
    TrackerStatus.active => 'Actif',
    TrackerStatus.inactive => 'Désactivé',
    TrackerStatus.lowBattery => 'Batterie faible (dernière info)',
    TrackerStatus.signalLost => 'Signal perdu (dernière info)',
    TrackerStatus.removed => 'Retiré',
  };
}

String caseStatusLabel(CaseStatus status) {
  return switch (status) {
    CaseStatus.open => 'Ouvert',
    CaseStatus.searching => 'Recherche',
    CaseStatus.found => 'Retrouvé',
    CaseStatus.closed => 'Clôturé',
  };
}

String trackingModeLabel(TrackingMode mode) {
  return switch (mode) {
    TrackingMode.normal => 'Normal',
    TrackingMode.surveillance => 'Surveillance',
    TrackingMode.emergency => 'Urgence',
    TrackingMode.powerSave => 'Économie d’énergie',
  };
}

String riskLevelLabel(RiskLevel level) {
  return switch (level) {
    RiskLevel.low => 'Faible',
    RiskLevel.medium => 'Moyen',
    RiskLevel.high => 'Élevé',
  };
}

String searchZoneKindLabel(SearchZoneKind kind) {
  return switch (kind) {
    SearchZoneKind.probableDisplacement => 'Zone de recherche estimée',
    SearchZoneKind.prioritySearch => 'Zone de recherche prioritaire',
  };
}

String searchPriorityLabel(SearchPriority priority) {
  return switch (priority) {
    SearchPriority.low => 'Priorité faible',
    SearchPriority.medium => 'Priorité moyenne',
    SearchPriority.high => 'Priorité élevée',
  };
}

String testimonyStatusLabel(TestimonyStatus status) {
  return switch (status) {
    TestimonyStatus.submitted => 'Déposé',
    TestimonyStatus.underReview => 'En examen',
    TestimonyStatus.verified => 'Vérifié',
    TestimonyStatus.rejected => 'Rejeté',
  };
}

String trackerEventTypeLabel(TrackerEventType type) {
  return switch (type) {
    TrackerEventType.location => 'Position',
    TrackerEventType.sos => 'SOS kit',
    TrackerEventType.geofenceExit => 'Sortie de zone',
    TrackerEventType.geofenceEnter => 'Entrée de zone',
    TrackerEventType.signalLost => 'Connexion perdue',
    TrackerEventType.signalRestored => 'Connexion rétablie',
    TrackerEventType.deviceRemoved => 'Kit retiré',
    TrackerEventType.lowBattery => 'Batterie faible',
    TrackerEventType.riskZoneEnter => 'Zone à risque',
  };
}

String consistencyLevelLabel(ConsistencyLevel level) {
  return switch (level) {
    ConsistencyLevel.low => 'Faible',
    ConsistencyLevel.medium => 'Moyenne',
    ConsistencyLevel.high => 'Élevée',
  };
}

String aiDimensionLabel(String code) {
  return switch (code) {
    'geography' => 'Comportement géographique',
    'trajectory' => 'Trajectoire',
    'anomalies' => 'Anomalies',
    'risk_zones' => 'Zones à risque',
    'testimonies' => 'Cohérence des témoignages',
    _ => code,
  };
}
