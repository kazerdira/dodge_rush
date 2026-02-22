import 'package:flutter/material.dart';
import 'ship_painter_helpers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NOVA — Advanced Delta Fighter
// ─────────────────────────────────────────────────────────────────────────────
void drawNovaShip(Canvas canvas, double r, Color color, double animTick) {
  final paint = Paint()..style = PaintingStyle.fill;

  // Wide, aggressive delta wings
  final wings = Path()
    ..moveTo(0, -r * 0.8)
    ..lineTo(r * 1.3, r * 0.7)
    ..lineTo(r * 0.8, r * 0.8)
    ..lineTo(r * 0.4, r * 0.4)
    ..lineTo(0, r * 0.7)
    ..lineTo(-r * 0.4, r * 0.4)
    ..lineTo(-r * 0.8, r * 0.8)
    ..lineTo(-r * 1.3, r * 0.7)
    ..close();

  paint.shader = RadialGradient(
    colors: [Colors.white, color, Colors.black87],
    center: const Alignment(0, -0.3),
    radius: 0.8,
  ).createShader(Rect.fromLTWH(-r * 1.5, -r, r * 3, r * 2));
  canvas.drawPath(wings, paint);
  paint.shader = null;

  // Central Fuselage (gives 3D volume)
  final fuselage = Path()
    ..moveTo(0, -r * 1.1)
    ..lineTo(r * 0.3, -r * 0.2)
    ..lineTo(r * 0.25, r * 0.8)
    ..lineTo(-r * 0.25, r * 0.8)
    ..lineTo(-r * 0.3, -r * 0.2)
    ..close();
  paint.shader = LinearGradient(
    colors: [Colors.grey.shade300, Colors.grey.shade800],
  ).createShader(Rect.fromLTWH(-r * 0.3, -r * 1.1, r * 0.6, r * 2));
  canvas.drawPath(fuselage, paint);
  paint.shader = null;

  // Panel Seams
  paint.color = Colors.black.withOpacity(0.5);
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 1.0;
  canvas.drawLine(Offset(0, -r * 0.8), Offset(0, r * 0.7), paint);
  canvas.drawLine(Offset(-r * 0.4, r * 0.4), Offset(-r * 1.1, r * 0.6), paint);
  canvas.drawLine(Offset(r * 0.4, r * 0.4), Offset(r * 1.1, r * 0.6), paint);
  paint.style = PaintingStyle.fill;

  // Glowing Vents
  paint.color = Colors.cyanAccent;
  paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
  canvas.drawRect(Rect.fromLTWH(r * 0.35, r * 0.1, r * 0.15, r * 0.4), paint);
  canvas.drawRect(Rect.fromLTWH(-r * 0.5, r * 0.1, r * 0.15, r * 0.4), paint);
  paint.maskFilter = null;

  // Gold-tinted Canopy
  paint.color = const Color(0xFFFFD700).withOpacity(0.85);
  canvas.drawOval(
      Rect.fromCenter(center: Offset(0, 0), width: r * 0.35, height: r * 0.8),
      paint);

  drawEngineFlame(
      canvas,
      r,
      color,
      [
        Offset(-r * 0.5, r * 0.7),
        Offset(0, r * 0.85),
        Offset(r * 0.5, r * 0.7)
      ],
      [0.15, 0.2, 0.15],
      animTick);
}
