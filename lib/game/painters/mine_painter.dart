import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/game_models.dart';
import '../../utils/safe_color.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MINE PAINTER — Grounded, physical design
// Key changes from old version:
// • No giant ambient aura blur rings (those cheapened the look)
// • Surfaces shaded by single top-left light source
// • Glows ONLY on indicator lights and actual energy sources
// • Metal rendered with radial gradients (sheen), not flat colors
// ─────────────────────────────────────────────────────────────────────────────

void drawMine(Canvas canvas, Size size, MineEntity obs, double animTick) {
  final cx = (obs.x + obs.width / 2) * size.width;
  final cy = (obs.y + obs.height / 2) * size.height;
  final r = obs.width * size.width * 0.5;
  final opacity = obs.damageOpacity;
  final type = obs.mineType;
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
void _drawProximityMine(Canvas canvas, double cx, double cy, double r,
    Color color, double opacity, double pulsePhase, double rotation) {
  final paint = Paint()..style = PaintingStyle.fill;
  final blink = (sin(pulsePhase * 3) > 0) ? 1.0 : 0.25;

  canvas.save();
  canvas.translate(cx, cy);
  canvas.rotate(rotation * 2);

  // Hexagonal body — metallic radial shading (no blur)
  final hexPath = Path();
  for (int i = 0; i < 6; i++) {
    final a = (pi / 3 * i) - pi / 6;
    if (i == 0)
      hexPath.moveTo(cos(a) * r, sin(a) * r);
    else
      hexPath.lineTo(cos(a) * r, sin(a) * r);
  }
  hexPath.close();

  // Metal body with top-left lit shading
  paint.shader = RadialGradient(
    colors: [
      const Color(0xFF5A5A68), // lit surface (top-left)
      const Color(0xFF2A2A32),
      const Color(0xFF080810),
    ],
    center: const Alignment(-0.35, -0.35),
  ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));
  canvas.drawPath(hexPath, paint);
  paint.shader = null;

  // Edge outline
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 1.5;
  paint.color = const Color(0xFF0C0C14).o((opacity).clamp(0.0, 0.9999));
  canvas.drawPath(hexPath, paint);
  paint.style = PaintingStyle.fill;

  // Spikes — metallic tapered rods
  for (int i = 0; i < 8; i++) {
    final a = (pi / 4) * i;
    canvas.save();
    canvas.rotate(a);

    final spike = Path()
      ..moveTo(-r * 0.10, r * 0.84)
      ..lineTo(r * 0.10, r * 0.84)
      ..lineTo(r * 0.03, r * 1.52)
      ..lineTo(-r * 0.03, r * 1.52)
      ..close();

    // Spike shading — lit on left face
    paint.shader = LinearGradient(
      colors: [const Color(0xFF888898), const Color(0xFF323240)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ).createShader(Rect.fromLTWH(-r * 0.10, r * 0.84, r * 0.20, r * 0.70));
    canvas.drawPath(spike, paint);
    paint.shader = null;

    // Spike tip indicator light — small, tight
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    paint.color =
        const Color(0xFFFF2200).o((0.7 * blink * opacity).clamp(0.0, 0.9999));
    canvas.drawCircle(Offset(0, r * 1.50), r * 0.07, paint);
    paint.maskFilter = null;
    paint.color = Colors.white.o((0.85 * blink * opacity).clamp(0.0, 0.9999));
    canvas.drawCircle(Offset(0, r * 1.50), r * 0.04, paint);

    canvas.restore();
  }

  // Panel screws
  paint.color = const Color(0xFF3A3A48).o((opacity).clamp(0.0, 0.9999));
  for (int i = 0; i < 6; i++) {
    final a = (pi / 3 * i) - pi / 6;
    canvas.drawCircle(
        Offset(cos(a) * r * 0.76, sin(a) * r * 0.76), r * 0.065, paint);
    paint.color = Colors.white.o((0.12 * opacity).clamp(0.0, 0.9999));
    canvas.drawCircle(
        Offset(cos(a) * r * 0.74, sin(a) * r * 0.74), r * 0.025, paint);
    paint.color = const Color(0xFF3A3A48).o((opacity).clamp(0.0, 0.9999));
  }

  // Warning ring — engraved circle, no blur
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 1.2;
  paint.color = const Color(0xFF661100).o((0.6 * opacity).clamp(0.0, 0.9999));
  canvas.drawCircle(Offset.zero, r * 0.54, paint);
  paint.style = PaintingStyle.fill;

  // Core indicator light — small, single glow
  paint.color = const Color(0xFF200000);
  canvas.drawCircle(Offset.zero, r * 0.24, paint);
  paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
  paint.color =
      const Color(0xFFFF0000).o((0.9 * blink * opacity).clamp(0.0, 0.9999));
  canvas.drawCircle(Offset.zero, r * 0.18, paint);
  paint.maskFilter = null;
  paint.color = Colors.white.o((0.95 * blink * opacity).clamp(0.0, 0.9999));
  canvas.drawCircle(Offset.zero, r * 0.08, paint);

  canvas.restore();
}

// ── TRACKER MINE ───────────────────────────────────────────────────────────
void _drawTrackerMine(Canvas canvas, double cx, double cy, double r,
    Color color, double opacity, double pulsePhase, double animTick) {
  final paint = Paint()..style = PaintingStyle.fill;

  // Sonar ring — single crisp stroke, no blur
  final scanAngle = animTick * 4.0;
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 1.2;
  paint.color = color.o((0.25 * opacity).clamp(0.0, 0.9999));
  canvas.drawCircle(Offset(cx, cy), r * 1.55, paint);
  paint.color = color.o((0.15 * opacity).clamp(0.0, 0.9999));
  canvas.drawCircle(Offset(cx, cy), r * 2.0, paint);
  paint.style = PaintingStyle.fill;

  canvas.save();
  canvas.translate(cx, cy);

  // Smooth body — physically lit teardrop
  paint.shader = RadialGradient(
    colors: [
      const Color(0xFF2A3040),
      const Color(0xFF141820),
      const Color(0xFF06080C),
    ],
    center: const Alignment(-0.28, -0.28),
  ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));
  canvas.drawOval(
    Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 2.1),
    paint,
  );
  paint.shader = null;

  // Body edge — dark outline
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 1.5;
  paint.color = const Color(0xFF080810).o((opacity).clamp(0.0, 0.9999));
  canvas.drawOval(
    Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 2.1),
    paint,
  );
  paint.style = PaintingStyle.fill;

  // Specular highlight (physical, no blur)
  paint.shader = LinearGradient(
    colors: [Colors.white.o((0.18).clamp(0.0, 0.9999)), Colors.transparent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));
  canvas.drawOval(
    Rect.fromCenter(
        center: Offset(-r * 0.25, -r * 0.25), width: r * 0.8, height: r * 0.6),
    paint,
  );
  paint.shader = null;

  // Scanner sweep — two thin arcs (rotation effect, no blur needed)
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 2.0;
  for (int arc = 0; arc < 2; arc++) {
    final a = scanAngle + arc * pi;
    final arcOpacity = (0.2 + cos(a - scanAngle).abs() * 0.5).clamp(0.0, 1.0);
    paint.color = color.o((arcOpacity * opacity).clamp(0.0, 0.9999));
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: r * 0.70),
      a,
      0.55,
      false,
      paint,
    );
  }
  paint.style = PaintingStyle.fill;

  // Eye socket
  paint.color = const Color(0xFF00000A);
  canvas.drawCircle(Offset.zero, r * 0.38, paint);

  // Iris — radial gradient, single glow
  paint.shader = RadialGradient(
    colors: [Colors.white, color, color.o((0.0).clamp(0.0, 0.9999))],
  ).createShader(Rect.fromCircle(center: Offset.zero, radius: r * 0.28));
  canvas.drawCircle(Offset.zero, r * 0.28, paint);
  paint.shader = null;

  // Pupil glow — ONE small blur
  paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
  paint.color = color.o((0.75 * opacity).clamp(0.0, 0.9999));
  canvas.drawCircle(Offset.zero, r * 0.22, paint);
  paint.maskFilter = null;

  // Glint
  paint.color = Colors.white.o((0.85 * opacity).clamp(0.0, 0.9999));
  canvas.drawCircle(Offset(-r * 0.09, -r * 0.09), r * 0.09, paint);

  // Side fins — dark, physically simple
  for (int side = -1; side <= 1; side += 2) {
    paint.color = const Color(0xFF1A1E28).o((opacity).clamp(0.0, 0.9999));
    final fin = Path()
      ..moveTo(side * r * 0.88, -r * 0.22)
      ..lineTo(side * r * 1.38, -r * 0.52)
      ..lineTo(side * r * 1.28, r * 0.18)
      ..lineTo(side * r * 0.88, r * 0.22)
      ..close();
    canvas.drawPath(fin, paint);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 0.8;
    paint.color = const Color(0xFF0A0A14).o((opacity).clamp(0.0, 0.9999));
    canvas.drawPath(fin, paint);
    paint.style = PaintingStyle.fill;
  }

  canvas.restore();
}

// ── CLUSTER MINE ───────────────────────────────────────────────────────────
void _drawClusterMine(Canvas canvas, double cx, double cy, double r,
    Color color, double opacity, double pulsePhase, double animTick) {
  final paint = Paint()..style = PaintingStyle.fill;

  canvas.save();
  canvas.translate(cx, cy);
  canvas.rotate(animTick * 0.8);

  // Triangular casing — dark, physically shaded
  final bodyPath = Path();
  for (int i = 0; i < 3; i++) {
    final a = (2 * pi / 3 * i) - pi / 2;
    if (i == 0)
      bodyPath.moveTo(cos(a) * r, sin(a) * r);
    else
      bodyPath.lineTo(cos(a) * r, sin(a) * r);
  }
  bodyPath.close();

  paint.shader = RadialGradient(
    colors: [
      const Color(0xFF2E1A1A),
      const Color(0xFF180A0A),
      const Color(0xFF060202),
    ],
    center: const Alignment(-0.3, -0.3),
  ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));
  canvas.drawPath(bodyPath, paint);
  paint.shader = null;

  // Casing edge
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 2.5;
  paint.color = color.o((0.75 * opacity).clamp(0.0, 0.9999));
  canvas.drawPath(bodyPath, paint);
  paint.style = PaintingStyle.fill;

  // Seam lines between chambers
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 1.5;
  paint.color = color.o((0.35 * opacity).clamp(0.0, 0.9999));
  for (int i = 0; i < 3; i++) {
    final a = (2 * pi / 3 * i) - pi / 2;
    canvas.drawLine(
        Offset.zero, Offset(cos(a) * r * 0.92, sin(a) * r * 0.92), paint);
  }
  paint.style = PaintingStyle.fill;

  // 3 child-mine chambers
  for (int i = 0; i < 3; i++) {
    final a = (2 * pi / 3 * i) - pi / 2;
    final cx2 = cos(a) * r * 0.48;
    final cy2 = sin(a) * r * 0.48;
    final cr = r * 0.30;

    // Socket
    paint.color = const Color(0xFF080202);
    canvas.drawCircle(Offset(cx2, cy2), cr, paint);

    // Sub-mine — radial gradient, no ambient blur
    paint.shader = RadialGradient(
      colors: [
        color.o((0.7).clamp(0.0, 0.9999)),
        color.o((0.25).clamp(0.0, 0.9999)),
        Colors.transparent
      ],
      center: const Alignment(-0.25, -0.25),
    ).createShader(
        Rect.fromCircle(center: Offset(cx2, cy2), radius: cr * 0.75));
    canvas.drawCircle(Offset(cx2, cy2), cr * 0.72, paint);
    paint.shader = null;

    // Sub-mine indicator — white dot, one small glow
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    paint.color = Colors.white.o((0.9 * opacity).clamp(0.0, 0.9999));
    canvas.drawCircle(Offset(cx2, cy2), cr * 0.22, paint);
    paint.maskFilter = null;

    // Mini spikes — short stubs, no glow
    for (int s = 0; s < 6; s++) {
      final sa = (pi / 3 * s) + animTick;
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 1.2;
      paint.color =
          const Color(0xFF666678).o((opacity * 0.8).clamp(0.0, 0.9999));
      canvas.drawLine(
        Offset(cx2 + cos(sa) * cr * 0.70, cy2 + sin(sa) * cr * 0.70),
        Offset(cx2 + cos(sa) * cr * 1.02, cy2 + sin(sa) * cr * 1.02),
        paint,
      );
      paint.style = PaintingStyle.fill;
    }

    // Chamber ring
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.2;
    paint.color = const Color(0xFF0A0A10).o((opacity).clamp(0.0, 0.9999));
    canvas.drawCircle(Offset(cx2, cy2), cr, paint);
    paint.style = PaintingStyle.fill;
  }

  // Centre detonator
  paint.color = const Color(0xFF0A0202);
  canvas.drawCircle(Offset.zero, r * 0.17, paint);
  paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
  paint.color = const Color(0xFFCC0000).o((0.9 * opacity).clamp(0.0, 0.9999));
  canvas.drawCircle(Offset.zero, r * 0.12, paint);
  paint.maskFilter = null;
  paint.color = Colors.white.o((opacity).clamp(0.0, 0.9999));
  canvas.drawCircle(Offset.zero, r * 0.06, paint);

  canvas.restore();

  // "CLUSTER" label
  final tp = TextPainter(
    text: TextSpan(
      text: 'CLUSTER',
      style: TextStyle(
        color: color.o((0.6 * opacity).clamp(0.0, 0.9999)),
        fontSize: 7,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  tp.layout();
  tp.paint(canvas, Offset(cx - tp.width / 2, cy + r * 1.68));
}

// ── DEATH EXPLOSION ────────────────────────────────────────────────────────
void _drawMineExplosion(
    Canvas canvas, double cx, double cy, double r, double t, Color color) {
  final paint = Paint()..style = PaintingStyle.fill;
  // One radial burst — tight blur on the expanding ring
  paint.maskFilter =
      MaskFilter.blur(BlurStyle.normal, (18 * (1 - t)).clamp(0.1, 18.0));
  paint.color = color.o(((1.0 - t) * 0.85).clamp(0.0, 0.9999));
  canvas.drawCircle(Offset(cx, cy), r * (1 + t * 2.8), paint);
  paint.maskFilter = null;
  // Bright flash core
  paint.color = Colors.white.o(((1.0 - t) * 0.55).clamp(0.0, 0.9999));
  canvas.drawCircle(Offset(cx, cy), r * (1 + t * 1.4), paint);
}
