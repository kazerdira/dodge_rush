import 'package:flutter/material.dart';
import 'ship_painter_helpers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TITAN — Massive Dreadnought / Carrier
// ─────────────────────────────────────────────────────────────────────────────
void drawTitanShip(Canvas canvas, double r, Color color, double animTick) {
  final paint = Paint()..style = PaintingStyle.fill;

  // Massive blocky hull
  final hull = Path()
    ..moveTo(-r * 0.6, -r * 1.1)
    ..lineTo(r * 0.6, -r * 1.1)
    ..lineTo(r * 0.9, -r * 0.6)
    ..lineTo(r * 0.9, r * 0.5)
    ..lineTo(r * 1.2, r * 0.8)
    ..lineTo(r * 0.8, r * 1.1)
    ..lineTo(-r * 0.8, r * 1.1)
    ..lineTo(-r * 1.2, r * 0.8)
    ..lineTo(-r * 0.9, r * 0.5)
    ..lineTo(-r * 0.9, -r * 0.6)
    ..close();

  paint.shader = LinearGradient(
    colors: [
      const Color(0xFF667788),
      const Color(0xFF223344),
      const Color(0xFF000000)
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ).createShader(Rect.fromLTWH(-r * 1.2, -r * 1.1, r * 2.4, r * 2.2));
  canvas.drawPath(hull, paint);
  paint.shader = null;

  // Heavy Plating and Structural Ribs
  paint.color = const Color(0xFF111111);
  canvas.drawRect(Rect.fromLTWH(-r * 0.4, -r * 1.1, r * 0.8, r * 2.0), paint);

  paint.color = Colors.grey.shade600;
  for (int i = 0; i < 4; i++) {
    double y = -r * 0.8 + (i * r * 0.4);
    canvas.drawRect(Rect.fromLTWH(-r * 0.8, y, r * 0.3, r * 0.15), paint);
    canvas.drawRect(Rect.fromLTWH(r * 0.5, y, r * 0.3, r * 0.15), paint);
  }

  // Tiny illuminated windows (This trick makes the ship look HUGE)
  paint.color = Colors.lightBlueAccent;
  paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
  for (int i = 0; i < 6; i++) {
    double y = -r * 0.4 + (i * r * 0.2);
    canvas.drawCircle(Offset(-r * 0.3, y), r * 0.04, paint);
    canvas.drawCircle(Offset(r * 0.3, y), r * 0.04, paint);
  }
  paint.maskFilter = null;

  // Bridge / Command Tower
  paint.color = const Color(0xFFFF8800);
  canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(-r * 0.25, -r * 0.2, r * 0.5, r * 0.3),
          const Radius.circular(4)),
      paint);

  drawEngineFlame(
      canvas,
      r,
      color,
      [
        Offset(-r * 0.6, r * 1.1),
        Offset(-r * 0.2, r * 1.1),
        Offset(r * 0.2, r * 1.1),
        Offset(r * 0.6, r * 1.1)
      ],
      [0.15, 0.15, 0.15, 0.15],
      animTick);
}
