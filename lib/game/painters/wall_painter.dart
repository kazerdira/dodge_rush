import 'package:flutter/material.dart';
import 'dart:math';
import '../../models/game_models.dart';
import '../../theme/app_theme.dart';
import '../../utils/safe_color.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WALL PAINTER — Grounded, tier-specific laser walls
// Key changes:
// • Housing panels shaded by top-left light (not just flat dark boxes)
// • Plasma channel has ONE glow — the active energy conduit, not the whole wall
// • Panel seams are engraved (dark), not glowing
// • Damage cracks use physical opacity, not stacked blurs
// • HP bar remains (it's functional, not decorative)
// ─────────────────────────────────────────────────────────────────────────────

void drawLaserWall(
    Canvas canvas, Size size, LaserWallEntity obs, double animTick) {
  final rect = Rect.fromLTWH(obs.x * size.width, obs.y * size.height,
      obs.width * size.width, obs.height * size.height);
  final paint = Paint();
  final opacity = obs.damageOpacity;
  final tier = obs.wallTier ?? WallTier.standard;
  final td = wallTierData(tier);
  final effectiveColor =
      Color.lerp(td.color, const Color(0xFF666666), obs.greyShift)!;
  final effectiveGlow =
      Color.lerp(td.glowColor, const Color(0xFF888888), obs.greyShift)!;

  // ── DEATH EXPLOSION ──────────────────────────────────────────────────────
  if (obs.isDying) {
    final t = obs.deathTimer;
    paint.maskFilter =
        MaskFilter.blur(BlurStyle.normal, (20 * (1 - t)).clamp(0.1, 20.0));
    paint.color = effectiveColor.o(((1.0 - t) * 0.85).clamp(0.0, 0.9999));
    canvas.drawRect(rect.inflate(6 * (1 - t)), paint);
    paint.maskFilter = null;

    final debrisCount = tier == WallTier.armored
        ? 10
        : tier == WallTier.reinforced
            ? 6
            : 4;
    for (int i = 0; i < debrisCount; i++) {
      final dx = sin(i * 1.7 + t * 10) * 38 * t;
      final dy = -55 * t * (0.5 + i * 0.18) + sin(i * 2.3) * 18 * t;
      final chunkW = rect.width * (0.05 + (i % 3) * 0.04) * (1 - t);
      final chunkH = rect.height * (0.75 + sin(i) * 0.2) * (1 - t);
      paint.color = effectiveColor.o(((1.0 - t) * 0.75).clamp(0.0, 0.9999));
      canvas.save();
      canvas.translate(rect.center.dx + dx, rect.center.dy + dy);
      canvas.rotate(t * i * 1.8);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: chunkW, height: chunkH),
        paint,
      );
      canvas.restore();
    }
    return;
  }

  // ── FRAGILE: Thin glass panel ─────────────────────────────────────────────
  if (tier == WallTier.fragile) {
    // Glass body — barely visible
    paint.color = effectiveColor.o((0.12 * opacity).clamp(0.0, 0.9999));
    canvas.drawRect(rect, paint);

    // Hot wire centre — ONE glow
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    paint.color = effectiveGlow.o((0.85 * opacity).clamp(0.0, 0.9999));
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.top + rect.height * 0.36, rect.width,
          rect.height * 0.28),
      paint,
    );
    paint.maskFilter = null;
    // Crisp white core
    paint.color = Colors.white.o((0.9 * opacity).clamp(0.0, 0.9999));
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.top + rect.height * 0.43, rect.width,
          rect.height * 0.14),
      paint,
    );

    _drawHpBar(canvas, rect, obs, effectiveColor, opacity);
    return;
  }

  // ── STANDARD: Industrial armour panel ────────────────────────────────────
  if (tier == WallTier.standard) {
    // Base housing — gradient gives slight 3D bevel
    paint.shader = LinearGradient(
      colors: [const Color(0xFF252530), const Color(0xFF111118)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(rect);
    canvas.drawRect(rect, paint);
    paint.shader = null;

    // Panel seams — engraved dark lines
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 0.8;
    paint.color = const Color(0xFF0A0A12).o((opacity).clamp(0.0, 0.9999));
    canvas.drawRect(rect, paint);
    for (double x = rect.left + 24; x < rect.right; x += 48) {
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), paint);
    }
    paint.style = PaintingStyle.fill;

    // Damage cracks — flat, no blur
    if (obs.damageState != DamageState.healthy) {
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 1.2;
      paint.color = Colors.orange.o(
          (obs.damageState == DamageState.critical ? 0.65 : 0.30)
              .clamp(0.0, 0.9999));
      final crackPath = Path();
      for (int i = 0; i < 3; i++) {
        final sx = rect.left + rect.width * (0.2 + i * 0.25);
        crackPath.moveTo(sx, rect.top);
        crackPath.lineTo(sx + 5, rect.center.dy);
        crackPath.lineTo(sx - 3, rect.bottom);
      }
      canvas.drawPath(crackPath, paint);
      paint.style = PaintingStyle.fill;
    }

    // Plasma channel — single controlled glow in the channel, not the housing
    final innerRect = Rect.fromLTWH(
      rect.left,
      rect.top + rect.height * 0.30,
      rect.width,
      rect.height * 0.40,
    );
    // Glow halo — one blur pass
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    paint.color = effectiveColor.o((0.5 * opacity).clamp(0.0, 0.9999));
    canvas.drawRect(innerRect, paint);
    paint.maskFilter = null;
    // Crisp channel fill
    paint.shader = LinearGradient(
      colors: [
        Colors.white.o((0.9 * opacity).clamp(0.0, 0.9999)),
        effectiveColor.o((opacity).clamp(0.0, 0.9999)),
        effectiveColor.o((0.35 * opacity).clamp(0.0, 0.9999)),
      ],
      stops: const [0.0, 0.4, 1.0],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(innerRect);
    canvas.drawRect(innerRect, paint);
    paint.shader = null;

    // Emitter nodes — small lit dots, no bloom
    final nodePhase = (animTick * 4) % (pi * 2);
    paint.color = Colors.white
        .o(((0.4 + sin(nodePhase) * 0.4) * opacity).clamp(0.0, 0.9999));
    for (double x = rect.left + 12; x < rect.right; x += 48) {
      canvas.drawCircle(Offset(x, rect.center.dy), 2.5, paint);
    }

    _drawHpBar(canvas, rect, obs, effectiveColor, opacity);
    return;
  }

  // ── REINFORCED: Heavy armour plate ────────────────────────────────────────
  if (tier == WallTier.reinforced) {
    // Thick dark hull — subtle top-lit gradient
    paint.shader = LinearGradient(
      colors: [
        const Color(0xFF2E1600),
        const Color(0xFF140900),
        const Color(0xFF060300)
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(rect);
    canvas.drawRect(rect, paint);
    paint.shader = null;

    // Armour segments
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.0;
    paint.color = const Color(0xFF0A0500).o((opacity).clamp(0.0, 0.9999));
    for (double x = rect.left + 28; x < rect.right; x += 28) {
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), paint);
    }
    paint.style = PaintingStyle.fill;

    // Rivets
    paint.color = const Color(0xFF4A3018).o((opacity).clamp(0.0, 0.9999));
    for (double x = rect.left + 14; x < rect.right; x += 28) {
      canvas.drawCircle(Offset(x, rect.top + 4), 2.2, paint);
      canvas.drawCircle(Offset(x, rect.bottom - 4), 2.2, paint);
      // Rivet highlight
      paint.color = Colors.white.o((0.15 * opacity).clamp(0.0, 0.9999));
      canvas.drawCircle(Offset(x - 0.8, rect.top + 3.2), 1.0, paint);
      paint.color = const Color(0xFF4A3018).o((opacity).clamp(0.0, 0.9999));
    }

    // Orange energy channel
    final channelRect = Rect.fromLTWH(
      rect.left,
      rect.top + rect.height * 0.26,
      rect.width,
      rect.height * 0.48,
    );
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    paint.color = effectiveColor.o((0.65 * opacity).clamp(0.0, 0.9999));
    canvas.drawRect(channelRect, paint);
    paint.maskFilter = null;
    paint.shader = LinearGradient(
      colors: [
        Colors.white.o((0.85 * opacity).clamp(0.0, 0.9999)),
        effectiveColor.o((opacity).clamp(0.0, 0.9999)),
        const Color(0xFF3A1000).o((opacity).clamp(0.0, 0.9999)),
      ],
      stops: const [0.0, 0.35, 1.0],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(channelRect);
    canvas.drawRect(channelRect, paint);
    paint.shader = null;

    // Heavy frame outline
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2.5;
    paint.color = const Color(0xFF3A1800).o((opacity).clamp(0.0, 0.9999));
    canvas.drawRect(rect, paint);
    paint.style = PaintingStyle.fill;

    // Damage cracks — more dramatic
    if (obs.damageState != DamageState.healthy) {
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2.0;
      paint.color = Colors.red.o(
          (obs.damageState == DamageState.critical ? 0.85 : 0.40)
              .clamp(0.0, 0.9999));
      final rng = Random(obs.hashCode);
      for (int i = 0;
          i < (obs.damageState == DamageState.critical ? 5 : 2);
          i++) {
        final sx = rect.left + rng.nextDouble() * rect.width;
        final crackPath = Path()
          ..moveTo(sx, rect.top)
          ..lineTo(sx + (rng.nextDouble() - 0.5) * 18, rect.center.dy)
          ..lineTo(sx + (rng.nextDouble() - 0.5) * 25, rect.bottom);
        canvas.drawPath(crackPath, paint);
      }
      paint.style = PaintingStyle.fill;
    }

    _drawHpBar(canvas, rect, obs, effectiveColor, opacity);
    return;
  }

  // ── ARMORED: Military death machine ───────────────────────────────────────
  if (tier == WallTier.armored) {
    // Deep hull — violet-dark
    paint.shader = LinearGradient(
      colors: [
        const Color(0xFF180020),
        const Color(0xFF0C0012),
        const Color(0xFF050008)
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(rect);
    canvas.drawRect(rect, paint);
    paint.shader = null;

    // Armour segments — thick bolted plates
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.8;
    paint.color = const Color(0xFF220030).o((opacity).clamp(0.0, 0.9999));
    for (double x = rect.left + 30; x < rect.right; x += 30) {
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), paint);
    }
    // Heavy bolts at corners of each segment
    paint.style = PaintingStyle.fill;
    paint.color = const Color(0xFF3A2050).o((opacity).clamp(0.0, 0.9999));
    for (double x = rect.left + 15; x < rect.right; x += 30) {
      canvas.drawCircle(Offset(x, rect.top + 5), 2.5, paint);
      canvas.drawCircle(Offset(x, rect.bottom - 5), 2.5, paint);
    }

    // Triple energy channels — stacked, increasingly hot
    for (int ch = 0; ch < 3; ch++) {
      final yFrac = 0.18 + ch * 0.24;
      final chR = Rect.fromLTWH(
        rect.left,
        rect.top + rect.height * yFrac,
        rect.width,
        rect.height * 0.14,
      );
      // Single glow per channel
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + ch * 2.0);
      paint.color =
          effectiveColor.o(((0.45 + ch * 0.12) * opacity).clamp(0.0, 0.9999));
      canvas.drawRect(chR, paint);
      paint.maskFilter = null;
      // White-hot core on middle channel
      if (ch == 1) {
        paint.color = Colors.white.o((0.85 * opacity).clamp(0.0, 0.9999));
        canvas.drawRect(
          Rect.fromLTWH(rect.left, chR.top + chR.height * 0.30, rect.width,
              chR.height * 0.40),
          paint,
        );
      }
    }

    // Heavy frame
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 3.5;
    paint.color = const Color(0xFF3A0050).o((opacity).clamp(0.0, 0.9999));
    canvas.drawRect(rect, paint);

    // Corner brackets — structural steel
    paint.color = Colors.grey.shade500.o((opacity).clamp(0.0, 0.9999));
    paint.strokeWidth = 2.2;
    const bSize = 7.0;
    for (final corner in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight
    ]) {
      final sx =
          (corner == rect.topLeft || corner == rect.bottomLeft) ? 1.0 : -1.0;
      final sy =
          (corner == rect.topLeft || corner == rect.topRight) ? 1.0 : -1.0;
      canvas.drawLine(corner, corner + Offset(sx * bSize, 0), paint);
      canvas.drawLine(corner, corner + Offset(0, sy * bSize), paint);
    }
    paint.style = PaintingStyle.fill;

    // Critical damage crumble
    if (obs.damageState == DamageState.critical) {
      paint.color = Colors.white
          .o((0.12 * (0.5 + sin(animTick * 18) * 0.5)).clamp(0.0, 0.9999));
      canvas.drawRect(rect, paint);
      final rng = Random(obs.hashCode);
      paint.color = AppTheme.bg;
      for (int i = 0; i < 7; i++) {
        final cx = rect.left + rng.nextDouble() * rect.width;
        final cy = rect.top + rng.nextDouble() * rect.height;
        canvas.drawCircle(Offset(cx, cy), 2.5 + rng.nextDouble() * 5, paint);
      }
    }

    // Armoured label
    final tp = TextPainter(
      text: TextSpan(
        text: '⬡ ARMORED',
        style: TextStyle(
          color: effectiveColor.o((0.65 * opacity).clamp(0.0, 0.9999)),
          fontSize: 7,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas,
        Offset(rect.left + 4, rect.top + (rect.height - tp.height) / 2));

    _drawHpBar(canvas, rect, obs, effectiveColor, opacity);
  }
}

/// HP bar drawn below each wall.
void _drawHpBar(
    Canvas canvas, Rect wallRect, GameEntity obs, Color color, double opacity) {
  if (obs.maxHp <= 1) return;
  final ratio = (obs.hp / obs.maxHp).clamp(0.0, 1.0);
  const barH = 3.0;
  final barY = wallRect.bottom + 2;

  final paint = Paint()..style = PaintingStyle.fill;
  // Background
  paint.color = Colors.black.o((0.55).clamp(0.0, 0.9999));
  canvas.drawRect(
      Rect.fromLTWH(wallRect.left, barY, wallRect.width, barH), paint);
  // Fill
  final barColor = Color.lerp(Colors.red, color, ratio)!;
  paint.color = barColor.o((opacity).clamp(0.0, 0.9999));
  canvas.drawRect(
    Rect.fromLTWH(wallRect.left, barY, wallRect.width * ratio, barH),
    paint,
  );
  // Single glow pass on fill only
  paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
  paint.color = barColor.o((opacity * 0.45).clamp(0.0, 0.9999));
  canvas.drawRect(
    Rect.fromLTWH(wallRect.left, barY, wallRect.width * ratio, barH),
    paint,
  );
  paint.maskFilter = null;
}
