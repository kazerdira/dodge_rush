import 'dart:math';
import 'package:flutter/material.dart';
import '../../utils/safe_color.dart';
import 'ship_painter_helpers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SPECTER — Stealth Ghost Fighter
// Dark composite, extremely low observable. Almost no glow.
// Light: top-left. Dark all over — only the tiniest visor slit and engine
// exhaust give away its position. Think B-2 bomber crossed with alien predator.
// ─────────────────────────────────────────────────────────────────────────────
void drawSpecterShip(Canvas canvas, double r, Color color, double animTick) {
  final paint = Paint()..style = PaintingStyle.fill;
  final pulse = sin(animTick * 3) * 0.08 + 0.92; // very subtle

  // ── SWEPT WINGS ──────────────────────────────────────────────────────────
  for (int side = -1; side <= 1; side += 2) {
    final s = side.toDouble();
    final wing = Path()
      ..moveTo(s * r * 0.22, -r * 0.22)
      ..lineTo(s * r * 1.18, r * 0.12)
      ..lineTo(s * r * 1.12, r * 0.28)
      ..lineTo(s * r * 0.52, r * 0.52)
      ..lineTo(s * r * 0.18, r * 0.38)
      ..close();

    // Wing: very dark, slight variation from lit leading to shadow trailing
    paint.shader = LinearGradient(
      colors: [
        const Color(0xFF2E2E40), // leading edge slightly lighter
        const Color(0xFF1A1A28),
        const Color(0xFF0E0E18), // tip: near-black
      ],
      begin: side < 0 ? Alignment.topRight : Alignment.topLeft,
      end: side < 0 ? Alignment.bottomLeft : Alignment.bottomRight,
    ).createShader(Rect.fromLTWH(
      side < 0 ? -r * 1.2 : 0, -r * 0.25, r * 1.2, r * 0.82,
    ));
    canvas.drawPath(wing, paint);
    paint.shader = null;

    // Leading edge: single crisp highlight — physically correct rim light
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 0.9;
    paint.color = side < 0
        ? Colors.white.o(0.22) // lit side
        : Colors.white.o(0.08); // shadow side
    canvas.drawLine(
      Offset(s * r * 0.22, -r * 0.22),
      Offset(s * r * 1.18, r * 0.12),
      paint,
    );
    // Wing outline
    paint.strokeWidth = 0.8;
    paint.color = const Color(0xFF060610);
    canvas.drawPath(wing, paint);
    paint.style = PaintingStyle.fill;

    // Wingtip nav light: a single 2px dot, no bloom
    paint.color = color.o(0.8 * pulse);
    canvas.drawCircle(Offset(s * r * 1.12, r * 0.20), 1.8, paint);
  }

  // ── MAIN HULL ─────────────────────────────────────────────────────────────
  final body = Path()
    ..moveTo(0, -r * 1.32)
    ..lineTo(r * 0.11, -r * 1.06)
    ..quadraticBezierTo(r * 0.33, -r * 0.68, r * 0.43, -r * 0.33)
    ..quadraticBezierTo(r * 0.53, -r * 0.08, r * 0.43, r * 0.14)
    ..quadraticBezierTo(r * 0.33, r * 0.48, r * 0.19, r * 0.73)
    ..lineTo(r * 0.08, r * 0.63)
    ..lineTo(0, r * 0.78)
    ..lineTo(-r * 0.08, r * 0.63)
    ..lineTo(-r * 0.19, r * 0.73)
    ..quadraticBezierTo(-r * 0.33, r * 0.48, -r * 0.43, r * 0.14)
    ..quadraticBezierTo(-r * 0.53, -r * 0.08, -r * 0.43, -r * 0.33)
    ..quadraticBezierTo(-r * 0.33, -r * 0.68, -r * 0.11, -r * 1.06)
    ..close();

  // Left (lit) face
  final bodyLeft = Path()
    ..moveTo(0, -r * 1.32)
    ..lineTo(-r * 0.11, -r * 1.06)
    ..quadraticBezierTo(-r * 0.33, -r * 0.68, -r * 0.43, -r * 0.33)
    ..quadraticBezierTo(-r * 0.53, -r * 0.08, -r * 0.43, r * 0.14)
    ..quadraticBezierTo(-r * 0.33, r * 0.48, -r * 0.19, r * 0.73)
    ..lineTo(-r * 0.08, r * 0.63)
    ..lineTo(0, r * 0.78)
    ..lineTo(0, -r * 1.32)
    ..close();
  paint.shader = LinearGradient(
    colors: [
      const Color(0xFF4A4A60), // nose: slightly lit
      const Color(0xFF2C2C3C),
      const Color(0xFF16161E), // tail
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomLeft,
  ).createShader(Rect.fromLTWH(-r * 0.55, -r * 1.35, r * 0.55, r * 2.2));
  canvas.drawPath(bodyLeft, paint);
  paint.shader = null;

  // Right (shadow) face
  final bodyRight = Path()
    ..moveTo(0, -r * 1.32)
    ..lineTo(r * 0.11, -r * 1.06)
    ..quadraticBezierTo(r * 0.33, -r * 0.68, r * 0.43, -r * 0.33)
    ..quadraticBezierTo(r * 0.53, -r * 0.08, r * 0.43, r * 0.14)
    ..quadraticBezierTo(r * 0.33, r * 0.48, r * 0.19, r * 0.73)
    ..lineTo(r * 0.08, r * 0.63)
    ..lineTo(0, r * 0.78)
    ..lineTo(0, -r * 1.32)
    ..close();
  paint.shader = LinearGradient(
    colors: [
      const Color(0xFF2E2E40),
      const Color(0xFF18181E),
      const Color(0xFF0C0C12),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ).createShader(Rect.fromLTWH(0, -r * 1.35, r * 0.55, r * 2.2));
  canvas.drawPath(bodyRight, paint);
  paint.shader = null;

  // Centre ridge specular — very narrow bright line at the spine
  paint.color = Colors.white.o(0.16);
  canvas.drawLine(Offset(0, -r * 1.28), Offset(0, r * 0.55), paint);

  // ── PANEL ENGRAVING ───────────────────────────────────────────────────────
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 0.6;
  paint.color = const Color(0xFF080810);
  canvas.drawLine(Offset(0, -r * 1.1), Offset(0, r * 0.58), paint);
  for (int side = -1; side <= 1; side += 2) {
    canvas.drawLine(Offset(0, -r * 0.58), Offset(side * r * 0.33, r * 0.08), paint);
    canvas.drawLine(Offset(side * r * 0.10, -r * 0.88), Offset(side * r * 0.38, -r * 0.22), paint);
  }
  paint.style = PaintingStyle.fill;

  // Hull outline
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 1.1;
  paint.color = const Color(0xFF050508);
  canvas.drawPath(body, paint);
  paint.style = PaintingStyle.fill;

  // ── VISOR SLIT ────────────────────────────────────────────────────────────
  // Dark socket
  paint.color = Colors.black;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, -r * 0.44), width: r * 0.54, height: r * 0.14),
      const Radius.circular(20),
    ),
    paint,
  );
  // Glowing core slit — subtle, tight blur
  paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
  paint.color = color.o(0.80 * pulse);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, -r * 0.44), width: r * 0.44, height: r * 0.065),
      const Radius.circular(20),
    ),
    paint,
  );
  paint.maskFilter = null;
  // White core line — no blur
  paint.color = Colors.white.o(0.78);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, -r * 0.44), width: r * 0.26, height: r * 0.028),
      const Radius.circular(10),
    ),
    paint,
  );

  // ── EXHAUST HOUSINGS ──────────────────────────────────────────────────────
  for (final nx in [-r * 0.10, r * 0.10]) {
    paint.color = const Color(0xFF06060A);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(nx, r * 0.72), width: r * 0.14, height: r * 0.08),
      paint,
    );
  }

  drawEngineFlame(
    canvas,
    r,
    color,
    [Offset(-r * 0.10, r * 0.72), Offset(r * 0.10, r * 0.72)],
    [0.11, 0.11],
    animTick,
  );
}
