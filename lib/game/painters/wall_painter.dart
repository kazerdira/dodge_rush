import 'package:flutter/material.dart';
import 'dart:math';
import '../../models/game_models.dart';
import '../../theme/app_theme.dart';

/// Renders laser walls with tier-specific visuals (fragile / standard /
/// reinforced / armored), including death explosions, damage cracks, and the
/// small HP bar underneath.

void drawLaserWall(Canvas canvas, Size size, Obstacle obs, double animTick) {
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

  // Death explosion — specific to tier
  if (obs.isDying) {
    final t = obs.deathTimer;
    // Flash
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 30 * (1 - t));
    paint.color = effectiveColor.withOpacity((1.0 - t) * 0.9);
    canvas.drawRect(rect.inflate(8 * (1 - t)), paint);
    paint.maskFilter = null;

    // Flying debris chunks — more for armored
    final debrisCount = tier == WallTier.armored
        ? 12
        : tier == WallTier.reinforced
            ? 8
            : 4;
    for (int i = 0; i < debrisCount; i++) {
      final dx = sin(i * 1.7 + t * 10) * 40 * t;
      final dy = -60 * t * (0.5 + i * 0.2) + sin(i * 2.3) * 20 * t;
      final chunkW = rect.width * (0.06 + (i % 3) * 0.04) * (1 - t);
      final chunkH = rect.height * (0.8 + sin(i) * 0.2) * (1 - t);
      paint.color = effectiveColor.withOpacity((1.0 - t) * 0.8);
      // Rotating debris
      canvas.save();
      canvas.translate(rect.center.dx + dx, rect.center.dy + dy);
      canvas.rotate(t * i * 2.0);
      canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: chunkW, height: chunkH),
          paint);
      canvas.restore();
    }

    // Sparks flying off
    for (int i = 0; i < 6; i++) {
      final sx = rect.left + rect.width * (i / 5.0);
      final sy = rect.center.dy - 40 * t * (1 + i * 0.1);
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      paint.color = Colors.white.withOpacity((1 - t) * 0.8);
      canvas.drawCircle(Offset(sx, sy), 2 * (1 - t), paint);
      paint.maskFilter = null;
    }
    return;
  }

  // ── FRAGILE WALL: Thin glowing glass panel ─────────────────────────────
  if (tier == WallTier.fragile) {
    // Almost transparent, glassy look
    paint.color = effectiveColor.withOpacity(0.15 * opacity);
    canvas.drawRect(rect, paint);

    // Central glowing line
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    paint.color = effectiveGlow.withOpacity(0.9 * opacity);
    final lineRect = Rect.fromLTWH(rect.left, rect.top + rect.height * 0.35,
        rect.width, rect.height * 0.3);
    canvas.drawRect(lineRect, paint);
    paint.maskFilter = null;

    // Hot wire
    paint.color = Colors.white.withOpacity(0.95 * opacity);
    canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.top + rect.height * 0.44, rect.width,
            rect.height * 0.12),
        paint);

    // HP bar — tiny, shows 1/1
    _drawHpBar(canvas, rect, obs, effectiveColor, opacity);
    return;
  }

  // ── STANDARD WALL ──────────────────────────────────────────────────────
  if (tier == WallTier.standard) {
    // Dark housing
    paint.shader = LinearGradient(
      colors: [const Color(0xFF1A1A24), const Color(0xFF0D0D14)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(rect);
    canvas.drawRect(rect, paint);
    paint.shader = null;

    // Damage cracks
    if (obs.damageState != DamageState.healthy) {
      paint.color = Colors.orange
          .withOpacity(obs.damageState == DamageState.critical ? 0.7 : 0.35);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 1.5;
      final crackPath = Path();
      for (int i = 0; i < 3; i++) {
        final startX = rect.left + rect.width * (0.2 + i * 0.25);
        crackPath.moveTo(startX, rect.top);
        crackPath.lineTo(startX + 6, rect.center.dy);
        crackPath.lineTo(startX - 4, rect.bottom);
      }
      canvas.drawPath(crackPath, paint);
      paint.style = PaintingStyle.fill;
    }

    // Panel seams
    paint.color = Colors.black.withOpacity(0.6 * opacity);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2.0;
    canvas.drawRect(rect, paint);
    for (double x = rect.left + 20; x < rect.right; x += 40) {
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), paint);
    }
    paint.style = PaintingStyle.fill;

    // Plasma trench
    final innerRect = Rect.fromLTWH(
        rect.left, rect.top + rect.height * 0.3, rect.width, rect.height * 0.4);
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    paint.color = effectiveColor.withOpacity(0.6 * opacity);
    canvas.drawRect(innerRect, paint);
    paint.maskFilter = null;

    paint.shader = LinearGradient(
      colors: [
        Colors.white.withOpacity(opacity),
        effectiveColor.withOpacity(opacity),
        effectiveColor.withOpacity(0.4 * opacity)
      ],
      stops: const [0.1, 0.5, 1.0],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(innerRect);
    canvas.drawRect(innerRect, paint);
    paint.shader = null;

    // Warning nodes
    final nodePhase = (animTick * 4) % (pi * 2);
    paint.color =
        Colors.white.withOpacity((0.5 + sin(nodePhase) * 0.5) * opacity);
    for (double x = rect.left + 10; x < rect.right; x += 40) {
      canvas.drawCircle(Offset(x, rect.top + rect.height / 2), 3, paint);
    }
    _drawHpBar(canvas, rect, obs, effectiveColor, opacity);
    return;
  }

  // ── REINFORCED WALL: Heavy armor plating ───────────────────────────────
  if (tier == WallTier.reinforced) {
    // Thick hull base
    paint.shader = LinearGradient(
      colors: [
        const Color(0xFF2A1800),
        const Color(0xFF1A0E00),
        const Color(0xFF0A0500)
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(rect);
    canvas.drawRect(rect, paint);
    paint.shader = null;

    // Orange-hot energy channel
    final channelRect = Rect.fromLTWH(rect.left, rect.top + rect.height * 0.25,
        rect.width, rect.height * 0.5);
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    paint.color = effectiveColor.withOpacity(0.8 * opacity);
    canvas.drawRect(channelRect, paint);
    paint.maskFilter = null;

    paint.shader = LinearGradient(
      colors: [
        Colors.white.withOpacity(0.9 * opacity),
        effectiveColor.withOpacity(opacity),
        const Color(0xFF441100).withOpacity(opacity)
      ],
      stops: const [0.0, 0.4, 1.0],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(channelRect);
    canvas.drawRect(channelRect, paint);
    paint.shader = null;

    // Armor bolts / rivets
    paint.color = Colors.grey.shade600.withOpacity(opacity);
    for (double x = rect.left + 15; x < rect.right; x += 30) {
      canvas.drawCircle(Offset(x, rect.top + 4), 2.5, paint);
      canvas.drawCircle(Offset(x, rect.bottom - 4), 2.5, paint);
    }

    // Heavy outer frame
    paint.color = Colors.orange.shade900.withOpacity(0.8 * opacity);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 3.0;
    canvas.drawRect(rect, paint);
    paint.style = PaintingStyle.fill;

    // Damage cracks — dramatic
    if (obs.damageState != DamageState.healthy) {
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2.5;
      paint.color = Colors.red
          .withOpacity(obs.damageState == DamageState.critical ? 0.9 : 0.5);
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      final rng = Random(obs.hashCode);
      for (int i = 0;
          i < (obs.damageState == DamageState.critical ? 6 : 3);
          i++) {
        final startX = rect.left + rng.nextDouble() * rect.width;
        final crackPath = Path()
          ..moveTo(startX, rect.top)
          ..lineTo(startX + (rng.nextDouble() - 0.5) * 20, rect.center.dy)
          ..lineTo(startX + (rng.nextDouble() - 0.5) * 30, rect.bottom);
        canvas.drawPath(crackPath, paint);
      }
      paint.maskFilter = null;
      paint.style = PaintingStyle.fill;
    }

    // Pulsing warning lights
    final warnPhase = (animTick * 6) % (pi * 2);
    paint.color = const Color(0xFFFF4400)
        .withOpacity((0.4 + sin(warnPhase) * 0.4) * opacity);
    for (double x = rect.left + 20; x < rect.right; x += 60) {
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(x, rect.top + rect.height / 2), 4, paint);
      paint.maskFilter = null;
    }

    _drawHpBar(canvas, rect, obs, effectiveColor, opacity);
    return;
  }

  // ── ARMORED WALL: Military-grade death machine ─────────────────────────
  if (tier == WallTier.armored) {
    // Pitch-black heavy hull
    paint.shader = LinearGradient(
      colors: [
        const Color(0xFF1A0025),
        const Color(0xFF0D0018),
        const Color(0xFF050008)
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(rect);
    canvas.drawRect(rect, paint);
    paint.shader = null;

    // Triple energy channels
    for (int ch = 0; ch < 3; ch++) {
      final yFrac = 0.2 + ch * 0.25;
      final channelR = Rect.fromLTWH(rect.left, rect.top + rect.height * yFrac,
          rect.width, rect.height * 0.15);
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + ch * 2.0);
      paint.color = effectiveColor.withOpacity((0.5 + ch * 0.15) * opacity);
      canvas.drawRect(channelR, paint);
      paint.maskFilter = null;
      if (ch == 1) {
        // Middle one is white-hot
        paint.color = Colors.white.withOpacity(0.9 * opacity);
        canvas.drawRect(
            Rect.fromLTWH(rect.left, channelR.top + channelR.height * 0.3,
                rect.width, channelR.height * 0.4),
            paint);
      }
    }

    // Thick armor plates with rivets
    paint.color = Colors.purple.shade900.withOpacity(0.8 * opacity);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 4.0;
    canvas.drawRect(rect, paint);

    // Armored segments
    paint.strokeWidth = 2.0;
    paint.color = Colors.purple.shade700.withOpacity(0.6 * opacity);
    for (double x = rect.left + 30; x < rect.right; x += 30) {
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), paint);
    }
    paint.style = PaintingStyle.fill;

    // Heavy corner brackets
    paint.color = Colors.grey.shade400.withOpacity(opacity);
    const bSize = 8.0;
    for (final corner in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight
    ]) {
      final signX =
          corner == rect.topLeft || corner == rect.bottomLeft ? 1.0 : -1.0;
      final signY =
          corner == rect.topLeft || corner == rect.topRight ? 1.0 : -1.0;
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2.5;
      canvas.drawLine(corner, corner + Offset(signX * bSize, 0), paint);
      canvas.drawLine(corner, corner + Offset(0, signY * bSize), paint);
      paint.style = PaintingStyle.fill;
    }

    // Ominous pulsing — slow, menacing
    final armorPhase = (animTick * 2) % (pi * 2);
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 12);
    paint.color =
        effectiveColor.withOpacity((0.3 + sin(armorPhase) * 0.2) * opacity);
    canvas.drawRect(rect.inflate(4), paint);
    paint.maskFilter = null;

    // Critical damage — wall is crumbling
    if (obs.damageState == DamageState.critical) {
      paint.color =
          Colors.white.withOpacity(0.15 * (0.5 + sin(animTick * 20) * 0.5));
      canvas.drawRect(rect, paint);
      // Crumble effect — chunks missing
      final rng = Random(obs.hashCode);
      paint.color = AppTheme.bg;
      for (int i = 0; i < 8; i++) {
        final cx = rect.left + rng.nextDouble() * rect.width;
        final cy = rect.top + rng.nextDouble() * rect.height;
        final r = 3.0 + rng.nextDouble() * 6;
        canvas.drawCircle(Offset(cx, cy), r, paint);
      }
    }

    // ARMORED label tag
    final tp = TextPainter(
      text: TextSpan(
          text: '⬡ ARMORED',
          style: TextStyle(
            color: effectiveColor.withOpacity(0.7 * opacity),
            fontSize: 7,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          )),
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
    Canvas canvas, Rect wallRect, Obstacle obs, Color color, double opacity) {
  if (obs.maxHp <= 1) return; // fragile walls don't need a bar
  final ratio = (obs.hp / obs.maxHp).clamp(0.0, 1.0);
  const barH = 3.0;
  final barY = wallRect.bottom + 2;
  final bgRect = Rect.fromLTWH(wallRect.left, barY, wallRect.width, barH);
  final fillRect =
      Rect.fromLTWH(wallRect.left, barY, wallRect.width * ratio, barH);

  final paint = Paint()..style = PaintingStyle.fill;
  // Background
  paint.color = Colors.black.withOpacity(0.6);
  canvas.drawRect(bgRect, paint);
  // Fill — color shifts red as HP drops
  final barColor = Color.lerp(Colors.red, color, ratio)!;
  paint.color = barColor.withOpacity(opacity);
  canvas.drawRect(fillRect, paint);
  // Glow on fill
  paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  paint.color = barColor.withOpacity(opacity * 0.5);
  canvas.drawRect(fillRect, paint);
  paint.maskFilter = null;
}
