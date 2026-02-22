import 'dart:math';
import 'package:flutter/material.dart';

/// Enhanced engine flame with two-layer rendering (outer glow + inner hot core).
void drawEngineFlame(Canvas canvas, double r, Color color,
    List<Offset> positions, List<double> widths, double animTick) {
  final flicker =
      0.8 + sin(animTick * 25) * 0.3; // Faster, more erratic flicker
  final paint = Paint()..style = PaintingStyle.fill;

  for (int i = 0; i < positions.length; i++) {
    final pos = positions[i];
    final w = widths[i];
    final h = r * (1.2 + flicker * 0.4); // Longer flames

    // Outer Glow
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    paint.shader = LinearGradient(
      colors: [color.withOpacity(0.8), color.withOpacity(0.0)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(pos.dx - r * w * 1.5, pos.dy, r * w * 3, h));
    canvas.drawPath(
      Path()
        ..moveTo(pos.dx - r * w * 1.5, pos.dy)
        ..quadraticBezierTo(pos.dx, pos.dy + h, pos.dx + r * w * 1.5, pos.dy)
        ..close(),
      paint,
    );

    // Inner Hot Core (White/Bright)
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    paint.shader = LinearGradient(
      colors: [Colors.white, color.withOpacity(0.8), Colors.transparent],
      stops: const [0.0, 0.4, 1.0],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(
        Rect.fromLTWH(pos.dx - r * w * 0.6, pos.dy, r * w * 1.2, h * 0.7));
    canvas.drawPath(
      Path()
        ..moveTo(pos.dx - r * w * 0.6, pos.dy)
        ..quadraticBezierTo(
            pos.dx, pos.dy + (h * 0.7), pos.dx + r * w * 0.6, pos.dy)
        ..close(),
      paint,
    );
  }
  paint.shader = null;
  paint.maskFilter = null;
}

/// Builds the jagged Specter silhouette path at absolute coordinates.
/// Used by both the specter ship renderer and the ghost after-image renderer.
Path buildSpecterPath(double cx, double cy, double r) {
  return Path()
    ..moveTo(cx, cy - r * 1.1)
    ..lineTo(cx + r * 0.4, cy - r * 0.4)
    ..lineTo(cx + r * 0.9, cy - r * 0.2)
    ..lineTo(cx + r * 0.5, cy + r * 0.2)
    ..lineTo(cx + r * 0.8, cy + r * 0.8)
    ..lineTo(cx + r * 0.3, cy + r * 0.6)
    ..lineTo(cx, cy + r * 0.85)
    ..lineTo(cx - r * 0.2, cy + r * 0.5)
    ..lineTo(cx - r * 0.6, cy + r * 0.9)
    ..lineTo(cx - r * 0.45, cy + r * 0.3)
    ..lineTo(cx - r * 1.0, cy + r * 0.1)
    ..lineTo(cx - r * 0.5, cy - r * 0.3)
    ..close();
}
