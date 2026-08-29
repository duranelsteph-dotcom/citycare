import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/brand.dart';

/// Logo CityCare, dessiné en vectoriel (aucune image binaire).
///
/// Lecture du symbole : un **bouclier** (protection, prévention) qui contient
/// une **balise de localisation** ; le creux de la balise dessine un **cœur**
/// (l'enfant que l'on protège). Tout est tracé en coordonnées normalisées, donc
/// le logo reste net de 16 px (icône de barre) à 240 px (splash).
class CityCareLogoMark extends StatelessWidget {
  const CityCareLogoMark({
    super.key,
    this.size = 48,
    this.gradient,
    this.monochromeColor,
    this.showBadge = true,
  });

  /// Côté du carré occupé par le logo.
  final double size;

  /// Dégradé du fond. Par défaut le dégradé de marque.
  final Gradient? gradient;

  /// Rend le logo en une seule couleur (barre d'application, filigrane…).
  /// Dans ce mode le fond n'est pas dessiné.
  final Color? monochromeColor;

  /// Dessine la pastille arrondie derrière le bouclier.
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _LogoMarkPainter(
          gradient: gradient ?? CityCareBrand.brandGradient,
          monochromeColor: monochromeColor,
          showBadge: showBadge && monochromeColor == null,
        ),
        isComplex: true,
      ),
    );
  }
}

class _LogoMarkPainter extends CustomPainter {
  _LogoMarkPainter({
    required this.gradient,
    required this.monochromeColor,
    required this.showBadge,
  });

  final Gradient gradient;
  final Color? monochromeColor;
  final bool showBadge;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final mono = monochromeColor;

    // 1. Pastille arrondie de fond, en dégradé de marque.
    if (showBadge) {
      final badge = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, s, s),
        Radius.circular(s * 0.26),
      );
      canvas.drawRRect(
        badge,
        Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, s, s)),
      );

      // Anneaux de veille : évoquent le signal de localisation sans surcharger.
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white.withValues(alpha: 0.14)
        ..strokeWidth = s * 0.022;
      canvas.drawCircle(Offset(s * 0.5, s * 0.5), s * 0.46, ring);
      canvas.drawCircle(Offset(s * 0.5, s * 0.5), s * 0.58, ring);
    }

    // 2. Bouclier.
    final shield = _shieldPath(s);
    if (mono != null) {
      canvas.drawPath(
        shield,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.075
          ..strokeJoin = StrokeJoin.round
          ..color = mono,
      );
    } else {
      canvas.drawPath(shield, Paint()..color = Colors.white);
      // Léger voile intérieur pour donner du relief au bouclier.
      canvas.drawPath(
        shield,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.02
          ..color = CityCareBrand.primaryDark.withValues(alpha: 0.12),
      );
    }

    // 3. Balise de localisation évidée d'un cœur, au centre du bouclier.
    final pin = Path.combine(
      PathOperation.difference,
      _pinPath(s),
      _heartPath(s),
    );
    canvas.drawPath(
      pin,
      Paint()..color = mono ?? CityCareBrand.primary,
    );
  }

  /// Bouclier : épaules droites en haut, pointe arrondie en bas.
  Path _shieldPath(double s) {
    double x(double v) => v * s;
    double y(double v) => v * s;
    return Path()
      ..moveTo(x(0.50), y(0.10))
      ..lineTo(x(0.855), y(0.235))
      ..quadraticBezierTo(x(0.875), y(0.245), x(0.875), y(0.27))
      ..lineTo(x(0.875), y(0.52))
      ..cubicTo(x(0.875), y(0.735), x(0.725), y(0.865), x(0.50), y(0.935))
      ..cubicTo(x(0.275), y(0.865), x(0.125), y(0.735), x(0.125), y(0.52))
      ..lineTo(x(0.125), y(0.27))
      ..quadraticBezierTo(x(0.125), y(0.245), x(0.145), y(0.235))
      ..close();
  }

  /// Balise : demi-cercle supérieur prolongé par une pointe vers le bas.
  Path _pinPath(double s) {
    final center = Offset(s * 0.5, s * 0.445);
    final radius = s * 0.175;
    final tip = Offset(s * 0.5, s * 0.775);
    return Path()
      ..moveTo(center.dx - radius, center.dy)
      ..arcTo(Rect.fromCircle(center: center, radius: radius), math.pi, math.pi, false)
      ..quadraticBezierTo(center.dx + radius * 0.82, center.dy + radius * 1.15, tip.dx, tip.dy)
      ..quadraticBezierTo(center.dx - radius * 0.82, center.dy + radius * 1.15, center.dx - radius, center.dy)
      ..close();
  }

  /// Cœur évidé dans la balise : l'enfant protégé.
  Path _heartPath(double s) {
    final cx = s * 0.5;
    final cy = s * 0.44;
    final k = s * 0.155;
    return Path()
      ..moveTo(cx, cy + k * 0.42)
      ..cubicTo(cx - k * 0.62, cy - k * 0.10, cx - k * 0.34, cy - k * 0.62, cx, cy - k * 0.24)
      ..cubicTo(cx + k * 0.34, cy - k * 0.62, cx + k * 0.62, cy - k * 0.10, cx, cy + k * 0.42)
      ..close();
  }

  @override
  bool shouldRepaint(_LogoMarkPainter oldDelegate) {
    return oldDelegate.gradient != gradient ||
        oldDelegate.monochromeColor != monochromeColor ||
        oldDelegate.showBadge != showBadge;
  }
}

/// Nom de la marque en toutes lettres : « City » neutre, « Care » en primaire.
class CityCareWordmark extends StatelessWidget {
  const CityCareWordmark({
    super.key,
    this.fontSize = 28,
    this.color,
    this.accentColor,
  });

  final double fontSize;
  final Color? color;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      height: 1.1,
      color: color ?? scheme.onSurface,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'City', style: base),
          TextSpan(
            text: 'Care',
            style: base.copyWith(color: accentColor ?? scheme.primary),
          ),
        ],
      ),
      // Le nom de la marque est décoratif : les lecteurs d'écran annoncent
      // « CityCare » une seule fois plutôt que deux fragments.
      semanticsLabel: 'CityCare',
    );
  }
}

/// Logo complet : symbole + nom, avec une accroche optionnelle.
class CityCareLogo extends StatelessWidget {
  const CityCareLogo({
    super.key,
    this.markSize = 56,
    this.fontSize = 30,
    this.tagline,
    this.axis = Axis.horizontal,
    this.color,
    this.accentColor,
    this.monochromeColor,
  });

  final double markSize;
  final double fontSize;

  /// Accroche affichée sous le nom (« Prévention, alerte et assistance »).
  final String? tagline;

  /// Disposition horizontale (barre, formulaire) ou verticale (splash).
  final Axis axis;

  final Color? color;
  final Color? accentColor;
  final Color? monochromeColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mark = CityCareLogoMark(size: markSize, monochromeColor: monochromeColor);
    final taglineText = tagline;
    final texts = Column(
      crossAxisAlignment: axis == Axis.horizontal ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        CityCareWordmark(fontSize: fontSize, color: color, accentColor: accentColor),
        if (taglineText != null) ...[
          const SizedBox(height: CityCareBrand.spaceXs),
          Text(
            taglineText,
            textAlign: axis == Axis.horizontal ? TextAlign.start : TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color?.withValues(alpha: 0.85) ?? theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );

    if (axis == Axis.horizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          mark,
          const SizedBox(width: CityCareBrand.spaceMd),
          Flexible(child: texts),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(height: CityCareBrand.spaceMd),
        texts,
      ],
    );
  }
}
