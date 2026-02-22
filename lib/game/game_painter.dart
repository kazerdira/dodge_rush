import 'package:flutter/material.dart';
import 'dart:math';
import '../models/game_models.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import 'painters/wall_painter.dart';
import 'painters/chest_painter.dart';
import 'painters/gate_painter.dart';
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
    drawChests(canvas, size, game.chests);
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
    canvas.drawCircle(
        Offset(size.width * 0.18, size.height * 0.35), 170, paint);
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
      if (star.layer == 2)
        opacity = star.opacity * (0.7 + sin(animTick * 3 + star.x * 10) * 0.3);
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
        canvas.drawCircle(Offset(star.x * size.width, star.y * size.height),
            star.size, paint);
      }
    }
  }

  void _drawSpeedLines(Canvas canvas, Size size) {
    final sp = (game.state.speed - 1.0) / 2.0;
    if (sp <= 0.05) return;
    final paint = Paint()
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    final rng = Random(42);
    for (int side = 0; side < 2; side++) {
      for (int i = 0; i < 8; i++) {
        final x = side == 0
            ? rng.nextDouble() * size.width * 0.12
            : size.width - rng.nextDouble() * size.width * 0.12;
        final y = (rng.nextDouble() * size.height +
                animTick * 180 * game.state.speed) %
            size.height;
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
      canvas.drawCircle(
          Offset(sw.x * size.width, sw.y * size.height), r, paint);
      paint.maskFilter = null;
      // Inner bright ring
      paint.strokeWidth = 1.5 * sw.life;
      paint.color = Colors.white.withOpacity(opacity * 0.6);
      canvas.drawCircle(
          Offset(sw.x * size.width, sw.y * size.height), r * 0.7, paint);
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
      final maxRadius =
          sqrt(size.width * size.width + size.height * size.height);
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
      canvas.drawCircle(
          Offset(t.x * size.width, t.y * size.height), t.size * t.life, paint);
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
      canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, cy), width: 6, height: 16), paint);
      paint.maskFilter = null;
      paint.color = Colors.white;
      canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, cy), width: 3, height: 9), paint);
      paint.color = b.color;
      canvas.drawCircle(Offset(cx, cy - 4), 2.5, paint);
    }
  }

  // ── OBSTACLES ───────────────────────────────────────────────────────────────

  void _drawObstacles(Canvas canvas, Size size) {
    for (final obs in game.obstacles) {
      if (obs.isFullyDead) continue;
      switch (obs.type) {
        case ObstacleType.laserWall:
          drawLaserWall(canvas, size, obs, animTick);
          break;
        case ObstacleType.asteroid:
          _drawAsteroid(canvas, size, obs);
          break;
        case ObstacleType.mine:
          _drawMine(canvas, size, obs);
          break;
        case ObstacleType.sweepBeam:
          _drawSweepBeam(canvas, size, obs);
          break;
        case ObstacleType.pulseGate:
          drawPulseGate(canvas, size, obs);
          break;
      }
    }
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
      if (i == 0)
        path.moveTo(pt.dx * r, pt.dy * r);
      else
        path.lineTo(pt.dx * r, pt.dy * r);
    }
    path.close();

    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    paint.color = Colors.lightBlueAccent.withOpacity(0.3 * opacity);
    canvas.translate(-2, -2);
    canvas.drawPath(path, paint);
    canvas.translate(2, 2);
    paint.maskFilter = null;

    final baseColor1 = Color.lerp(
        const Color(0xFF555555), const Color(0xFF888888), obs.greyShift)!;
    final baseColor2 = Color.lerp(
        const Color(0xFF2A2A2A), const Color(0xFF666666), obs.greyShift)!;
    final baseColor3 = Color.lerp(
        const Color(0xFF0A0A0A), const Color(0xFF444444), obs.greyShift)!;
    paint.shader = RadialGradient(
      colors: [baseColor1, baseColor2, baseColor3],
      center: const Alignment(-0.4, -0.4),
      radius: 1.2,
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));
    paint.color = Colors.white.withOpacity(opacity);
    canvas.drawPath(path, paint);
    paint.shader = null;

    if (obs.damageState == DamageState.healthy) {
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2.0;
      paint.color =
          const Color(0xFF00E5FF).withOpacity(0.8 + sin(animTick * 3) * 0.2);
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      final vein = Path()
        ..moveTo(-r * 0.5, -r * 0.2)
        ..lineTo(-r * 0.1, 0)
        ..lineTo(r * 0.3, -r * 0.3)
        ..moveTo(-r * 0.1, 0)
        ..lineTo(r * 0.2, r * 0.5);
      canvas.drawPath(vein, paint);
      paint.style = PaintingStyle.fill;
      paint.maskFilter = null;
    }

    if (obs.damageState != DamageState.healthy) {
      paint.color = Colors.white
          .withOpacity(obs.damageState == DamageState.critical ? 0.5 : 0.25);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = obs.damageState == DamageState.critical ? 1.5 : 0.8;
      final rng = Random(obs.shape.length);
      for (int i = 0;
          i < (obs.damageState == DamageState.critical ? 5 : 2);
          i++) {
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
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(r * 0.3, r * 0.1),
              width: r * 0.4,
              height: r * 0.25),
          paint);
      paint.color = Colors.white.withOpacity(0.1);
      canvas.drawArc(
          Rect.fromCenter(
              center: Offset(r * 0.3, r * 0.1),
              width: r * 0.4,
              height: r * 0.25),
          pi,
          pi,
          false,
          paint);
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
    final effectiveColor =
        Color.lerp(obs.color, const Color(0xFF777777), obs.greyShift)!;
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
      canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: r * 1.7), a,
          0.25, false, paint);
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
        ..moveTo(-r * 0.15, r * 0.9)
        ..lineTo(r * 0.15, r * 0.9)
        ..lineTo(0, r * 1.5)
        ..close();
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
    final progress =
        obs.sweepFromLeft ? obs.sweepProgress : (1.0 - obs.sweepProgress);
    final headX = progress * size.width;

    final sweptRect = obs.sweepFromLeft
        ? Rect.fromLTWH(0, beamY, max(0, headX), beamH)
        : Rect.fromLTWH(headX, beamY, size.width - headX, beamH);

    if (sweptRect.width > 0) {
      paint.shader = LinearGradient(
        colors: [const Color(0xFF220000), Colors.transparent],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(sweptRect);
      canvas.drawRect(sweptRect, paint);
      paint.shader = null;
      paint.color = obs.color.withOpacity(0.3);
      for (double x = sweptRect.left; x < sweptRect.right; x += 15) {
        if (Random((x * 10).floor()).nextDouble() > 0.5) {
          canvas.drawCircle(
              Offset(x, beamY + beamH * Random(x.floor()).nextDouble()),
              1.5,
              paint);
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
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(headX - 15, beamY - 12, 30, 12),
            const Radius.circular(3)),
        paint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(headX - 15, beamY + beamH, 30, 12),
            const Radius.circular(3)),
        paint);
    paint.color = obs.color;
    canvas.drawRect(Rect.fromLTWH(headX - 8, beamY - 6, 16, 4), paint);

    final tp = TextPainter(
      text: TextSpan(
          text: 'DANGER',
          style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2)),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(headX - tp.width / 2, beamY - 26));
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
        colors: [
          const Color(0xFFFFF176),
          AppTheme.coinColor,
          const Color(0xFFFF8F00)
        ],
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
        case PowerUpType.shield:
          color = AppTheme.accentAlt;
          label = 'SHL';
          break;
        case PowerUpType.slowTime:
          color = AppTheme.slowColor;
          label = 'SLW';
          break;
        case PowerUpType.extraLife:
          color = AppTheme.danger;
          label = '♥';
          break;
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
        if (i == 0)
          path.moveTo(cos(angle) * r * pulse, sin(angle) * r * pulse);
        else
          path.lineTo(cos(angle) * r * pulse, sin(angle) * r * pulse);
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
        text: TextSpan(
            text: label,
            style: TextStyle(
                color: color,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5)),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
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
        canvas.translate(
            (p['x'] as double) * size.width, (p['y'] as double) * size.height);
        canvas.rotate(life * 8);
        canvas.drawRect(
            Rect.fromCenter(
                center: Offset.zero, width: pSize, height: pSize * 0.4),
            paint);
        canvas.restore();
      } else {
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
        paint.color = (p['color'] as Color).withOpacity(life.clamp(0.0, 1.0));
        canvas.drawCircle(
            Offset((p['x'] as double) * size.width,
                (p['y'] as double) * size.height),
            pSize,
            paint);
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
          colors: [
            AppTheme.accentAlt.withOpacity(0.0),
            AppTheme.accentAlt.withOpacity(0.2 * sp),
            AppTheme.accentAlt.withOpacity(0.8 * sp)
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r + 18));
      canvas.drawCircle(Offset.zero, r + 18, shP);
      shP.shader = null;
      shP.color = Colors.white.withOpacity(0.4 * sp);
      shP.style = PaintingStyle.stroke;
      shP.strokeWidth = 2.0;
      canvas.drawCircle(Offset.zero, r + 16, shP);
    }

    switch (p.skin) {
      case SkinType.phantom:
        drawPhantomShip(canvas, r, color, animTick);
        break;
      case SkinType.nova:
        drawNovaShip(canvas, r, color, animTick);
        break;
      case SkinType.inferno:
        drawInfernoShip(canvas, r, color, animTick);
        break;
      case SkinType.specter:
        drawSpecterShip(canvas, r, color, animTick);
        break;
      case SkinType.titan:
        drawTitanShip(canvas, r, color, animTick);
        break;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(GamePainter old) => true;
}
