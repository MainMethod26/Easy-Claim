import 'package:flutter/material.dart';

class ShieldPlusIcon extends StatelessWidget {
  final double size;
  final Color color;

  const ShieldPlusIcon({
    super.key,
    this.size = 32.0,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ShieldPlusPainter(color: color),
      ),
    );
  }
}

class _ShieldPlusPainter extends CustomPainter {
  final Color color;

  _ShieldPlusPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final shieldPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    // Shield shape
    path.moveTo(w * 0.15, h * 0.22);
    path.lineTo(w * 0.5, h * 0.12);
    path.lineTo(w * 0.85, h * 0.22);
    path.quadraticBezierTo(w * 0.88, h * 0.58, w * 0.5, h * 0.90);
    path.quadraticBezierTo(w * 0.12, h * 0.58, w * 0.15, h * 0.22);
    path.close();

    canvas.drawPath(path, shieldPaint);

    // Plus sign inside
    final plusPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final cx = w * 0.5;
    final cy = h * 0.48;
    final plusArm = w * 0.14;

    // Horizontal arm
    canvas.drawLine(Offset(cx - plusArm, cy), Offset(cx + plusArm, cy), plusPaint);
    // Vertical arm
    canvas.drawLine(Offset(cx, cy - plusArm), Offset(cx, cy + plusArm), plusPaint);
  }

  @override
  bool shouldRepaint(covariant _ShieldPlusPainter oldDelegate) =>
      oldDelegate.color != color;
}
