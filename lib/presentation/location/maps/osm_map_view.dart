import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'map_data.dart';
import 'map_pin_marker.dart';
import 'osm_tiles.dart';

/// Carte OpenStreetMap (flutter_map).
///
/// Repli quand la clé Google Maps n’est pas configurée. User-Agent CityCare
/// obligatoire : OSM refuse les tuiles avec l’UA générique `flutter_map (…)`.
class OsmMapView extends StatefulWidget {
  const OsmMapView({super.key, required this.model, this.onTap});

  final MapViewModel model;
  final void Function(double latitude, double longitude)? onTap;

  @override
  State<OsmMapView> createState() => _OsmMapViewState();
}

class _OsmMapViewState extends State<OsmMapView> {
  final MapController _controller = MapController();
  final StreamController<void> _tileReset = StreamController<void>.broadcast();
  late TileProvider _tiles = cityCareOsmTileProvider();
  bool _ready = false;
  int _tileErrors = 0;
  bool _tilesFailed = false;
  int _retryGeneration = 0;
  Timer? _failureTimer;

  static const _failureGrace = Duration(seconds: 5);
  static const _failureThreshold = 8;

  @override
  void didUpdateWidget(OsmMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final model = widget.model;
    final previous = oldWidget.model;
    if (model.focusGeneration != previous.focusGeneration &&
        model.focusLatitude != null &&
        model.focusLongitude != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_ready) {
          return;
        }
        _controller.move(LatLng(model.focusLatitude!, model.focusLongitude!), 16);
      });
      return;
    }
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
    _failureTimer?.cancel();
    _tileReset.close();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleFailureCheck() {
    _failureTimer?.cancel();
    _failureTimer = Timer(_failureGrace, () {
      if (!mounted) {
        return;
      }
      if (_tileErrors >= _failureThreshold && !_tilesFailed) {
        setState(() => _tilesFailed = true);
      }
    });
  }

  void _retryTiles() {
    _failureTimer?.cancel();
    _tiles = cityCareOsmTileProvider();
    _tileErrors = 0;
    setState(() {
      _tilesFailed = false;
      _retryGeneration += 1;
    });
    if (!_tileReset.isClosed) {
      _tileReset.add(null);
    }
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

    // Clip : attribution / pin ne débordent pas d’1 px sous la carte.
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: model.center,
              initialZoom: model.zoom,
              minZoom: 4,
              maxZoom: 18,
              backgroundColor: kOsmMapBackground,
              keepAlive: true,
              onMapReady: () => _ready = true,
              onTap: widget.onTap == null ? null : (tap, latlng) => widget.onTap!(latlng.latitude, latlng.longitude),
            ),
            children: [
              TileLayer(
                key: ValueKey<int>(_retryGeneration),
                urlTemplate: cityCarePrimaryTileUrl(),
                fallbackUrl: cityCareFallbackTileUrl(),
                userAgentPackageName: 'com.citycare.citycare',
                tileProvider: _tiles,
                maxNativeZoom: 19,
                evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
                errorTileCallback: (tile, error, stackTrace) {
                  _tileErrors += 1;
                  _scheduleFailureCheck();
                },
                reset: _tileReset.stream,
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
              if (point != null && !model.pointCoveredByPin)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 44,
                      height: 44,
                      alignment: Alignment.bottomCenter,
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
                        width: mapPinMarkerWidth(pin),
                        height: mapPinMarkerHeight(pin),
                        alignment: Alignment.bottomCenter,
                        child: MapPinMarker(pin: pin),
                      ),
                  ],
                ),
              const Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(4, 4, 8, 4),
                  child: Text(
                    '© OpenStreetMap',
                    style: TextStyle(fontSize: 10, color: Color(0x99000000)),
                  ),
                ),
              ),
            ],
          ),
          if (_tilesFailed)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                child: MapTilesUnavailableBanner(onRetry: _retryTiles),
              ),
            ),
        ],
      ),
    );
  }
}
