import 'package:flutter/material.dart';
import 'ship_painter_helpers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NOVA — Advanced Delta Fighter
// Wide low-wing delta. Titanium-alloy upper skin, carbon-dark underside.
// Light: upper-left → left wing surface brightest, right trailing edge darkest.
// Glow: only engine exhaust nozzles + weapon cell under fuselage.
// ─────────────────────────────────────────────────────────────────────────────
void drawNovaShip(Canvas canvas, double r, Color color, double animTick) {
  final paint = Paint()..style = PaintingStyle.fill;

  // ── LEFT WING SURFACE (lit — faces upper-left light) ─────────────────────
  final wingLeft = Path()
    ..moveTo(0, -r * 0.85)
    ..lineTo(-r * 1.3, r * 0.65)
    ..lineTo(-r * 0.8, r * 0.78)
    ..lineTo(-r * 0.38, r * 0.42)
    ..lineTo(0, r * 0.68)
    ..close();
  paint.shader = LinearGradient(
    colors: [
      const Color(0xFF9A9AAA), // bright, near fuselage root
      const Color(0xFF5A5A6C),
      const Color(0xFF282834), // dark wing tip
    ],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  ).createShader(Rect.fromLTWH(-r * 1.35, -r * 0.9, r * 1.4, r * 1.7));
  canvas.drawPath(wingLeft, paint);
  paint.shader = null;

  // ── RIGHT WING SURFACE (shadow — facing away from light) ──────────────────
  final wingRight = Path()
    ..moveTo(0, -r * 0.85)
    ..lineTo(r * 1.3, r * 0.65)
    ..lineTo(r * 0.8, r * 0.78)
    ..lineTo(r * 0.38, r * 0.42)
    ..lineTo(0, r * 0.68)
    ..close();
  paint.shader = LinearGradient(
    colors: [
      const Color(0xFF606070), // slightly lit at nose
      const Color(0xFF303040),
      const Color(0xFF141420),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ).createShader(Rect.fromLTWH(0, -r * 0.9, r * 1.35, r * 1.7));
  canvas.drawPath(wingRight, paint);
  paint.shader = null;

  // ── WING PANEL LINES ─────────────────────────────────────────────────────
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 0.7;
  paint.color = const Color(0xFF0A0A14);
  // Left wing ribs (3 structural lines)
  for (int i = 1; i <= 3; i++) {
    final t = i / 4.0;
    canvas.drawLine(
      Offset(-r * 0.08, -r * 0.6 + t * r * 1.1),
      Offset(-r * (0.3 + t * 0.85), r * 0.35 + t * r * 0.28),
      paint,
    );
  }
  // Right wing ribs
  for (int i = 1; i <= 3; i++) {
    final t = i / 4.0;
    canvas.drawLine(
      Offset(r * 0.08, -r * 0.6 + t * r * 1.1),
      Offset(r * (0.3 + t * 0.85), r * 0.35 + t * r * 0.28),
      paint,
    );
  }
  // Centre spine
  canvas.drawLine(Offset(0, -r * 0.8), Offset(0, r * 0.65), paint);
  paint.style = PaintingStyle.fill;

  // ── FUSELAGE BODY ─────────────────────────────────────────────────────────
  final fuselage = Path()
    ..moveTo(0, -r * 1.15)
    ..lineTo(r * 0.28, -r * 0.18)
    ..lineTo(r * 0.22, r * 0.80)
    ..lineTo(-r * 0.22, r * 0.80)
    ..lineTo(-r * 0.28, -r * 0.18)
    ..close();
  // Left face of fuselage — lit
  final fuseLeft = Path()
    ..moveTo(0, -r * 1.15)
    ..lineTo(-r * 0.28, -r * 0.18)
    ..lineTo(-r * 0.22, r * 0.80)
    ..lineTo(0, r * 0.80)
    ..close();
  paint.shader = LinearGradient(
    colors: [const Color(0xFFB0B0C0), const Color(0xFF606070), const Color(0xFF303040)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ).createShader(Rect.fromLTWH(-r * 0.3, -r * 1.2, r * 0.3, r * 2.0));
  canvas.drawPath(fuseLeft, paint);
  paint.shader = null;

  final fuseRight = Path()
    ..moveTo(0, -r * 1.15)
    ..lineTo(r * 0.28, -r * 0.18)
    ..lineTo(r * 0.22, r * 0.80)
    ..lineTo(0, r * 0.80)
    ..close();
  paint.shader = LinearGradient(
    colors: [const Color(0xFF6A6A7A), const Color(0xFF2E2E3C), const Color(0xFF18181E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ).createShader(Rect.fromLTWH(0, -r * 1.2, r * 0.3, r * 2.0));
  canvas.drawPath(fuseRight, paint);
  paint.shader = null;

  // Fuselage outline
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 1.0;
  paint.color = const Color(0xFF06060E);
  canvas.drawPath(fuselage, paint);
  paint.style = PaintingStyle.fill;

  // ── COCKPIT ───────────────────────────────────────────────────────────────
  // Flat faceted canopy typical of delta fighters — no giant glowing orb
  final canopy = Path()
    ..moveTo(0, -r * 0.82)
    ..lineTo(r * 0.18, -r * 0.1)
    ..lineTo(-r * 0.18, -r * 0.1)
    ..close();
  paint.shader = LinearGradient(
    colors: [const Color(0xFF1C3048), const Color(0xFF0A1820)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ).createShader(Rect.fromLTWH(-r * 0.2, -r * 0.85, r * 0.4, r * 0.78));
  canvas.drawPath(canopy, paint);
  paint.shader = null;
  // Glare line
  paint.color = Colors.white.withOpacity(0.45);
  canvas.drawLine(Offset(-r * 0.05, -r * 0.72), Offset(r * 0.03, -r * 0.28), paint);

  // ── WEAPON CELL — small glowing recess under nose ─────────────────────────
  // One tight glow is fine — it's a real energy source
  paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
  paint.color = color.withOpacity(0.7);
  canvas.drawOval(
    Rect.fromCenter(center: Offset(0, -r * 0.05), width: r * 0.12, height: r * 0.08),
    paint,
  );
  paint.maskFilter = null;
  paint.color = Colors.white.withOpacity(0.9);
  canvas.drawOval(
    Rect.fromCenter(center: Offset(0, -r * 0.05), width: r * 0.06, height: r * 0.04),
    paint,
  );

  // ── ENGINE NOZZLES ────────────────────────────────────────────────────────
  // Show nozzle housings before flame — adds mechanical realism
  for (final nx in [-r * 0.48, -r * 0.02, r * 0.48]) {
    paint.color = const Color(0xFF181820);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(nx, r * 0.78), width: r * 0.22, height: r * 0.1),
      paint,
    );
    paint.color = const Color(0xFF2A2A34);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(nx, r * 0.76), width: r * 0.16, height: r * 0.07),
      paint,
    );
  }

  drawEngineFlame(
    canvas,
    r,
    color,
    [Offset(-r * 0.48, r * 0.78), Offset(0, r * 0.82), Offset(r * 0.48, r * 0.78)],
    [0.13, 0.17, 0.13],
    animTick,
  );
}
