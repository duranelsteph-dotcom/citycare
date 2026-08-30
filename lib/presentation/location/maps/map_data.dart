import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/brand.dart';
import '../../../domain/entities/search.dart';
import '../../map/care_status.dart';
import '../../map/freshness.dart';

/// Centre par défaut (Yaoundé) lorsqu’aucune position n’est connue.
const LatLng kDefaultMapCenter = LatLng(3.8480, 11.5021);

/// Cercle de zone (école, maison…) distinct du cercle de précision GPS.
class MapCircle {
  const MapCircle({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.isActive = true,
    this.isRisk = false,
    this.isEstimate = false,
    this.isPriority = false,
    this.isHighPriority = false,
  });

  final double latitude;
  final double longitude;
  final double radiusMeters;
  final bool isActive;
  final bool isRisk;
  final bool isEstimate;
  final bool isPriority;
  final bool isHighPriority;

  LatLng get point => LatLng(latitude, longitude);
}

class MapPin {
  const MapPin({
    required this.latitude,
    required this.longitude,
    this.isTestimony = false,
    this.label,
    this.id,
    this.isSelected = false,
    this.isStale = false,
    this.ageSeconds = 0,
    this.photoUrl,
    this.batteryCaption,
    this.careLevel,
  });

  final double latitude;
  final double longitude;
  final bool isTestimony;

  /// Libellé optionnel (prénom du jeune sur la carte famille).
  final String? label;

  /// Identifiant du membre (recentrage depuis le panneau).
  final String? id;

  /// Pastille mise en avant après un tap dans le sheet.
  final bool isSelected;

  /// Position ancienne : ne pas la styler comme un GPS actuel.
  final bool isStale;

  /// Âge du point, pour la bulle de fraîcheur (mêmes règles que le sheet).
  final int ageSeconds;

  /// Photo de profil si le backend l’a déjà (Phase 10). Pas une image inventée.
  final String? photoUrl;

  /// Batterie déjà connue (téléphone ou kit). Jamais un 100 % inventé.
  final String? batteryCaption;

  /// Statut unifié Phase 18. Null = dérivé de la fraîcheur (stale → Attention).
  final CareLevel? careLevel;

  LatLng get point => LatLng(latitude, longitude);

  CareLevel get resolvedCareLevel {
    if (careLevel != null) {
      return careLevel!;
    }
    return looksStale ? CareLevel.attention : CareLevel.secure;
  }

  /// Libellé pin : « Position récente », jamais « en sécurité ».
  String get careCaption => careShortLabel(resolvedCareLevel);

  /// Stale déclaré ou âge au-delà du seuil backend (~5 min).
  bool get looksStale =>
      isTestimony ? false : locationLooksStale(isStale: isStale, ageSeconds: ageSeconds);

  /// Texte de fraîcheur de la bulle — jamais « temps réel ».
  String get freshnessCaption =>
      locationFreshnessLabel(isStale: isStale, ageSeconds: ageSeconds);
}

/// Données communes aux deux implémentations de carte (Google et OpenStreetMap).
///
/// Centraliser ces calculs garantit qu'une zone garde exactement la même
/// couleur et le même cadrage quel que soit le fournisseur de carte affiché.
class MapViewModel {
  const MapViewModel({
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.isStale = false,
    this.isUnsynced = false,
    this.circles = const [],
    this.pathSegments = const [],
    this.pins = const [],
    this.focusLatitude,
    this.focusLongitude,
    this.focusGeneration = 0,
    this.careLevel,
  });

  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final bool isStale;
  final bool isUnsynced;
  final List<MapCircle> circles;
  final List<List<LatLng>> pathSegments;
  final List<MapPin> pins;

  /// Cible de recentrage (tap membre). [focusGeneration] change à chaque demande.
  final double? focusLatitude;
  final double? focusLongitude;
  final int focusGeneration;

  /// Statut du point principal (carte jeune / ma position).
  final CareLevel? careLevel;

  CareLevel get resolvedCareLevel =>
      careLevel ?? ((isUnsynced || isStale) ? CareLevel.attention : CareLevel.secure);

  bool get hasPoint => latitude != null && longitude != null;

  LatLng? get point => hasPoint ? LatLng(latitude!, longitude!) : null;

  /// Cadrage : on privilégie la zone estimée par la recherche, puis la
  /// position connue, puis la première zone affichée.
  LatLng get center {
    for (final circle in circles) {
      if (circle.isEstimate) {
        return circle.point;
      }
    }
    final current = point;
    if (current != null) {
      return current;
    }
    if (pins.isNotEmpty) {
      return pins.first.point;
    }
    if (circles.isNotEmpty) {
      return circles.first.point;
    }
    return kDefaultMapCenter;
  }

  /// Niveau de zoom déduit du plus grand rayon à faire tenir à l'écran.
  double get zoom {
    if (circles.isEmpty) {
      return (hasPoint || pins.isNotEmpty) ? 15 : 12;
    }
    var largest = 0.0;
    for (final circle in circles) {
      if (circle.radiusMeters > largest) {
        largest = circle.radiusMeters;
      }
    }
    return zoomForRadius(largest);
  }

  static double zoomForRadius(double meters) {
    if (meters >= 25000) {
      return 9;
    }
    if (meters >= 12000) {
      return 10;
    }
    if (meters >= 5000) {
      return 11;
    }
    if (meters >= 2000) {
      return 12;
    }
    if (meters >= 800) {
      return 13;
    }
    if (meters >= 300) {
      return 14;
    }
    return 15;
  }

  /// Couleur de la pastille de position (mêmes règles que le sheet / les pins).
  ///
  /// Stale ou file non sync = Attention (ambre), jamais un rouge d’urgence.
  /// Le rouge est réservé au SOS ([CareLevel.danger]).
  Color pointColor(ColorScheme _) {
    return careLevelColor(resolvedCareLevel);
  }

  /// True si une pastille recouvre déjà le point principal (évite un double icône).
  bool get pointCoveredByPin {
    final current = point;
    if (current == null) {
      return false;
    }
    for (final pin in pins) {
      if ((pin.latitude - current.latitude).abs() < 1e-6 &&
          (pin.longitude - current.longitude).abs() < 1e-6) {
        return true;
      }
    }
    return false;
  }
}

/// Pastille membre : statut unifié (vert / ambre / rouge SOS).
Color mapPinColor(MapPin pin) {
  if (pin.isTestimony) {
    return CityCareBrand.mapTestimony;
  }
  return careLevelColor(pin.resolvedCareLevel);
}

/// Couleur porteuse de sens d'un cercle de zone.
Color mapCircleColor(MapCircle circle, ColorScheme scheme) {
  if (circle.isPriority) {
    return circle.isHighPriority ? CityCareBrand.mapHighPriorityZone : CityCareBrand.mapPriorityZone;
  }
  if (circle.isEstimate) {
    return CityCareBrand.mapEstimateZone;
  }
  if (!circle.isActive) {
    return scheme.outline;
  }
  return circle.isRisk ? CityCareBrand.mapRiskZone : CityCareBrand.mapSafeZone;
}

/// Opacité de remplissage d'un cercle de zone.
double mapCircleFillAlpha(MapCircle circle) => circle.isPriority ? 0.18 : 0.14;

/// Découpe une trajectoire en segments continus.
///
/// Un « trou de communication » coupe le trait : on ne relie jamais deux points
/// séparés par une perte de signal, car cela laisserait croire à un trajet
/// observé alors qu'il est inconnu.
List<List<LatLng>> trajectorySegments(Trajectory? trajectory) {
  if (trajectory == null || trajectory.points.isEmpty) {
    return const [];
  }
  final segments = <List<LatLng>>[];
  var current = <LatLng>[];
  for (final item in trajectory.points) {
    current.add(LatLng(item.latitude, item.longitude));
    if (item.gapAfter) {
      if (current.isNotEmpty) {
        segments.add(current);
      }
      current = <LatLng>[];
    }
  }
  if (current.isNotEmpty) {
    segments.add(current);
  }
  return segments;
}
