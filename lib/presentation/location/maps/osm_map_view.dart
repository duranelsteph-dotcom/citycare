import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/brand.dart';
import 'map_data.dart';

/// Carte OpenStreetMap (flutter_map).
///
/// C'est l'implémentation historique du projet, conservée telle quelle : elle
/// sert désormais de repli quand la clé Google Maps n'est pas configurée, ce
/// qui garantit qu'une démonstration reste possible sans aucune clé.
class OsmMapView extends StatefulWidget {
  const OsmMapView({super.key, required this.model, this.onTap});

  final MapViewModel model;
  final void Function(double latitude, double longitude)? onTap;

  @override
  State<OsmMapView> createState() => _OsmMapViewState();
}

class _OsmMapViewState extends State<OsmMapView> {
  final MapController _controller = MapController();
  bool _ready = false;

  @override
  void didUpdateWidget(OsmMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final model = widget.model;
    final previous = oldWidget.model;
    if (model.latitude != previous.latitude ||
        model.longitude != previous.longitude ||
        model.circles.length != previous.circles.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_ready) {
          return;
        }
        _controller.move(model.center, model.zoom);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final model = widget.model;
    final pointColor = model.pointColor(scheme);
    final point = model.point;
    final accuracy = model.accuracyMeters;

    final zoneCircles = [
      for (final circle in model.circles)
        CircleMarker(
          point: circle.point,
          radius: circle.radiusMeters,
          useRadiusInMeter: true,
          color: mapCircleColor(circle, scheme).withValues(alpha: mapCircleFillAlpha(circle)),
          borderStrokeWidth: circle.isEstimate || circle.isPriority ? 3 : 2,
          borderColor: mapCircleColor(circle, scheme).withValues(alpha: 0.85),
        ),
    ];
    if (point != null && accuracy != null && accuracy > 0) {
      // Le cercle de précision GPS passe sous les zones : il décrit
      // l'incertitude de la mesure, pas une zone décidée par un humain.
      zoneCircles.insert(
        0,
        CircleMarker(
          point: point,
          radius: accuracy,
          useRadiusInMeter: true,
          color: pointColor.withValues(alpha: 0.16),
          borderStrokeWidth: 1,
          borderColor: pointColor.withValues(alpha: 0.55),
        ),
      );
    }

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: model.center,
        initialZoom: model.zoom,
        minZoom: 4,
        maxZoom: 18,
        onMapReady: () => _ready = true,
        onTap: widget.onTap == null ? null : (tap, latlng) => widget.onTap!(latlng.latitude, latlng.longitude),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.citycare.citycare',
          maxNativeZoom: 19,
        ),
        if (zoneCircles.isNotEmpty) CircleLayer(circles: zoneCircles),
        if (model.pathSegments.any((segment) => segment.length >= 2))
          PolylineLayer(
            polylines: [
              for (final segment in model.pathSegments)
                if (segment.length >= 2)
                  Polyline(
                    points: segment,
                    color: scheme.secondary,
                    strokeWidth: 4,
                  ),
            ],
          ),
        if (model.pathSegments.isNotEmpty)
          MarkerLayer(
            markers: [
              for (final segment in model.pathSegments)
                for (final LatLng item in segment)
                  Marker(
                    point: item,
                    width: 12,
                    height: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.secondary,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.surface, width: 1.5),
                      ),
                    ),
                  ),
            ],
          ),
        if (point != null)
          MarkerLayer(
            markers: [
              Marker(
                point: point,
                width: 44,
                height: 44,
                alignment: Alignment.topCenter,
                child: Icon(Icons.location_on, color: pointColor, size: 40),
              ),
            ],
          ),
        if (model.pins.isNotEmpty)
          MarkerLayer(
            markers: [
              for (final pin in model.pins)
                Marker(
                  point: pin.point,
                  width: 36,
                  height: 36,
                  alignment: Alignment.topCenter,
                  child: Icon(
                    pin.isTestimony ? Icons.record_voice_over : Icons.place,
                    color: pin.isTestimony ? CityCareBrand.mapTestimony : scheme.primary,
                    size: 28,
                  ),
                ),
            ],
          ),
        const SimpleAttributionWidget(source: Text('OpenStreetMap')),
      ],
    );
  }
}
