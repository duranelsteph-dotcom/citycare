import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/brand.dart';

/// Illustrations de prévention contre l'enlèvement d'enfants.
///
/// Tout est dessiné en vectoriel avec [CustomPainter] : aucun fichier binaire,
/// aucune image à télécharger, et un rendu net à n'importe quelle taille.
/// Le style est volontairement « à plat » (aplats de couleur, pas de détail de
/// visage) pour rester lisible en petit et ne cibler aucun enfant réel.
enum PreventionScene {
  /// Un trajet connu entre la maison et l'école, sous le regard d'un adulte.
  knownRoute,

  /// Ne jamais suivre ni monter avec une personne inconnue.
  strangerDanger,

  /// Donner l'alerte immédiatement, sans attendre.
  raiseAlert,
}

/// Rend une scène de prévention dans un cadre 4:3.
class PreventionIllustration extends StatelessWidget {
  const PreventionIllustration({
    super.key,
    required this.scene,
    this.height = 180,
    this.onDarkSurface = false,
  });

  final PreventionScene scene;
  final double height;

  /// Adapte les contrastes lorsque l'illustration est posée sur un fond foncé
  /// (splash en dégradé, thème sombre).
  final bool onDarkSurface;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: CustomPaint(
          painter: _PreventionPainter(scene: scene, onDarkSurface: onDarkSurface),
          isComplex: true,
        ),
      ),
    );
  }
}

/// Palette locale des illustrations. Isolée ici pour qu'une scène reste
/// cohérente quel que soit le thème actif.
class _Ink {
  _Ink(this.onDark);

  final bool onDark;

  Color get backdrop =>
      onDark ? Colors.white.withValues(alpha: 0.08) : CityCareBrand.primary.withValues(alpha: 0.07);
  Color get ground =>
      onDark ? Colors.white.withValues(alpha: 0.16) : CityCareBrand.primary.withValues(alpha: 0.16);
  Color get neutral => onDark ? const Color(0xFFD7DEEA) : const Color(0xFF4E5865);
  Color get adult => onDark ? const Color(0xFFC8FFD4) : CityCareBrand.limeDark;
  Color get child => onDark ? const Color(0xFFFFFF8D) : CityCareBrand.lime;
  Color get skin => onDark ? const Color(0xFFF3D2AE) : const Color(0xFFE8B98C);
  Color get safe => CityCareBrand.safe;
  Color get warn => CityCareBrand.amber;
  Color get danger => CityCareBrand.sos;
  Color get paper => onDark ? const Color(0xFF1B2536) : Colors.white;
}

class _PreventionPainter extends CustomPainter {
  _PreventionPainter({required this.scene, required this.onDarkSurface});

  final PreventionScene scene;
  final bool onDarkSurface;

  /// Toutes les scènes sont composées sur une grille virtuelle de 100 × 75,
  /// puis mises à l'échelle. Les coordonnées restent donc lisibles.
  static const Size _design = Size(100, 75);

  @override
  void paint(Canvas canvas, Size size) {
    final ink = _Ink(onDarkSurface);
    canvas.save();
    canvas.scale(size.width / _design.width, size.height / _design.height);

    _paintBackdrop(canvas, ink);
    switch (scene) {
      case PreventionScene.knownRoute:
        _paintKnownRoute(canvas, ink);
      case PreventionScene.strangerDanger:
        _paintStrangerDanger(canvas, ink);
      case PreventionScene.raiseAlert:
        _paintRaiseAlert(canvas, ink);
    }
    canvas.restore();
  }

  void _paintBackdrop(Canvas canvas, _Ink ink) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(2, 2, 96, 71), const Radius.circular(10)),
      Paint()..color = ink.backdrop,
    );
  }

  // --- Scène 1 : le trajet connu ------------------------------------------

  void _paintKnownRoute(Canvas canvas, _Ink ink) {
    // Le sol.
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(6, 58, 88, 5), const Radius.circular(3)),
      Paint()..color = ink.ground,
    );

    // Corridor de sécurité : le chemin autorisé entre la maison et l'école.
    final corridor = Path()
      ..moveTo(20, 60)
      ..quadraticBezierTo(50, 48, 80, 60);
    canvas.drawPath(
      corridor,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..color = ink.safe.withValues(alpha: 0.18),
    );
    _drawDashedPath(
      canvas,
      corridor,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = ink.safe,
      dash: 3,
      gap: 2.6,
    );

    // La maison, départ du trajet.
    _drawBuilding(canvas, ink, base: const Offset(17, 58), width: 20, wallHeight: 15, roofHeight: 8,
        wallColor: ink.paper, roofColor: ink.adult, windows: 2);
    // L'école, arrivée du trajet.
    _drawBuilding(canvas, ink, base: const Offset(82, 58), width: 24, wallHeight: 19, roofHeight: 7,
        wallColor: ink.paper, roofColor: ink.child, windows: 3, hasFlag: true);

    // L'enfant, en chemin.
    _drawPerson(canvas, ink, feet: const Offset(45, 57), height: 15, clothes: ink.child);
    // L'adulte de confiance, à distance mais présent.
    _drawPerson(canvas, ink, feet: const Offset(60, 58), height: 21, clothes: ink.adult);

    // Le bouclier de la zone de sécurité, posé sur le corridor.
    _drawShieldBadge(canvas, center: const Offset(50, 20), radius: 8, color: ink.safe, glyph: _Glyph.check);
  }

  // --- Scène 2 : l'inconnu -------------------------------------------------

  void _paintStrangerDanger(Canvas canvas, _Ink ink) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(6, 58, 88, 5), const Radius.circular(3)),
      Paint()..color = ink.ground,
    );

    // L'enfant reste à distance, du côté sûr.
    _drawPerson(canvas, ink, feet: const Offset(24, 57), height: 20, clothes: ink.child);

    // Le véhicule inconnu.
    _drawCar(canvas, ink, base: const Offset(68, 58), width: 44, color: ink.neutral);

    // L'écart à conserver, matérialisé et étiqueté par le pictogramme d'interdit.
    final distancePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = ink.danger.withValues(alpha: 0.55);
    _drawDashedPath(
      canvas,
      Path()
        ..moveTo(32, 46)
        ..lineTo(46, 46),
      distancePaint,
      dash: 3,
      gap: 2.5,
    );

    // Pictogramme d'interdiction, centré entre l'enfant et le véhicule.
    const forbidCenter = Offset(50, 24);
    canvas.drawCircle(forbidCenter, 11, Paint()..color = ink.danger.withValues(alpha: 0.14));
    canvas.drawCircle(
      forbidCenter,
      9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..color = ink.danger,
    );
    canvas.drawLine(
      forbidCenter + const Offset(-6.2, 6.2),
      forbidCenter + const Offset(6.2, -6.2),
      Paint()
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = ink.danger,
    );

    // La main tendue de l'inconnu : le geste que l'enfant doit refuser.
    canvas.drawLine(
      const Offset(56, 44),
      const Offset(46, 44),
      Paint()
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = ink.neutral.withValues(alpha: 0.6),
    );
  }

  // --- Scène 3 : donner l'alerte ------------------------------------------

  void _paintRaiseAlert(Canvas canvas, _Ink ink) {
    const phoneCenter = Offset(50, 36);

    // Ondes d'alerte : le message part vers les proches.
    for (var i = 0; i < 3; i++) {
      final radius = 16.0 + i * 8;
      canvas.drawCircle(
        phoneCenter,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = ink.danger.withValues(alpha: 0.30 - i * 0.08),
      );
    }

    // Le téléphone, au centre.
    final phone = RRect.fromRectAndRadius(
      Rect.fromCenter(center: phoneCenter, width: 20, height: 34),
      const Radius.circular(4),
    );
    canvas.drawRRect(phone, Paint()..color = ink.paper);
    canvas.drawRRect(
      phone,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = ink.neutral.withValues(alpha: 0.45),
    );

    // Le bouton SOS occupe l'écran : une seule cible, impossible à manquer.
    canvas.drawCircle(phoneCenter, 6.6, Paint()..color = ink.danger);
    canvas.drawCircle(
      phoneCenter,
      6.6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = ink.danger.withValues(alpha: 0.35),
    );
    _drawSosGlyph(canvas, phoneCenter, 4.6);

    // Les proches alertés, de part et d'autre.
    _drawPerson(canvas, ink, feet: const Offset(16, 60), height: 19, clothes: ink.adult);
    _drawPerson(canvas, ink, feet: const Offset(84, 60), height: 19, clothes: ink.child);

    // Coche de réception : l'alerte est arrivée.
    _drawShieldBadge(canvas, center: const Offset(84, 30), radius: 6.5, color: ink.safe, glyph: _Glyph.check);
    _drawShieldBadge(canvas, center: const Offset(16, 30), radius: 6.5, color: ink.warn, glyph: _Glyph.bell);
  }

  // --- Briques de dessin ---------------------------------------------------

  /// Silhouette « à plat » : tête, buste évasé, deux jambes. Pas de visage.
  void _drawPerson(
    Canvas canvas,
    _Ink ink, {
    required Offset feet,
    required double height,
    required Color clothes,
  }) {
    final headRadius = height * 0.16;
    final headCenter = Offset(feet.dx, feet.dy - height + headRadius);
    final bodyTop = headCenter.dy + headRadius * 1.15;
    final bodyBottom = feet.dy - height * 0.26;
    final topHalf = height * 0.12;
    final bottomHalf = height * 0.20;

    // Jambes.
    final legPaint = Paint()
      ..color = clothes.withValues(alpha: 0.85)
      ..strokeWidth = height * 0.09
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(feet.dx - bottomHalf * 0.45, bodyBottom),
      Offset(feet.dx - bottomHalf * 0.55, feet.dy),
      legPaint,
    );
    canvas.drawLine(
      Offset(feet.dx + bottomHalf * 0.45, bodyBottom),
      Offset(feet.dx + bottomHalf * 0.55, feet.dy),
      legPaint,
    );

    // Buste.
    final body = Path()
      ..moveTo(feet.dx - topHalf, bodyTop)
      ..quadraticBezierTo(feet.dx, bodyTop - height * 0.05, feet.dx + topHalf, bodyTop)
      ..lineTo(feet.dx + bottomHalf, bodyBottom)
      ..quadraticBezierTo(feet.dx, bodyBottom + height * 0.04, feet.dx - bottomHalf, bodyBottom)
      ..close();
    canvas.drawPath(body, Paint()..color = clothes);

    // Bras.
    final armPaint = Paint()
      ..color = clothes
      ..strokeWidth = height * 0.075
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(feet.dx - topHalf * 0.85, bodyTop + height * 0.05),
      Offset(feet.dx - bottomHalf * 1.15, bodyBottom - height * 0.02),
      armPaint,
    );
    canvas.drawLine(
      Offset(feet.dx + topHalf * 0.85, bodyTop + height * 0.05),
      Offset(feet.dx + bottomHalf * 1.15, bodyBottom - height * 0.02),
      armPaint,
    );

    // Tête.
    canvas.drawCircle(headCenter, headRadius, Paint()..color = ink.skin);
  }

  void _drawBuilding(
    Canvas canvas,
    _Ink ink, {
    required Offset base,
    required double width,
    required double wallHeight,
    required double roofHeight,
    required Color wallColor,
    required Color roofColor,
    int windows = 2,
    bool hasFlag = false,
  }) {
    final left = base.dx - width / 2;
    final wallTop = base.dy - wallHeight;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(left, wallTop, width, wallHeight),
        bottomLeft: const Radius.circular(1.5),
        bottomRight: const Radius.circular(1.5),
      ),
      Paint()..color = wallColor,
    );
    canvas.drawRect(
      Rect.fromLTWH(left, wallTop, width, wallHeight),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = ink.neutral.withValues(alpha: 0.35),
    );

    // Toit.
    canvas.drawPath(
      Path()
        ..moveTo(left - 1.5, wallTop)
        ..lineTo(base.dx, wallTop - roofHeight)
        ..lineTo(left + width + 1.5, wallTop)
        ..close(),
      Paint()..color = roofColor,
    );

    // Fenêtres régulièrement réparties.
    final step = width / (windows + 1);
    for (var i = 1; i <= windows; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(left + step * i, wallTop + wallHeight * 0.38),
            width: 3.4,
            height: 3.4,
          ),
          const Radius.circular(0.8),
        ),
        Paint()..color = roofColor.withValues(alpha: 0.45),
      );
    }

    // Porte.
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(base.dx - 2.2, base.dy - wallHeight * 0.42, 4.4, wallHeight * 0.42),
        topLeft: const Radius.circular(1.6),
        topRight: const Radius.circular(1.6),
      ),
      Paint()..color = roofColor.withValues(alpha: 0.75),
    );

    if (hasFlag) {
      canvas.drawLine(
        Offset(base.dx, wallTop - roofHeight),
        Offset(base.dx, wallTop - roofHeight - 7),
        Paint()
          ..strokeWidth = 0.9
          ..strokeCap = StrokeCap.round
          ..color = ink.neutral,
      );
      canvas.drawPath(
        Path()
          ..moveTo(base.dx, wallTop - roofHeight - 7)
          ..lineTo(base.dx + 6, wallTop - roofHeight - 5.2)
          ..lineTo(base.dx, wallTop - roofHeight - 3.4)
          ..close(),
        Paint()..color = ink.warn,
      );
    }
  }

  void _drawCar(Canvas canvas, _Ink ink, {required Offset base, required double width, required Color color}) {
    final left = base.dx - width / 2;
    final bodyHeight = width * 0.26;
    final bodyTop = base.dy - bodyHeight - width * 0.06;

    // Habitacle.
    canvas.drawPath(
      Path()
        ..moveTo(left + width * 0.24, bodyTop)
        ..lineTo(left + width * 0.36, bodyTop - width * 0.18)
        ..lineTo(left + width * 0.70, bodyTop - width * 0.18)
        ..lineTo(left + width * 0.80, bodyTop)
        ..close(),
      Paint()..color = color.withValues(alpha: 0.55),
    );

    // Carrosserie.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, bodyTop, width, bodyHeight),
        Radius.circular(bodyHeight * 0.45),
      ),
      Paint()..color = color,
    );

    // Roues.
    final wheelY = bodyTop + bodyHeight;
    for (final dx in [left + width * 0.24, left + width * 0.76]) {
      canvas.drawCircle(Offset(dx, wheelY), width * 0.10, Paint()..color = ink.neutral);
      canvas.drawCircle(Offset(dx, wheelY), width * 0.045, Paint()..color = ink.paper);
    }

    // Vitre côté enfant : elle est ouverte, c'est le point de contact à refuser.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left + width * 0.10, bodyTop + bodyHeight * 0.25, width * 0.16, bodyHeight * 0.42),
        const Radius.circular(1),
      ),
      Paint()..color = ink.paper.withValues(alpha: 0.75),
    );
  }

  void _drawShieldBadge(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
    required _Glyph glyph,
  }) {
    canvas.drawCircle(center, radius * 1.35, Paint()..color = color.withValues(alpha: 0.16));
    canvas.drawCircle(center, radius, Paint()..color = color);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.24
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white;
    switch (glyph) {
      case _Glyph.check:
        canvas.drawPath(
          Path()
            ..moveTo(center.dx - radius * 0.42, center.dy)
            ..lineTo(center.dx - radius * 0.08, center.dy + radius * 0.36)
            ..lineTo(center.dx + radius * 0.46, center.dy - radius * 0.34),
          stroke,
        );
      case _Glyph.bell:
        canvas.drawPath(
          Path()
            ..moveTo(center.dx - radius * 0.42, center.dy + radius * 0.22)
            ..lineTo(center.dx + radius * 0.42, center.dy + radius * 0.22)
            ..moveTo(center.dx - radius * 0.30, center.dy + radius * 0.22)
            ..lineTo(center.dx - radius * 0.30, center.dy - radius * 0.12)
            ..arcToPoint(
              Offset(center.dx + radius * 0.30, center.dy - radius * 0.12),
              radius: Radius.circular(radius * 0.30),
            )
            ..lineTo(center.dx + radius * 0.30, center.dy + radius * 0.22),
          stroke,
        );
    }
  }

  /// « SOS » stylisé : trois glyphes tracés au trait, sans dépendre d'une police.
  void _drawSosGlyph(Canvas canvas, Offset center, double width) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.30
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;
    final unit = width / 3.4;
    for (final dx in [-unit * 2.2, unit * 2.2]) {
      final c = Offset(center.dx + dx, center.dy);
      canvas.drawPath(
        Path()
          ..moveTo(c.dx + unit * 0.7, c.dy - unit)
          ..lineTo(c.dx - unit * 0.7, c.dy - unit)
          ..lineTo(c.dx - unit * 0.7, c.dy)
          ..lineTo(c.dx + unit * 0.7, c.dy)
          ..lineTo(c.dx + unit * 0.7, c.dy + unit)
          ..lineTo(c.dx - unit * 0.7, c.dy + unit),
        paint,
      );
    }
    canvas.drawCircle(
      center,
      unit * 0.95,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width * 0.30
        ..color = Colors.white,
    );
  }

  /// Trace un chemin en pointillés : utilisé pour les trajets et les distances.
  void _drawDashedPath(Canvas canvas, Path path, Paint paint, {required double dash, required double gap}) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_PreventionPainter oldDelegate) {
    return oldDelegate.scene != scene || oldDelegate.onDarkSurface != onDarkSurface;
  }
}

enum _Glyph { check, bell }
