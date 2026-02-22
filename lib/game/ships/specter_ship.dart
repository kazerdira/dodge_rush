import 'dart:math';
import 'package:flutter/material.dart';
import 'ship_painter_helpers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SPECTER — Alien / Bio-mechanical Ghost Ship
// ─────────────────────────────────────────────────────────────────────────────
void drawSpecterShip(Canvas canvas, double r, Color color, double animTick) {
  final paint = Paint()..style = PaintingStyle.fill;
  final pulse = sin(animTick * 4) * 0.2 + 0.8;

  // Ethereal Aura
  paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
  paint.color = color.withOpacity(0.4 * pulse);
  canvas.drawCircle(Offset(0, 0), r * 1.2, paint);
  paint.maskFilter = null;

  // Organic, curving hull
  final body = Path()
    ..moveTo(0, -r * 1.3)
    ..quadraticBezierTo(r * 0.8, -r * 0.5, r * 0.6, r * 0.2)
    ..quadraticBezierTo(r * 1.2, r * 0.8, r * 0.4, r * 0.7)
    ..quadraticBezierTo(0, r * 1.2, -r * 0.4, r * 0.7)
    ..quadraticBezierTo(-r * 1.2, r * 0.8, -r * 0.6, r * 0.2)
    ..quadraticBezierTo(-r * 0.8, -r * 0.5, 0, -r * 1.3)
    ..close();

  paint.shader = RadialGradient(
    colors: [Colors.white, color, const Color(0xFF001122)],
    center: const Alignment(0, -0.2),
    radius: 0.8,
  ).createShader(Rect.fromLTWH(-r * 1.2, -r * 1.3, r * 2.4, r * 2.5));
  canvas.drawPath(body, paint);
  paint.shader = null;

  // Internal Energy Veins
  paint.color = Colors.white.withOpacity(0.6 * pulse);
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 1.5;
  paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
  canvas.drawPath(
      Path()
        ..moveTo(0, -r * 1)
        ..quadraticBezierTo(r * 0.3, 0, 0, r * 0.6),
      paint);
  canvas.drawPath(
      Path()
        ..moveTo(0, -r * 1)
        ..quadraticBezierTo(-r * 0.3, 0, 0, r * 0.6),
      paint);
  paint.style = PaintingStyle.fill;
  paint.maskFilter = null;

  // The "Eye" (Cockpit)
  paint.color = Colors.black;
  canvas.drawOval(
      Rect.fromCenter(
          center: Offset(0, -r * 0.2), width: r * 0.5, height: r * 0.8),
      paint);
  paint.color = color;
  canvas.drawOval(
      Rect.fromCenter(
          center: Offset(0, -r * 0.2),
          width: r * 0.15,
          height: r * 0.6 * pulse),
      paint);

  drawEngineFlame(canvas, r, color, [Offset(0, r * 0.9)], [0.3], animTick);
}
