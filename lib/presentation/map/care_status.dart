import 'package:flutter/material.dart';

import '../../app/brand.dart';
import '../../domain/entities/alerts.dart';
import '../../domain/entities/location_access.dart';
import '../../domain/entities/tracking.dart';
import '../../domain/enums/citycare_enums.dart';
import '../location/location_controller.dart';
import 'freshness.dart';

/// Aligné sur [NotificationController.recentAnomaly] (Phase 17, 6 h).
const Duration kRecentAnomalyWindow = Duration(hours: 6);

/// Statut unifié Phase 18 — pas une garantie de sécurité.
enum CareLevel {
  /// Position fraîche, sans alerte connue.
  secure,

  /// Donnée douteuse ou incomplète (stale, GPS, hors-ligne, file, anomalie).
  attention,

  /// SOS / urgence active déjà connue pour ce membre.
  danger,
}

/// Résultat honnête : libellé « Position récente », jamais « en sécurité absolue ».
class CareStatus {
  const CareStatus({
    required this.level,
    required this.shortLabel,
    required this.levelLabel,
    required this.reason,
    required this.disclaimer,
    this.visible = true,
  });

  /// Pas de pastille (gardien sans GPS — éviter un faux « hors ligne »).
  static const CareStatus hidden = CareStatus(
    level: CareLevel.attention,
    shortLabel: '',
    levelLabel: '',
    reason: '',
    disclaimer: '',
    visible: false,
  );

  final CareLevel level;
  final String shortLabel;
  final String levelLabel;
  final String reason;
  final String disclaimer;
  final bool visible;
}

/// Couleur sémantique partagée (sheet, pins, profil, carte).
Color careLevelColor(CareLevel level) {
  return switch (level) {
    CareLevel.danger => CityCareBrand.sos,
    CareLevel.attention => CityCareBrand.amberDark,
    CareLevel.secure => CityCareBrand.safe,
  };
}

String careShortLabel(CareLevel level) {
  return switch (level) {
    CareLevel.secure => 'Position récente',
    CareLevel.attention => 'Attention',
    CareLevel.danger => 'Danger',
  };
}

String careLevelLabel(CareLevel level) {
  return switch (level) {
    CareLevel.secure => 'Sécurisé',
    CareLevel.attention => 'Attention',
    CareLevel.danger => 'Danger',
  };
}

/// SOS ouvert déjà chargé (alerts existantes, pas un nouveau backend).
bool memberHasOpenSos({
  required Iterable<Alert> alerts,
  String? youngPersonId,
}) {
  for (final alert in alerts) {
    if (!alert.isOpen) {
      continue;
    }
    if (youngPersonId == null || alert.youngPersonId == youngPersonId) {
      return true;
    }
  }
  return false;
}

/// Réutilise [NotificationType.anomaly] (Phase 17) — ne pas inventer un autre signal.
bool inboxHasRecentAnomaly({
  required Iterable<AppNotification> inbox,
  String? youngPersonId,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  for (final note in inbox) {
    if (note.notificationType != NotificationType.anomaly) {
      continue;
    }
    final noteYoung = note.youngPersonId;
    if (youngPersonId != null && noteYoung != null && noteYoung != youngPersonId) {
      continue;
    }
    if (clock.difference(note.createdAt).abs() <= kRecentAnomalyWindow) {
      return true;
    }
  }
  return false;
}

bool deviceGpsOff(LocationAccess? access) {
  return access?.status == LocationAccessStatus.serviceDisabled;
}

/// Priorité : Danger > Attention > Sécurisé. Aucun libellé « en sécurité absolue ».
CareStatus resolveCareStatus({
  TrackerLocation? point,
  bool hasOpenSos = false,
  bool gpsOff = false,
  bool queueUnsynced = false,
  bool hasRecentAnomaly = false,
}) {
  if (hasOpenSos) {
    return const CareStatus(
      level: CareLevel.danger,
      shortLabel: 'Danger',
      levelLabel: 'Danger',
      reason: 'SOS actif',
      disclaimer: 'SOS / urgence — pas un kidnapping confirmé.',
    );
  }

  final stale = point != null &&
      locationLooksStale(isStale: point.isStale, ageSeconds: point.ageSeconds);
  final offline = point == null;

  if (gpsOff || queueUnsynced || hasRecentAnomaly || offline || stale) {
    final reason = gpsOff
        ? 'GPS éteint'
        : queueUnsynced
            ? 'File non synchronisée'
            : hasRecentAnomaly
                ? 'Anomalie récente'
                : offline
                    ? 'Hors ligne'
                    : 'Position ancienne';
    return CareStatus(
      level: CareLevel.attention,
      shortLabel: 'Attention',
      levelLabel: 'Attention',
      reason: reason,
      disclaimer: 'À vérifier — pas un kidnapping confirmé.',
    );
  }

  return const CareStatus(
    level: CareLevel.secure,
    shortLabel: 'Position récente',
    levelLabel: 'Sécurisé',
    reason: 'Position récente',
    disclaimer: 'Position récente — pas une garantie de sécurité.',
  );
}

/// Assemble les signaux déjà présents (alerts, inbox ANOMALY, GPS, file).
CareStatus careStatusForMember({
  required TrackerLocation? point,
  String? youngPersonId,
  Iterable<Alert> alerts = const [],
  Iterable<AppNotification> inbox = const [],
  bool isSelf = false,
  LocationController? locations,
  DateTime? now,
}) {
  final pendingSos = isSelf && (locations?.queue.sos.isNotEmpty ?? false);
  return resolveCareStatus(
    point: point,
    hasOpenSos: pendingSos || memberHasOpenSos(alerts: alerts, youngPersonId: youngPersonId),
    gpsOff: isSelf && deviceGpsOff(locations?.locationAccess),
    queueUnsynced: isSelf && (locations?.hasUnsyncedLocations ?? false) && !pendingSos,
    hasRecentAnomaly: inboxHasRecentAnomaly(
      inbox: inbox,
      youngPersonId: youngPersonId,
      now: now,
    ),
  );
}

/// Plus grave des statuts (profil parent : aperçu du groupe).
CareStatus? worstCareStatus(Iterable<CareStatus> statuses) {
  CareStatus? worst;
  for (final status in statuses) {
    if (!status.visible) {
      continue;
    }
    if (worst == null || status.level.index > worst.level.index) {
      worst = status;
    }
  }
  return worst;
}

/// Pastille unique : sheet, pins, profil, carte.
class CareStatusBadge extends StatelessWidget {
  const CareStatusBadge({
    super.key,
    required this.status,
    this.compact = true,
    this.showDisclaimer = false,
  });

  final CareStatus status;
  final bool compact;
  final bool showDisclaimer;

  @override
  Widget build(BuildContext context) {
    if (!status.visible) {
      return const SizedBox.shrink();
    }
    final color = careLevelColor(status.level);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      key: const Key('care-status-badge'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          key: Key('care-status-${status.level.name}'),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: CityCareBrand.borderRadiusPill,
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  compact ? status.shortLabel : '${status.levelLabel} · ${status.reason}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showDisclaimer) ...[
          const SizedBox(height: 4),
          Text(
            status.disclaimer,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }
}
