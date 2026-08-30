import 'package:flutter/material.dart';

import '../../../app/brand.dart';
import '../../../core/config/api_config.dart';
import 'map_data.dart';

/// Marqueur Life360 : bulle (nom + durée) au-dessus, flèche qui pointe le lieu.
class MapPinMarker extends StatelessWidget {
  const MapPinMarker({super.key, required this.pin});

  final MapPin pin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = mapPinColor(pin);
    final showCallout = !pin.isTestimony;
    // FittedBox : la bulle + flèche + pin ne débordent jamais le Marker (bande 1 px).
    return SizedBox(
      width: mapPinMarkerWidth(pin),
      height: mapPinMarkerHeight(pin),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showCallout) _PinCallout(pin: pin, scheme: scheme, color: color),
            if (showCallout)
              CustomPaint(
                size: const Size(14, 7),
                painter: _CalloutArrowPainter(scheme.surface.withValues(alpha: 0.94)),
              ),
            _PinGlyph(pin: pin, color: color),
          ],
        ),
      ),
    );
  }
}

/// Bulle : nom, statut, « Mis à jour il y a X » — jamais « temps réel ».
class _PinCallout extends StatelessWidget {
  const _PinCallout({required this.pin, required this.scheme, required this.color});

  final MapPin pin;
  final ColorScheme scheme;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: Key('map-pin-callout-${pin.id ?? pin.label ?? 'anon'}'),
      color: scheme.surface.withValues(alpha: 0.94),
      elevation: 2,
      borderRadius: CityCareBrand.borderRadiusSm,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pin.label != null)
              Text(
                pin.label!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
            Text(
              pin.careCaption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              pin.freshnessCaption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: pin.looksStale ? CityCareBrand.amberDark : scheme.onSurfaceVariant,
              ),
            ),
            if (pin.batteryCaption != null)
              Text(
                pin.batteryCaption!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Triangle sous la bulle : la flèche visuelle vers le lieu.
class _CalloutArrowPainter extends CustomPainter {
  const _CalloutArrowPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CalloutArrowPainter oldDelegate) => oldDelegate.color != color;
}

/// Tête de pin : icône qui pointe le sol, photo éventuelle dans la tête.
class _PinGlyph extends StatelessWidget {
  const _PinGlyph({required this.pin, required this.color});

  final MapPin pin;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (pin.isTestimony) {
      return Icon(Icons.record_voice_over, color: color, size: pin.isSelected ? 34 : 28);
    }
    final photo = ApiConfig.resolveMediaUrl(pin.photoUrl);
    final size = pin.isSelected ? 42.0 : 36.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Icon(Icons.location_on, color: color, size: size),
          if (photo != null && photo.isNotEmpty)
            Positioned(
              top: size * 0.12,
              child: CircleAvatar(
                radius: size * 0.18,
                backgroundColor: CityCareBrand.lavender,
                backgroundImage: NetworkImage(photo),
                onBackgroundImageError: (_, __) {},
              ),
            ),
        ],
      ),
    );
  }
}

/// Taille du marqueur OSM selon présence d’une bulle.
double mapPinMarkerWidth(MapPin pin) => pin.isTestimony && pin.label == null ? 36 : 148;

double mapPinMarkerHeight(MapPin pin) {
  if (pin.isTestimony && pin.label == null) {
    return 36;
  }
  // Bulle + flèche + pin qui pointe le lieu.
  var height = 112.0;
  if (pin.batteryCaption != null) {
    height += 16;
  }
  return height;
}
