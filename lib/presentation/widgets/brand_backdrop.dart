import 'package:flutter/material.dart';

import '../../app/brand.dart';

/// Fond violet des écrans d’accueil : cercles superposés + grand cœur filigrane.
class CityCareBrandBackdrop extends StatelessWidget {
  const CityCareBrandBackdrop({super.key, this.color = CityCareBrand.violet});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: const CustomPaint(
        painter: _BrandBackdropPainter(),
        size: Size.infinite,
      ),
    );
  }
}

class _BrandBackdropPainter extends CustomPainter {
  const _BrandBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final soft = Paint()..color = Colors.white.withValues(alpha: 0.06);
    final softer = Paint()..color = CityCareBrand.violetDeep.withValues(alpha: 0.28);

    canvas.drawCircle(Offset(w * 0.12, h * 0.08), w * 0.42, soft);
    canvas.drawCircle(Offset(w * 0.92, h * 0.18), w * 0.38, softer);
    canvas.drawCircle(Offset(w * 0.85, h * 0.92), w * 0.48, soft);
    canvas.drawCircle(Offset(w * 0.05, h * 0.78), w * 0.32, softer);

    // Grands cœurs translucides, calqués sur l’accueil type sécurité.
    canvas.drawPath(
      _heart(Offset(w * 0.50, h * 0.48), w * 0.46),
      Paint()..color = CityCareBrand.violetDeep.withValues(alpha: 0.26),
    );
    canvas.drawPath(
      _heart(Offset(w * 0.16, h * 0.20), w * 0.30),
      Paint()..color = Colors.white.withValues(alpha: 0.05),
    );
    canvas.drawPath(
      _heart(Offset(w * 0.88, h * 0.78), w * 0.34),
      Paint()..color = Colors.white.withValues(alpha: 0.045),
    );
  }

  Path _heart(Offset center, double scale) {
    final cx = center.dx;
    final cy = center.dy;
    final k = scale;
    return Path()
      ..moveTo(cx, cy + k * 0.48)
      ..cubicTo(cx - k * 0.95, cy - k * 0.05, cx - k * 0.55, cy - k * 0.82, cx, cy - k * 0.28)
      ..cubicTo(cx + k * 0.55, cy - k * 0.82, cx + k * 0.95, cy - k * 0.05, cx, cy + k * 0.48)
      ..close();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
