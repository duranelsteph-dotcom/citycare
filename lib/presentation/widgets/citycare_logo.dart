import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/brand.dart';

/// Logo CityCare, dessiné en vectoriel (aucune image binaire).
///
/// Monogramme : un **C** minuscule dont l’ouverture abrite un **cœur**,
/// le tout inscrit dans un **bouclier**. Lecture : la ville protège
/// (bouclier) ceux que l’on aime (cœur).
class CityCareLogoMark extends StatelessWidget {
  const CityCareLogoMark({
    super.key,
    this.size = 48,
    this.gradient,
    this.monochromeColor,
    this.showBadge = true,
  });

  final double size;
  final Gradient? gradient;
  final Color? monochromeColor;
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
    final ink = monochromeColor ?? Colors.white;

    if (showBadge) {
      final badge = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, s, s),
        Radius.circular(s * 0.22),
      );
      canvas.drawRRect(
        badge,
        Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, s, s)),
      );
    }

    final shield = _shieldPath(s);
    canvas.drawPath(
      shield,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.055
        ..strokeJoin = StrokeJoin.round
        ..color = ink,
    );

    final cPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.09
      ..strokeCap = StrokeCap.round
      ..color = ink;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(s * 0.50, s * 0.48), radius: s * 0.18),
      0.55,
      math.pi * 1.55,
      false,
      cPaint,
    );

    canvas.drawPath(_heartPath(s), Paint()..color = ink);
  }

  Path _shieldPath(double s) {
    double x(double v) => v * s;
    double y(double v) => v * s;
    return Path()
      ..moveTo(x(0.50), y(0.12))
      ..lineTo(x(0.82), y(0.24))
      ..quadraticBezierTo(x(0.86), y(0.26), x(0.86), y(0.31))
      ..lineTo(x(0.86), y(0.52))
      ..cubicTo(x(0.86), y(0.72), x(0.70), y(0.84), x(0.50), y(0.90))
      ..cubicTo(x(0.30), y(0.84), x(0.14), y(0.72), x(0.14), y(0.52))
      ..lineTo(x(0.14), y(0.31))
      ..quadraticBezierTo(x(0.14), y(0.26), x(0.18), y(0.24))
      ..close();
  }

  Path _heartPath(double s) {
    final cx = s * 0.58;
    final cy = s * 0.48;
    final k = s * 0.09;
    return Path()
      ..moveTo(cx, cy + k * 0.55)
      ..cubicTo(cx - k * 0.85, cy - k * 0.05, cx - k * 0.45, cy - k * 0.78, cx, cy - k * 0.22)
      ..cubicTo(cx + k * 0.45, cy - k * 0.78, cx + k * 0.85, cy - k * 0.05, cx, cy + k * 0.55)
      ..close();
  }

  @override
  bool shouldRepaint(_LogoMarkPainter oldDelegate) {
    return oldDelegate.gradient != gradient ||
        oldDelegate.monochromeColor != monochromeColor ||
        oldDelegate.showBadge != showBadge;
  }
}

/// Wordmark « citycare » en bas de casse, comme sur une icône home sécurité.
class CityCareWordmark extends StatelessWidget {
  const CityCareWordmark({
    super.key,
    this.fontSize = 28,
    this.color,
    this.accentColor,
    this.onLime = false,
    this.onBrand = false,
  });

  final double fontSize;
  final Color? color;
  final Color? accentColor;

  /// Ancien drapeau splash vert : désormais wordmark blanc sur violet.
  final bool onLime;
  final bool onBrand;

  @override
  Widget build(BuildContext context) {
    final light = onLime || onBrand;
    final ink = color ?? (light ? Colors.white : CityCareBrand.violet);
    return Text(
      'citycare',
      semanticsLabel: 'CityCare',
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        height: 1.1,
        color: ink,
      ),
    );
  }
}

/// Logo complet : monogramme + wordmark, accroche optionnelle.
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
  final String? tagline;
  final Axis axis;
  final Color? color;
  final Color? accentColor;
  final Color? monochromeColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mark = CityCareLogoMark(size: markSize, monochromeColor: monochromeColor);
    final taglineText = tagline;
    final onBrand = monochromeColor != null || (color != null && color == Colors.white);
    final texts = Column(
      crossAxisAlignment: axis == Axis.horizontal ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        CityCareWordmark(fontSize: fontSize, color: color, accentColor: accentColor, onBrand: onBrand),
        if (taglineText != null) ...[
          const SizedBox(height: CityCareBrand.spaceXs),
          Text(
            taglineText,
            textAlign: axis == Axis.horizontal ? TextAlign.start : TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color?.withValues(alpha: 0.85) ?? theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.4,
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
