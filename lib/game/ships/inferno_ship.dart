import 'package:flutter/material.dart';
import 'ship_painter_helpers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// INFERNO — Heavy Muscle/Bomber
// ─────────────────────────────────────────────────────────────────────────────
void drawInfernoShip(Canvas canvas, double r, Color color, double animTick) {
  final paint = Paint()..style = PaintingStyle.fill;

  // Bulky Main Body
  final body = Path()
    ..moveTo(-r * 0.4, -r * 0.9)
    ..lineTo(r * 0.4, -r * 0.9) // Flat, aggressive nose
    ..lineTo(r * 0.8, -r * 0.3)
    ..lineTo(r * 1.1, r * 0.6)
    ..lineTo(r * 0.6, r * 1.0)
    ..lineTo(0, r * 0.7)
    ..lineTo(-r * 0.6, r * 1.0)
    ..lineTo(-r * 1.1, r * 0.6)
    ..lineTo(-r * 0.8, -r * 0.3)
    ..close();

  paint.shader = LinearGradient(
    colors: [
      const Color(0xFFFFAA00),
      const Color(0xFFCC1100),
      const Color(0xFF330000)
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ).createShader(Rect.fromLTWH(-r * 1.1, -r * 1, r * 2.2, r * 2));
  canvas.drawPath(body, paint);
  paint.shader = null;

  // Dark Armor Plating overlapping
  final armor = Path()
    ..moveTo(-r * 0.3, -r * 0.6)
    ..lineTo(r * 0.3, -r * 0.6)
    ..lineTo(r * 0.6, r * 0.2)
    ..lineTo(0, r * 0.5)
    ..lineTo(-r * 0.6, r * 0.2)
    ..close();
  paint.color = const Color(0xFF1A1A1A);
  canvas.drawPath(armor, paint);

  // Armor Highlights
  paint.color = Colors.white.withOpacity(0.2);
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 2;
  canvas.drawPath(armor, paint);
  paint.style = PaintingStyle.fill;

  // Forward Swept Canards (Wings)
  paint.color = const Color(0xFF881100);
  canvas.drawPath(
      Path()
        ..moveTo(r * 0.7, -r * 0.1)
        ..lineTo(r * 1.4, -r * 0.5)
        ..lineTo(r * 1.0, r * 0.3)
        ..close(),
      paint);
  canvas.drawPath(
      Path()
        ..moveTo(-r * 0.7, -r * 0.1)
        ..lineTo(-r * 1.4, -r * 0.5)
        ..lineTo(-r * 1.0, r * 0.3)
        ..close(),
      paint);

  // Glowing Red Eyes / Cockpit slit
  paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  paint.color = Colors.yellowAccent;
  canvas.drawRect(Rect.fromLTWH(-r * 0.3, -r * 0.8, r * 0.6, r * 0.15), paint);
  paint.maskFilter = null;
  paint.color = Colors.white;
  canvas.drawRect(
      Rect.fromLTWH(-r * 0.25, -r * 0.78, r * 0.5, r * 0.08), paint);

  drawEngineFlame(
      canvas,
      r,
      color,
      [Offset(-r * 0.45, r * 0.9), Offset(r * 0.45, r * 0.9)],
      [0.25, 0.25],
      animTick);
}
