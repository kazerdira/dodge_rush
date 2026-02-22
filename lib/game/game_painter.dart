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
    _drawTrail(canvas, size);
    _drawGhostImages(canvas, size);
    _drawObstacles(canvas, size);
    _drawCoins(canvas, size);
    _drawPowerUps(canvas, size);
    _drawParticles(canvas, size);
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
    // Specter skin: fading after-images of the ship
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

  // ─── OBSTACLES ──────────────────────────────────────────────────────────────

  void _drawObstacles(Canvas canvas, Size size) {
    for (final obs in game.obstacles) {
      switch (obs.type) {
        case ObstacleType.laserWall:
          _drawLaserWall(canvas, size, obs);
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
          _drawPulseGate(canvas, size, obs);
          break;
      }
    }
  }

  void _drawLaserWall(Canvas canvas, Size size, Obstacle obs) {
    final rect = Rect.fromLTWH(obs.x * size.width, obs.y * size.height,
        obs.width * size.width, obs.height * size.height);
    final paint = Paint();

    // Outer glow
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    paint.color = obs.color.withOpacity(0.4);
    canvas.drawRect(rect.inflate(3), paint);
    paint.maskFilter = null;

    // Body
    paint.shader = LinearGradient(colors: [
      obs.color.withOpacity(0.9),
      obs.color.withOpacity(0.5),
      obs.color.withOpacity(0.9)
    ], begin: Alignment.topCenter, end: Alignment.bottomCenter)
        .createShader(rect);
    canvas.drawRect(rect, paint);
    paint.shader = null;

    // Scan line
    final scanY = rect.top + (rect.height * ((animTick * 1.5) % 1.0));
    paint.color = Colors.white.withOpacity(0.28);
    paint.strokeWidth = 1.5;
    paint.style = PaintingStyle.stroke;
    canvas.drawLine(Offset(rect.left, scanY), Offset(rect.right, scanY), paint);
    paint.style = PaintingStyle.fill;

    // Warning stripes
    paint.color = Colors.white.withOpacity(0.1);
    var sx = rect.left;
    while (sx < rect.right) {
      canvas.drawRect(Rect.fromLTWH(sx, rect.top, 3.5, rect.height), paint);
      sx += 9;
    }
  }

  void _drawAsteroid(Canvas canvas, Size size, Obstacle obs) {
    if (obs.shape.isEmpty) return;
    final cx = (obs.x + obs.width / 2) * size.width;
    final cy = (obs.y + obs.height / 2) * size.height;
    final r = obs.width * size.width * 0.55;
    final paint = Paint();

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(obs.rotation);

    final path = Path();
    for (int i = 0; i < obs.shape.length; i++) {
      final pt = obs.shape[i];
      if (i == 0)
        path.moveTo(pt.dx * r, pt.dy * r);
      else
        path.lineTo(pt.dx * r, pt.dy * r);
    }
    path.close();

    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    paint.color = obs.color.withOpacity(0.3);
    canvas.drawPath(path, paint);
    paint.maskFilter = null;

    paint.shader = RadialGradient(colors: [
      const Color(0xFFA07850),
      const Color(0xFF6B4E30),
      const Color(0xFF3D2A15)
    ], center: const Alignment(-0.3, -0.4))
        .createShader(Rect.fromCircle(center: Offset.zero, radius: r));
    canvas.drawPath(path, paint);
    paint.shader = null;

    paint.color = const Color(0xFF2A1A08).withOpacity(0.5);
    canvas.drawCircle(Offset(-r * 0.25, -r * 0.15), r * 0.18, paint);
    canvas.drawCircle(Offset(r * 0.3, r * 0.2), r * 0.12, paint);
    paint.color = Colors.white.withOpacity(0.15);
    canvas.drawCircle(Offset(-r * 0.3, -r * 0.3), r * 0.2, paint);
    canvas.restore();
  }

  void _drawMine(Canvas canvas, Size size, Obstacle obs) {
    final cx = (obs.x + obs.width / 2) * size.width;
    final cy = (obs.y + obs.height / 2) * size.height;
    final r = obs.width * size.width * 0.5;
    final pulse = sin(animTick * 5) * 0.3 + 0.7;
    final paint = Paint();

    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    paint.color = obs.color.withOpacity(0.4 * pulse);
    canvas.drawCircle(Offset(cx, cy), r + 8, paint);
    paint.maskFilter = null;

    paint.color = const Color(0xFF2A1208);
    canvas.drawCircle(Offset(cx, cy), r, paint);
    paint.color = obs.color;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;
    canvas.drawCircle(Offset(cx, cy), r, paint);
    paint.style = PaintingStyle.fill;

    for (int i = 0; i < 8; i++) {
      final angle = (pi / 4 * i) + obs.rotation;
      paint.color = obs.color.withOpacity(0.8 * pulse);
      paint.strokeWidth = 1.5;
      paint.style = PaintingStyle.stroke;
      canvas.drawLine(Offset(cx + cos(angle) * r, cy + sin(angle) * r),
          Offset(cx + cos(angle) * (r + 7), cy + sin(angle) * (r + 7)), paint);
    }
    paint.style = PaintingStyle.fill;
    paint.color = obs.color.withOpacity(pulse);
    canvas.drawCircle(Offset(cx, cy), r * 0.35, paint);
  }

  // ── SWEEP BEAM ─────────────────────────────────────────────────────────────
  // A hot magenta laser that sweeps across the full screen width
  void _drawSweepBeam(Canvas canvas, Size size, Obstacle obs) {
    if (obs.sweepDone) return;
    final beamY = obs.y * size.height;
    final beamH = obs.height * size.height;
    final paint = Paint();

    // Background warning: full-width dim tint of the beam row
    paint.color = obs.color.withOpacity(0.06);
    canvas.drawRect(Rect.fromLTWH(0, beamY, size.width, beamH), paint);

    // Dashed warning lines on sides
    paint.color = obs.color.withOpacity(0.3);
    paint.strokeWidth = 1;
    paint.style = PaintingStyle.stroke;
    for (double d = 0; d < size.width; d += 16) {
      canvas.drawLine(Offset(d, beamY), Offset(d + 8, beamY), paint);
      canvas.drawLine(
          Offset(d, beamY + beamH), Offset(d + 8, beamY + beamH), paint);
    }
    paint.style = PaintingStyle.fill;

    // Calculate beam head position
    final progress =
        obs.sweepFromLeft ? obs.sweepProgress : (1.0 - obs.sweepProgress);
    final headX = progress * size.width;

    // Already-swept (dangerous) zone
    if (obs.sweepFromLeft) {
      final sweptRect = Rect.fromLTWH(0, beamY, max(0, headX - 20), beamH);
      if (sweptRect.width > 0) {
        paint.shader = LinearGradient(
          colors: [obs.color.withOpacity(0.55), obs.color.withOpacity(0.35)],
        ).createShader(sweptRect);
        canvas.drawRect(sweptRect, paint);
        paint.shader = null;
      }
    } else {
      final sweptRect =
          Rect.fromLTWH(headX + 20, beamY, size.width - headX - 20, beamH);
      if (sweptRect.width > 0) {
        paint.shader = LinearGradient(
          colors: [obs.color.withOpacity(0.35), obs.color.withOpacity(0.55)],
        ).createShader(sweptRect);
        canvas.drawRect(sweptRect, paint);
        paint.shader = null;
      }
    }

    // Beam head — bright glowing front edge
    final headRect = Rect.fromLTWH(headX - 18, beamY - 4, 36, beamH + 8);
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    paint.color = Colors.white.withOpacity(0.7);
    canvas.drawRect(headRect, paint);
    paint.maskFilter = null;

    paint.shader = LinearGradient(
      colors: [Colors.white, obs.color, obs.color.withOpacity(0)],
      begin: obs.sweepFromLeft ? Alignment.centerRight : Alignment.centerLeft,
      end: obs.sweepFromLeft ? Alignment.centerLeft : Alignment.centerRight,
    ).createShader(Rect.fromLTWH(headX - 24, beamY, 48, beamH));
    canvas.drawRect(Rect.fromLTWH(headX - 24, beamY, 48, beamH), paint);
    paint.shader = null;

    // Spark particles at head
    final rng = Random((animTick * 100).floor());
    paint.color = Colors.white.withOpacity(0.6);
    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(headX + (rng.nextDouble() - 0.5) * 20,
            beamY + rng.nextDouble() * beamH),
        1.5 + rng.nextDouble() * 2.5,
        paint,
      );
    }

    // WARNING label
    final tp = TextPainter(
      text: TextSpan(
          text: '⚠ SWEEP',
          style: TextStyle(
              color: obs.color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 2)),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(8, beamY - 14));
  }

  // ── PULSE GATE ─────────────────────────────────────────────────────────────
  // Two energy pillars that pulse, with a rhythmic gap between them
  void _drawPulseGate(Canvas canvas, Size size, Obstacle obs) {
    final openness = (sin(obs.pulsePhase) + 1) / 2; // 0=closed, 1=open
    final gapHalf = obs.gapHalfWidth * openness * size.width;
    final gapCX = obs.gapCenterX * size.width;
    final wallY = obs.y * size.height;
    final wallH = obs.height * 2 * size.height; // tall pillar
    const wallW = 10.0;
    final paint = Paint();
    final pulse = sin(obs.pulsePhase * 2) * 0.3 + 0.7;

    // Left pillar (from left edge to gap left)
    final leftW = gapCX - gapHalf;
    if (leftW > 0) {
      final leftRect = Rect.fromLTWH(0, wallY, leftW, wallH);
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      paint.color = obs.color.withOpacity(0.35 * pulse);
      canvas.drawRect(leftRect.inflate(3), paint);
      paint.maskFilter = null;
      paint.shader = LinearGradient(
        colors: [obs.color.withOpacity(0.8), obs.color.withOpacity(0.4)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(leftRect);
      canvas.drawRect(leftRect, paint);
      paint.shader = null;
      // Inner glow on right edge of left wall
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      paint.color = obs.color.withOpacity(0.6 * pulse);
      canvas.drawRect(Rect.fromLTWH(leftW - wallW, wallY, wallW, wallH), paint);
      paint.maskFilter = null;
    }

    // Right pillar (from gap right to right edge)
    final rightStart = gapCX + gapHalf;
    if (rightStart < size.width) {
      final rightRect =
          Rect.fromLTWH(rightStart, wallY, size.width - rightStart, wallH);
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      paint.color = obs.color.withOpacity(0.35 * pulse);
      canvas.drawRect(rightRect.inflate(3), paint);
      paint.maskFilter = null;
      paint.shader = LinearGradient(
        colors: [obs.color.withOpacity(0.8), obs.color.withOpacity(0.4)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rightRect);
      canvas.drawRect(rightRect, paint);
      paint.shader = null;
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      paint.color = obs.color.withOpacity(0.6 * pulse);
      canvas.drawRect(Rect.fromLTWH(rightStart, wallY, wallW, wallH), paint);
      paint.maskFilter = null;
    }

    // Energy arc connecting the two pillars across the gap
    if (gapHalf > 4) {
      final arcPaint = Paint()
        ..color = obs.color.withOpacity(0.2 * (1.0 - openness))
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      // Wavy arc
      final path = Path();
      path.moveTo(gapCX - gapHalf, wallY + wallH / 2);
      final rng = Random((obs.pulsePhase * 10).floor());
      for (double x = gapCX - gapHalf; x <= gapCX + gapHalf; x += 4) {
        path.lineTo(
            x,
            wallY +
                wallH / 2 +
                sin(x * 0.3 + obs.pulsePhase * 4) * 8 * (1.0 - openness));
      }
      canvas.drawPath(path, arcPaint);
    }

    // PULSE WARNING label
    final isOpen = openness > 0.35;
    final tp = TextPainter(
      text: TextSpan(
        text: isOpen ? '◆ OPEN' : '◆ CLOSED',
        style: TextStyle(
            color: isOpen ? AppTheme.accent : obs.color,
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(gapCX - tp.width / 2, wallY - 14));
  }

  // ─── COINS ──────────────────────────────────────────────────────────────────

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

  // ─── POWER-UPS ──────────────────────────────────────────────────────────────

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
          textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    }
  }

  // ─── PARTICLES ──────────────────────────────────────────────────────────────

  void _drawParticles(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    for (final p in game.particles) {
      final life = p['life'] as double;
      paint.color = (p['color'] as Color).withOpacity(life.clamp(0.0, 1.0));
      canvas.drawCircle(
          Offset((p['x'] as double) * size.width,
              (p['y'] as double) * size.height),
          (p['size'] as double) * life,
          paint);
    }
    paint.maskFilter = null;
  }

  // ─── SHIP — 5 DISTINCT SHAPES ───────────────────────────────────────────────

  void _drawShip(Canvas canvas, Size size) {
    final p = game.player;
    final cx = p.x * size.width;
    final cy = p.y * size.height;
    // Boosted the base radius visually by 20% to make them feel less "tiny"
    final r = p.size.toDouble() * 1.2;
    final color = p.color;
    final lean = p.velocityX * 80;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.skew(lean * 0.02, 0); // Slightly more dynamic lean

    // Shield - Made it look more like an energy bubble
    if (game.state.isShieldActive) {
      final sp = sin(animTick * 6) * 0.2 + 0.8;
      final shP = Paint()
        ..shader = RadialGradient(
          colors: [
            AppTheme.accentAlt.withOpacity(0.0),
            AppTheme.accentAlt.withOpacity(0.2 * sp),
            AppTheme.accentAlt.withOpacity(0.8 * sp),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r + 18));
      canvas.drawCircle(Offset.zero, r + 18, shP);

      shP.shader = null;
      shP.color = Colors.white.withOpacity(0.4 * sp);
      shP.style = PaintingStyle.stroke;
      shP.strokeWidth = 2.0;
      canvas.drawCircle(Offset.zero, r + 16, shP);
    }

    // Draw skin-specific shape
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
