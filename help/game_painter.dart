import 'package:flutter/material.dart';
import 'dart:math';
import '../models/game_models.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import 'painters/wall_painter.dart';
import 'painters/chest_painter.dart';
import 'painters/gate_painter.dart';
import 'painters/mine_painter.dart';
import 'painters/bullet_painter.dart';
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
    drawBullets(canvas, size, game.bullets);
    _drawParticles(canvas, size);
    _drawBombEffect(canvas, size);
    _drawBossMissiles(canvas, size);
    _drawBossShip(canvas, size);
    _drawShip(canvas, size);
    _drawRampageOverlay(canvas, size);
    _drawGauntletOverlay(canvas, size);
    // Overlay effects — drawn last so they sit on top of everything
    _drawDangerVignette(canvas, size);
    _drawSweepWarning(canvas, size);
    _drawNearMissFlash(canvas, size);
    _drawComboFlash(canvas, size);
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
    final t = animTick * 0.12;
    final pal = game.palette;
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80)
      ..style = PaintingStyle.fill;
    // Sector-colored nebula — more intense per sector
    final intensity = 0.18 + (game.state.sector - 1) * 0.04;
    paint.color = pal.nebulaColor.withOpacity(intensity + sin(t) * 0.04);
    canvas.drawCircle(
        Offset(size.width * 0.18, size.height * 0.35), 220, paint);
    paint.color = pal.accentA.withOpacity(0.12 + cos(t * 0.8) * 0.04);
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.6), 200, paint);
    paint.color = pal.accentB.withOpacity(0.09 + sin(t * 1.3) * 0.03);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.12), 180, paint);
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
    final sp = (game.state.speed - 1.0) / 1.8;
    if (sp <= 0.03) return;
    final paint = Paint()..style = PaintingStyle.stroke;
    final rng = Random(42);
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
        paint.color = lineColor.withOpacity(lineOpacity.clamp(0.0, 0.55));
        canvas.drawLine(Offset(xBand, y), Offset(xBand, y + len), paint);
      }
    }
    // At very high speed (sector 4+): full-width streaks across center
    if (sp > 0.7) {
      final centerRng = Random(99);
      for (int i = 0; i < 3; i++) {
        final y = (centerRng.nextDouble() * size.height + animTick * 300) % size.height;
        paint.strokeWidth = 0.3;
        paint.color = Colors.white.withOpacity(0.04 * (sp - 0.7));
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }
  }

  void _drawShockwaves(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke;
    for (final sw in game.shockwaves) {
      final r = sw.radius * size.width;
      final opacity = sw.life;
      paint.strokeWidth = 3.0 * sw.life;
      paint.color = sw.color.withOpacity(opacity * 0.8);
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * sw.life);
      canvas.drawCircle(
          Offset(sw.x * size.width, sw.y * size.height), r, paint);
      paint.maskFilter = null;
      paint.strokeWidth = 1.5 * sw.life;
      paint.color = Colors.white.withOpacity(opacity * 0.6);
      canvas.drawCircle(
          Offset(sw.x * size.width, sw.y * size.height), r * 0.7, paint);
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
      paint.color = Colors.white.withOpacity((1.0 - flashT) * 0.95);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    }

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
          drawMine(canvas, size, obs, animTick);
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
            radius: 1.2)
        .createShader(Rect.fromCircle(center: Offset.zero, radius: r));
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
        canvas.drawPath(
            Path()
              ..moveTo(cos(a) * r * 0.2, sin(a) * r * 0.2)
              ..lineTo(cos(a + 0.3) * r * 0.8, sin(a + 0.3) * r * 0.8),
            paint);
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
              end: Alignment.bottomCenter)
          .createShader(sweptRect);
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
    _drawText(canvas, 'DANGER', Offset(headX, beamY - 26), Colors.white, 10,
        letterSpacing: 2);
  }

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
      paint.shader = RadialGradient(colors: [
        const Color(0xFFFFF176),
        AppTheme.coinColor,
        const Color(0xFFFF8F00)
      ], center: const Alignment(-0.35, -0.35))
          .createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
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
      _drawText(canvas, label, Offset(cx, cy), color, 8,
          letterSpacing: 0.5, centered: true);
    }
  }

  void _drawParticles(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in game.particles) {
      final life = p['life'] as double;
      final isDebris = p['isDebris'] as bool? ?? false;
      final pSize = (p['size'] as double) * life;
      if (isDebris) {
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

  void _drawShip(Canvas canvas, Size size) {
    final p = game.player;
    final cx = p.x * size.width;
    final cy = p.y * size.height;
    final r = p.size.toDouble() * 1.44; // 20% bigger than original 1.2
    final color = p.color;
    // Use gentle rotation instead of skew — skew causes the "shaking" bug
    final rawLean = p.velocityX * 18;
    final lean = rawLean.abs() < 1.0 ? 0.0 : rawLean.clamp(-12.0, 12.0);

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(lean * 0.012); // subtle roll, no skew

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

  // ── DANGER VIGNETTE — pulsing red edge when obstacles are very close ─────
  void _drawDangerVignette(Canvas canvas, Size size) {
    final v = game.dangerVignette;
    if (v < 0.02) return;
    final pulse = 0.7 + sin(animTick * 12) * 0.3; // rapid pulse = urgency
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.transparent,
          const Color(0xFFFF2D55).withOpacity(v * 0.55 * pulse),
        ],
        center: Alignment.center,
        radius: 0.85,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  // ── SWEEP WARNING — yellow flash before sweep beam hits player zone ───────
  void _drawSweepWarning(Canvas canvas, Size size) {
    final f = game.sweepWarningFlash;
    if (f < 0.02) return;
    // Top and bottom bars that pulse — classic danger signal
    final barH = size.height * 0.035;
    final paint = Paint()
      ..color = const Color(0xFFFFD60A).withOpacity(f * 0.7);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, barH), paint);
    canvas.drawRect(Rect.fromLTWH(0, size.height - barH, size.width, barH), paint);
    // Warning stripes
    paint.color = Colors.black.withOpacity(f * 0.5);
    const stripeW = 28.0;
    for (double x = 0; x < size.width; x += stripeW * 2) {
      canvas.drawRect(Rect.fromLTWH(x, 0, stripeW, barH), paint);
      canvas.drawRect(Rect.fromLTWH(x, size.height - barH, stripeW, barH), paint);
    }
  }

  // ── NEAR-MISS FLASH — cyan edge flash when you thread the needle ──────────
  void _drawNearMissFlash(Canvas canvas, Size size) {
    final f = game.nearMissFlash;
    if (f < 0.02) return;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF00FFD1).withOpacity(f * 0.6),
          Colors.transparent,
          Colors.transparent,
          const Color(0xFF00FFD1).withOpacity(f * 0.6),
        ],
        stops: const [0.0, 0.12, 0.88, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    // Score popup text
    if (f > 0.5) {
      _drawText(canvas, '✓ NEAR MISS',
        Offset(size.width * 0.5, size.height * 0.42),
        const Color(0xFF00FFD1), 14, letterSpacing: 3);
    }
  }

  // ── COMBO FLASH — full-screen flare on milestone combos ──────────────────
  void _drawComboFlash(Canvas canvas, Size size) {
    final f = game.comboFlash;
    if (f < 0.02) return;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFD60A).withOpacity(f * 0.35),
          Colors.transparent,
        ],
        center: Alignment.center,
        radius: 1.0,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  // ── BOSS SHIP ────────────────────────────────────────────────────────────
  void _drawBossShip(Canvas canvas, Size size) {
    final boss = game.boss;
    if (boss == null || boss.isFullyDead) return;

    final cx = boss.x * size.width;
    final cy = boss.y * size.height;
    final hpRatio = boss.hpRatio;
    final pulse = sin(boss.pulsePhase) * 0.5 + 0.5;
    double scl = 1.0;
    double opacity = 1.0;
    if (boss.isDead) {
      scl = 1.0 + boss.deathTimer * 2.2;
      opacity = (1.0 - boss.deathTimer).clamp(0.0, 1.0);
    }

    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(scl);

    final w = size.width * 0.13;
    final h = size.height * 0.085;
    final paint = Paint()..style = PaintingStyle.fill;

    // Outer danger aura — glows red when low HP or about to fire
    final aura = (1.0 - hpRatio) * 0.55 + boss.warningFlash * 0.45;
    if (aura > 0.05) {
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 35 + aura * 28);
      paint.color = const Color(0xFFFF2D55).withOpacity(aura * 0.55 * opacity);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: w * 2.8, height: h * 2.2), paint);
      paint.maskFilter = null;
    }

    // Main hull path — angular warship, nose pointing DOWN toward player
    final hull = Path();
    hull.moveTo(0, h * 0.75);             // nose (bottom — faces player)
    hull.lineTo(w * 0.45, h * 0.25);
    hull.lineTo(w, -h * 0.2);            // right wing tip
    hull.lineTo(w * 0.65, -h * 0.55);
    hull.lineTo(w * 0.18, -h * 0.75);
    hull.lineTo(-w * 0.18, -h * 0.75);
    hull.lineTo(-w * 0.65, -h * 0.55);
    hull.lineTo(-w, -h * 0.2);           // left wing tip
    hull.lineTo(-w * 0.45, h * 0.25);
    hull.close();

    // Glow behind hull
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 16);
    paint.color = const Color(0xFFFF2D55).withOpacity((0.25 + pulse * 0.18) * opacity);
    canvas.drawPath(hull, paint);
    paint.maskFilter = null;

    // Hull fill — dark red metallic, gets angrier as HP drops
    final hullDark = Color.lerp(const Color(0xFF1A0005), const Color(0xFF5A0000), 1.0 - hpRatio)!;
    final hullMid = Color.lerp(const Color(0xFF080003), const Color(0xFF2A0000), 1.0 - hpRatio)!;
    paint.shader = RadialGradient(
      colors: [hullDark, hullMid, const Color(0xFF030001)],
      center: const Alignment(0.0, -0.2), radius: 1.0,
    ).createShader(Rect.fromCenter(center: Offset.zero, width: w * 2, height: h * 2));
    paint.color = Colors.white.withOpacity(opacity);
    canvas.drawPath(hull, paint);
    paint.shader = null;

    // Hull outline
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2.0;
    paint.color = const Color(0xFFFF2D55).withOpacity((0.75 + pulse * 0.25) * opacity);
    canvas.drawPath(hull, paint);
    paint.style = PaintingStyle.fill;

    // Engine vents on wings (emit upward — away from player)
    for (final dx in [-w * 0.58, w * 0.58]) {
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 10);
      paint.color = const Color(0xFF8B0000).withOpacity((0.5 + pulse * 0.5) * opacity);
      canvas.drawOval(Rect.fromCenter(center: Offset(dx, -h * 0.5), width: w * 0.28, height: h * 0.2), paint);
      paint.maskFilter = null;
      paint.color = Color.lerp(const Color(0xFFFF2D55), Colors.white, pulse * 0.4)!.withOpacity(opacity);
      canvas.drawOval(Rect.fromCenter(center: Offset(dx, -h * 0.5), width: w * 0.15, height: h * 0.1), paint);
    }

    // Central cannon barrel pointing DOWN
    paint.color = const Color(0xFF0D0003).withOpacity(opacity);
    canvas.drawRect(Rect.fromCenter(center: Offset(0, h * 0.35), width: w * 0.14, height: h * 0.45), paint);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.2;
    paint.color = const Color(0xFFFF2D55).withOpacity(0.5 * opacity);
    canvas.drawRect(Rect.fromCenter(center: Offset(0, h * 0.35), width: w * 0.14, height: h * 0.45), paint);
    paint.style = PaintingStyle.fill;

    // Cannon tip glow — red-hot when about to fire
    if (boss.warningFlash > 0.05) {
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 14);
      paint.color = const Color(0xFFFF0040).withOpacity(boss.warningFlash * opacity);
      canvas.drawCircle(Offset(0, h * 0.62), w * 0.1, paint);
      paint.maskFilter = null;
      paint.color = Colors.white.withOpacity(boss.warningFlash * 0.8 * opacity);
      canvas.drawCircle(Offset(0, h * 0.62), w * 0.045, paint);
    }

    // HP bar — red strip across the top of the boss silhouette
    if (!boss.isDead) {
      final barW = w * 1.7;
      const barY = -0.0; // centered on boss y origin, above hull
      final barActualY = -h * 0.95;
      paint.color = const Color(0xFF2A0008).withOpacity(0.85 * opacity);
      canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, barActualY), width: barW, height: 5),
        const Radius.circular(2)), paint);
      paint.color = Color.lerp(const Color(0xFFFF2D55), const Color(0xFF00FF88), hpRatio)!.withOpacity(opacity);
      canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset((hpRatio - 1.0) * barW / 2, barActualY), width: barW * hpRatio, height: 5),
        const Radius.circular(2)), paint);

      // "HUNTER" label
      _drawText(canvas, 'IMPERIAL HUNTER', Offset(0, barActualY - 14),
        const Color(0xFFFF2D55).withOpacity(opacity), 9, letterSpacing: 3);
    }

    canvas.restore();
  }

  // ── BOSS MISSILES ─────────────────────────────────────────────────────────
  void _drawBossMissiles(Canvas canvas, Size size) {
    if (game.bossMissiles.isEmpty) return;
    final paint = Paint()..style = PaintingStyle.fill;
    for (final m in game.bossMissiles) {
      if (!m.active) continue;
      final mx = m.x * size.width;
      final my = m.y * size.height;
      // Outer glow
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
      paint.color = m.color.withOpacity(m.life * 0.55);
      canvas.drawCircle(Offset(mx, my), 11, paint);
      paint.maskFilter = null;
      // Body
      paint.color = m.color.withOpacity(m.life * 0.9);
      canvas.drawCircle(Offset(mx, my), 6, paint);
      paint.color = Colors.white.withOpacity(m.life * 0.9);
      canvas.drawCircle(Offset(mx, my), 3, paint);
      // Trail streak
      final ang = atan2(m.vy, m.vx);
      paint.color = m.color.withOpacity(m.life * 0.35);
      final trailLen = 18.0;
      canvas.drawOval(Rect.fromCenter(
        center: Offset(mx - cos(ang) * trailLen * 0.5, my - sin(ang) * trailLen * 0.5),
        width: 5, height: trailLen,
      ), paint);
    }
    paint.maskFilter = null;
  }

  // ── RAMPAGE OVERLAY ───────────────────────────────────────────────────────
  void _drawRampageOverlay(Canvas canvas, Size size) {
    final r = game.rampage;
    if (r.chargeLevel <= 0.01 && !r.isActive) return;

    final barW = size.width * 0.42;
    final barH = 6.0;
    final barX = size.width / 2 - barW / 2;
    final barY = size.height - 88.0;
    final paint = Paint()..style = PaintingStyle.fill;

    if (r.isActive) {
      // Pulsing orange screen edge
      final pulse = sin(r.flashPhase * 2) * 0.5 + 0.5;
      paint.shader = RadialGradient(
        colors: [Colors.transparent, Colors.transparent, const Color(0xFFFF6B00).withOpacity(0.22 + pulse * 0.14)],
        center: Alignment.center, radius: 0.78,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
      paint.shader = null;

      // Timer bar (drains left to right)
      final timeRatio = (r.timer / 10.0).clamp(0.0, 1.0);
      paint.color = const Color(0xFF1A0800).withOpacity(0.8);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(barX, barY, barW, barH), const Radius.circular(3)), paint);
      paint.color = Color.lerp(const Color(0xFFFF2D55), const Color(0xFFFF8C00), timeRatio)!;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(barX, barY, barW * timeRatio, barH), const Radius.circular(3)), paint);
      _drawText(canvas, 'RAMPAGE', Offset(size.width / 2, barY - 13), const Color(0xFFFF6B00), 10, letterSpacing: 4);
    } else {
      // Charge bar
      paint.color = const Color(0xFF1A0800).withOpacity(0.65);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(barX, barY, barW, barH), const Radius.circular(3)), paint);
      final filled = r.chargeLevel;
      final barColor = filled >= 1.0 ? const Color(0xFFFF6B00) : const Color(0xFFFF8C00).withOpacity(0.65);
      paint.color = barColor;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(barX, barY, barW * filled, barH), const Radius.circular(3)), paint);
      if (filled >= 1.0) {
        final pulse = sin(r.flashPhase) * 0.5 + 0.5;
        _drawText(canvas, '🔥 RAMPAGE READY — TAP',
          Offset(size.width / 2, barY - 13),
          const Color(0xFFFF6B00).withOpacity(0.65 + pulse * 0.35), 9, letterSpacing: 2);
      } else {
        _drawText(canvas, 'CHARGE', Offset(size.width / 2, barY - 13),
          const Color(0xFFFF8C00).withOpacity(0.5), 8, letterSpacing: 2);
      }
    }
  }

  // ── GAUNTLET / ESCAPE OVERLAY ─────────────────────────────────────────────
  void _drawGauntletOverlay(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Escape flash
    if (game.escapeFlashTimer > 0) {
      paint.color = Colors.white.withOpacity(game.escapeFlashTimer * 0.85);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    }

    if (!game.gauntletActive || game.escaped) return;

    // Progress bar across top
    final progress = (game.gauntletTimer / 30.0).clamp(0.0, 1.0);
    final barW = size.width * 0.68;
    final barX = size.width / 2 - barW / 2;
    const barY = 54.0;

    paint.color = const Color(0xFF150008).withOpacity(0.8);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(barX, barY, barW, 5), const Radius.circular(2)), paint);
    paint.color = Color.lerp(const Color(0xFFFF2D55), const Color(0xFF00FF88), progress)!;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(barX, barY, barW * progress, 5), const Radius.circular(2)), paint);

    final secs = (30 - game.gauntletTimer).ceil().clamp(0, 30);
    _drawText(canvas, 'ESCAPE IN  ${secs}s',
      Offset(size.width / 2, barY - 12),
      const Color(0xFFFFD60A), 10, letterSpacing: 2);
  }

  @override
  bool shouldRepaint(GamePainter old) => true;
}
