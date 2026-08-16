import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// The GoalFlow mark: a progress ring with a check inside.
///
/// Drawn rather than shipped as an image so it stays sharp at any size, tints
/// with the theme, and can animate its progress. The same shape is the app
/// launcher icon and the Android notification icon, so the brand reads as one
/// thing everywhere.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 64,
    this.color,
    this.progress = 0.78,
    this.strokeWidth,
  });

  final double size;
  final Color? color;

  /// 0..1 of the ring that is "done".
  final double progress;
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MarkPainter(
          color: color ?? Theme.of(context).colorScheme.primary,
          progress: progress,
          stroke: strokeWidth ?? size * 0.105,
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter({required this.color, required this.progress, required this.stroke});

  final Color color;
  final double progress;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: c, radius: r);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.22);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawCircle(c, r, track);

    // Starts at the lower-left and sweeps clockwise, leaving the gap at the
    // bottom so the check inside stays the focal point.
    const start = 140 * math.pi / 180;
    canvas.drawArc(rect, start, 2 * math.pi * progress, false, arc);

    final check = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 0.95
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    final path = Path()
      ..moveTo(c.dx - r * 0.42, c.dy + r * 0.02)
      ..lineTo(c.dx - r * 0.10, c.dy + r * 0.36)
      ..lineTo(c.dx + r * 0.46, c.dy - r * 0.34);
    canvas.drawPath(path, check);
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.color != color || old.progress != progress || old.stroke != stroke;
}

/// Mark inside a filled brand tile — used on the login and splash screens.
class BrandBadge extends StatelessWidget {
  const BrandBadge({super.key, this.size = 76});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6C6CE8), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.32),
            blurRadius: size * 0.34,
            offset: Offset(0, size * 0.13),
          ),
        ],
      ),
      child: Center(
        child: BrandMark(size: size * 0.58, color: Colors.white),
      ),
    );
  }
}
