import 'dart:math';
import 'package:flutter/material.dart';
import 'ship_painter_helpers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SPECTER — Stealth Ghost Fighter
// Dark, angular, solid hull. Minimal glow — only on cockpit slit and engines.
// Think stealth bomber meets alien predator.
// ─────────────────────────────────────────────────────────────────────────────
void drawSpecterShip(Canvas canvas, double r, Color color, double animTick) {
  final paint = Paint()..style = PaintingStyle.fill;
  final pulse = sin(animTick * 3) * 0.12 + 0.88;

  // ── 1. SUBTLE UNDERGLOW (single, tight, understated) ──────────────────
  paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
  paint.color = color.withOpacity(0.18 * pulse);
  canvas.drawOval(
      Rect.fromCenter(
          center: Offset(0, r * 0.1), width: r * 2.0, height: r * 2.2),
      paint);
  paint.maskFilter = null;

  // ── 2. SWEPT WINGS (solid, dark, angular) ─────────────────────────────
  for (int side = -1; side <= 1; side += 2) {
    final wing = Path()
      ..moveTo(side * r * 0.25, -r * 0.2)
      ..lineTo(side * r * 1.2, r * 0.15)
      ..lineTo(side * r * 1.15, r * 0.3)
      ..lineTo(side * r * 0.55, r * 0.55)
      ..lineTo(side * r * 0.2, r * 0.4)
      ..close();

    // Solid wing fill — visible against dark background
    paint.shader = LinearGradient(
      colors: [
        const Color(0xFF3D3D58),
        const Color(0xFF262638),
        const Color(0xFF16162A),
      ],
      begin: side < 0 ? Alignment.centerRight : Alignment.centerLeft,
      end: side < 0 ? Alignment.centerLeft : Alignment.centerRight,
    ).createShader(
        Rect.fromLTWH(side < 0 ? -r * 1.25 : 0, -r * 0.25, r * 1.25, r * 0.85));
    canvas.drawPath(wing, paint);
    paint.shader = null;

    // Wing edge highlight — thin colored accent line
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.2;
    paint.color = color.withOpacity(0.5);
    canvas.drawLine(Offset(side * r * 0.25, -r * 0.2),
        Offset(side * r * 1.2, r * 0.15), paint);
    // Trailing edge — dimmer
    paint.color = color.withOpacity(0.2);
    paint.strokeWidth = 0.8;
    canvas.drawLine(Offset(side * r * 1.15, r * 0.3),
        Offset(side * r * 0.55, r * 0.55), paint);
    paint.style = PaintingStyle.fill;

    // Wingtip light — small solid dot
    paint.color = color.withOpacity(0.9 * pulse);
    canvas.drawCircle(Offset(side * r * 1.15, r * 0.22), 1.8, paint);
  }

  // ── 3. MAIN HULL (solid, dark, sleek) ─────────────────────────────────
  final body = Path()
    ..moveTo(0, -r * 1.3)
    // Narrow pointed nose
    ..lineTo(r * 0.12, -r * 1.05)
    // Right upper hull — subtle curve
    ..quadraticBezierTo(r * 0.35, -r * 0.7, r * 0.45, -r * 0.35)
    // Right shoulder widens
    ..quadraticBezierTo(r * 0.55, -r * 0.1, r * 0.45, r * 0.15)
    // Right flank tapers to tail
    ..quadraticBezierTo(r * 0.35, r * 0.5, r * 0.2, r * 0.75)
    // Tail notch (center)
    ..lineTo(r * 0.08, r * 0.65)
    ..lineTo(0, r * 0.8)
    ..lineTo(-r * 0.08, r * 0.65)
    ..lineTo(-r * 0.2, r * 0.75)
    // Left flank
    ..quadraticBezierTo(-r * 0.35, r * 0.5, -r * 0.45, r * 0.15)
    // Left shoulder
    ..quadraticBezierTo(-r * 0.55, -r * 0.1, -r * 0.45, -r * 0.35)
    // Left upper hull
    ..quadraticBezierTo(-r * 0.35, -r * 0.7, -r * 0.12, -r * 1.05)
    ..close();

  // Solid hull gradient — bright enough to stand out on the dark background
  paint.shader = LinearGradient(
    colors: [
      const Color(0xFF4A4A65),
      const Color(0xFF303048),
      const Color(0xFF1E1E35),
      const Color(0xFF141428),
    ],
    stops: const [0.0, 0.3, 0.7, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ).createShader(Rect.fromLTWH(-r * 0.55, -r * 1.3, r * 1.1, r * 2.1));
  canvas.drawPath(body, paint);
  paint.shader = null;

  // Specular highlight — bright strip on upper hull (gives 3D shape)
  paint.shader = LinearGradient(
    colors: [
      Colors.white.withOpacity(0.22),
      Colors.white.withOpacity(0.08),
      Colors.transparent,
    ],
    stops: const [0.0, 0.35, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ).createShader(Rect.fromLTWH(-r * 0.3, -r * 1.3, r * 0.6, r * 1.0));
  canvas.drawPath(body, paint);
  paint.shader = null;

  // Hull panel lines — structural detail
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 0.6;
  paint.color = const Color(0xFF5A5A78).withOpacity(0.5);
  // Center spine line
  canvas.drawLine(Offset(0, -r * 1.1), Offset(0, r * 0.6), paint);
  // Angled panel seams
  for (int side = -1; side <= 1; side += 2) {
    canvas.drawLine(
        Offset(0, -r * 0.6), Offset(side * r * 0.35, r * 0.1), paint);
    canvas.drawLine(Offset(side * r * 0.1, -r * 0.9),
        Offset(side * r * 0.4, -r * 0.2), paint);
  }
  paint.style = PaintingStyle.fill;

  // ── 4. COCKPIT (narrow slit visor, not a round eye) ───────────────────
  // Dark socket
  final cockpitRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(0, -r * 0.45), width: r * 0.6, height: r * 0.15),
      const Radius.circular(20));
  paint.color = const Color(0xFF000000);
  canvas.drawRRect(cockpitRect, paint);

  // Glowing visor slit
  paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  paint.color = color.withOpacity(0.85 * pulse);
  final visorRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(0, -r * 0.45), width: r * 0.5, height: r * 0.07),
      const Radius.circular(20));
  canvas.drawRRect(visorRect, paint);
  paint.maskFilter = null;
  // Bright center of visor
  paint.color = Colors.white.withOpacity(0.8);
  final visorCore = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(0, -r * 0.45), width: r * 0.3, height: r * 0.03),
      const Radius.circular(10));
  canvas.drawRRect(visorCore, paint);

  // ── 5. HULL ACCENT LINES (colored trim, not glow) ────────────────────
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 1.5;
  paint.color = color.withOpacity(0.6);
  // V-shaped accent on nose
  canvas.drawLine(Offset(0, -r * 1.0), Offset(-r * 0.2, -r * 0.55), paint);
  canvas.drawLine(Offset(0, -r * 1.0), Offset(r * 0.2, -r * 0.55), paint);

  // Side stripes along flanks
  paint.strokeWidth = 1.0;
  paint.color = color.withOpacity(0.35);
  for (int side = -1; side <= 1; side += 2) {
    final stripe = Path()
      ..moveTo(side * r * 0.35, -r * 0.3)
      ..quadraticBezierTo(side * r * 0.38, r * 0.1, side * r * 0.25, r * 0.5);
    canvas.drawPath(stripe, paint);
  }
  paint.style = PaintingStyle.fill;

  // ── 6. REAR DETAILS (exhaust housing, tail lights) ────────────────────
  // Dark exhaust housing recesses
  for (int side = -1; side <= 1; side += 2) {
    paint.color = const Color(0xFF050508);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(side * r * 0.1, r * 0.7),
                width: r * 0.1,
                height: r * 0.12),
            const Radius.circular(2)),
        paint);
  }

  // Small tail navigation lights
  paint.color = color.withOpacity(0.8);
  canvas.drawCircle(Offset(-r * 0.18, r * 0.73), 1.5, paint);
  canvas.drawCircle(Offset(r * 0.18, r * 0.73), 1.5, paint);

  // ── 7. ENGINE FLAMES (proper, using helper) ───────────────────────────
  drawEngineFlame(
    canvas,
    r,
    color,
    [Offset(-r * 0.1, r * 0.76), Offset(r * 0.1, r * 0.76)],
    [0.12, 0.12],
    animTick,
  );

  // ── 8. HULL EDGE OUTLINE (visible, defines the silhouette) ────────────
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 1.2;
  paint.color = color.withOpacity(0.45);
  canvas.drawPath(body, paint);
  paint.style = PaintingStyle.fill;
}
