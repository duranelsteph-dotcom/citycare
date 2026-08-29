import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/brand.dart';
import '../../../domain/entities/search.dart';

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
  });

  final double latitude;
  final double longitude;
  final bool isTestimony;

  LatLng get point => LatLng(latitude, longitude);
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
  });

  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final bool isStale;
  final bool isUnsynced;
  final List<MapCircle> circles;
  final List<List<LatLng>> pathSegments;
  final List<MapPin> pins;

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
    if (circles.isNotEmpty) {
      return circles.first.point;
    }
    return kDefaultMapCenter;
  }

  /// Niveau de zoom déduit du plus grand rayon à faire tenir à l'écran.
  double get zoom {
    if (circles.isEmpty) {
      return hasPoint ? 15 : 12;
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

  /// Couleur de la pastille de position.
  ///
  /// Une position ancienne ou non synchronisée n'est jamais stylée comme une
  /// position actuelle : c'est une règle produit, pas une préférence visuelle.
  Color pointColor(ColorScheme scheme) {
    if (isUnsynced) {
      return scheme.tertiary;
    }
    if (isStale) {
      return scheme.error;
    }
    return scheme.primary;
  }
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
