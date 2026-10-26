import 'package:flutter/material.dart';

import '../core/theme/tokens.dart';

class CarliLogo extends StatelessWidget {
  const CarliLogo({super.key, this.size = 30, this.eyeOpenness = 1});

  final double size;
  final double eyeOpenness;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: 'carli',
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: CarliFacePainter(face: colors.primary, eyes: colors.onPrimary, eyeOpenness: eyeOpenness),
      ),
    );
  }
}

class CarliFacePainter extends CustomPainter {
  const CarliFacePainter({required this.face, required this.eyes, this.eyeOpenness = 1});

  final Color face;
  final Color eyes;
  final double eyeOpenness;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);
    canvas.drawRRect(RRect.fromLTRBR(12, 12, 88, 88, const Radius.circular(28)), Paint()..color = face);
    final eyePaint = Paint()..color = eyes;
    for (final x in const [39.0, 61.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 47), width: 11, height: 18 * eyeOpenness.clamp(0.08, 1)),
        eyePaint,
      );
    }
  }

  @override
  bool shouldRepaint(CarliFacePainter oldDelegate) =>
      oldDelegate.face != face || oldDelegate.eyes != eyes || oldDelegate.eyeOpenness != eyeOpenness;
}
