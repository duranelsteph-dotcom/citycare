import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart' as osm;

import 'map_data.dart';

/// Carte Google Maps.
///
/// Cette vue n'est construite que lorsque `MapsConfig.provider` vaut
/// `MapProvider.google`, c'est-à-dire clé d'API fournie **et** plateforme
/// supportée. Elle affiche exactement les mêmes couches que la carte
/// OpenStreetMap (zones, précision GPS, trajectoire, témoignages) pour qu'un
/// écran ait la même lecture quel que soit le fournisseur.
class GoogleMapsView extends StatefulWidget {
  const GoogleMapsView({super.key, required this.model, this.onTap});

  final MapViewModel model;
  final void Function(double latitude, double longitude)? onTap;

  @override
  State<GoogleMapsView> createState() => _GoogleMapsViewState();
}

class _GoogleMapsViewState extends State<GoogleMapsView> {
  gmaps.GoogleMapController? _controller;

  gmaps.LatLng _toGoogle(osm.LatLng value) => gmaps.LatLng(value.latitude, value.longitude);

  @override
  void didUpdateWidget(GoogleMapsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final model = widget.model;
    final previous = oldWidget.model;
    if (model.latitude != previous.latitude ||
        model.longitude != previous.longitude ||
        model.circles.length != previous.circles.length) {
      final controller = _controller;
      if (controller != null) {
        controller.animateCamera(
          gmaps.CameraUpdate.newLatLngZoom(_toGoogle(model.center), model.zoom),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final model = widget.model;
    final pointColor = model.pointColor(scheme);
    final point = model.point;
    final accuracy = model.accuracyMeters;

    final circles = <gmaps.Circle>{};
    if (point != null && accuracy != null && accuracy > 0) {
      // Cercle de précision GPS : incertitude de la mesure, pas une zone.
      circles.add(
        gmaps.Circle(
          circleId: const gmaps.CircleId('precision-gps'),
          center: _toGoogle(point),
          radius: accuracy,
          fillColor: pointColor.withValues(alpha: 0.16),
          strokeColor: pointColor.withValues(alpha: 0.55),
          strokeWidth: 1,
        ),
      );
    }
    for (var i = 0; i < model.circles.length; i++) {
      final circle = model.circles[i];
      final color = mapCircleColor(circle, scheme);
      circles.add(
        gmaps.Circle(
          circleId: gmaps.CircleId('zone-$i'),
          center: _toGoogle(circle.point),
          radius: circle.radiusMeters,
          fillColor: color.withValues(alpha: mapCircleFillAlpha(circle)),
          strokeColor: color.withValues(alpha: 0.85),
          strokeWidth: circle.isEstimate || circle.isPriority ? 3 : 2,
        ),
      );
    }

    final polylines = <gmaps.Polyline>{};
    for (var i = 0; i < model.pathSegments.length; i++) {
      final segment = model.pathSegments[i];
      if (segment.length < 2) {
        continue;
      }
      // Un segment par tronçon continu : les trous de communication ne sont
      // jamais reliés, comme sur la carte OpenStreetMap.
      polylines.add(
        gmaps.Polyline(
          polylineId: gmaps.PolylineId('trajet-$i'),
          points: [for (final item in segment) _toGoogle(item)],
          color: scheme.secondary,
          width: 4,
        ),
      );
    }

    final markers = <gmaps.Marker>{};
    if (point != null) {
      markers.add(
        gmaps.Marker(
          markerId: const gmaps.MarkerId('position'),
          position: _toGoogle(point),
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(_pointHue(model)),
          infoWindow: gmaps.InfoWindow(
            title: model.isStale ? 'Dernière position connue' : 'Position connue',
            snippet: model.isStale
                ? 'Ancienne — ce n’est pas la position actuelle.'
                : 'Ce n’est pas un suivi en direct.',
          ),
        ),
      );
    }
    for (var i = 0; i < model.pins.length; i++) {
      final pin = model.pins[i];
      markers.add(
        gmaps.Marker(
          markerId: gmaps.MarkerId('pin-$i'),
          position: _toGoogle(pin.point),
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
            pin.isTestimony ? gmaps.BitmapDescriptor.hueCyan : gmaps.BitmapDescriptor.hueAzure,
          ),
          infoWindow: pin.isTestimony
              ? const gmaps.InfoWindow(
                  title: 'Témoignage',
                  snippet: 'Déclaration d’un tiers — non vérifiée automatiquement.',
                )
              : const gmaps.InfoWindow(title: 'Point signalé'),
        ),
      );
    }
    // Les extrémités de trajectoire sont matérialisées par de petites pastilles
    // sur la carte OSM ; en Google Maps on les rend par un point de départ et
    // d'arrivée pour ne pas saturer l'écran de marqueurs.
    for (var i = 0; i < model.pathSegments.length; i++) {
      final segment = model.pathSegments[i];
      if (segment.isEmpty) {
        continue;
      }
      markers.add(
        gmaps.Marker(
          markerId: gmaps.MarkerId('trajet-$i-debut'),
          position: _toGoogle(segment.first),
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueGreen),
          alpha: 0.85,
          infoWindow: const gmaps.InfoWindow(title: 'Début du tronçon enregistré'),
        ),
      );
      if (segment.length > 1) {
        markers.add(
          gmaps.Marker(
            markerId: gmaps.MarkerId('trajet-$i-fin'),
            position: _toGoogle(segment.last),
            icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueViolet),
            alpha: 0.85,
            infoWindow: const gmaps.InfoWindow(title: 'Fin du tronçon enregistré'),
          ),
        );
      }
    }

    return gmaps.GoogleMap(
      initialCameraPosition: gmaps.CameraPosition(
        target: _toGoogle(model.center),
        zoom: model.zoom,
      ),
      onMapCreated: (controller) => _controller = controller,
      circles: circles,
      polylines: polylines,
      markers: markers,
      onTap: widget.onTap == null ? null : (position) => widget.onTap!(position.latitude, position.longitude),
      // La localisation « point bleu » natif reste désactivée : CityCare
      // affiche uniquement des positions passées par le backend, pour ne jamais
      // laisser croire à un suivi en direct.
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: true,
      minMaxZoomPreference: const gmaps.MinMaxZoomPreference(4, 18),
    );
  }


  double _pointHue(MapViewModel model) {
    if (model.isUnsynced) {
      return gmaps.BitmapDescriptor.hueOrange;
    }
    if (model.isStale) {
      return gmaps.BitmapDescriptor.hueRed;
    }
    return gmaps.BitmapDescriptor.hueAzure;
  }
}
