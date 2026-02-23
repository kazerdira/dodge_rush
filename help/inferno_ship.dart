import 'package:flutter/material.dart';
import 'ship_painter_helpers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// INFERNO — Heavy Bomber / Gunship
// Thick, brutish silhouette. Riveted dark-orange heat-shield plates on nose.
// Underbelly bomb-bay recess. No rainbow gradients — just cast iron + heat.
// Light: top-left. Nose top is bright warm-grey, flanks drop to near-black.
// Glow: only engine nozzles + bomb-bay thermal recess.
// ─────────────────────────────────────────────────────────────────────────────
void drawInfernoShip(Canvas canvas, double r, Color color, double animTick) {
  final paint = Paint()..style = PaintingStyle.fill;

  // ── MAIN BODY ─────────────────────────────────────────────────────────────
  final body = Path()
    ..moveTo(-r * 0.38, -r * 0.92)
    ..lineTo(r * 0.38, -r * 0.92) // flat nose — aggressive
    ..lineTo(r * 0.75, -r * 0.28)
    ..lineTo(r * 1.08, r * 0.55)
    ..lineTo(r * 0.55, r * 0.98)
    ..lineTo(0, r * 0.72)
    ..lineTo(-r * 0.55, r * 0.98)
    ..lineTo(-r * 1.08, r * 0.55)
    ..lineTo(-r * 0.75, -r * 0.28)
    ..close();

  // Left (lit) half
  final bodyLeft = Path()
    ..moveTo(-r * 0.38, -r * 0.92)
    ..lineTo(0, -r * 0.92)
    ..lineTo(0, r * 0.72)
    ..lineTo(-r * 0.55, r * 0.98)
    ..lineTo(-r * 1.08, r * 0.55)
    ..lineTo(-r * 0.75, -r * 0.28)
    ..close();
  paint.shader = LinearGradient(
    colors: [
      const Color(0xFF8C6040), // warm lit nose
      const Color(0xFF4A2E18),
      const Color(0xFF1E1008), // deep shadow at flanks
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomLeft,
  ).createShader(Rect.fromLTWH(-r * 1.1, -r, r * 1.1, r * 2.0));
  canvas.drawPath(bodyLeft, paint);
  paint.shader = null;

  // Right (shadow) half
  final bodyRight = Path()
    ..moveTo(0, -r * 0.92)
    ..lineTo(r * 0.38, -r * 0.92)
    ..lineTo(r * 0.75, -r * 0.28)
    ..lineTo(r * 1.08, r * 0.55)
    ..lineTo(r * 0.55, r * 0.98)
    ..lineTo(0, r * 0.72)
    ..close();
  paint.shader = LinearGradient(
    colors: [
      const Color(0xFF5A3A22),
      const Color(0xFF2A1A0C),
      const Color(0xFF100805),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ).createShader(Rect.fromLTWH(0, -r, r * 1.1, r * 2.0));
  canvas.drawPath(bodyRight, paint);
  paint.shader = null;

  // ── FORWARD SWEPT CANARDS ─────────────────────────────────────────────────
  final canardColor = const Color(0xFF3A1A08);
  for (int side = -1; side <= 1; side += 2) {
    final s = side.toDouble();
    final canard = Path()
      ..moveTo(s * r * 0.65, -r * 0.18)
      ..lineTo(s * r * 1.38, -r * 0.52)
      ..lineTo(s * r * 1.0, r * 0.25)
      ..close();
    paint.color = canardColor;
    canvas.drawPath(canard, paint);
    // Top edge rim light
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.0;
    paint.color = const Color(0xFF886644).withOpacity(side < 0 ? 0.7 : 0.3);
    canvas.drawLine(Offset(s * r * 0.65, -r * 0.18), Offset(s * r * 1.38, -r * 0.52), paint);
    paint.style = PaintingStyle.fill;
  }

  // ── NOSE HEAT-SHIELD PLATE ─────────────────────────────────────────────────
  // Slightly lighter panel on nose suggesting a separate armour tile
  paint.shader = LinearGradient(
    colors: [const Color(0xFF9A6840), const Color(0xFF5A3820)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ).createShader(Rect.fromLTWH(-r * 0.28, -r * 0.90, r * 0.56, r * 0.45));
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(-r * 0.28, -r * 0.90, r * 0.56, r * 0.45),
      const Radius.circular(2),
    ),
    paint,
  );
  paint.shader = null;

  // ── PANEL SEAMS ───────────────────────────────────────────────────────────
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 0.7;
  paint.color = const Color(0xFF0A0404);
  canvas.drawLine(Offset(0, -r * 0.88), Offset(0, r * 0.65), paint);
  // Armour plate dividers
  canvas.drawLine(Offset(-r * 0.38, -r * 0.44), Offset(r * 0.38, -r * 0.44), paint);
  canvas.drawLine(Offset(-r * 0.60, r * 0.10), Offset(r * 0.60, r * 0.10), paint);
  for (int side = -1; side <= 1; side += 2) {
    canvas.drawLine(Offset(side * r * 0.28, -r * 0.88), Offset(side * r * 0.68, r * 0.08), paint);
  }
  paint.style = PaintingStyle.fill;

  // ── BODY SILHOUETTE OUTLINE ───────────────────────────────────────────────
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 1.3;
  paint.color = const Color(0xFF080404);
  canvas.drawPath(body, paint);
  paint.style = PaintingStyle.fill;

  // ── BOMB-BAY THERMAL RECESS ───────────────────────────────────────────────
  // A recessed glow showing live ordnance — one single justified glow
  paint.color = const Color(0xFF100802);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, r * 0.25), width: r * 0.44, height: r * 0.18),
      const Radius.circular(3),
    ),
    paint,
  );
  paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
  paint.color = color.withOpacity(0.65);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, r * 0.25), width: r * 0.36, height: r * 0.12),
      const Radius.circular(2),
    ),
    paint,
  );
  paint.maskFilter = null;

  // ── COCKPIT SLIT ──────────────────────────────────────────────────────────
  paint.color = const Color(0xFF080404);
  canvas.drawRect(Rect.fromLTWH(-r * 0.28, -r * 0.82, r * 0.56, r * 0.14), paint);
  // Thin amber glow line inside the slit — not blasting white
  paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
  paint.color = const Color(0xFFCC8800).withOpacity(0.9);
  canvas.drawRect(Rect.fromLTWH(-r * 0.22, -r * 0.78, r * 0.44, r * 0.06), paint);
  paint.maskFilter = null;

  // ── ENGINE NOZZLE HOUSINGS + FLAMES ──────────────────────────────────────
  for (final nx in [-r * 0.42, r * 0.42]) {
    paint.color = const Color(0xFF1C0E06);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(nx, r * 0.92), width: r * 0.32, height: r * 0.14),
      paint,
    );
    paint.color = const Color(0xFF2C1A0C);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(nx, r * 0.90), width: r * 0.22, height: r * 0.09),
      paint,
    );
  }

  drawEngineFlame(
    canvas,
    r,
    color,
    [Offset(-r * 0.42, r * 0.90), Offset(r * 0.42, r * 0.90)],
    [0.22, 0.22],
    animTick,
  );
}
