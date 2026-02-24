import 'dart:math';
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import '../../utils/safe_color.dart';
import 'ship_painter_helpers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SOVEREIGN — Imperial Strike Cruiser (v3 — High Detail Reference Match)
// Based closely on the provided textured sci-fi fighter image.
// Features highly detailed gold central spine, complex ivory/dirty metal
// wing plating, massive twin engines with specific gold banding, and
// numerous blue glowing auxiliary thrusters.
// ─────────────────────────────────────────────────────────────────────────────

void drawSovereignShip(Canvas canvas, double r, Color color, double animTick) {
  // ──────── COLOR PALETTE REFINEMENT (Matching the image texture) ────────
  // Ivory/White Hull (dirty, metallic)
  const cHullLight = Color(0xFFE0E0E8);
  const cHullMid = Color(0xFFB0B0B8);
  const cHullShadow = Color(0xFF707078);
  // Gold/Bronze (rich, highly reflective)
  const cGoldBright = Color(0xFFFFE080);
  const cGoldMid = Color(0xFFD4A017);
  const cGoldDark = Color(0xFF8A5E08);
  // Mechanical/Dark (vents, joints)
  const cMechLight = Color(0xFF606070);
  const cMechDark = Color(0xFF202028);
  const cMechBlack = Color(0xFF0A0A10);
  // Blue Energy
  const cEnergyCore = Color(0xFFBBEEFF);
  const cEnergyMid = Color(0xFF44AAFF);
  const cEnergyOuter = Color(0xFF0066EE);

  final paint = Paint()..style = PaintingStyle.fill;
  final bluePulse = sin(animTick * 4.2) * 0.16 + 0.84;
  final goldPulse = sin(animTick * 2.5) * 0.08 + 0.92;

  // Helper for drawing dense mechanical panel lines
  void drawPanelLines(Path path, {double spacing = 0.15}) {
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = cMechDark.o(0.6);
    canvas.drawPath(path, paint);
    paint.style = PaintingStyle.fill;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LAYER 1 — MAIN WING STRUCTURE (Complex layered delta)
  // ══════════════════════════════════════════════════════════════════════════
  for (int side = -1; side <= 1; side += 2) {
    final s = side.toDouble();

    // --- 1A. Main underlying wing slab ---
    final mainWing = Path()
      ..moveTo(s * r * 0.25, -r * 0.60)
      ..lineTo(s * r * 1.60, r * 0.25) // Outer tip
      ..lineTo(s * r * 1.45, r * 0.60)
      ..lineTo(s * r * 0.80, r * 0.85)
      ..lineTo(s * r * 0.40, r * 0.70)
      ..close();

    paint.shader = LinearGradient(
      colors: side < 0
          ? [cHullLight, cHullMid, cHullShadow]
          : [cHullMid, cHullShadow, cMechLight],
      stops: const [0.1, 0.5, 0.9],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(Rect.fromLTWH(-r * 1.6, -r * 0.6, r * 3.2, r * 1.5));
    canvas.drawPath(mainWing, paint);
    drawPanelLines(mainWing);

    // --- 1B. Upper wing armour plating (The lighter, stepped sections) ---
    final wingPlate = Path()
      ..moveTo(s * r * 0.30, -r * 0.45)
      ..lineTo(s * r * 1.35, r * 0.20)
      ..lineTo(s * r * 1.20, r * 0.45)
      ..lineTo(s * r * 0.60, r * 0.60)
      ..lineTo(s * r * 0.35, r * 0.30)
      ..close();
    paint.shader = LinearGradient(
      colors: side < 0 ? [cHullLight, cHullMid] : [cHullLight, cHullShadow],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(s * 0.3 * r, -r * 0.5, r * 1.0, r * 1.0));
    canvas.drawPath(wingPlate, paint);

    // Detailed gold leading edge trim (thicker, metallic)
    final leadingEdge = Path()
      ..moveTo(s * r * 0.28, -r * 0.58)
      ..lineTo(s * r * 1.62, r * 0.25)
      ..lineTo(s * r * 1.58, r * 0.32)
      ..lineTo(s * r * 0.32, -r * 0.48)
      ..close();
    paint.shader = LinearGradient(
      colors: [cGoldMid, cGoldBright, cGoldDark],
      stops: const [0.0, 0.5, 1.0],
      begin: side < 0 ? Alignment.topLeft : Alignment.topRight,
      end: side < 0 ? Alignment.bottomRight : Alignment.bottomLeft,
    ).createShader(Rect.fromLTWH(s * 0.3 * r, -r * 0.6, r * 1.3, r * 0.9));
    canvas.drawPath(leadingEdge, paint);
    paint.shader = null;

    // Dense mechanical panel seams (simulating the texture)
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = cMechDark.o(0.7);
    final seams = [
      [Offset(s * r * 0.45, -r * 0.30), Offset(s * r * 1.20, r * 0.18)],
      [Offset(s * r * 0.55, -r * 0.10), Offset(s * r * 1.30, r * 0.35)],
      [Offset(s * r * 0.65, r * 0.15), Offset(s * r * 1.10, r * 0.45)],
      [Offset(s * r * 0.75, r * 0.40), Offset(s * r * 1.00, r * 0.58)],
      // Cross seams
      [Offset(s * r * 0.90, 0), Offset(s * r * 1.05, r * 0.25)],
      [Offset(s * r * 0.60, -r * 0.2), Offset(s * r * 0.75, 0)],
    ];
    for (final seg in seams) canvas.drawLine(seg[0], seg[1], paint);
    paint.style = PaintingStyle.fill;

    // Forward Canard (re-textured)
    final canard = Path()
      ..moveTo(s * r * 0.28, -r * 0.55)
      ..lineTo(s * r * 0.75, -r * 0.82)
      ..lineTo(s * r * 0.92, -r * 0.65)
      ..lineTo(s * r * 0.60, -r * 0.45)
      ..close();
    paint.shader = LinearGradient(
      colors: side < 0 ? [cHullLight, cHullMid] : [cHullMid, cHullShadow],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(Rect.fromLTWH(s * 0.3 * r, -r * 0.8, r * 0.6, r * 0.4));
    canvas.drawPath(canard, paint);
    paint
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = cGoldMid.o(0.5); // Gold trim on canard
    canvas.drawPath(canard, paint);
    paint.style = PaintingStyle.fill;

    // Outer wingtip Spikes (darker mechanical look)
    final tipSpike = Path()
      ..moveTo(s * r * 1.60, r * 0.25)
      ..lineTo(s * r * 1.85, -r * 0.10) // Point forward
      ..lineTo(s * r * 1.70, r * 0.15)
      ..close();
    paint.color = cMechLight;
    canvas.drawPath(tipSpike, paint);
    paint
      ..style = PaintingStyle.stroke
      ..color = cMechDark
      ..strokeWidth = 1.0;
    canvas.drawPath(tipSpike, paint);
    paint.style = PaintingStyle.fill;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LAYER 2 — CENTRAL HULL BODY (The underlying structure)
  // ══════════════════════════════════════════════════════════════════════════
  final hullPath = Path()
    ..moveTo(0, -r * 1.6)
    ..quadraticBezierTo(-r * 0.35, -r * 0.8, -r * 0.40, 0)
    ..quadraticBezierTo(-r * 0.42, r * 0.5, -r * 0.25, r * 0.9)
    ..lineTo(0, r * 1.1)
    ..lineTo(r * 0.25, r * 0.9)
    ..quadraticBezierTo(r * 0.42, r * 0.5, r * 0.40, 0)
    ..quadraticBezierTo(r * 0.35, -r * 0.8, 0, -r * 1.6)
    ..close();

  // Dark mechanical underbody shader
  paint.shader = const LinearGradient(
    colors: [cMechLight, cMechDark, cMechBlack],
    stops: [0.1, 0.6, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ).createShader(Rect.fromLTWH(-r * 0.4, -r * 1.6, r * 0.8, r * 2.7));
  canvas.drawPath(hullPath, paint);

  // Horizontal ribbing on the underbody
  paint
    ..shader = null
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..color = cMechBlack.o(0.8);
  for (double y = -r * 1.2; y < r * 0.8; y += r * 0.18) {
    final widthAtY = lerpDouble(0.1, 0.38, (y + r * 1.6) / (r * 2.4))!;
    canvas.drawLine(Offset(-r * widthAtY, y), Offset(r * widthAtY, y), paint);
  }
  paint.style = PaintingStyle.fill;

  // ══════════════════════════════════════════════════════════════════════════
  // LAYER 3 — THE GOLD SPINE (Dominant Feature - High Detail)
  // ══════════════════════════════════════════════════════════════════════════
  // The reference shows the spine is made of many stacked, complex segments.

  // 3A. Nose Cone (Sharp, multi-faceted gold)
  final nosePath = Path()
    ..moveTo(0, -r * 2.05) // Sharp tip
    ..lineTo(-r * 0.07, -r * 1.75)
    ..lineTo(-r * 0.10, -r * 1.50)
    ..lineTo(r * 0.10, -r * 1.50)
    ..lineTo(r * 0.07, -r * 1.75)
    ..close();
  paint.shader = LinearGradient(
    colors: [cGoldBright, cGoldMid, cGoldDark, cGoldMid],
    stops: const [0.0, 0.3, 0.7, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ).createShader(Rect.fromLTWH(-r * 0.1, -r * 2.05, r * 0.2, r * 0.55));
  canvas.drawPath(nosePath, paint);
  paint
    ..shader = null
    ..style = PaintingStyle.stroke
    ..color = cGoldDark
    ..strokeWidth = 0.8;
  canvas.drawPath(nosePath, paint);
  paint.style = PaintingStyle.fill;

  // 3B. Main Spine Segments (Iterative stacked plating)
  final segmentCount = 7;
  final spineStartY = -r * 1.50;
  final spineEndY = r * 0.85;
  final segmentHeight = (spineEndY - spineStartY) / segmentCount;

  for (int i = 0; i < segmentCount; i++) {
    final segY = spineStartY + i * segmentHeight;
    // Width varies down the spine
    final segW = r * (0.12 + sin(i / segmentCount * pi) * 0.05);
    final segRect = Rect.fromCenter(
        center: Offset(0, segY + segmentHeight / 2),
        width: segW * 2,
        height: segmentHeight * 1.05); // Slight overlap

    // Main gold body of the segment
    paint.shader = LinearGradient(
      colors: [cGoldBright.o(goldPulse), cGoldMid, cGoldDark, cGoldMid],
      stops: const [0.1, 0.3, 0.8, 1.0],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ).createShader(segRect);

    // Draw segment with cutouts to look mechanical
    final segPath = Path()
      ..moveTo(-segW, segY)
      ..lineTo(-segW * 0.9, segY + segmentHeight * 0.3)
      ..lineTo(-segW, segY + segmentHeight * 0.7)
      ..lineTo(-segW * 0.8, segY + segmentHeight)
      ..lineTo(segW * 0.8, segY + segmentHeight)
      ..lineTo(segW, segY + segmentHeight * 0.7)
      ..lineTo(segW * 0.9, segY + segmentHeight * 0.3)
      ..lineTo(segW, segY)
      ..close();
    canvas.drawPath(segPath, paint);

    // Dark mechanical joint between segments
    paint.shader = null;
    paint.color = cMechDark;
    canvas.drawRect(
        Rect.fromLTWH(-segW * 0.7, segY + segmentHeight * 0.9, segW * 1.4,
            segmentHeight * 0.2),
        paint);

    // Central highlight line down the spine
    paint.color = cGoldBright.o(0.7);
    canvas.drawRect(
        Rect.fromLTWH(-r * 0.01, segY, r * 0.02, segmentHeight), paint);
  }

  // 3C. Tail Spike (Long, dark gold/bronze)
  final tailSpike = Path()
    ..moveTo(-r * 0.04, r * 0.85)
    ..lineTo(r * 0.04, r * 0.85)
    ..lineTo(0, r * 1.95) // Very long point
    ..close();
  paint.shader = const LinearGradient(
    colors: [cGoldMid, cGoldDark, cMechDark],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ).createShader(Rect.fromLTWH(-r * 0.04, r * 0.85, r * 0.08, r * 1.1));
  canvas.drawPath(tailSpike, paint);

  // ══════════════════════════════════════════════════════════════════════════
  // LAYER 4 — ENGINES & NACELLES (Massive, detailed banding)
  // ══════════════════════════════════════════════════════════════════════════
  for (int side = -1; side <= 1; side += 2) {
    final s = side.toDouble();
    final nx = s * r * 0.38;
    final ny = r * 0.35;
    const nW = 0.42;
    const nH = 0.80;

    final nacelleRect =
        Rect.fromCenter(center: Offset(nx, ny), width: r * nW, height: r * nH);

    // 4A. Main Nacelle Body (Dark mechanical underlying structure)
    paint.shader = LinearGradient(
      colors: [cMechLight, cMechDark, cMechBlack],
      begin: side < 0 ? Alignment.topLeft : Alignment.topRight,
      end: side < 0 ? Alignment.bottomRight : Alignment.bottomLeft,
    ).createShader(nacelleRect);
    canvas.drawRRect(
        RRect.fromRectAndRadius(nacelleRect, Radius.circular(r * 0.05)), paint);

    // 4B. The Gold Banding (Crucial detail from reference)

    // Top Band (Medium width)
    final topBandRect = Rect.fromCenter(
        center: Offset(nx, ny - r * 0.25),
        width: r * (nW + 0.04),
        height: r * 0.12);
    paint.shader = LinearGradient(colors: [cGoldBright, cGoldMid, cGoldDark])
        .createShader(topBandRect);
    canvas.drawRRect(
        RRect.fromRectAndRadius(topBandRect, Radius.circular(r * 0.02)), paint);

    // Middle Main Band (Thickest, most prominent)
    final midBandRect = Rect.fromCenter(
        center: Offset(nx, ny + r * 0.05),
        width: r * (nW + 0.06),
        height: r * 0.18);
    paint.shader = LinearGradient(colors: [cGoldBright, cGoldMid, cGoldDark])
        .createShader(midBandRect);
    canvas.drawRRect(
        RRect.fromRectAndRadius(midBandRect, Radius.circular(r * 0.03)), paint);

    // Lower Bands (Two thinner ones)
    final lowBand1Rect = Rect.fromCenter(
        center: Offset(nx, ny + r * 0.28),
        width: r * (nW + 0.04),
        height: r * 0.06);
    canvas.drawRRect(
        RRect.fromRectAndRadius(lowBand1Rect, Radius.circular(r * 0.01)),
        paint);
    final lowBand2Rect = Rect.fromCenter(
        center: Offset(nx, ny + r * 0.38),
        width: r * (nW + 0.03),
        height: r * 0.04);
    canvas.drawRRect(
        RRect.fromRectAndRadius(lowBand2Rect, Radius.circular(r * 0.01)),
        paint);

    // 4C. Engine Nozzle & Glow
    final nozzleY = ny + r * 0.42;
    // Dark ribbed interior of nozzle
    paint.shader = null;
    paint.color = cMechBlack;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(nx, nozzleY), width: r * nW * 0.8, height: r * 0.15),
        paint);
    paint
      ..color = cMechDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(nx, nozzleY), width: r * nW * 0.7, height: r * 0.12),
        paint);
    paint.style = PaintingStyle.fill;

    // Intense Blue Glow
    paint.shader = RadialGradient(
      colors: [
        cEnergyCore.o(bluePulse),
        cEnergyMid.o(bluePulse * 0.8),
        cEnergyOuter.o(0)
      ],
      stops: const [0.2, 0.5, 1.0],
    ).createShader(Rect.fromCenter(
        center: Offset(nx, nozzleY + r * 0.02),
        width: r * nW * 0.7,
        height: r * 0.2));
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(nx, nozzleY + r * 0.02),
            width: r * nW * 0.6,
            height: r * 0.18),
        paint);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LAYER 5 — AUXILIARY THRUSTERS & WEAPONS (The "blue flame" pendants)
  // ══════════════════════════════════════════════════════════════════════════
  // The reference has many small blue jets hanging under the wings.

  final thrusterPositions = [
    // Inner wing thrusters (larger)
    Offset(-r * 0.65, r * 0.45), Offset(r * 0.65, r * 0.45),
    // Mid wing thrusters
    Offset(-r * 0.95, r * 0.35), Offset(r * 0.95, r * 0.35),
    // Outer wing weapon pods
    Offset(-r * 1.25, r * 0.25), Offset(r * 1.25, r * 0.25),
    // Trailing edge thrusters
    Offset(-r * 0.5, r * 0.7), Offset(r * 0.5, r * 0.7)
  ];

  for (int i = 0; i < thrusterPositions.length; i++) {
    final pos = thrusterPositions[i];
    final flicker = sin(animTick * 6.0 + i * 1.2) * 0.15 + 0.85;
    final sizeScale =
        (pos.dx.abs() < r * 0.7) ? 1.0 : 0.7; // Inner ones are bigger

    // Mechanical pod structure
    paint.shader = LinearGradient(colors: [cMechLight, cMechDark]).createShader(
        Rect.fromCenter(
            center: pos,
            width: r * 0.12 * sizeScale,
            height: r * 0.15 * sizeScale));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: pos,
                width: r * 0.1 * sizeScale,
                height: r * 0.12 * sizeScale),
            Radius.circular(r * 0.02)),
        paint);

    // Blue Flame/Glow pendant
    final flameLen = r * 0.15 * sizeScale * flicker;
    final flamePath = Path()
      ..moveTo(pos.dx - r * 0.03 * sizeScale, pos.dy + r * 0.05 * sizeScale)
      ..quadraticBezierTo(pos.dx, pos.dy + flameLen * 1.2,
          pos.dx + r * 0.03 * sizeScale, pos.dy + r * 0.05 * sizeScale)
      ..close();

    paint.shader = LinearGradient(
      colors: [cEnergyMid.o(flicker), cEnergyOuter.o(0)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(
        Rect.fromLTWH(pos.dx - r * 0.05, pos.dy, r * 0.1, flameLen * 1.5));
    canvas.drawPath(flamePath, paint);

    // Bright core dot
    paint.shader = null;
    paint.color = cEnergyCore.o(flicker);
    canvas.drawCircle(Offset(pos.dx, pos.dy + r * 0.06 * sizeScale),
        r * 0.015 * sizeScale, paint);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LAYER 6 — COCKPIT & FINAL DETAILS
  // ══════════════════════════════════════════════════════════════════════════
  // Cockpit integrated into the upper spine
  final cockpitY = -r * 0.8;
  paint.shader = LinearGradient(
    colors: [cGoldDark, cMechBlack, cGoldDark],
  ).createShader(Rect.fromLTWH(-r * 0.05, cockpitY, r * 0.1, r * 0.15));
  canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(0, cockpitY), width: r * 0.09, height: r * 0.14),
          Radius.circular(r * 0.04)),
      paint);

  // Glass/Sensor glow
  paint.shader = RadialGradient(
    colors: [cEnergyCore.o(0.8), cEnergyMid.o(0.4)],
  ).createShader(Rect.fromCenter(
      center: Offset(0, cockpitY - r * 0.02),
      width: r * 0.06,
      height: r * 0.08));
  canvas.drawOval(
      Rect.fromCenter(
          center: Offset(0, cockpitY - r * 0.02),
          width: r * 0.05,
          height: r * 0.07),
      paint);

  // ══════════════════════════════════════════════════════════════════════════
  // LAYER 7 — MAIN ENGINE EXHAUST FLAMES
  // ══════════════════════════════════════════════════════════════════════════
  drawEngineFlame(
    canvas,
    r,
    cEnergyOuter,
    [Offset(-r * 0.38, r * 0.75), Offset(r * 0.38, r * 0.75)],
    [0.28, 0.28],
    animTick,
  );
}


/* 



 */