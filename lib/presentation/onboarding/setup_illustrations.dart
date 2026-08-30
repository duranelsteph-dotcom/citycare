import 'package:flutter/material.dart';

import '../../app/brand.dart';

/// Scènes dessinées pour le wizard d’installation (pas de photo Life360).
enum SetupScene { tile, connect, location, home, place }

/// Carte visuelle : photo prévention si fournie, sinon illustration vectorielle.
class SetupHeroCard extends StatelessWidget {
  const SetupHeroCard({
    super.key,
    required this.scene,
    this.photoAsset,
    this.height = 220,
  });

  final SetupScene scene;
  final String? photoAsset;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: CityCareBrand.borderRadiusXl,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photoAsset != null)
              Image.asset(
                photoAsset!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => CustomPaint(
                  painter: _SetupPainter(scene),
                ),
              )
            else
              CustomPaint(painter: _SetupPainter(scene)),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x33000000), Color(0xCC5B2C8B)],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(CityCareBrand.spaceMd),
                child: Icon(_icon, color: Colors.white, size: 36),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData get _icon => switch (scene) {
        SetupScene.tile => Icons.bluetooth_searching,
        SetupScene.connect => Icons.link,
        SetupScene.location => Icons.my_location,
        SetupScene.home => Icons.home_outlined,
        SetupScene.place => Icons.add_location_alt_outlined,
      };
}

class _SetupPainter extends CustomPainter {
  _SetupPainter(this.scene);

  final SetupScene scene;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    final white = Paint()..color = Colors.white.withValues(alpha: 0.92);
    final soft = Paint()..color = Colors.white.withValues(alpha: 0.18);
    final cx = size.width / 2;
    final cy = size.height / 2;

    switch (scene) {
      case SetupScene.tile:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, cy), width: 88, height: 88),
            const Radius.circular(22),
          ),
          white,
        );
        canvas.drawCircle(Offset(cx, cy), 14, Paint()..color = CityCareBrand.violet);
        _arc(canvas, Offset(cx, cy), 28, soft);
        _arc(canvas, Offset(cx, cy), 40, soft);
      case SetupScene.connect:
        canvas.drawCircle(Offset(cx - 36, cy), 28, white);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx + 40, cy), width: 56, height: 88),
            const Radius.circular(12),
          ),
          white,
        );
        canvas.drawLine(
          Offset(cx - 10, cy),
          Offset(cx + 12, cy),
          Paint()
            ..color = Colors.white
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round,
        );
      case SetupScene.location:
        final pin = Path()
          ..moveTo(cx, cy + 36)
          ..quadraticBezierTo(cx - 32, cy + 4, cx - 28, cy - 12)
          ..arcToPoint(Offset(cx + 28, cy - 12), radius: const Radius.circular(28), clockwise: true)
          ..quadraticBezierTo(cx + 32, cy + 4, cx, cy + 36);
        canvas.drawPath(pin, white);
        canvas.drawCircle(Offset(cx, cy - 10), 10, Paint()..color = CityCareBrand.violet);
      case SetupScene.home:
        canvas.drawCircle(Offset(cx, cy + 8), 52, soft);
        final house = Path()
          ..moveTo(cx, cy - 36)
          ..lineTo(cx + 40, cy - 4)
          ..lineTo(cx + 40, cy + 36)
          ..lineTo(cx - 40, cy + 36)
          ..lineTo(cx - 40, cy - 4)
          ..close();
        canvas.drawPath(house, white);
      case SetupScene.place:
        canvas.drawCircle(Offset(cx - 24, cy + 6), 18, white);
        canvas.drawCircle(Offset(cx + 28, cy - 10), 22, white);
        canvas.drawCircle(Offset(cx + 4, cy + 28), 14, soft);
    }
  }

  void _arc(Canvas canvas, Offset c, double r, Paint paint) {
    canvas.drawCircle(c, r, paint..style = PaintingStyle.stroke..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(covariant _SetupPainter oldDelegate) => oldDelegate.scene != scene;
}
