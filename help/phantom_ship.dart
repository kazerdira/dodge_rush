import 'package:flutter/material.dart';
import 'ship_painter_helpers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PHANTOM — Stealth Interceptor
// Slender needle silhouette. Matte dark-grey composite hull.
// Light source: upper-left → nose tip bright, underbelly dark.
// Only glow: cockpit glass + engine core.
// ─────────────────────────────────────────────────────────────────────────────
void drawPhantomShip(Canvas canvas, double r, Color color, double animTick) {
  final paint = Paint()..style = PaintingStyle.fill;

  // ── HULL ─────────────────────────────────────────────────────────────────
  // Upper face (lit by top-left source)
  final hullLeft = Path()
    ..moveTo(0, -r * 1.6)
    ..cubicTo(-r * 0.05, -r * 1.0, -r * 0.2, -r * 0.4, -r * 0.45, r * 0.35)
    ..lineTo(-r * 0.55, r * 0.75)
    ..lineTo(-r * 0.18, r * 0.6)
    ..lineTo(0, r * 0.78)
    ..close();

  final hullRight = Path()
    ..moveTo(0, -r * 1.6)
    ..cubicTo(r * 0.05, -r * 1.0, r * 0.2, -r * 0.4, r * 0.45, r * 0.35)
    ..lineTo(r * 0.55, r * 0.75)
    ..lineTo(r * 0.18, r * 0.6)
    ..lineTo(0, r * 0.78)
    ..close();

  // Left face: lit (brighter) — faces the light source
  paint.shader = LinearGradient(
    colors: [
      const Color(0xFF8A8A9A), // bright nose edge
      const Color(0xFF484858), // mid hull
      const Color(0xFF1C1C28), // tail shadow
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ).createShader(Rect.fromLTWH(-r * 0.6, -r * 1.6, r * 0.6, r * 2.5));
  canvas.drawPath(hullLeft, paint);
  paint.shader = null;

  // Right face: shadow (darker)
  paint.shader = LinearGradient(
    colors: [
      const Color(0xFF5A5A6A), // slightly bright at tip (catches some light)
      const Color(0xFF2A2A38),
      const Color(0xFF10101A), // deep shadow
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ).createShader(Rect.fromLTWH(0, -r * 1.6, r * 0.6, r * 2.5));
  canvas.drawPath(hullRight, paint);
  paint.shader = null;

  // Centre ridge highlight — raised spine catches light
  paint.shader = LinearGradient(
    colors: [
      Colors.white.withOpacity(0.30),
      Colors.white.withOpacity(0.10),
      Colors.transparent,
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ).createShader(Rect.fromLTWH(-r * 0.04, -r * 1.6, r * 0.08, r * 2.0));
  canvas.drawRect(Rect.fromLTWH(-r * 0.04, -r * 1.6, r * 0.08, r * 2.0), paint);
  paint.shader = null;

  // ── PANEL SEAMS ──────────────────────────────────────────────────────────
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 0.7;
  paint.color = const Color(0xFF0C0C18);
  // Centre spine
  canvas.drawLine(Offset(0, -r * 1.5), Offset(0, r * 0.7), paint);
  // Rib lines
  for (int i = 1; i <= 4; i++) {
    final y = -r * 1.0 + i * r * 0.4;
    final xOff = r * 0.05 + i * r * 0.07;
    canvas.drawLine(Offset(-xOff, y), Offset(xOff, y), paint);
  }
  paint.style = PaintingStyle.fill;

  // ── DARK SILHOUETTE OUTLINE ───────────────────────────────────────────────
  final fullHull = Path()
    ..moveTo(0, -r * 1.6)
    ..cubicTo(r * 0.05, -r * 1.0, r * 0.2, -r * 0.4, r * 0.45, r * 0.35)
    ..lineTo(r * 0.55, r * 0.75)
    ..lineTo(r * 0.18, r * 0.6)
    ..lineTo(0, r * 0.78)
    ..lineTo(-r * 0.18, r * 0.6)
    ..lineTo(-r * 0.55, r * 0.75)
    ..cubicTo(-r * 0.2, -r * 0.4, -r * 0.05, -r * 1.0, 0, -r * 1.6)
    ..close();
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 1.2;
  paint.color = const Color(0xFF06060F);
  canvas.drawPath(fullHull, paint);
  paint.style = PaintingStyle.fill;

  // ── COCKPIT — tinted glass, single small glow ─────────────────────────────
  final cockpit = Path()
    ..moveTo(0, -r * 0.75)
    ..quadraticBezierTo(r * 0.17, -r * 0.42, r * 0.10, r * 0.05)
    ..lineTo(-r * 0.10, r * 0.05)
    ..quadraticBezierTo(-r * 0.17, -r * 0.42, 0, -r * 0.75)
    ..close();
  // Tinted canopy — dark with slight blue tint, like real glass
  paint.shader = LinearGradient(
    colors: [
      const Color(0xFF1A2840).withOpacity(0.95),
      const Color(0xFF0D1520).withOpacity(0.90),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ).createShader(Rect.fromLTWH(-r * 0.18, -r * 0.75, r * 0.36, r * 0.82));
  canvas.drawPath(cockpit, paint);
  paint.shader = null;

  // Glare — single bright streak, no blur needed
  paint.color = Colors.white.withOpacity(0.55);
  canvas.drawOval(Rect.fromLTWH(-r * 0.12, -r * 0.68, r * 0.06, r * 0.26), paint);

  // Subtle cockpit edge glow (only slight blur, tight radius)
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 1.0;
  paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  paint.color = color.withOpacity(0.5);
  canvas.drawPath(cockpit, paint);
  paint.maskFilter = null;
  paint.style = PaintingStyle.fill;

  // ── ENGINE EXHAUST ────────────────────────────────────────────────────────
  drawEngineFlame(canvas, r, color, [Offset(0, r * 0.78)], [0.22], animTick);
}
