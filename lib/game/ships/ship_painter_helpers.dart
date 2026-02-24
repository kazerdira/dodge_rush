import 'dart:math';
import 'package:flutter/material.dart';
import '../../utils/safe_color.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VISUAL PHILOSOPHY
// • Single overhead-left light source → top-left faces bright, bottom-right dark
// • Matte armor surfaces, NOT chrome / rainbow everything
// • Glow ONLY on: engine exhaust core, weapon energy cells, cockpit glass
// • Sharp silhouette edges with a thin dark outline (no blurry hull borders)
// • Depth via value contrast, not via stacked blur effects
// • Panel seams are subtle dark lines — engraved, not glowing
// ─────────────────────────────────────────────────────────────────────────────

// Light direction constants (top-left source)
const _lightAngle = -pi / 3; // ~−60°, upper-left
final _lightDir = Offset(cos(_lightAngle), sin(_lightAngle));

/// Returns a brightness factor [0..1] for a surface normal described by [angle].
/// angle = 0 → pointing up, pi/2 → pointing right, etc.
double surfaceLit(double angle) {
  final nx = cos(angle - pi / 2);
  final ny = sin(angle - pi / 2);
  final dot = nx * _lightDir.dx + ny * _lightDir.dy;
  return (dot * 0.5 + 0.5).clamp(0.0, 1.0);
}

/// Returns a tinted armor color influenced by the global light direction.
Color armorColor(Color base, double surfaceAngle) {
  final lit = surfaceLit(surfaceAngle);
  return Color.lerp(
    Color.lerp(Colors.black, base, 0.4)!, // shadow
    Color.lerp(base, Colors.white, 0.25)!, // lit
    lit,
  )!;
}

/// Tight, physically-believable engine exhaust.
/// Only the HOT CORE glows. The outer plume is dim and fades quickly.
void drawEngineFlame(
  Canvas canvas,
  double r,
  Color color,
  List<Offset> positions,
  List<double> widths,
  double animTick,
) {
  final flicker = 0.85 + sin(animTick * 22) * 0.15;
  final paint = Paint()..style = PaintingStyle.fill;

  for (int i = 0; i < positions.length; i++) {
    final pos = positions[i];
    final w = widths[i];
    final h = r * (0.9 + flicker * 0.35);

    // Plume: narrow translucent cone, low opacity — not a fireball
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    paint.shader = LinearGradient(
      colors: [color.o(0.55), Colors.transparent],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(
        Rect.fromLTWH(pos.dx - r * w, pos.dy, r * w * 2, h));
    canvas.drawPath(
      Path()
        ..moveTo(pos.dx - r * w * 0.9, pos.dy)
        ..quadraticBezierTo(pos.dx, pos.dy + h, pos.dx + r * w * 0.9, pos.dy)
        ..close(),
      paint,
    );

    // Hot core: white → color, very small, only slight blur
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    paint.shader = LinearGradient(
      colors: [Colors.white, color.o(0.9), Colors.transparent],
      stops: const [0.0, 0.45, 1.0],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(
        Rect.fromLTWH(pos.dx - r * w * 0.38, pos.dy, r * w * 0.76, h * 0.55));
    canvas.drawPath(
      Path()
        ..moveTo(pos.dx - r * w * 0.35, pos.dy)
        ..quadraticBezierTo(
            pos.dx, pos.dy + h * 0.55, pos.dx + r * w * 0.35, pos.dy)
        ..close(),
      paint,
    );
  }
  paint.shader = null;
  paint.maskFilter = null;
}

/// Builds the Specter silhouette path (unchanged interface).
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
