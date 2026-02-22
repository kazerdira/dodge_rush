import 'package:flutter/material.dart';
import 'ship_painter_helpers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PHANTOM — Hyper-sleek Stealth Interceptor
// ─────────────────────────────────────────────────────────────────────────────
void drawPhantomShip(Canvas canvas, double r, Color color, double animTick) {
  final paint = Paint()..style = PaintingStyle.fill;

  // Outer Glow / Energy Field
  paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
  paint.color = color.withOpacity(0.3);
  canvas.drawOval(
      Rect.fromCenter(center: Offset(0, 0), width: r * 1.5, height: r * 3),
      paint);
  paint.maskFilter = null;

  // Main Fuselage (Sleek, multi-layered)
  final hull = Path()
    ..moveTo(0, -r * 1.6) // Pointy nose
    ..cubicTo(r * 0.15, -r * 0.8, r * 0.35, -r * 0.2, r * 0.6, r * 0.4)
    ..lineTo(r * 0.65, r * 0.8)
    ..lineTo(r * 0.3, r * 0.6)
    ..lineTo(r * 0.15, r * 0.9) // Thruster housing
    ..lineTo(0, r * 0.8)
    ..lineTo(-r * 0.15, r * 0.9)
    ..lineTo(-r * 0.3, r * 0.6)
    ..lineTo(-r * 0.65, r * 0.8)
    ..cubicTo(-r * 0.35, -r * 0.2, -r * 0.15, -r * 0.8, 0, -r * 1.6)
    ..close();

  // Metallic Gradient
  paint.shader = LinearGradient(
    colors: [const Color(0xFFE8F6FF), color, const Color(0xFF001522)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ).createShader(Rect.fromLTWH(-r, -r * 1.6, r * 2, r * 3.2));
  canvas.drawPath(hull, paint);
  paint.shader = null;

  // Inner Armor Plates (Adds realistic depth)
  final innerArmor = Path()
    ..moveTo(0, -r * 1.2)
    ..lineTo(r * 0.2, -r * 0.3)
    ..lineTo(r * 0.3, r * 0.5)
    ..lineTo(0, r * 0.7)
    ..lineTo(-r * 0.3, r * 0.5)
    ..lineTo(-r * 0.2, -r * 0.3)
    ..close();
  paint.color = Colors.black.withOpacity(0.3);
  canvas.drawPath(innerArmor, paint);

  // Specular Highlight (Makes it look shiny/metal)
  final highlight = Path()
    ..moveTo(0, -r * 1.5)
    ..lineTo(r * 0.1, -r * 0.5)
    ..lineTo(0, r * 0.5)
    ..close();
  paint.color = Colors.white.withOpacity(0.4);
  canvas.drawPath(highlight, paint);

  // High-tech Cockpit Glass
  final cockpit = Path()
    ..moveTo(0, -r * 0.7)
    ..quadraticBezierTo(r * 0.2, -r * 0.3, r * 0.1, r * 0.1)
    ..lineTo(-r * 0.1, r * 0.1)
    ..quadraticBezierTo(-r * 0.2, -r * 0.3, 0, -r * 0.7)
    ..close();
  paint.shader = LinearGradient(
    colors: [Colors.lightBlueAccent, Colors.blue.shade900],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ).createShader(Rect.fromLTWH(-r * 0.2, -r * 0.7, r * 0.4, r * 0.8));
  canvas.drawPath(cockpit, paint);
  paint.shader = null;

  // Cockpit Glare
  paint.color = Colors.white.withOpacity(0.6);
  canvas.drawOval(Rect.fromLTWH(-r * 0.08, -r * 0.6, r * 0.05, r * 0.3), paint);

  drawEngineFlame(canvas, r, color, [Offset(0, r * 0.85)], [0.25], animTick);
}
