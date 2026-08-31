import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../app/brand.dart';
import '../../../core/config/api_config.dart';
import '../../../core/config/dev_api_resolver.dart';

/// Politique OSM : un User-Agent qui identifie **CityCare**, pas la lib.
///
/// `flutter_map (com.citycare…)` est souvent refusé → tuiles grises.
const kCityCareOsmUserAgent = 'CityCare/0.43.0 (com.citycare.citycare)';

/// Serveur public OSM. Repli [kOsmFallbackTileUrl] si une tuile échoue.
const kOsmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Tuiles OSM France : même données, autre hôte si osm.org coupe.
const kOsmFallbackTileUrl = 'https://tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png';

/// Fond visible tant que les tuiles n’ont pas chargé — pas un écran gris vide.
const kOsmMapBackground = Color(0xFFD4E6F1);

/// Chemin relatif du proxy tuiles sur l'API CityCare (PC avec Internet).
const kDevTileProxyPath = '/map/tiles/{z}/{x}/{y}.png';

/// En dev (API HTTP ou tunnel), les tuiles passent par le backend.
bool get cityCareUsesBackendTileProxy {
  if (kIsWeb) {
    return false;
  }
  final base = ApiConfig.baseUrl;
  return base.startsWith('http://') || isNgrokOrTunnelUrl(base);
}

/// URL principale des tuiles (proxy dev ou OSM direct en production HTTPS).
String cityCarePrimaryTileUrl() {
  if (cityCareUsesBackendTileProxy) {
    return '${ApiConfig.baseUrl}$kDevTileProxyPath';
  }
  return kOsmTileUrl;
}

/// Repli si la source principale échoue.
String? cityCareFallbackTileUrl() {
  if (cityCareUsesBackendTileProxy) {
    return kOsmTileUrl;
  }
  return kOsmFallbackTileUrl;
}

/// En-têtes HTTP des tuiles. [TileLayer] ne les écrase pas (putIfAbsent).
Map<String, String> cityCareOsmHeaders() {
  return {'User-Agent': kCityCareOsmUserAgent};
}

/// Fournisseur réseau avec User-Agent CityCare obligatoire.
NetworkTileProvider cityCareOsmTileProvider() {
  return NetworkTileProvider(headers: cityCareOsmHeaders());
}

/// Overlay si les tuiles OSM ne chargent pas (réseau, blocage, timeout).
class MapTilesUnavailableBanner extends StatelessWidget {
  const MapTilesUnavailableBanner({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const Key('map-tiles-unavailable'),
      color: scheme.surface.withValues(alpha: 0.94),
      borderRadius: CityCareBrand.borderRadiusMd,
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Carte indisponible',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Les tuiles OpenStreetMap n’ont pas chargé (réseau ou serveur). '
              'En développement, elles passent par le PC : vérifiez que l’API tourne '
              'et que adb reverse tcp:8000 tcp:8000 est actif.',
              style: TextStyle(fontSize: 12, height: 1.3, color: scheme.onSurfaceVariant),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('map-tiles-retry'),
                onPressed: onRetry,
                child: const Text('Réessayer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pastille honnête : Yaoundé par défaut, jamais un GPS inventé.
class MapFallbackCenterBanner extends StatelessWidget {
  const MapFallbackCenterBanner({super.key, required this.usingLastKnown});

  final bool usingLastKnown;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const Key('map-fallback-center'),
      color: scheme.surface.withValues(alpha: 0.92),
      borderRadius: CityCareBrand.borderRadiusSm,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text(
          usingLastKnown
              ? 'Dernière position connue — pas un suivi en direct'
              : 'Aucune position GPS — carte centrée sur Yaoundé. Pas un suivi en direct.',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurface),
        ),
      ),
    );
  }
}
