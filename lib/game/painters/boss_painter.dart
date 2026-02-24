import 'package:flutter/material.dart';
import 'dart:math';
import '../../providers/game_provider.dart';
import '../../utils/safe_color.dart';

// ── BOSS PAINTER ─────────────────────────────────────────────────────────────
// IMPERIAL DREADNOUGHT — Massive metallic warship with strong 3-D shading.
// All .o() replaced with .o() to prevent "Invalid argument" crash.

void drawBossShip(
    Canvas canvas,
    Size size,
    GameProvider game,
    double animTick,
    void Function(Canvas, String, Offset, Color, double, {double letterSpacing})
        drawText) {
  final boss = game.boss;
  if (boss == null || boss.isFullyDead) return;

  final cx = boss.x * size.width;
  final cy = boss.y * size.height;
  final hpRatio = boss.hpRatio.clamp(0.0, 1.0);
  // Clamp pulse to [0,1] — sin() is always in [-1,1] so this is fine,
  // but we clamp defensively.
  final pulse = (sin(boss.pulsePhase) * 0.5 + 0.5).clamp(0.0, 1.0);

  double opacity = 1.0;
  if (boss.isDead) {
    opacity = (1.0 - boss.deathTimer * 1.5).clamp(0.0, 1.0);
  }

  canvas.save();
  canvas.translate(cx, cy);
  // No scale on death — was causing huge draw calls and lag

  final w = size.width * 0.20;
  final h = size.height * 0.10;

  final paint = Paint()..style = PaintingStyle.fill;

  // ── 1. DANGER AURA ────────────────────────────────────────────────────────
  final aura =
      ((1.0 - hpRatio) * 0.35 + boss.warningFlash * 0.5).clamp(0.0, 1.0);
  if (aura > 0.05) {
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 70);
    paint.color = const Color(0xFFCC1100).o(aura * 0.35 * opacity);
    canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: w * 4.0, height: h * 4.0),
        paint);
    paint.maskFilter = null;
  }

  // ── 2. WIDE DELTA WINGS ───────────────────────────────────────────────────
  for (int side = -1; side <= 1; side += 2) {
    final s = side.toDouble();

    // Main wing — wider and more swept, like the reference
    final wing = Path()
      ..moveTo(s * w * 0.15, -h * 0.30) // root leading
      ..lineTo(s * w * 1.20, -h * 0.72) // tip leading (farther out)
      ..lineTo(s * w * 1.28, -h * 0.50) // outer tip
      ..lineTo(s * w * 1.22, h * 0.05) // outer mid
      ..lineTo(s * w * 1.05, h * 0.38) // outer trailing shoulder
      ..lineTo(s * w * 0.72, h * 0.55) // trailing notch
      ..lineTo(s * w * 0.45, h * 0.48)
      ..lineTo(s * w * 0.20, h * 0.18) // root trailing
      ..close();

    // ── Deep 3-D gradient: bright top edge → dark body → near-black at far tip
    paint.shader = LinearGradient(
      colors: [
        const Color(0xFF9A9AAA), // bright near-hull
        const Color(0xFF6A6A7A),
        const Color(0xFF404050),
        const Color(0xFF252532),
        const Color(0xFF0E0E18), // black wing tip
      ],
      stops: const [0.0, 0.18, 0.45, 0.72, 1.0],
      begin: side < 0 ? Alignment.centerRight : Alignment.centerLeft,
      end: side < 0 ? Alignment.centerLeft : Alignment.centerRight,
    ).createShader(Rect.fromCenter(
        center: Offset(s * w * 0.65, 0), width: w * 1.45, height: h * 1.4));
    canvas.drawPath(wing, paint);
    paint.shader = null;

    // ── TOP FACE specular sheen (upper-lit feeling)
    final sheen = Path()
      ..moveTo(s * w * 0.15, -h * 0.30)
      ..lineTo(s * w * 0.70, -h * 0.55)
      ..lineTo(s * w * 0.65, h * 0.05)
      ..lineTo(s * w * 0.20, h * 0.18)
      ..close();
    paint.color = Colors.white.o(0.10 * opacity);
    canvas.drawPath(sheen, paint);

    // ── RIM LIGHT on leading edge (bright top highlight → 3-D illusion)
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    paint.color = Colors.white.o(0.28 * opacity);
    canvas.drawLine(Offset(s * w * 0.15, -h * 0.30),
        Offset(s * w * 1.20, -h * 0.72), paint);
    paint.style = PaintingStyle.fill;

    // ── Wing outline dark
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.2;
    paint.color = const Color(0xFF08080F).o(opacity);
    canvas.drawPath(wing, paint);
    paint.style = PaintingStyle.fill;

    // ── RED GLOW trim — leading edge (double pass: blur + crisp)
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 3.0;
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 8);
    paint.color = const Color(0xFFFF2200).o((0.70 + pulse * 0.30) * opacity);
    canvas.drawLine(Offset(s * w * 0.15, -h * 0.30),
        Offset(s * w * 1.20, -h * 0.72), paint);
    paint.maskFilter = null;
    paint.strokeWidth = 1.8;
    paint.color = const Color(0xFFFF5533).o(opacity);
    canvas.drawLine(Offset(s * w * 0.15, -h * 0.30),
        Offset(s * w * 1.20, -h * 0.72), paint);

    // ── RED GLOW trim — trailing shoulder
    paint.strokeWidth = 2.0;
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 5);
    paint.color = const Color(0xFFFF2200).o(0.55 * opacity);
    canvas.drawLine(
        Offset(s * w * 1.05, h * 0.38), Offset(s * w * 0.72, h * 0.55), paint);
    paint.maskFilter = null;
    paint.strokeWidth = 1.2;
    paint.color = const Color(0xFFFF3311).o(0.80 * opacity);
    canvas.drawLine(
        Offset(s * w * 1.05, h * 0.38), Offset(s * w * 0.72, h * 0.55), paint);

    // ── PANEL SEAM LINES (structural rib feel)
    paint.strokeWidth = 0.8;
    paint.color = const Color(0xFF0D0D1A).o(0.9 * opacity);
    for (int p = 1; p <= 5; p++) {
      final t = p / 6.0;
      canvas.drawLine(
        Offset(s * w * (0.18 + t * 0.72), -h * (0.26 + t * 0.35)),
        Offset(s * w * (0.18 + t * 0.60), h * (0.12 + t * 0.30)),
        paint,
      );
    }

    // Cross-panel ribs
    for (int r = 0; r < 3; r++) {
      final t = (r + 1) / 4.0;
      final x0 = s * w * (0.22 + t * 0.55);
      final y0 = -h * (0.32 - t * 0.12);
      canvas.drawLine(
        Offset(x0, y0),
        Offset(x0 + s * w * 0.12, y0 + h * 0.30),
        paint,
      );
    }
    paint.style = PaintingStyle.fill;

    // ── RAISED PANEL BLOCKS — armour plates on wing surface
    for (int block = 0; block < 3; block++) {
      final bt = (block + 1) / 4.0;
      final bx = s * w * (0.30 + bt * 0.52);
      final by = -h * 0.18 + bt * h * 0.22;
      final bw = w * 0.12;
      final bh2 = h * 0.18;
      // Slightly lighter than wing fill → raised-panel illusion
      paint.color = const Color(0xFF525262).o(0.55 * opacity);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(bx, by), width: bw, height: bh2),
              const Radius.circular(2)),
          paint);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 0.7;
      paint.color = const Color(0xFF0A0A14).o(opacity);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(bx, by), width: bw, height: bh2),
              const Radius.circular(2)),
          paint);
      paint.style = PaintingStyle.fill;
    }

    // ── RED VENT DOTS along leading edge
    for (int d = 0; d < 6; d++) {
      final t = (d + 1) / 7.0;
      final vx = s * (w * 0.15 + t * w * 0.92);
      final vy = -h * 0.30 + t * (-h * 0.34);
      paint.color = const Color(0xFF08000A).o(opacity);
      canvas.drawCircle(Offset(vx, vy), 3.8, paint);
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 6);
      paint.color = const Color(0xFFFF2200).o((0.55 + pulse * 0.45) * opacity);
      canvas.drawCircle(Offset(vx, vy), 3.2, paint);
      paint.maskFilter = null;
      paint.color = Colors.white.o(0.90 * opacity);
      canvas.drawCircle(Offset(vx, vy), 1.3, paint);
    }

    // ── Mechanical claw arm
    _drawClawArm(canvas, side, w, h, opacity, pulse, animTick, paint);

    // ── FORWARD MANDIBLE — aggressive pincer extension from wing trailing edge
    final mSwing = sin(animTick * 1.5 + side * pi) * h * 0.025;
    final mandible = Path()
      ..moveTo(s * w * 0.45, h * 0.48)
      ..lineTo(s * w * 0.72, h * 0.55)
      ..lineTo(s * w * 0.88, h * 0.78 + mSwing)
      ..lineTo(s * w * 0.80, h * 1.08 + mSwing)
      ..lineTo(s * w * 0.68, h * 0.88 + mSwing)
      ..lineTo(s * w * 0.52, h * 0.64)
      ..close();

    // 3-D gradient matching wing light direction
    paint.shader = LinearGradient(
      colors: [
        const Color(0xFF707080),
        const Color(0xFF404050),
        const Color(0xFF12121A),
      ],
      begin: side < 0 ? Alignment.centerRight : Alignment.centerLeft,
      end: side < 0 ? Alignment.centerLeft : Alignment.centerRight,
    ).createShader(mandible.getBounds());
    canvas.drawPath(mandible, paint);
    paint.shader = null;

    // Dark outline
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.2;
    paint.color = const Color(0xFF08080F).o(opacity);
    canvas.drawPath(mandible, paint);

    // Rim light on outer edge
    paint.strokeWidth = 1.0;
    paint.color = Colors.white.o(0.22 * opacity);
    canvas.drawLine(Offset(s * w * 0.72, h * 0.55),
        Offset(s * w * 0.88, h * 0.78 + mSwing), paint);
    paint.style = PaintingStyle.fill;

    // Red glow trim on mandible leading edge
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2.5;
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 6);
    paint.color = const Color(0xFFFF2200).o((0.55 + pulse * 0.35) * opacity);
    canvas.drawLine(Offset(s * w * 0.88, h * 0.78 + mSwing),
        Offset(s * w * 0.80, h * 1.08 + mSwing), paint);
    paint.maskFilter = null;
    paint.strokeWidth = 1.2;
    paint.color = const Color(0xFFFF3311).o(0.80 * opacity);
    canvas.drawLine(Offset(s * w * 0.88, h * 0.78 + mSwing),
        Offset(s * w * 0.80, h * 1.08 + mSwing), paint);
    paint.style = PaintingStyle.fill;

    // Mandible glowing vent dots
    for (int v = 0; v < 3; v++) {
      final t = v / 2.0;
      final vx = s * w * (0.74 - t * 0.06);
      final vy = h * (0.64 + t * 0.18) + mSwing * t;
      paint.color = const Color(0xFF08000A).o(opacity);
      canvas.drawCircle(Offset(vx, vy), 4.0, paint);
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 5);
      paint.color = const Color(0xFFFF2200).o((0.65 + pulse * 0.35) * opacity);
      canvas.drawCircle(Offset(vx, vy), 3.0, paint);
      paint.maskFilter = null;
      paint.color = Colors.white.o(0.85 * opacity);
      canvas.drawCircle(Offset(vx, vy), 1.2, paint);
    }
  }

  // ── 3. MAIN HULL ──────────────────────────────────────────────────────────
  final hull = Path()
    ..moveTo(-w * 0.18, -h * 1.05)
    ..lineTo(w * 0.18, -h * 1.05)
    ..lineTo(w * 0.35, -h * 0.65)
    ..lineTo(w * 0.42, -h * 0.15)
    ..lineTo(w * 0.34, h * 0.42)
    ..lineTo(w * 0.26, h * 0.90)
    ..lineTo(w * 0.12, h * 1.04)
    ..lineTo(-w * 0.12, h * 1.04)
    ..lineTo(-w * 0.26, h * 0.90)
    ..lineTo(-w * 0.34, h * 0.42)
    ..lineTo(-w * 0.42, -h * 0.15)
    ..lineTo(-w * 0.35, -h * 0.65)
    ..close();

  // ── Hull base coat: top-lit metallic, dark at bottom
  paint.shader = LinearGradient(
    colors: [
      const Color(0xFF9A9AAB), // top highlight
      const Color(0xFF6A6A7A),
      const Color(0xFF444452),
      const Color(0xFF252530),
      const Color(0xFF0E0E16), // dark bottom
    ],
    stops: const [0.0, 0.20, 0.50, 0.75, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ).createShader(
      Rect.fromCenter(center: Offset.zero, width: w * 0.90, height: h * 2.2));
  canvas.drawPath(hull, paint);
  paint.shader = null;

  // ── Centre specular hot-spot (simulates top light source)
  paint.shader = LinearGradient(
    colors: [
      Colors.white.o(0.22 * opacity),
      Colors.white.o(0.08 * opacity),
      Colors.transparent,
    ],
    stops: const [0.0, 0.35, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.center,
  ).createShader(Rect.fromCenter(
      center: Offset(0, -h * 0.4), width: w * 0.50, height: h * 1.2));
  canvas.drawPath(hull, paint);
  paint.shader = null;

  // ── Edge rim light — left side bright edge
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 1.2;
  paint.color = Colors.white.o(0.18 * opacity);
  canvas.drawLine(
      Offset(-w * 0.35, -h * 0.65), Offset(-w * 0.42, -h * 0.15), paint);
  canvas.drawLine(
      Offset(w * 0.35, -h * 0.65), Offset(w * 0.42, -h * 0.15), paint);
  paint.style = PaintingStyle.fill;

  // ── Armour plate panels
  final plateRects = [
    Rect.fromCenter(
        center: Offset(-w * 0.24, -h * 0.38),
        width: w * 0.20,
        height: h * 0.30),
    Rect.fromCenter(
        center: Offset(w * 0.24, -h * 0.38), width: w * 0.20, height: h * 0.30),
    Rect.fromCenter(
        center: Offset(-w * 0.22, h * 0.20), width: w * 0.18, height: h * 0.32),
    Rect.fromCenter(
        center: Offset(w * 0.22, h * 0.20), width: w * 0.18, height: h * 0.32),
    Rect.fromCenter(
        center: Offset(0.0, -h * 0.50), width: w * 0.22, height: h * 0.18),
  ];
  for (final pr in plateRects) {
    // Raised plate — lighter
    paint.color = const Color(0xFF565668).o(0.65 * opacity);
    canvas.drawRRect(
        RRect.fromRectAndRadius(pr, const Radius.circular(2)), paint);
    // Plate top sheen
    paint.color = Colors.white.o(0.07 * opacity);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(pr.left, pr.top, pr.width, pr.height * 0.40),
            const Radius.circular(2)),
        paint);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 0.8;
    paint.color = const Color(0xFF0A0A14).o(opacity);
    canvas.drawRRect(
        RRect.fromRectAndRadius(pr, const Radius.circular(2)), paint);
    paint.style = PaintingStyle.fill;
  }

  // ── Grooved rib lines (shadow + highlight for 3-D groove illusion)
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 1.0;
  for (int rib = 0; rib < 7; rib++) {
    final ry = -h * 0.85 + rib * h * 0.28;
    final ww = w * (0.40 - rib * 0.008);
    // Shadow cut
    paint.color = const Color(0xFF05050A).o(opacity);
    canvas.drawLine(Offset(-ww, ry), Offset(ww, ry), paint);
    // Highlight 1px below → deep groove illusion
    paint.color = Colors.white.o(0.12 * opacity);
    canvas.drawLine(Offset(-ww, ry + 1.0), Offset(ww, ry + 1.0), paint);
  }

  // ── Red vertical accent lines on hull sides
  paint.strokeWidth = 2.2;
  paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 5);
  paint.color = const Color(0xFFFF2200).o((0.55 + pulse * 0.35) * opacity);
  for (int side = -1; side <= 1; side += 2) {
    canvas.drawLine(Offset(side * w * 0.37, -h * 0.58),
        Offset(side * w * 0.30, h * 0.68), paint);
  }
  paint.maskFilter = null;
  paint.strokeWidth = 1.4;
  paint.color = const Color(0xFFFF3311).o(0.85 * opacity);
  for (int side = -1; side <= 1; side += 2) {
    canvas.drawLine(Offset(side * w * 0.37, -h * 0.58),
        Offset(side * w * 0.30, h * 0.68), paint);
  }
  paint.style = PaintingStyle.fill;

  // ── Hull outline
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 1.5;
  paint.color = const Color(0xFF070710).o(opacity);
  canvas.drawPath(hull, paint);
  paint.style = PaintingStyle.fill;

  // ── 4. RED EYE / REACTOR CORE ─────────────────────────────────────────────
  // Housing ring — deep metallic
  paint.shader = RadialGradient(
    colors: [const Color(0xFF2E2E3C), const Color(0xFF101018)],
    center: const Alignment(-0.25, -0.35),
  ).createShader(
      Rect.fromCircle(center: Offset(0, -h * 0.08), radius: w * 0.18));
  canvas.drawCircle(Offset(0, -h * 0.08), w * 0.17, paint);
  paint.shader = null;

  // Outer ring — brushed metal rim
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 4.0;
  paint.color = const Color(0xFF606072).o(opacity);
  canvas.drawCircle(Offset(0, -h * 0.08), w * 0.155, paint);
  paint.strokeWidth = 1.5;
  paint.color = Colors.white.o(0.20 * opacity); // rim light
  canvas.drawArc(
      Rect.fromCircle(center: Offset(0, -h * 0.08), radius: w * 0.155),
      -pi * 0.9,
      pi * 0.6,
      false,
      paint);
  paint.strokeWidth = 1.5;
  paint.color = const Color(0xFF2A2A38).o(opacity);
  canvas.drawCircle(Offset(0, -h * 0.08), w * 0.122, paint);
  paint.style = PaintingStyle.fill;

  // Eye outer glow
  paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 22);
  paint.color = const Color(0xFFFF1A00).o((0.65 + pulse * 0.35) * opacity);
  canvas.drawCircle(Offset(0, -h * 0.08), w * 0.135, paint);
  paint.maskFilter = null;

  // Eye iris
  paint.shader = RadialGradient(
    colors: [
      const Color(0xFFFFFFFF),
      const Color(0xFFFF8800),
      const Color(0xFFDD1100),
      const Color(0xFF880000),
      const Color(0xFF220000),
    ],
    stops: const [0.0, 0.18, 0.45, 0.72, 1.0],
  ).createShader(
      Rect.fromCircle(center: Offset(0, -h * 0.08), radius: w * 0.115));
  canvas.drawCircle(Offset(0, -h * 0.08), w * 0.115, paint);
  paint.shader = null;

  // Glare spot
  paint.color = Colors.white.o(0.72 * opacity);
  canvas.drawCircle(Offset(-w * 0.028, -h * 0.118), w * 0.030, paint);

  if (boss.warningFlash > 0.05) {
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 28);
    paint.color =
        const Color(0xFFFF0000).o(boss.warningFlash.clamp(0.0, 1.0) * opacity);
    canvas.drawCircle(Offset(0, -h * 0.08), w * 0.28, paint);
    paint.maskFilter = null;
  }

  // ── 5. CANNON BARREL ─────────────────────────────────────────────────────
  final cannonPath = Path()
    ..moveTo(-w * 0.068, h * 0.12)
    ..lineTo(w * 0.068, h * 0.12)
    ..lineTo(w * 0.058, h * 1.00)
    ..lineTo(-w * 0.058, h * 1.00)
    ..close();

  // 3-D left-lit barrel
  paint.shader = LinearGradient(
    colors: [
      const Color(0xFF787888),
      const Color(0xFF505060),
      const Color(0xFF303040),
      const Color(0xFF181820),
    ],
    stops: const [0.0, 0.28, 0.60, 1.0],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  ).createShader(Rect.fromCenter(
      center: Offset(0, h * 0.56), width: w * 0.14, height: h * 0.90));
  canvas.drawPath(cannonPath, paint);
  paint.shader = null;

  // Barrel highlight line (left edge lit)
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 1.5;
  paint.color = Colors.white.o(0.22 * opacity);
  canvas.drawLine(
      Offset(-w * 0.068, h * 0.12), Offset(-w * 0.058, h * 1.00), paint);
  paint.style = PaintingStyle.fill;

  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 1.0;
  paint.color = const Color(0xFF08080F).o(opacity);
  canvas.drawPath(cannonPath, paint);
  paint.style = PaintingStyle.fill;

  // Barrel rings
  for (int ring = 0; ring < 6; ring++) {
    final ry = h * 0.16 + ring * h * 0.138;
    paint.shader = LinearGradient(
      colors: [const Color(0xFF585868), const Color(0xFF222230)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ).createShader(Rect.fromCenter(
        center: Offset(0, ry), width: w * 0.148, height: h * 0.055));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(0, ry), width: w * 0.148, height: h * 0.055),
            const Radius.circular(2)),
        paint);
    paint.shader = null;
    // Ring top sheen
    paint.color = Colors.white.o(0.10 * opacity);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(0, ry - h * 0.012),
                width: w * 0.148,
                height: h * 0.018),
            const Radius.circular(1)),
        paint);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 0.7;
    paint.color = const Color(0xFF08080F).o(opacity);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(0, ry), width: w * 0.148, height: h * 0.055),
            const Radius.circular(2)),
        paint);
    paint.style = PaintingStyle.fill;
  }

  // Muzzle brake
  paint.shader = LinearGradient(
    colors: [const Color(0xFF484858), const Color(0xFF1A1A24)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  ).createShader(Rect.fromCenter(
      center: Offset(0, h * 1.02), width: w * 0.18, height: h * 0.08));
  canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(0, h * 1.02), width: w * 0.18, height: h * 0.08),
          const Radius.circular(2)),
      paint);
  paint.shader = null;
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 1.2;
  paint.color = const Color(0xFF08080F).o(opacity);
  canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(0, h * 1.02), width: w * 0.18, height: h * 0.08),
          const Radius.circular(2)),
      paint);
  paint.style = PaintingStyle.fill;

  // Cannon charge glow
  if (boss.warningFlash > 0.05) {
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 22);
    paint.color =
        const Color(0xFFFF0033).o(boss.warningFlash.clamp(0.0, 1.0) * opacity);
    canvas.drawCircle(Offset(0, h * 1.06), w * 0.12, paint);
    paint.maskFilter = null;
    paint.color =
        Colors.white.o(boss.warningFlash.clamp(0.0, 1.0) * 0.9 * opacity);
    canvas.drawCircle(Offset(0, h * 1.06), w * 0.042, paint);
  }

  // ── 6. COMMAND BRIDGE TOWER ───────────────────────────────────────────────
  final tower = Path()
    ..moveTo(-w * 0.13, -h * 0.85)
    ..lineTo(w * 0.13, -h * 0.85)
    ..lineTo(w * 0.095, -h * 1.05)
    ..lineTo(-w * 0.095, -h * 1.05)
    ..close();

  paint.shader = LinearGradient(
    colors: [
      const Color(0xFF8A8A9A),
      const Color(0xFF555568),
      const Color(0xFF2E2E3C),
    ],
    stops: const [0.0, 0.45, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ).createShader(Rect.fromCenter(
      center: Offset(0, -h * 0.95), width: w * 0.26, height: h * 0.24));
  canvas.drawPath(tower, paint);
  paint.shader = null;

  // Tower rim lights
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 1.0;
  paint.color = Colors.white.o(0.22 * opacity);
  canvas.drawLine(
      Offset(-w * 0.13, -h * 0.85), Offset(-w * 0.095, -h * 1.05), paint);
  paint.strokeWidth = 0.8;
  paint.color = const Color(0xFF08080F).o(opacity);
  canvas.drawPath(tower, paint);
  // Seam lines
  canvas.drawLine(
      Offset(-w * 0.042, -h * 0.85), Offset(-w * 0.032, -h * 1.05), paint);
  canvas.drawLine(
      Offset(w * 0.042, -h * 0.85), Offset(w * 0.032, -h * 1.05), paint);
  paint.style = PaintingStyle.fill;

  // Red slit windows
  paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 3);
  paint.color = const Color(0xFFFF2200).o(0.90 * opacity);
  for (int tw = -1; tw <= 1; tw++) {
    canvas.drawRect(
        Rect.fromCenter(
            center: Offset(tw * w * 0.058, -h * 0.94),
            width: w * 0.024,
            height: h * 0.06),
        paint);
  }
  paint.maskFilter = null;

  // ── 7. HP BAR ─────────────────────────────────────────────────────────────
  if (!boss.isDead) {
    final barW = w * 2.0;
    const barH = 7.0;
    final barActualY = -h * 1.28;

    paint.color = const Color(0xFF0D0D15).o(0.92 * opacity);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(0, barActualY), width: barW, height: barH),
            const Radius.circular(3)),
        paint);

    const segments = 24;
    final segW = barW / segments;
    for (int i = 0; i < segments; i++) {
      if (hpRatio > i / segments) {
        final segColor = Color.lerp(
                const Color(0xFFFF2200), const Color(0xFF00FF88), hpRatio)!
            .o(opacity);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH((-barW / 2) + (i * segW) + 0.8,
                    barActualY - barH / 2 + 0.5, segW - 1.6, barH - 1),
                const Radius.circular(1.5)),
            Paint()..color = segColor);
      }
    }

    drawText(canvas, '✦  IMPERIAL DREADNOUGHT  ✦', Offset(0, barActualY - 15),
        const Color(0xFFFF3311).o(opacity), 9,
        letterSpacing: 2.5);
  }

  canvas.restore();
}

// ── CLAW ARM ──────────────────────────────────────────────────────────────────
void _drawClawArm(Canvas canvas, int side, double w, double h, double opacity,
    double pulse, double animTick, Paint paint) {
  final s = side.toDouble();
  final swing = sin(animTick * 1.5 + side * pi) * h * 0.04;
  final baseX = s * w * 0.70;
  final baseY = h * 0.20;

  // Upper arm — 3-D gradient
  paint.shader = LinearGradient(
    colors: [
      const Color(0xFF6A6A78),
      const Color(0xFF3A3A48),
      const Color(0xFF181820),
    ],
    begin: side < 0 ? Alignment.centerRight : Alignment.centerLeft,
    end: side < 0 ? Alignment.centerLeft : Alignment.centerRight,
  ).createShader(Rect.fromCenter(
      center: Offset(baseX, baseY + h * 0.18),
      width: w * 0.09,
      height: h * 0.38));
  canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(baseX, baseY + h * 0.18),
              width: w * 0.075,
              height: h * 0.36),
          const Radius.circular(3)),
      paint);
  paint.shader = null;

  // Arm rim highlight
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 1.0;
  paint.color = Colors.white.o(0.18 * opacity);
  canvas.drawLine(Offset(baseX - s * w * 0.037, baseY),
      Offset(baseX - s * w * 0.037, baseY + h * 0.36), paint);
  paint.strokeWidth = 0.9;
  paint.color = const Color(0xFF08080F).o(opacity);
  canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(baseX, baseY + h * 0.18),
              width: w * 0.075,
              height: h * 0.36),
          const Radius.circular(3)),
      paint);
  paint.style = PaintingStyle.fill;

  // Joint ball
  paint.shader = RadialGradient(
    colors: [const Color(0xFF727282), const Color(0xFF2A2A3A)],
    center: const Alignment(-0.35, -0.35),
  ).createShader(Rect.fromCircle(
      center: Offset(baseX, baseY + h * 0.37), radius: w * 0.048));
  canvas.drawCircle(Offset(baseX, baseY + h * 0.37), w * 0.048, paint);
  paint.shader = null;

  // Joint red ring glow
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 1.8;
  paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 4);
  paint.color = const Color(0xFFFF2200).o((0.55 + pulse * 0.45) * opacity);
  canvas.drawCircle(Offset(baseX, baseY + h * 0.37), w * 0.048, paint);
  paint.maskFilter = null;
  paint.style = PaintingStyle.fill;

  // Lower arm — angled outward with 3-D shading
  final endX = baseX + s * w * 0.15;
  final endY = baseY + h * 0.66 + swing;
  final lowerPath = Path()
    ..moveTo(baseX - s * w * 0.030, baseY + h * 0.36)
    ..lineTo(baseX + s * w * 0.030, baseY + h * 0.36)
    ..lineTo(endX + s * w * 0.024, endY)
    ..lineTo(endX - s * w * 0.024, endY)
    ..close();
  paint.shader = LinearGradient(
    colors: [
      const Color(0xFF585868),
      const Color(0xFF2A2A38),
      const Color(0xFF141418),
    ],
    begin: side < 0 ? Alignment.centerRight : Alignment.centerLeft,
    end: side < 0 ? Alignment.centerLeft : Alignment.centerRight,
  ).createShader(
      Rect.fromPoints(Offset(baseX, baseY + h * 0.36), Offset(endX, endY)));
  canvas.drawPath(lowerPath, paint);
  paint.shader = null;

  // Lower arm outline
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 0.8;
  paint.color = const Color(0xFF08080F).o(opacity);
  canvas.drawPath(lowerPath, paint);
  paint.style = PaintingStyle.fill;

  // 3 claw prongs
  for (int c = -1; c <= 1; c++) {
    final cx2 = endX + c * s * w * 0.044;
    final cy2base = endY;
    final claw = Path()
      ..moveTo(cx2 - w * 0.019, cy2base)
      ..lineTo(cx2 + w * 0.019, cy2base)
      ..lineTo(cx2 + w * 0.008, cy2base + h * 0.16)
      ..lineTo(cx2 - w * 0.008, cy2base + h * 0.16)
      ..close();
    paint.shader = LinearGradient(
      colors: [const Color(0xFF484858), const Color(0xFF1A1A26)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(
        Rect.fromLTWH(cx2 - w * 0.019, cy2base, w * 0.038, h * 0.16));
    canvas.drawPath(claw, paint);
    paint.shader = null;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 0.8;
    paint.color = const Color(0xFF08080F).o(opacity);
    canvas.drawPath(claw, paint);
    paint.style = PaintingStyle.fill;
    // Red claw tip glow
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 5);
    paint.color = const Color(0xFFFF2200).o((0.55 + pulse * 0.45) * opacity);
    canvas.drawCircle(Offset(cx2, cy2base + h * 0.162), 2.5, paint);
    paint.maskFilter = null;
    paint.color = Colors.white.o(0.85 * opacity);
    canvas.drawCircle(Offset(cx2, cy2base + h * 0.162), 1.0, paint);
  }
}

// ── BOSS MISSILES ─────────────────────────────────────────────────────────────
void drawBossMissiles(Canvas canvas, Size size, GameProvider game) {
  if (game.bossMissiles.isEmpty) return;
  final paint = Paint()..style = PaintingStyle.fill;
  for (final m in game.bossMissiles) {
    if (!m.active) continue;
    final mx = m.x * size.width;
    final my = m.y * size.height;
    final life = m.life.clamp(0.0, 1.0);
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    paint.color = m.color.o(life * 0.55);
    canvas.drawCircle(Offset(mx, my), 11, paint);
    paint.maskFilter = null;
    paint.color = m.color.o(life * 0.9);
    canvas.drawCircle(Offset(mx, my), 6, paint);
    paint.color = Colors.white.o(life * 0.9);
    canvas.drawCircle(Offset(mx, my), 3, paint);
    final ang = atan2(m.vy, m.vx);
    paint.color = m.color.o(life * 0.35);
    const trailLen = 18.0;
    canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
              mx - cos(ang) * trailLen * 0.5, my - sin(ang) * trailLen * 0.5),
          width: 5,
          height: trailLen,
        ),
        paint);
  }
  paint.maskFilter = null;
}
