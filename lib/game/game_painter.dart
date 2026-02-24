import 'package:flutter/material.dart';
import 'dart:math';
import '../models/game_models.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import '../utils/safe_color.dart';
import 'painters/wall_painter.dart';
import 'painters/chest_painter.dart';
import 'painters/gate_painter.dart';
import 'painters/mine_painter.dart';
import 'painters/bullet_painter.dart';
import 'painters/boss_painter.dart' as boss_p;
import 'painters/overlay_painter.dart' as overlay_p;
import 'painter_registry.dart';
import 'ships/ships.dart';

class GamePainter extends CustomPainter {
  final GameProvider game;
  final double animTick;

  static bool _paintersRegistered = false;

  GamePainter(this.game, this.animTick) {
    if (!_paintersRegistered) {
      _registerPainters();
      _paintersRegistered = true;
    }
  }

  static void _registerPainters() {
    final reg = PainterRegistry.instance;
    reg.register('laserWall', (canvas, size, entity, tick) {
      drawLaserWall(canvas, size, entity as LaserWallEntity, tick);
    });
    reg.register('asteroid', (canvas, size, entity, tick) {
      _drawAsteroidStatic(canvas, size, entity as AsteroidEntity, tick);
    });
    reg.register('mine', (canvas, size, entity, tick) {
      drawMine(canvas, size, entity as MineEntity, tick);
    });
    reg.register('sweepBeam', (canvas, size, entity, tick) {
      _drawSweepBeamStatic(canvas, size, entity as SweepBeamEntity);
    });
    reg.register('pulseGate', (canvas, size, entity, tick) {
      drawPulseGate(canvas, size, entity as PulseGateEntity);
    });
  }

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
    drawBullets(canvas, size, game.bullets);
    _drawParticles(canvas, size);
    _drawBombEffect(canvas, size);
    boss_p.drawBossMissiles(canvas, size, game);
    boss_p.drawBossShip(canvas, size, game, animTick, _drawText);
    _drawShip(canvas, size);
    overlay_p.drawRampageOverlay(canvas, size, game, _drawText);
    overlay_p.drawGauntletOverlay(canvas, size, game, _drawText);
    // Overlay effects — drawn last so they sit on top of everything
    overlay_p.drawDangerVignette(canvas, size, game, animTick);
    overlay_p.drawSweepWarning(canvas, size, game);
    overlay_p.drawNearMissFlash(canvas, size, game, _drawText);
    overlay_p.drawComboFlash(canvas, size, game);
  }

  void _drawSpaceBackground(Canvas canvas, Size size) {
    // Sector-tinted background for stronger sector identity
    final pal = game.palette;
    final sectorTint = pal.nebulaColor;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [AppTheme.bg, Color.lerp(AppTheme.bg, sectorTint, 0.15)!],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    paint.shader = null;
  }

  void _drawNebula(Canvas canvas, Size size) {
    // NO blur(80) — RadialGradient is identical visually, costs nothing on GPU
    final t = animTick * 0.12;
    final pal = game.palette;
    final intensity = 0.18 + (game.state.sector - 1) * 0.04;
    final paint = Paint()..style = PaintingStyle.fill;
    void neb(Offset center, double radius, Color col, double op) {
      paint.shader = RadialGradient(
        colors: [col.o(op), col.o(op * 0.35), Colors.transparent],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
      paint.shader = null;
    }

    neb(Offset(size.width * 0.18, size.height * 0.35), 220, pal.nebulaColor,
        intensity + sin(t) * 0.04);
    neb(Offset(size.width * 0.82, size.height * 0.6), 200, pal.accentA,
        0.12 + cos(t * 0.8) * 0.04);
    neb(Offset(size.width * 0.5, size.height * 0.12), 180, pal.accentB,
        0.09 + sin(t * 1.3) * 0.03);
  }

  void _drawStars(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final star in game.stars) {
      double opacity = star.opacity;
      if (star.layer == 2)
        opacity = star.opacity * (0.7 + sin(animTick * 3 + star.x * 10) * 0.3);
      paint.color = Colors.white.o(opacity.clamp(0.0, 1.0));
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
    final sp = (game.state.speed - 1.0) / 1.8;
    if (sp <= 0.03) return;
    final paint = Paint()..style = PaintingStyle.stroke;
    final rng = _speedRng;
    final lineColor = game.palette.accentA;
    // More lines + longer at higher speed — dramatic warp effect
    final lineCount = (6 + sp * 14).round();
    final maxLen = 20.0 + sp * 120.0;
    for (int side = 0; side < 2; side++) {
      for (int i = 0; i < lineCount; i++) {
        final xBand = side == 0
            ? rng.nextDouble() * size.width * 0.18
            : size.width - rng.nextDouble() * size.width * 0.18;
        final y = (rng.nextDouble() * size.height +
                animTick * 200 * game.state.speed) %
            size.height;
        final len = (8.0 + rng.nextDouble() * maxLen);
        final lineOpacity = (0.04 + sp * 0.13) * (0.5 + rng.nextDouble() * 0.5);
        paint.strokeWidth = 0.5 + sp * 1.2;
        paint.color = lineColor.o(lineOpacity.clamp(0.0, 0.55));
        canvas.drawLine(Offset(xBand, y), Offset(xBand, y + len), paint);
      }
    }
    // At very high speed (sector 4+): full-width streaks across center
    if (sp > 0.7) {
      final centerRng = _centerRng;
      for (int i = 0; i < 3; i++) {
        final y = (centerRng.nextDouble() * size.height + animTick * 300) %
            size.height;
        paint.strokeWidth = 0.3;
        paint.color = Colors.white.o(0.04 * (sp - 0.7));
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }
  }

  void _drawShockwaves(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke;
    // NO blur — three rings at different widths/opacities = identical glow
    for (final sw in game.shockwaves) {
      final cx = sw.x * size.width;
      final cy = sw.y * size.height;
      final r = sw.radius * size.width;
      paint.strokeWidth = 8.0 * sw.life;
      paint.color = sw.color.o(sw.life * 0.20);
      canvas.drawCircle(Offset(cx, cy), r * 1.12, paint);
      paint.strokeWidth = 3.5 * sw.life;
      paint.color = sw.color.o(sw.life * 0.75);
      canvas.drawCircle(Offset(cx, cy), r, paint);
      paint.strokeWidth = 1.5 * sw.life;
      paint.color = Colors.white.o(sw.life * 0.55);
      canvas.drawCircle(Offset(cx, cy), r * 0.72, paint);
    }
    paint.style = PaintingStyle.fill;
  }

  void _drawBombEffect(Canvas canvas, Size size) {
    final bomb = game.activeBomb;
    if (bomb == null) return;
    final t = bomb.detonationTimer;
    final cx = bomb.x * size.width;
    final cy = bomb.y * size.height;
    final paint = Paint()..style = PaintingStyle.fill;

    if (t < 0.3) {
      final flashT = t / 0.3;
      paint.color = Colors.white.o((1.0 - flashT) * 0.95);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    }

    if (t > 0.05) {
      final ringT = ((t - 0.05) / 0.95).clamp(0.0, 1.0);
      final maxRadius =
          sqrt(size.width * size.width + size.height * size.height);
      final r = ringT * maxRadius;
      final ringOpacity = (1.0 - ringT) * 0.7;
      paint.style = PaintingStyle.stroke;
      // NO blur — three rings replicate the shockwave glow
      paint.strokeWidth = 26.0 * (1.0 - ringT);
      paint.color = const Color(0xFFFF6B00).o(ringOpacity * 0.25);
      canvas.drawCircle(Offset(cx, cy), r * 1.06, paint);
      paint.strokeWidth = 14.0 * (1.0 - ringT);
      paint.color = const Color(0xFFFF6B00).o(ringOpacity);
      canvas.drawCircle(Offset(cx, cy), r, paint);
      paint.strokeWidth = 5.0 * (1.0 - ringT);
      paint.color = Colors.white.o(ringOpacity * 0.85);
      canvas.drawCircle(Offset(cx, cy), r * 0.88, paint);
      paint.style = PaintingStyle.fill;
    }

    if (t > 0.2 && t < 0.8) {
      final fT = (t - 0.2) / 0.6;
      final fireRadius = size.width * 0.35 * sin(fT * pi);
      // NO blur — layered circles recreate fireball volume
      final fade = 1.0 - fT;
      paint.color = const Color(0xFFFF6B00).o(0.12 * fade);
      canvas.drawCircle(Offset(cx, cy), fireRadius * 1.5, paint);
      paint.color = const Color(0xFFFF3300).o(0.50 * fade);
      canvas.drawCircle(Offset(cx, cy), fireRadius, paint);
      paint.color = Colors.white.o(0.38 * fade);
      canvas.drawCircle(Offset(cx, cy), fireRadius * 0.48, paint);
    }

    paint.style = PaintingStyle.fill;
  }

  void _drawTrail(Canvas canvas, Size size) {
    // NO blur per point — large dim outer + small bright core = identical glow
    final paint = Paint()..style = PaintingStyle.fill;
    for (final t in game.trail) {
      final cx = t.x * size.width;
      final cy = t.y * size.height;
      final r = t.size * t.life;
      paint.color = t.color.o((t.life * 0.20).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(cx, cy), r * 1.9, paint);
      paint.color = t.color.o((t.life * 0.80).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  void _drawGhostImages(Canvas canvas, Size size) {
    for (final g in game.ghostImages) {
      final cx = g.x * size.width;
      final cy = g.y * size.height;
      final r = g.size * 0.9;
      final path = buildSpecterPath(cx, cy, r);
      final paint = Paint()
        ..color = AppTheme.slowColor.o(g.life * 0.25)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, paint);
      paint.color = AppTheme.slowColor.o(g.life * 0.5);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 1.0;
      canvas.drawPath(path, paint);
    }
  }

  void _drawObstacles(Canvas canvas, Size size) {
    final reg = PainterRegistry.instance;
    for (final obs in game.obstacles) {
      if (obs.isFullyDead) continue;
      reg.paint(canvas, size, obs, animTick);
    }
  }

  static void _drawAsteroidStatic(
      Canvas canvas, Size size, AsteroidEntity obs, double animTick) {
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

    // NO blur — offset shadow path
    paint.color = Colors.lightBlueAccent.o(0.18 * opacity);
    canvas.translate(-2, -2);
    canvas.drawPath(path, paint);
    canvas.translate(2, 2);

    final baseColor1 = Color.lerp(
        const Color(0xFF555555), const Color(0xFF888888), obs.greyShift)!;
    final baseColor2 = Color.lerp(
        const Color(0xFF2A2A2A), const Color(0xFF666666), obs.greyShift)!;
    final baseColor3 = Color.lerp(
        const Color(0xFF0A0A0A), const Color(0xFF444444), obs.greyShift)!;
    paint.shader = RadialGradient(
            colors: [baseColor1, baseColor2, baseColor3],
            center: const Alignment(-0.4, -0.4),
            radius: 1.2)
        .createShader(Rect.fromCircle(center: Offset.zero, radius: r));
    paint.color = Colors.white.o(opacity);
    canvas.drawPath(path, paint);
    paint.shader = null;

    if (obs.damageState == DamageState.healthy) {
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2.0;
      // NO blur on vein — bright stroke reads fine without it
      paint.color = const Color(0xFF00E5FF)
          .o((0.85 + sin(animTick * 3) * 0.15).clamp(0.0, 0.9999));
      final vein = Path()
        ..moveTo(-r * 0.5, -r * 0.2)
        ..lineTo(-r * 0.1, 0)
        ..lineTo(r * 0.3, -r * 0.3)
        ..moveTo(-r * 0.1, 0)
        ..lineTo(r * 0.2, r * 0.5);
      canvas.drawPath(vein, paint);
      paint.style = PaintingStyle.fill;
    }

    if (obs.damageState != DamageState.healthy) {
      paint.color =
          Colors.white.o(obs.damageState == DamageState.critical ? 0.5 : 0.25);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = obs.damageState == DamageState.critical ? 1.5 : 0.8;
      final rng = Random(obs.shape.length);
      for (int i = 0;
          i < (obs.damageState == DamageState.critical ? 5 : 2);
          i++) {
        final a = rng.nextDouble() * 2 * pi;
        canvas.drawPath(
            Path()
              ..moveTo(cos(a) * r * 0.2, sin(a) * r * 0.2)
              ..lineTo(cos(a + 0.3) * r * 0.8, sin(a + 0.3) * r * 0.8),
            paint);
      }
      paint.style = PaintingStyle.fill;
    }

    if (obs.damageState == DamageState.healthy) {
      paint.color = Colors.black.o(0.6);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(r * 0.3, r * 0.1),
              width: r * 0.4,
              height: r * 0.25),
          paint);
      paint.color = Colors.white.o(0.1);
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

  static void _drawSweepBeamStatic(
      Canvas canvas, Size size, SweepBeamEntity obs) {
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
              end: Alignment.bottomCenter)
          .createShader(sweptRect);
      canvas.drawRect(sweptRect, paint);
      paint.shader = null;
      // NO Random() loop — 6 fixed sparks, deterministic, zero allocation
      paint.color = obs.color.o(0.38);
      for (int di = 0; di < 6; di++) {
        final dx = sweptRect.left + sweptRect.width * (0.05 + di * 0.17);
        canvas.drawCircle(
            Offset(dx, beamY + beamH * (0.2 + (di % 3) * 0.3)), 1.5, paint);
      }
    }

    // NO blur on sweep head — layered rects of decreasing opacity
    paint.color = obs.color.o(0.10);
    canvas.drawRect(
        Rect.fromLTWH(headX - 55, beamY - 18, 110, beamH + 36), paint);
    paint.color = obs.color.o(0.38);
    canvas.drawRect(
        Rect.fromLTWH(headX - 24, beamY - 7, 48, beamH + 14), paint);
    paint.color = obs.color.o(0.90);
    canvas.drawRect(Rect.fromLTWH(headX - 10, beamY, 20, beamH), paint);
    paint.color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(headX - 4, beamY + 1, 8, beamH - 2), paint);
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
          style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              fontFamily: 'Courier')),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(headX - tp.width / 2, beamY - 26 - tp.height / 2));
  }

  void _drawCoins(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final coin in game.coins) {
      if (coin.collected) continue;
      final cx = coin.x * size.width;
      final cy = coin.y * size.height;
      final pulse = sin(coin.pulsePhase) * 0.15 + 1.0;
      final r = 9.0 * pulse;
      // NO blur — three dim rings create the gold glow
      paint.color = AppTheme.coinColor.o(0.08);
      canvas.drawCircle(Offset(cx, cy), r + 15, paint);
      paint.color = AppTheme.coinColor.o(0.18);
      canvas.drawCircle(Offset(cx, cy), r + 7, paint);
      paint.color = AppTheme.coinColor.o(0.30);
      canvas.drawCircle(Offset(cx, cy), r + 2, paint);
      paint.shader = RadialGradient(colors: [
        const Color(0xFFFFF176),
        AppTheme.coinColor,
        const Color(0xFFFF8F00)
      ], center: const Alignment(-0.35, -0.35))
          .createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      canvas.drawCircle(Offset(cx, cy), r, paint);
      paint.shader = null;
      paint.color = const Color(0xFFFF8F00).o(0.5);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 1.5;
      canvas.drawCircle(Offset(cx, cy), r * 0.65, paint);
      paint.style = PaintingStyle.fill;
      paint.color = Colors.white.o(0.5);
      canvas.drawCircle(Offset(cx - r * 0.28, cy - r * 0.28), r * 0.25, paint);
    }
  }

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
        case PowerUpType.extraLife:
          color = AppTheme.danger;
          label = '♥';
          break;
      }
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(pu.pulsePhase * 0.5);
      final paint = Paint()..style = PaintingStyle.fill;
      // NO blur — three concentric dim circles = powerup glow
      paint.color = color.o(0.07);
      canvas.drawCircle(Offset.zero, r * pulse + 20, paint);
      paint.color = color.o(0.17);
      canvas.drawCircle(Offset.zero, r * pulse + 10, paint);
      paint.color = color.o(0.30);
      canvas.drawCircle(Offset.zero, r * pulse + 4, paint);
      final path = Path();
      for (int i = 0; i < 6; i++) {
        final angle = (pi / 3 * i) - pi / 6;
        if (i == 0)
          path.moveTo(cos(angle) * r * pulse, sin(angle) * r * pulse);
        else
          path.lineTo(cos(angle) * r * pulse, sin(angle) * r * pulse);
      }
      path.close();
      paint.color = color.o(0.2);
      canvas.drawPath(path, paint);
      paint.color = color.o(0.9);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2;
      canvas.drawPath(path, paint);
      paint.style = PaintingStyle.fill;
      canvas.restore();
      _drawText(canvas, label, Offset(cx, cy), color, 8,
          letterSpacing: 0.5, centered: true);
    }
  }

  void _drawParticles(Canvas canvas, Size size) {
    // ── SHAPE-AWARE PARTICLE RENDERER ────────────────────────────────────────
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in game.particles) {
      if (p.life <= 0) continue;
      final col = p.color;
      final pSize = p.size * p.life;
      final px = p.x * size.width;
      final py = p.y * size.height;

      switch (p.shape) {
        // ── DOT ────────────────────────────────────────────────────────────
        case ParticleShape.dot:
          paint.color = col.o((p.life * 0.16).clamp(0.0, 1.0));
          canvas.drawCircle(Offset(px, py), pSize * 1.9, paint);
          paint.color = col.o(p.life.clamp(0.0, 1.0));
          canvas.drawCircle(Offset(px, py), pSize, paint);
          break;

        // ── SPARK: tiny bright needle, fades quickly ───────────────────────
        case ParticleShape.spark:
          paint.color = Colors.white.o(p.life.clamp(0.0, 1.0));
          canvas.drawCircle(
              Offset(px, py), (pSize * 0.9).clamp(0.4, 3.2), paint);
          paint.color = col.o((p.life * 0.6).clamp(0.0, 1.0));
          canvas.drawCircle(
              Offset(px, py), (pSize * 0.55).clamp(0.3, 2.0), paint);
          break;

        // ── EMBER: glowing orb with hot bright core ────────────────────────
        case ParticleShape.ember:
          paint.color = col.o((p.life * 0.11).clamp(0.0, 1.0));
          canvas.drawCircle(Offset(px, py), pSize * 2.3, paint);
          paint.color = col.o((p.life * 0.68).clamp(0.0, 1.0));
          canvas.drawCircle(Offset(px, py), pSize, paint);
          paint.color = Colors.white.o((p.life * 0.52).clamp(0.0, 1.0));
          canvas.drawCircle(Offset(px, py), pSize * 0.36, paint);
          break;

        // ── SHARD: thin elongated rectangle, spinning metal debris ─────────
        case ParticleShape.shard:
          final w = pSize;
          final h = (pSize * p.aspect).clamp(w < 0.6 ? w : 0.6, w);
          canvas.save();
          canvas.translate(px, py);
          canvas.rotate(p.angle);
          paint.color = col.o(p.life.clamp(0.0, 1.0));
          canvas.drawRect(
              Rect.fromCenter(center: Offset.zero, width: w, height: h), paint);
          paint.color = Colors.white.o((p.life * 0.32).clamp(0.0, 1.0));
          canvas.drawRect(
              Rect.fromCenter(
                  center: Offset(0, -h * 0.28),
                  width: w * 0.85,
                  height: h * 0.28),
              paint);
          canvas.restore();
          break;

        // ── CHUNK: wider rounded rect, tumbling stone/wood debris ──────────
        case ParticleShape.chunk:
          final w = pSize;
          final upper = w * 1.2;
          final h = (pSize * p.aspect).clamp(upper < 1.0 ? upper : 1.0, upper);
          canvas.save();
          canvas.translate(px, py);
          canvas.rotate(p.angle);
          paint.color = col.o(p.life.clamp(0.0, 1.0));
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromCenter(center: Offset.zero, width: w, height: h),
                  Radius.circular(h * 0.20)),
              paint);
          paint.color = Colors.white.o((p.life * 0.20).clamp(0.0, 1.0));
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromCenter(
                      center: Offset(-w * 0.06, -h * 0.28),
                      width: w * 0.82,
                      height: h * 0.22),
                  Radius.circular(2)),
              paint);
          canvas.restore();
          break;
      }
    }
    paint.maskFilter = null;
  }

  void _drawShip(Canvas canvas, Size size) {
    final p = game.player;
    final cx = p.x * size.width;
    final cy = p.y * size.height;
    final r = p.size.toDouble() * 1.44; // 20% bigger than original 1.2
    final color = p.color;
    // Use gentle rotation instead of skew — skew causes the "shaking" bug
    final rawLean = p.velocityX * 12; // reduced multiplier
    final lean = rawLean.clamp(-8.0, 8.0); // no dead zone causing jump

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(lean * 0.012); // subtle roll, no skew

    if (game.state.isShieldActive) {
      final sp = sin(animTick * 6) * 0.2 + 0.8;
      final shP = Paint()
        ..shader = RadialGradient(
          colors: [
            AppTheme.accentAlt.o(0.0),
            AppTheme.accentAlt.o(0.2 * sp),
            AppTheme.accentAlt.o(0.8 * sp)
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r + 18));
      canvas.drawCircle(Offset.zero, r + 18, shP);
      shP.shader = null;
      shP.color = Colors.white.o(0.4 * sp);
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
      case SkinType.sovereign:
        drawSovereignShip(canvas, r, color, animTick);
        break;
    }

    canvas.restore();
  }

  void _drawText(
      Canvas canvas, String text, Offset center, Color color, double fontSize,
      {double letterSpacing = 0, bool centered = true}) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: letterSpacing,
              fontFamily: 'Courier')),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(
        canvas,
        centered
            ? Offset(center.dx - tp.width / 2, center.dy - tp.height / 2)
            : center);
  }

  // Cached — avoids allocating Random on every frame
  static final _speedRng = Random(42);
  static final _centerRng = Random(99);

  @override
  bool shouldRepaint(GamePainter old) => true;
}
