import 'package:flutter/material.dart';
import 'dart:math';
import '../models/game_models.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import 'ships/ships.dart';

class GamePainter extends CustomPainter {
  final GameProvider game;
  final double animTick;

  GamePainter(this.game, this.animTick);

  @override
  void paint(Canvas canvas, Size size) {
    _drawSpaceBackground(canvas, size);
    _drawNebula(canvas, size);
    _drawStars(canvas, size);
    _drawSpeedLines(canvas, size);
    _drawShockwaves(canvas, size);
    _drawTrail(canvas, size);
    _drawGhostImages(canvas, size);
    _drawObstacles(canvas, size);
    _drawCoins(canvas, size);
    _drawPowerUps(canvas, size);
    _drawChests(canvas, size);
    _drawBullets(canvas, size);
    _drawParticles(canvas, size);
    _drawBombEffect(canvas, size);
    _drawShip(canvas, size);
  }

  void _drawSpaceBackground(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = AppTheme.bg);
  }

  void _drawNebula(Canvas canvas, Size size) {
    final t = animTick * 0.12;
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80)
      ..style = PaintingStyle.fill;
    paint.color = AppTheme.purple.withOpacity(0.04 + sin(t) * 0.01);
    canvas.drawCircle(Offset(size.width * 0.18, size.height * 0.35), 170, paint);
    paint.color = AppTheme.accentAlt.withOpacity(0.03 + cos(t * 0.8) * 0.01);
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.6), 150, paint);
    paint.color = AppTheme.orange.withOpacity(0.025);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.12), 130, paint);
    paint.maskFilter = null;
  }

  void _drawStars(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final star in game.stars) {
      double opacity = star.opacity;
      if (star.layer == 2) opacity = star.opacity * (0.7 + sin(animTick * 3 + star.x * 10) * 0.3);
      paint.color = Colors.white.withOpacity(opacity.clamp(0.0, 1.0));
      if (star.layer == 2 && star.size > 2.0) {
        final cx = star.x * size.width;
        final cy = star.y * size.height;
        final r = star.size;
        paint.strokeWidth = 0.8;
        paint.style = PaintingStyle.stroke;
        canvas.drawLine(Offset(cx - r, cy), Offset(cx + r, cy), paint);
        canvas.drawLine(Offset(cx, cy - r), Offset(cx, cy + r), paint);
        paint.style = PaintingStyle.fill;
        canvas.drawCircle(Offset(cx, cy), r * 0.5, paint);
      } else {
        canvas.drawCircle(Offset(star.x * size.width, star.y * size.height), star.size, paint);
      }
    }
  }

  void _drawSpeedLines(Canvas canvas, Size size) {
    final sp = (game.state.speed - 1.0) / 2.0;
    if (sp <= 0.05) return;
    final paint = Paint()..strokeWidth = 0.8..style = PaintingStyle.stroke;
    final rng = Random(42);
    for (int side = 0; side < 2; side++) {
      for (int i = 0; i < 8; i++) {
        final x = side == 0
            ? rng.nextDouble() * size.width * 0.12
            : size.width - rng.nextDouble() * size.width * 0.12;
        final y = (rng.nextDouble() * size.height + animTick * 180 * game.state.speed) % size.height;
        final len = 18.0 + rng.nextDouble() * 35;
        paint.color = AppTheme.accent.withOpacity(0.06 * sp);
        canvas.drawLine(Offset(x, y), Offset(x, y + len), paint);
      }
    }
  }

  // ── SHOCKWAVES ──────────────────────────────────────────────────────────────

  void _drawShockwaves(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke;
    for (final sw in game.shockwaves) {
      final r = sw.radius * size.width;
      final opacity = sw.life;
      // Outer ring
      paint.strokeWidth = 3.0 * sw.life;
      paint.color = sw.color.withOpacity(opacity * 0.8);
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * sw.life);
      canvas.drawCircle(Offset(sw.x * size.width, sw.y * size.height), r, paint);
      paint.maskFilter = null;
      // Inner bright ring
      paint.strokeWidth = 1.5 * sw.life;
      paint.color = Colors.white.withOpacity(opacity * 0.6);
      canvas.drawCircle(Offset(sw.x * size.width, sw.y * size.height), r * 0.7, paint);
    }
    paint.style = PaintingStyle.fill;
  }

  // ── BOMB VFX ────────────────────────────────────────────────────────────────

  void _drawBombEffect(Canvas canvas, Size size) {
    final bomb = game.activeBomb;
    if (bomb == null) return;

    final t = bomb.detonationTimer; // 0..1
    final cx = bomb.x * size.width;
    final cy = bomb.y * size.height;
    final paint = Paint()..style = PaintingStyle.fill;

    // Phase 1 (0..0.3): Blinding white flash
    if (t < 0.3) {
      final flashT = t / 0.3;
      final opacity = (1.0 - flashT) * 0.95;
      paint.color = Colors.white.withOpacity(opacity);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    }

    // Phase 2 (0.1..1.0): Expanding plasma ring
    if (t > 0.05) {
      final ringT = ((t - 0.05) / 0.95).clamp(0.0, 1.0);
      final maxRadius = sqrt(size.width * size.width + size.height * size.height);
      final r = ringT * maxRadius;
      final ringOpacity = (1.0 - ringT) * 0.7;

      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 20.0 * (1.0 - ringT);
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 15 * (1 - ringT));
      paint.color = const Color(0xFFFF6B00).withOpacity(ringOpacity);
      canvas.drawCircle(Offset(cx, cy), r, paint);

      paint.strokeWidth = 8.0 * (1.0 - ringT);
      paint.maskFilter = null;
      paint.color = Colors.white.withOpacity(ringOpacity * 0.8);
      canvas.drawCircle(Offset(cx, cy), r * 0.88, paint);

      paint.style = PaintingStyle.fill;
    }

    // Phase 3 (0.2..0.8): Central fireball that expands then shrinks
    if (t > 0.2 && t < 0.8) {
      final fT = (t - 0.2) / 0.6;
      final fireRadius = size.width * 0.35 * sin(fT * pi);
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 30 * (1 - fT));
      paint.color = const Color(0xFFFF3300).withOpacity(0.6 * (1 - fT));
      canvas.drawCircle(Offset(cx, cy), fireRadius, paint);
      paint.maskFilter = null;
      paint.color = Colors.white.withOpacity(0.4 * (1 - fT));
      canvas.drawCircle(Offset(cx, cy), fireRadius * 0.5, paint);
    }

    paint.style = PaintingStyle.fill;
    paint.maskFilter = null;
  }

  void _drawTrail(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final t in game.trail) {
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      paint.color = t.color.withOpacity((t.life * 0.7).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(t.x * size.width, t.y * size.height), t.size * t.life, paint);
    }
    paint.maskFilter = null;
  }

  void _drawGhostImages(Canvas canvas, Size size) {
    for (final g in game.ghostImages) {
      final life = g['life'] as double;
      final cx = (g['x'] as double) * size.width;
      final cy = (g['y'] as double) * size.height;
      final r = (g['size'] as double) * 0.9;
      final path = buildSpecterPath(cx, cy, r);
      final paint = Paint()
        ..color = AppTheme.slowColor.withOpacity(life * 0.25)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, paint);
      paint.color = AppTheme.slowColor.withOpacity(life * 0.5);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 1.0;
      canvas.drawPath(path, paint);
    }
  }

  // ── BULLETS ─────────────────────────────────────────────────────────────────

  void _drawBullets(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final b in game.bullets) {
      if (!b.active) continue;
      final cx = b.x * size.width;
      final cy = b.y * size.height;
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      paint.color = b.color.withOpacity(0.5);
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: 6, height: 16), paint);
      paint.maskFilter = null;
      paint.color = Colors.white;
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: 3, height: 9), paint);
      paint.color = b.color;
      canvas.drawCircle(Offset(cx, cy - 4), 2.5, paint);
    }
  }

  // ── OBSTACLES ───────────────────────────────────────────────────────────────

  void _drawObstacles(Canvas canvas, Size size) {
    for (final obs in game.obstacles) {
      if (obs.isFullyDead) continue;
      switch (obs.type) {
        case ObstacleType.laserWall: _drawLaserWall(canvas, size, obs); break;
        case ObstacleType.asteroid:  _drawAsteroid(canvas, size, obs); break;
        case ObstacleType.mine:      _drawMine(canvas, size, obs); break;
        case ObstacleType.sweepBeam: _drawSweepBeam(canvas, size, obs); break;
        case ObstacleType.pulseGate: _drawPulseGate(canvas, size, obs); break;
      }
    }
  }

  // ── LASER WALL (TIER-BASED) ──────────────────────────────────────────────────

  void _drawLaserWall(Canvas canvas, Size size, Obstacle obs) {
    final rect = Rect.fromLTWH(obs.x * size.width, obs.y * size.height,
        obs.width * size.width, obs.height * size.height);
    final paint = Paint();
    final opacity = obs.damageOpacity;
    final tier = obs.wallTier ?? WallTier.standard;
    final td = wallTierData(tier);
    final effectiveColor = Color.lerp(td.color, const Color(0xFF666666), obs.greyShift)!;
    final effectiveGlow = Color.lerp(td.glowColor, const Color(0xFF888888), obs.greyShift)!;

    // Death explosion — specific to tier
    if (obs.isDying) {
      final t = obs.deathTimer;
      // Flash
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 30 * (1 - t));
      paint.color = effectiveColor.withOpacity((1.0 - t) * 0.9);
      canvas.drawRect(rect.inflate(8 * (1 - t)), paint);
      paint.maskFilter = null;

      // Flying debris chunks — more for armored
      final debrisCount = tier == WallTier.armored ? 12 :
                          tier == WallTier.reinforced ? 8 : 4;
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
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: chunkW, height: chunkH), paint);
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
      final lineRect = Rect.fromLTWH(rect.left, rect.top + rect.height * 0.35, rect.width, rect.height * 0.3);
      canvas.drawRect(lineRect, paint);
      paint.maskFilter = null;

      // Hot wire
      paint.color = Colors.white.withOpacity(0.95 * opacity);
      canvas.drawRect(Rect.fromLTWH(rect.left, rect.top + rect.height * 0.44, rect.width, rect.height * 0.12), paint);

      // HP bar — tiny, shows 1/1
      _drawHpBar(canvas, rect, obs, effectiveColor, opacity);
      return;
    }

    // ── STANDARD WALL ──────────────────────────────────────────────────────
    if (tier == WallTier.standard) {
      // Dark housing
      paint.shader = LinearGradient(
        colors: [const Color(0xFF1A1A24), const Color(0xFF0D0D14)],
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
      ).createShader(rect);
      canvas.drawRect(rect, paint);
      paint.shader = null;

      // Damage cracks
      if (obs.damageState != DamageState.healthy) {
        paint.color = Colors.orange.withOpacity(obs.damageState == DamageState.critical ? 0.7 : 0.35);
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
      final innerRect = Rect.fromLTWH(rect.left, rect.top + rect.height * 0.3, rect.width, rect.height * 0.4);
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      paint.color = effectiveColor.withOpacity(0.6 * opacity);
      canvas.drawRect(innerRect, paint);
      paint.maskFilter = null;

      paint.shader = LinearGradient(
        colors: [Colors.white.withOpacity(opacity), effectiveColor.withOpacity(opacity), effectiveColor.withOpacity(0.4 * opacity)],
        stops: const [0.1, 0.5, 1.0],
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
      ).createShader(innerRect);
      canvas.drawRect(innerRect, paint);
      paint.shader = null;

      // Warning nodes
      final nodePhase = (animTick * 4) % (pi * 2);
      paint.color = Colors.white.withOpacity((0.5 + sin(nodePhase) * 0.5) * opacity);
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
        colors: [const Color(0xFF2A1800), const Color(0xFF1A0E00), const Color(0xFF0A0500)],
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
      ).createShader(rect);
      canvas.drawRect(rect, paint);
      paint.shader = null;

      // Orange-hot energy channel
      final channelRect = Rect.fromLTWH(rect.left, rect.top + rect.height * 0.25, rect.width, rect.height * 0.5);
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      paint.color = effectiveColor.withOpacity(0.8 * opacity);
      canvas.drawRect(channelRect, paint);
      paint.maskFilter = null;

      paint.shader = LinearGradient(
        colors: [Colors.white.withOpacity(0.9 * opacity), effectiveColor.withOpacity(opacity), const Color(0xFF441100).withOpacity(opacity)],
        stops: const [0.0, 0.4, 1.0],
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
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
        paint.color = Colors.red.withOpacity(obs.damageState == DamageState.critical ? 0.9 : 0.5);
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
        final rng = Random(obs.hashCode);
        for (int i = 0; i < (obs.damageState == DamageState.critical ? 6 : 3); i++) {
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
      paint.color = const Color(0xFFFF4400).withOpacity((0.4 + sin(warnPhase) * 0.4) * opacity);
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
        colors: [const Color(0xFF1A0025), const Color(0xFF0D0018), const Color(0xFF050008)],
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
      ).createShader(rect);
      canvas.drawRect(rect, paint);
      paint.shader = null;

      // Triple energy channels
      for (int ch = 0; ch < 3; ch++) {
        final yFrac = 0.2 + ch * 0.25;
        final channelR = Rect.fromLTWH(rect.left, rect.top + rect.height * yFrac, rect.width, rect.height * 0.15);
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + ch * 2.0);
        paint.color = effectiveColor.withOpacity((0.5 + ch * 0.15) * opacity);
        canvas.drawRect(channelR, paint);
        paint.maskFilter = null;
        if (ch == 1) {
          // Middle one is white-hot
          paint.color = Colors.white.withOpacity(0.9 * opacity);
          canvas.drawRect(Rect.fromLTWH(rect.left, channelR.top + channelR.height * 0.3, rect.width, channelR.height * 0.4), paint);
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
      for (final corner in [rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight]) {
        final signX = corner == rect.topLeft || corner == rect.bottomLeft ? 1.0 : -1.0;
        final signY = corner == rect.topLeft || corner == rect.topRight ? 1.0 : -1.0;
        paint.style = PaintingStyle.stroke;
        paint.strokeWidth = 2.5;
        canvas.drawLine(corner, corner + Offset(signX * bSize, 0), paint);
        canvas.drawLine(corner, corner + Offset(0, signY * bSize), paint);
        paint.style = PaintingStyle.fill;
      }

      // Ominous pulsing — slow, menacing
      final armorPhase = (animTick * 2) % (pi * 2);
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 12);
      paint.color = effectiveColor.withOpacity((0.3 + sin(armorPhase) * 0.2) * opacity);
      canvas.drawRect(rect.inflate(4), paint);
      paint.maskFilter = null;

      // Critical damage — wall is crumbling
      if (obs.damageState == DamageState.critical) {
        paint.color = Colors.white.withOpacity(0.15 * (0.5 + sin(animTick * 20) * 0.5));
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
        text: TextSpan(text: '⬡ ARMORED', style: TextStyle(
          color: effectiveColor.withOpacity(0.7 * opacity),
          fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 2,
        )),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(rect.left + 4, rect.top + (rect.height - tp.height) / 2));

      _drawHpBar(canvas, rect, obs, effectiveColor, opacity);
    }
  }

  // HP bar drawn below each wall
  void _drawHpBar(Canvas canvas, Rect wallRect, Obstacle obs, Color color, double opacity) {
    if (obs.maxHp <= 1) return; // fragile walls don't need a bar
    final ratio = (obs.hp / obs.maxHp).clamp(0.0, 1.0);
    const barH = 3.0;
    final barY = wallRect.bottom + 2;
    final bgRect = Rect.fromLTWH(wallRect.left, barY, wallRect.width, barH);
    final fillRect = Rect.fromLTWH(wallRect.left, barY, wallRect.width * ratio, barH);

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

  // ── ASTEROID ────────────────────────────────────────────────────────────────

  void _drawAsteroid(Canvas canvas, Size size, Obstacle obs) {
    if (obs.shape.isEmpty) return;
    final cx = (obs.x + obs.width / 2) * size.width;
    final cy = (obs.y + obs.height / 2) * size.height;
    final r = obs.width * size.width * 0.55;
    final paint = Paint();
    final opacity = obs.damageOpacity;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(obs.rotation);

    if (obs.isDying) {
      final t = obs.deathTimer;
      canvas.scale(1.0 + t * 0.8);
    }

    final path = Path();
    for (int i = 0; i < obs.shape.length; i++) {
      final pt = obs.shape[i];
      if (i == 0) path.moveTo(pt.dx * r, pt.dy * r);
      else path.lineTo(pt.dx * r, pt.dy * r);
    }
    path.close();

    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    paint.color = Colors.lightBlueAccent.withOpacity(0.3 * opacity);
    canvas.translate(-2, -2);
    canvas.drawPath(path, paint);
    canvas.translate(2, 2);
    paint.maskFilter = null;

    final baseColor1 = Color.lerp(const Color(0xFF555555), const Color(0xFF888888), obs.greyShift)!;
    final baseColor2 = Color.lerp(const Color(0xFF2A2A2A), const Color(0xFF666666), obs.greyShift)!;
    final baseColor3 = Color.lerp(const Color(0xFF0A0A0A), const Color(0xFF444444), obs.greyShift)!;
    paint.shader = RadialGradient(
      colors: [baseColor1, baseColor2, baseColor3],
      center: const Alignment(-0.4, -0.4), radius: 1.2,
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));
    paint.color = Colors.white.withOpacity(opacity);
    canvas.drawPath(path, paint);
    paint.shader = null;

    if (obs.damageState == DamageState.healthy) {
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2.0;
      paint.color = const Color(0xFF00E5FF).withOpacity(0.8 + sin(animTick * 3) * 0.2);
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      final vein = Path()
        ..moveTo(-r * 0.5, -r * 0.2)..lineTo(-r * 0.1, 0)..lineTo(r * 0.3, -r * 0.3)
        ..moveTo(-r * 0.1, 0)..lineTo(r * 0.2, r * 0.5);
      canvas.drawPath(vein, paint);
      paint.style = PaintingStyle.fill;
      paint.maskFilter = null;
    }

    if (obs.damageState != DamageState.healthy) {
      paint.color = Colors.white.withOpacity(obs.damageState == DamageState.critical ? 0.5 : 0.25);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = obs.damageState == DamageState.critical ? 1.5 : 0.8;
      final rng = Random(obs.shape.length);
      for (int i = 0; i < (obs.damageState == DamageState.critical ? 5 : 2); i++) {
        final a = rng.nextDouble() * 2 * pi;
        final crackPath = Path()
          ..moveTo(cos(a) * r * 0.2, sin(a) * r * 0.2)
          ..lineTo(cos(a + 0.3) * r * 0.8, sin(a + 0.3) * r * 0.8);
        canvas.drawPath(crackPath, paint);
      }
      paint.style = PaintingStyle.fill;
    }

    if (obs.damageState == DamageState.healthy) {
      paint.color = Colors.black.withOpacity(0.6);
      canvas.drawOval(Rect.fromCenter(center: Offset(r * 0.3, r * 0.1), width: r * 0.4, height: r * 0.25), paint);
      paint.color = Colors.white.withOpacity(0.1);
      canvas.drawArc(Rect.fromCenter(center: Offset(r * 0.3, r * 0.1), width: r * 0.4, height: r * 0.25), pi, pi, false, paint);
    }

    canvas.restore();
  }

  // ── MINE ────────────────────────────────────────────────────────────────────

  void _drawMine(Canvas canvas, Size size, Obstacle obs) {
    final cx = (obs.x + obs.width / 2) * size.width;
    final cy = (obs.y + obs.height / 2) * size.height;
    final r = obs.width * size.width * 0.5;
    final pulse = sin(animTick * 8) * 0.3 + 0.7;
    final opacity = obs.damageOpacity;
    final effectiveColor = Color.lerp(obs.color, const Color(0xFF777777), obs.greyShift)!;
    final paint = Paint();

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(obs.rotation * 2);

    if (obs.isDying) {
      final t = obs.deathTimer;
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 20 * (1 - t));
      paint.color = Colors.white.withOpacity(1.0 - t);
      canvas.drawCircle(Offset.zero, r * (1 + t * 3), paint);
      paint.maskFilter = null;
      canvas.restore();
      return;
    }

    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    paint.color = const Color(0xFFFF2200).withOpacity(0.25 * pulse * opacity);
    canvas.drawCircle(Offset.zero, r * 2.0, paint);
    paint.maskFilter = null;

    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    paint.color = effectiveColor.withOpacity(0.6 * pulse * opacity);
    canvas.drawCircle(Offset.zero, r * 1.5, paint);
    paint.maskFilter = null;

    paint.color = effectiveColor.withOpacity(0.4 * opacity);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    for (int i = 0; i < 8; i++) {
      final a = (pi / 4) * i + animTick * 3;
      canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: r * 1.7), a, 0.25, false, paint);
    }
    paint.style = PaintingStyle.fill;

    paint.shader = RadialGradient(
      colors: [const Color(0xFF444455), const Color(0xFF111115)],
      center: const Alignment(-0.3, -0.3),
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));
    canvas.drawCircle(Offset.zero, r, paint);
    paint.shader = null;

    paint.color = Colors.grey.shade400.withOpacity(opacity);
    for (int i = 0; i < 6; i++) {
      canvas.save();
      canvas.rotate((pi / 3) * i);
      final spike = Path()
        ..moveTo(-r * 0.15, r * 0.9)..lineTo(r * 0.15, r * 0.9)..lineTo(0, r * 1.5)..close();
      canvas.drawPath(spike, paint);
      canvas.restore();
    }

    paint.color = const Color(0xFF111111);
    canvas.drawCircle(Offset.zero, r * 0.6, paint);
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    paint.color = effectiveColor.withOpacity(opacity);
    canvas.drawCircle(Offset.zero, r * 0.4 * pulse, paint);
    paint.maskFilter = null;
    paint.color = Colors.white.withOpacity(opacity);
    canvas.drawCircle(Offset.zero, r * 0.15, paint);

    canvas.restore();
  }

  // ── SWEEP BEAM ──────────────────────────────────────────────────────────────

  void _drawSweepBeam(Canvas canvas, Size size, Obstacle obs) {
    if (obs.sweepDone) return;
    final beamY = obs.y * size.height;
    final beamH = obs.height * size.height;
    final paint = Paint();
    final progress = obs.sweepFromLeft ? obs.sweepProgress : (1.0 - obs.sweepProgress);
    final headX = progress * size.width;

    final sweptRect = obs.sweepFromLeft
        ? Rect.fromLTWH(0, beamY, max(0, headX), beamH)
        : Rect.fromLTWH(headX, beamY, size.width - headX, beamH);

    if (sweptRect.width > 0) {
      paint.shader = LinearGradient(
        colors: [const Color(0xFF220000), Colors.transparent],
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
      ).createShader(sweptRect);
      canvas.drawRect(sweptRect, paint);
      paint.shader = null;
      paint.color = obs.color.withOpacity(0.3);
      for (double x = sweptRect.left; x < sweptRect.right; x += 15) {
        if (Random((x * 10).floor()).nextDouble() > 0.5) {
          canvas.drawCircle(Offset(x, beamY + beamH * Random(x.floor()).nextDouble()), 1.5, paint);
        }
      }
    }

    final headRect = Rect.fromLTWH(headX - 30, beamY - 10, 60, beamH + 20);
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    paint.color = obs.color.withOpacity(0.8);
    canvas.drawRect(headRect, paint);
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    paint.color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(headX - 10, beamY, 20, beamH), paint);
    paint.maskFilter = null;

    paint.color = const Color(0xFF222222);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(headX - 15, beamY - 12, 30, 12), const Radius.circular(3)), paint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(headX - 15, beamY + beamH, 30, 12), const Radius.circular(3)), paint);
    paint.color = obs.color;
    canvas.drawRect(Rect.fromLTWH(headX - 8, beamY - 6, 16, 4), paint);

    final tp = TextPainter(
      text: TextSpan(text: 'DANGER', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(headX - tp.width / 2, beamY - 26));
  }

  // ── PULSE GATE ──────────────────────────────────────────────────────────────

  void _drawPulseGate(Canvas canvas, Size size, Obstacle obs) {
    final openness = (sin(obs.pulsePhase) + 1) / 2;
    final gapHalf = obs.gapHalfWidth * openness * size.width;
    final gapCX = obs.gapCenterX * size.width;
    final wallY = obs.y * size.height;
    final wallH = obs.height * 2.5 * size.height;
    final pulse = sin(obs.pulsePhase * 4) * 0.4 + 0.6;
    final paint = Paint();

    void drawGatePillar(Rect rect, bool isLeft) {
      paint.shader = LinearGradient(
        colors: [const Color(0xFF111115), const Color(0xFF333344), const Color(0xFF0A0A0E)],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
      canvas.drawRect(rect, paint);
      paint.shader = null;
      paint.color = Colors.black.withOpacity(0.5);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2;
      canvas.drawRect(rect, paint);
      canvas.drawLine(Offset(rect.left, rect.top + wallH * 0.3), Offset(rect.right, rect.top + wallH * 0.3), paint);
      canvas.drawLine(Offset(rect.left, rect.top + wallH * 0.7), Offset(rect.right, rect.top + wallH * 0.7), paint);
      paint.style = PaintingStyle.fill;

      final edgeX = isLeft ? rect.right - 12 : rect.left;
      final coilRect = Rect.fromLTWH(edgeX, rect.top + 5, 12, rect.height - 10);
      paint.color = const Color(0xFF1A1A1A);
      canvas.drawRect(coilRect, paint);
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      paint.color = obs.color.withOpacity(0.8 * pulse);
      canvas.drawRect(coilRect.deflate(2), paint);
      paint.maskFilter = null;
      paint.color = Colors.white.withOpacity(0.8);
      for (double y = coilRect.top + 4; y < coilRect.bottom; y += 8) {
        canvas.drawRect(Rect.fromLTWH(coilRect.left, y, coilRect.width, 2), paint);
      }
    }

    final leftW = gapCX - gapHalf;
    if (leftW > 0) drawGatePillar(Rect.fromLTWH(0, wallY, leftW, wallH), true);
    final rightStart = gapCX + gapHalf;
    if (rightStart < size.width) drawGatePillar(Rect.fromLTWH(rightStart, wallY, size.width - rightStart, wallH), false);

    if (openness < 0.8) {
      final webIntensity = 1.0 - openness;
      paint.strokeWidth = 2.0;
      paint.style = PaintingStyle.stroke;
      for (int i = 0; i < 4; i++) {
        final yOffset = wallY + (wallH * 0.2 * (i + 1));
        final path = Path()..moveTo(gapCX - gapHalf, yOffset);
        for (double x = gapCX - gapHalf; x <= gapCX + gapHalf; x += 10) {
          final erratic = (Random((x * yOffset).floor()).nextDouble() - 0.5) * 15 * webIntensity;
          path.lineTo(x, yOffset + erratic);
        }
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        paint.color = obs.color.withOpacity(webIntensity * pulse);
        canvas.drawPath(path, paint);
        paint.maskFilter = null;
        paint.color = Colors.white.withOpacity(webIntensity * 0.8);
        canvas.drawPath(path, paint);
      }
      paint.style = PaintingStyle.fill;
    }

    final isOpen = openness > 0.4;
    final textStr = isOpen ? '>>> CLEAR <<<' : '!!! LOCK !!!';
    final textColor = isOpen ? Colors.greenAccent : Colors.redAccent;
    final tp = TextPainter(
      text: TextSpan(text: textStr, style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2)),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(gapCX - tp.width / 2, wallY - 20));
  }

  // ── COINS ────────────────────────────────────────────────────────────────────

  void _drawCoins(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final coin in game.coins) {
      if (coin.collected) continue;
      final cx = coin.x * size.width;
      final cy = coin.y * size.height;
      final pulse = sin(coin.pulsePhase) * 0.15 + 1.0;
      final r = 9.0 * pulse;

      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      paint.color = AppTheme.coinColor.withOpacity(0.35);
      canvas.drawCircle(Offset(cx, cy), r + 5, paint);
      paint.maskFilter = null;

      paint.shader = RadialGradient(
        colors: [const Color(0xFFFFF176), AppTheme.coinColor, const Color(0xFFFF8F00)],
        center: const Alignment(-0.35, -0.35),
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      canvas.drawCircle(Offset(cx, cy), r, paint);
      paint.shader = null;

      paint.color = const Color(0xFFFF8F00).withOpacity(0.5);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 1.5;
      canvas.drawCircle(Offset(cx, cy), r * 0.65, paint);
      paint.style = PaintingStyle.fill;
      paint.color = Colors.white.withOpacity(0.5);
      canvas.drawCircle(Offset(cx - r * 0.28, cy - r * 0.28), r * 0.25, paint);
    }
  }

  // ── POWER-UPS ────────────────────────────────────────────────────────────────

  void _drawPowerUps(Canvas canvas, Size size) {
    for (final pu in game.powerUps) {
      if (pu.collected) continue;
      final cx = pu.x * size.width;
      final cy = pu.y * size.height;
      final pulse = sin(pu.pulsePhase) * 0.2 + 1.0;
      const r = 15.0;

      Color color;
      String label;
      switch (pu.type) {
        case PowerUpType.shield:    color = AppTheme.accentAlt; label = 'SHL'; break;
        case PowerUpType.slowTime:  color = AppTheme.slowColor; label = 'SLW'; break;
        case PowerUpType.extraLife: color = AppTheme.danger;    label = '♥';   break;
      }

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(pu.pulsePhase * 0.5);

      final paint = Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14)
        ..color = color.withOpacity(0.4);
      canvas.drawCircle(Offset.zero, r * pulse + 6, paint);
      paint.maskFilter = null;

      final path = Path();
      for (int i = 0; i < 6; i++) {
        final angle = (pi / 3 * i) - pi / 6;
        if (i == 0) path.moveTo(cos(angle) * r * pulse, sin(angle) * r * pulse);
        else path.lineTo(cos(angle) * r * pulse, sin(angle) * r * pulse);
      }
      path.close();
      paint.color = color.withOpacity(0.2);
      canvas.drawPath(path, paint);
      paint.color = color.withOpacity(0.9);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2;
      canvas.drawPath(path, paint);
      paint.style = PaintingStyle.fill;
      canvas.restore();

      final tp = TextPainter(
        text: TextSpan(text: label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    }
  }

  // ── TREASURE CHESTS — BIGGER & JUICIER ──────────────────────────────────────

  void _drawChests(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final chest in game.chests) {
      if (chest.collected) continue;
      final cx = chest.x * size.width;
      final cy = chest.y * size.height;
      final pulse = sin(chest.pulsePhase) * 0.12 + 1.0;
      final float = sin(chest.pulsePhase * 0.8) * 4.0;
      final isBomb = chest.reward == TreasureReward.bomb;

      Color chestColor;
      String rewardLabel;
      switch (chest.reward) {
        case TreasureReward.slowTime:  chestColor = AppTheme.slowColor;  rewardLabel = '⏱'; break;
        case TreasureReward.extraLife: chestColor = AppTheme.danger;     rewardLabel = '♥'; break;
        case TreasureReward.coins:     chestColor = AppTheme.coinColor;  rewardLabel = '✦${chest.coinAmount}'; break;
        case TreasureReward.shield:    chestColor = AppTheme.accentAlt;  rewardLabel = '◉'; break;
        case TreasureReward.bomb:      chestColor = const Color(0xFFFF6B00); rewardLabel = '💥'; break;
      }

      canvas.save();
      canvas.translate(cx, cy + float);

      // Outer glow — bigger than before (40x30 base)
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, isBomb ? 24 : 18);
      paint.color = chestColor.withOpacity(isBomb ? 0.7 : 0.5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 44 * pulse, height: 36 * pulse), const Radius.circular(6)),
        paint,
      );
      paint.maskFilter = null;

      // Chest body (40x24)
      paint.shader = LinearGradient(
        colors: isBomb
            ? [const Color(0xFF3A1500), const Color(0xFF1A0800), const Color(0xFF0A0400)]
            : [const Color(0xFF8B6914), const Color(0xFF5C4409), const Color(0xFF3A2A05)],
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
      ).createShader(Rect.fromCenter(center: const Offset(0, 3), width: 40, height: 24));
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, 3), width: 40, height: 22), const Radius.circular(4)),
        paint,
      );
      paint.shader = null;

      // Chest lid (40x14)
      paint.shader = LinearGradient(
        colors: isBomb
            ? [const Color(0xFF5A2200), const Color(0xFF3A1400)]
            : [const Color(0xFFB8860B), const Color(0xFF8B6914)],
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
      ).createShader(Rect.fromCenter(center: const Offset(0, -9), width: 40, height: 14));
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, -9), width: 40, height: 12), const Radius.circular(4)),
        paint,
      );
      paint.shader = null;

      // Metal band
      paint.color = isBomb ? chestColor.withOpacity(0.8) : const Color(0xFFD4AF37);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2.0;
      canvas.drawLine(const Offset(-20, -3), const Offset(20, -3), paint);

      // Corner bands
      paint.strokeWidth = 1.5;
      paint.color = isBomb ? chestColor.withOpacity(0.6) : const Color(0xFFD4AF37).withOpacity(0.7);
      canvas.drawLine(const Offset(-20, -14), const Offset(-20, 14), paint);
      canvas.drawLine(const Offset(20, -14), const Offset(20, 14), paint);
      canvas.drawLine(const Offset(0, -14), const Offset(0, 14), paint);

      // Padlock / gem
      paint.style = PaintingStyle.fill;
      paint.color = chestColor;
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, isBomb ? 8 : 4);
      canvas.drawCircle(Offset.zero, 5.5 * pulse, paint);
      paint.maskFilter = null;
      paint.color = Colors.white.withOpacity(0.95);
      canvas.drawCircle(Offset.zero, 3.0, paint);

      // Radiating glow lines
      paint.color = chestColor.withOpacity(0.5);
      paint.strokeWidth = 0.8;
      paint.style = PaintingStyle.stroke;
      for (int i = 0; i < 8; i++) {
        final a = (pi / 4 * i) + chest.pulsePhase * 0.5;
        canvas.drawLine(
            Offset(cos(a) * 8, sin(a) * 8),
            Offset(cos(a) * (18 + pulse * 4), sin(a) * (18 + pulse * 4)),
            paint);
      }
      paint.style = PaintingStyle.fill;

      // Bomb chest: extra danger markings
      if (isBomb) {
        paint.color = chestColor.withOpacity(0.6);
        paint.style = PaintingStyle.stroke;
        paint.strokeWidth = 1.0;
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: 44 * pulse, height: 36 * pulse), paint);
        paint.style = PaintingStyle.fill;
      }

      canvas.restore();

      // Reward label — below chest, bigger font
      final tp = TextPainter(
        text: TextSpan(text: rewardLabel, style: TextStyle(
          color: chestColor,
          fontSize: chest.reward == TreasureReward.coins ? 9 : 12,
          fontWeight: FontWeight.w900,
        )),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy + float + 20));

      // "RARE" tag for bomb chests
      if (isBomb) {
        final rareTp = TextPainter(
          text: TextSpan(text: 'RARE', style: TextStyle(
            color: chestColor.withOpacity(0.8),
            fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 2,
          )),
          textDirection: TextDirection.ltr,
        );
        rareTp.layout();
        rareTp.paint(canvas, Offset(cx - rareTp.width / 2, cy + float + 34));
      }
    }
  }

  // ── PARTICLES ────────────────────────────────────────────────────────────────

  void _drawParticles(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in game.particles) {
      final life = p['life'] as double;
      final isDebris = p['isDebris'] as bool? ?? false;
      final pSize = (p['size'] as double) * life;

      if (isDebris) {
        // Draw debris as rectangles
        paint.maskFilter = null;
        paint.color = (p['color'] as Color).withOpacity(life.clamp(0.0, 1.0));
        canvas.save();
        canvas.translate((p['x'] as double) * size.width, (p['y'] as double) * size.height);
        canvas.rotate(life * 8);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: pSize, height: pSize * 0.4), paint);
        canvas.restore();
      } else {
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
        paint.color = (p['color'] as Color).withOpacity(life.clamp(0.0, 1.0));
        canvas.drawCircle(
            Offset((p['x'] as double) * size.width, (p['y'] as double) * size.height),
            pSize, paint);
      }
    }
    paint.maskFilter = null;
  }

  // ── SHIP ─────────────────────────────────────────────────────────────────────

  void _drawShip(Canvas canvas, Size size) {
    final p = game.player;
    final cx = p.x * size.width;
    final cy = p.y * size.height;
    final r = p.size.toDouble() * 1.2;
    final color = p.color;
    final lean = p.velocityX * 80;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.skew(lean * 0.02, 0);

    if (game.state.isShieldActive) {
      final sp = sin(animTick * 6) * 0.2 + 0.8;
      final shP = Paint()
        ..shader = RadialGradient(
          colors: [AppTheme.accentAlt.withOpacity(0.0), AppTheme.accentAlt.withOpacity(0.2 * sp), AppTheme.accentAlt.withOpacity(0.8 * sp)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r + 18));
      canvas.drawCircle(Offset.zero, r + 18, shP);
      shP.shader = null;
      shP.color = Colors.white.withOpacity(0.4 * sp);
      shP.style = PaintingStyle.stroke;
      shP.strokeWidth = 2.0;
      canvas.drawCircle(Offset.zero, r + 16, shP);
    }

    switch (p.skin) {
      case SkinType.phantom: drawPhantomShip(canvas, r, color, animTick); break;
      case SkinType.nova:    drawNovaShip(canvas, r, color, animTick); break;
      case SkinType.inferno: drawInfernoShip(canvas, r, color, animTick); break;
      case SkinType.specter: drawSpecterShip(canvas, r, color, animTick); break;
      case SkinType.titan:   drawTitanShip(canvas, r, color, animTick); break;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(GamePainter old) => true;
}
