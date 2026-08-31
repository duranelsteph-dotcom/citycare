import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../app/brand.dart';
import '../../core/config/maps_config.dart';
import '../map/care_status.dart';
import 'maps/google_map_view.dart';
import 'maps/map_data.dart';
import 'maps/osm_map_view.dart';
import 'maps/osm_tiles.dart';

export 'maps/map_data.dart' show MapCircle, MapPin, MapViewModel, kDefaultMapCenter, trajectorySegments;

/// Carte de CityCare, indépendante du fournisseur.
///
/// L'écran appelant ne choisit pas la carte : il décrit ce qu'il veut montrer
/// (position, zones, trajectoire, témoignages) et [LocationMapView] sélectionne
/// Google Maps si la clé d'API est configurée, sinon OpenStreetMap.
///
/// Conséquence voulue : l'absence de clé ne casse jamais une démonstration, et
/// l'utilisateur est informé de la carte réellement affichée.
class LocationMapView extends StatelessWidget {
  const LocationMapView({
    super.key,
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
    this.careStatus,
    this.isLastKnownOnly = false,
    this.onTap,
  });

  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final bool isStale;
  final bool isUnsynced;
  final List<MapCircle> circles;
  final List<List<LatLng>> pathSegments;
  final List<MapPin> pins;

  /// Recentrage demandé depuis le panneau membres (pas un GPS continu).
  final double? focusLatitude;
  final double? focusLongitude;
  final int focusGeneration;

  /// Statut unifié affiché sur la carte (même helper que le sheet).
  final CareStatus? careStatus;

  /// True si le point affiché est une dernière position mémorisée, pas un GPS actuel.
  final bool isLastKnownOnly;
  final void Function(double latitude, double longitude)? onTap;

  bool get hasPoint => latitude != null && longitude != null;

  @override
  Widget build(BuildContext context) {
    final model = MapViewModel(
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracyMeters,
      isStale: isStale,
      isUnsynced: isUnsynced,
      circles: circles,
      pathSegments: pathSegments,
      pins: pins,
      focusLatitude: focusLatitude,
      focusLongitude: focusLongitude,
      focusGeneration: focusGeneration,
      careLevel: careStatus?.level,
    );
    final reason = MapsConfig.fallbackReason;

    return ClipRect(
      child: Stack(
      children: [
        Positioned.fill(
          child: MapsConfig.provider == MapProvider.google
              ? GoogleMapsView(model: model, onTap: onTap)
              : OsmMapView(model: model, onTap: onTap),
        ),
        if (reason != null)
          Positioned(
            top: CityCareBrand.spaceSm,
            left: CityCareBrand.spaceSm,
            child: _MapProviderNotice(reason: reason),
          ),
        if (!hasPoint && pins.isEmpty)
          Positioned(
            bottom: CityCareBrand.spaceSm,
            left: CityCareBrand.spaceSm,
            right: CityCareBrand.spaceSm,
            child: const MapFallbackCenterBanner(usingLastKnown: false),
          )
        else if (isLastKnownOnly)
          Positioned(
            bottom: CityCareBrand.spaceSm,
            left: CityCareBrand.spaceSm,
            right: CityCareBrand.spaceSm,
            child: const MapFallbackCenterBanner(usingLastKnown: true),
          ),
        if (careStatus != null && careStatus!.visible)
          Positioned(
            top: CityCareBrand.spaceSm,
            right: CityCareBrand.spaceSm,
            child: Material(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
              borderRadius: CityCareBrand.borderRadiusSm,
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: CareStatusBadge(status: careStatus!, showDisclaimer: false),
              ),
            ),
          ),
      ],
      ),
    );
  }
}

/// Pastille discrète indiquant quelle carte est réellement affichée.
///
/// Volontairement petite : elle informe sans masquer la carte, et le détail
/// (comment configurer la clé) est disponible au toucher.
class _MapProviderNotice extends StatelessWidget {
  const _MapProviderNotice({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withValues(alpha: 0.92),
      borderRadius: CityCareBrand.borderRadiusSm,
      elevation: 2,
      child: InkWell(
        borderRadius: CityCareBrand.borderRadiusSm,
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.layers_outlined, size: 16, color: CityCareBrand.lime),
              const SizedBox(width: 6),
              Text(
                'Carte OpenStreetMap',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.info_outline, size: 14, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.layers_outlined),
        title: const Text('Fournisseur de carte'),
        content: Text(reason),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('J’ai compris'),
          ),
        ],
      ),
    );
  }
}
