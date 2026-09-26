import 'dart:math' as math;
import 'package:flutter/material.dart';

class EasyClaimLogo extends StatelessWidget {
  final double size;
  final BoxFit fit;

  const EasyClaimLogo({
    super.key,
    this.size = 48.0,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/LOGO.png',
      height: size,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => SizedBox(
        width: size * 1.5,
        height: size,
        child: CustomPaint(
          painter: _EasyClaimLogoPainter(),
        ),
      ),
    );
  }
}

class _EasyClaimLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Speeds streaks on the left
    final speedPaint = Paint()
      ..color = const Color(0xFFFF5500)
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.08
      ..strokeCap = StrokeCap.round;

    // 3 Speed streaks on the left
    canvas.drawLine(
      Offset(w * 0.08, h * 0.32),
      Offset(w * 0.28, h * 0.32),
      speedPaint,
    );
    canvas.drawLine(
      Offset(w * 0.02, h * 0.46),
      Offset(w * 0.30, h * 0.46),
      speedPaint,
    );
    canvas.drawLine(
      Offset(w * 0.10, h * 0.60),
      Offset(w * 0.26, h * 0.60),
      speedPaint,
    );

    // Blue Circle / 'E' swoop
    final center = Offset(w * 0.58, h * 0.48);
    final radius = h * 0.38;

    final bluePaint = Paint()
      ..color = const Color(0xFF0072FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.14
      ..strokeCap = StrokeCap.round;

    // Draw the outer blue arc
    final blueRect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      blueRect,
      math.pi * 0.85,
      math.pi * 1.55,
      false,
      bluePaint,
    );

    // Inner checkmark / swoosh in vibrant orange
    final swooshPaint = Paint()
      ..color = const Color(0xFFFF5500)
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.13
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final swooshPath = Path();
    swooshPath.moveTo(center.dx - radius * 0.65, center.dy + radius * 0.05);
    swooshPath.lineTo(center.dx - radius * 0.15, center.dy + radius * 0.55);
    swooshPath.lineTo(center.dx + radius * 0.95, center.dy - radius * 0.45);

    canvas.drawPath(swooshPath, swooshPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
