import 'package:flutter/material.dart';

class MobileStatusBar extends StatelessWidget {
  final String time;
  final Color color;

  const MobileStatusBar({
    super.key,
    this.time = '9:41',
    this.color = const Color(0xFF0F172A),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Time
          Text(
            time,
            style: TextStyle(
              color: color,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          // Status Icons
          Row(
            children: [
              // Cellular Signal Bars
              CustomPaint(
                size: const Size(18, 12),
                painter: _SignalBarsPainter(color: color),
              ),
              const SizedBox(width: 6),
              // Wi-Fi Icon
              Icon(
                Icons.wifi,
                color: color,
                size: 16.5,
              ),
              const SizedBox(width: 6),
              // Battery Icon
              CustomPaint(
                size: const Size(24, 12),
                painter: _BatteryPainter(level: 0.85, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignalBarsPainter extends CustomPainter {
  final Color color;

  _SignalBarsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const barCount = 4;
    final barWidth = size.width / (barCount * 1.8);
    final gap = barWidth * 0.8;

    for (int i = 0; i < barCount; i++) {
      final barHeight = size.height * (0.4 + 0.6 * (i / (barCount - 1)));
      final x = i * (barWidth + gap);
      final y = size.height - barHeight;

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(1.0),
      );
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BatteryPainter extends CustomPainter {
  final double level;
  final Color color;

  _BatteryPainter({this.level = 0.85, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final outlinePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Body
    final bodyWidth = size.width - 3.5;
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, bodyWidth, size.height),
      const Radius.circular(3.5),
    );
    canvas.drawRRect(bodyRect, outlinePaint);

    // Terminal bump
    final terminalRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bodyWidth + 1.0, size.height * 0.3, 2.0, size.height * 0.4),
      const Radius.circular(1.0),
    );
    canvas.drawRRect(terminalRect, fillPaint);

    // Fill level
    final innerPad = 2.0;
    final fillMaxW = bodyWidth - (innerPad * 2);
    final fillW = fillMaxW * level.clamp(0.0, 1.0);
    final fillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        innerPad,
        innerPad,
        fillW,
        size.height - (innerPad * 2),
      ),
      const Radius.circular(2.0),
    );
    canvas.drawRRect(fillRect, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
