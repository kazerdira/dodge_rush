import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/game_models.dart';

/// Draws mine obstacles with 3 distinct visual identities:
/// - PROXIMITY: Classic naval mine with spikes and blinking red core
/// - TRACKER: Sleek scanning eye with rotating sonar ring
/// - CLUSTER: Segmented bomb body with visible child indicators
void drawMine(Canvas canvas, Size size, Obstacle obs, double animTick) {
  final cx = (obs.x + obs.width / 2) * size.width;
  final cy = (obs.y + obs.height / 2) * size.height;
  final r = obs.width * size.width * 0.5;
  final opacity = obs.damageOpacity;
  final type = obs.mineType ?? MineType.proximity;
  final effectiveColor =
      Color.lerp(obs.color, const Color(0xFF777777), obs.greyShift)!;

  if (obs.isDying) {
    _drawMineExplosion(canvas, cx, cy, r, obs.deathTimer, effectiveColor);
    return;
  }

  switch (type) {
    case MineType.proximity:
      _drawProximityMine(canvas, cx, cy, r, effectiveColor, opacity,
          obs.pulsePhase, obs.rotation);
      break;
    case MineType.tracker:
      _drawTrackerMine(
          canvas, cx, cy, r, effectiveColor, opacity, obs.pulsePhase, animTick);
      break;
    case MineType.cluster:
      _drawClusterMine(
          canvas, cx, cy, r, effectiveColor, opacity, obs.pulsePhase, animTick);
      break;
  }
}

// ── PROXIMITY MINE ─────────────────────────────────────────────────────────
// Hexagonal body, 8 sharp spikes, blinking red danger core
void _drawProximityMine(Canvas canvas, double cx, double cy, double r,
    Color color, double opacity, double pulsePhase, double rotation) {
  final paint = Paint()..style = PaintingStyle.fill;
  final pulse = sin(pulsePhase) * 0.3 + 0.7;

  // Outer danger glow
  paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 22);
  paint.color = const Color(0xFFFF2200).withOpacity(0.20 * pulse * opacity);
  canvas.drawCircle(Offset(cx, cy), r * 2.2, paint);
  paint.maskFilter = null;

  canvas.save();
  canvas.translate(cx, cy);
  canvas.rotate(rotation * 2);

  // Hexagonal main body
  final hexPath = Path();
  for (int i = 0; i < 6; i++) {
    final a = (pi / 3 * i) - pi / 6;
    final px = cos(a) * r;
    final py = sin(a) * r;
    if (i == 0)
      hexPath.moveTo(px, py);
    else
      hexPath.lineTo(px, py);
  }
  hexPath.close();

  paint.shader = RadialGradient(
    colors: [
      const Color(0xFF2A2A30),
      const Color(0xFF111115),
      const Color(0xFF050508)
    ],
    center: const Alignment(-0.3, -0.3),
  ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));
  canvas.drawPath(hexPath, paint);
  paint.shader = null;

  // Hex border
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 2.0;
  paint.color = color.withOpacity(0.7 * opacity);
  canvas.drawPath(hexPath, paint);
  paint.style = PaintingStyle.fill;

  // 8 Spikes
  paint.color = const Color(0xFFBBBBCC).withOpacity(opacity);
  for (int i = 0; i < 8; i++) {
    final a = (pi / 4) * i;
    canvas.save();
    canvas.rotate(a);
    final spike = Path()
      ..moveTo(-r * 0.12, r * 0.82)
      ..lineTo(r * 0.12, r * 0.82)
      ..lineTo(0, r * 1.55)
      ..close();
    canvas.drawPath(spike, paint);
    // Spike tip glow
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 3);
    paint.color = const Color(0xFFFF4400).withOpacity(0.6 * opacity);
    canvas.drawCircle(Offset(0, r * 1.52), r * 0.08, paint);
    paint.maskFilter = null;
    paint.color = const Color(0xFFBBBBCC).withOpacity(opacity);
    canvas.restore();
  }

  // Panel screws at hex corners
  paint.color = const Color(0xFF444455).withOpacity(opacity);
  for (int i = 0; i < 6; i++) {
    final a = (pi / 3 * i) - pi / 6;
    canvas.drawCircle(
        Offset(cos(a) * r * 0.78, sin(a) * r * 0.78), r * 0.07, paint);
  }

  // Blinking red core with warning ring
  final blink = (sin(pulsePhase * 3) > 0) ? 1.0 : 0.3;
  paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * blink);
  paint.color = const Color(0xFFFF0000).withOpacity(0.8 * blink * opacity);
  canvas.drawCircle(Offset.zero, r * 0.38 * pulse, paint);
  paint.maskFilter = null;
  paint.color = Colors.white.withOpacity(blink * opacity);
  canvas.drawCircle(Offset.zero, r * 0.16, paint);

  // Warning ring
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 1.5;
  paint.color = const Color(0xFFFF4400).withOpacity(0.5 * pulse * opacity);
  canvas.drawCircle(Offset.zero, r * 0.55, paint);
  paint.style = PaintingStyle.fill;

  canvas.restore();
}

// ── TRACKER MINE ───────────────────────────────────────────────────────────
// Smooth teardrop hull, rotating sonar ring, scanning blue eye
void _drawTrackerMine(Canvas canvas, double cx, double cy, double r,
    Color color, double opacity, double pulsePhase, double animTick) {
  final paint = Paint()..style = PaintingStyle.fill;
  final pulse = sin(pulsePhase) * 0.2 + 0.8;

  // Sonar pulse rings expanding outward
  for (int ring = 0; ring < 3; ring++) {
    final phase = (animTick * 1.5 + ring * 0.6) % (2 * pi);
    final ringRadius = r * 1.2 + (ring * r * 0.5) + sin(phase) * r * 0.4;
    final ringOpacity = (1.0 - (ring / 3.0)) * 0.25 * opacity;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.2;
    paint.color = color.withOpacity(ringOpacity);
    canvas.drawCircle(Offset(cx, cy), ringRadius, paint);
    paint.style = PaintingStyle.fill;
  }

  canvas.save();
  canvas.translate(cx, cy);

  // Outer glow
  paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 16);
  paint.color = color.withOpacity(0.35 * pulse * opacity);
  canvas.drawCircle(Offset.zero, r * 1.5, paint);
  paint.maskFilter = null;

  // Smooth body — slightly elongated oval
  paint.shader = RadialGradient(
    colors: [
      const Color(0xFF1A2030),
      const Color(0xFF0A0E1A),
      const Color(0xFF020508)
    ],
    center: const Alignment(-0.2, -0.3),
  ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));
  canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 2.1),
      paint);
  paint.shader = null;

  // Sleek body edge
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 2.0;
  paint.color = color.withOpacity(0.8 * opacity);
  paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 3);
  canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 2.1),
      paint);
  paint.maskFilter = null;
  paint.style = PaintingStyle.fill;

  // Rotating scanner dish (two arcs)
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 2.5;
  final scanAngle = animTick * 4.0;
  for (int arc = 0; arc < 2; arc++) {
    final a = scanAngle + arc * pi;
    final scanOpacity = (0.3 + cos(a - scanAngle) * 0.4).clamp(0.0, 1.0);
    paint.color = color.withOpacity(scanOpacity * opacity);
    canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: r * 0.72), a,
        0.6, false, paint);
  }
  paint.style = PaintingStyle.fill;

  // Scanning eye — alien blue iris
  paint.color = const Color(0xFF000010);
  canvas.drawCircle(Offset.zero, r * 0.4, paint);

  // Eye glow layers
  paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 6);
  paint.color = color.withOpacity(0.7 * pulse * opacity);
  canvas.drawCircle(Offset.zero, r * 0.32, paint);
  paint.maskFilter = null;

  paint.shader = RadialGradient(
    colors: [Colors.white, color, color.withOpacity(0.0)],
  ).createShader(Rect.fromCircle(center: Offset.zero, radius: r * 0.3));
  canvas.drawCircle(Offset.zero, r * 0.3, paint);
  paint.shader = null;

  // Eye glint
  paint.color = Colors.white.withOpacity(0.9 * opacity);
  canvas.drawCircle(Offset(-r * 0.1, -r * 0.1), r * 0.1, paint);

  // Side fins
  for (int side = -1; side <= 1; side += 2) {
    paint.color = color.withOpacity(0.4 * opacity);
    final finPath = Path()
      ..moveTo(side * r * 0.9, -r * 0.2)
      ..lineTo(side * r * 1.4, -r * 0.5)
      ..lineTo(side * r * 1.3, r * 0.2)
      ..lineTo(side * r * 0.9, r * 0.2)
      ..close();
    canvas.drawPath(finPath, paint);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.0;
    paint.color = color.withOpacity(0.7 * opacity);
    canvas.drawPath(finPath, paint);
    paint.style = PaintingStyle.fill;
  }

  canvas.restore();
}

// ── CLUSTER MINE ───────────────────────────────────────────────────────────
// Segmented body showing 3 child-mine chambers, pulsing red seams
void _drawClusterMine(Canvas canvas, double cx, double cy, double r,
    Color color, double opacity, double pulsePhase, double animTick) {
  final paint = Paint()..style = PaintingStyle.fill;
  final pulse = sin(pulsePhase) * 0.25 + 0.75;

  // Danger aura
  paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 24);
  paint.color = color.withOpacity(0.30 * pulse * opacity);
  canvas.drawCircle(Offset(cx, cy), r * 2.0, paint);
  paint.maskFilter = null;

  canvas.save();
  canvas.translate(cx, cy);
  canvas.rotate(animTick * 0.8);

  // Main casing — triangular-ish container
  final bodyPath = Path();
  for (int i = 0; i < 3; i++) {
    final a = (2 * pi / 3 * i) - pi / 2;
    final px = cos(a) * r;
    final py = sin(a) * r;
    if (i == 0)
      bodyPath.moveTo(px, py);
    else
      bodyPath.lineTo(px, py);
  }
  bodyPath.close();

  paint.shader = RadialGradient(
    colors: [
      const Color(0xFF1E0A0A),
      const Color(0xFF100505),
      const Color(0xFF050101)
    ],
  ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));
  canvas.drawPath(bodyPath, paint);
  paint.shader = null;

  // Outer casing border
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 3.0;
  paint.color = color.withOpacity(0.9 * opacity);
  canvas.drawPath(bodyPath, paint);
  paint.style = PaintingStyle.fill;

  // 3 Child-mine chambers with visible sub-mines inside
  for (int i = 0; i < 3; i++) {
    final a = (2 * pi / 3 * i) - pi / 2;
    final chamberX = cos(a) * r * 0.48;
    final chamberY = sin(a) * r * 0.48;
    final chamberR = r * 0.32;

    // Chamber well
    paint.color = const Color(0xFF0A0000);
    canvas.drawCircle(Offset(chamberX, chamberY), chamberR, paint);

    // Child mine orb
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 4);
    paint.color = color.withOpacity(0.6 * pulse * opacity);
    canvas.drawCircle(Offset(chamberX, chamberY), chamberR * 0.7, paint);
    paint.maskFilter = null;
    paint.color = Colors.white.withOpacity(0.85 * opacity);
    canvas.drawCircle(Offset(chamberX, chamberY), chamberR * 0.25, paint);

    // Tiny spike on each child
    for (int s = 0; s < 6; s++) {
      final sa = (pi / 3 * s) + animTick;
      final tipX = chamberX + cos(sa) * chamberR * 1.0;
      final tipY = chamberY + sin(sa) * chamberR * 1.0;
      paint.color = const Color(0xFF888899).withOpacity(opacity * 0.7);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 1.5;
      canvas.drawLine(
          Offset(chamberX + cos(sa) * chamberR * 0.7,
              chamberY + sin(sa) * chamberR * 0.7),
          Offset(tipX, tipY),
          paint);
      paint.style = PaintingStyle.fill;
    }

    // Chamber ring
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    paint.color = color.withOpacity(0.6 * opacity);
    canvas.drawCircle(Offset(chamberX, chamberY), chamberR, paint);
    paint.style = PaintingStyle.fill;
  }

  // Pulsing seam lines dividing the 3 chambers
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 1.8;
  final seamPulse = 0.4 + sin(pulsePhase * 4) * 0.4;
  paint.color = color.withOpacity(seamPulse * opacity);
  paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 2);
  for (int i = 0; i < 3; i++) {
    final a = (2 * pi / 3 * i) - pi / 2;
    canvas.drawLine(
        Offset.zero, Offset(cos(a) * r * 0.95, sin(a) * r * 0.95), paint);
  }
  paint.maskFilter = null;
  paint.style = PaintingStyle.fill;

  // Center detonator
  paint.color = const Color(0xFF050000);
  canvas.drawCircle(Offset.zero, r * 0.18, paint);
  paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 5);
  paint.color = const Color(0xFFFF0000).withOpacity(pulse * opacity);
  canvas.drawCircle(Offset.zero, r * 0.14, paint);
  paint.maskFilter = null;
  paint.color = Colors.white.withOpacity(opacity);
  canvas.drawCircle(Offset.zero, r * 0.07, paint);

  canvas.restore();

  // "CLUSTER" tag below
  final tp = TextPainter(
    text: TextSpan(
      text: 'CLUSTER',
      style: TextStyle(
          color: color.withOpacity(0.7 * opacity),
          fontSize: 7,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5),
    ),
    textDirection: TextDirection.ltr,
  );
  tp.layout();
  tp.paint(canvas, Offset(cx - tp.width / 2, cy + r * 1.7));
}

// ── DEATH EXPLOSION ────────────────────────────────────────────────────────
void _drawMineExplosion(
    Canvas canvas, double cx, double cy, double r, double t, Color color) {
  final paint = Paint()..style = PaintingStyle.fill;
  paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 20 * (1 - t));
  paint.color = color.withOpacity((1.0 - t) * 0.9);
  canvas.drawCircle(Offset(cx, cy), r * (1 + t * 3), paint);
  paint.maskFilter = null;
  paint.color = Colors.white.withOpacity((1.0 - t) * 0.6);
  canvas.drawCircle(Offset(cx, cy), r * (1 + t * 1.5), paint);
}
