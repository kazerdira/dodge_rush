import 'package:flutter/material.dart';
import 'dart:math';
import '../models/game_models.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';

class GamePainter extends CustomPainter {
  final GameProvider game;
  final double animTick;

  GamePainter(this.game, this.animTick);

  @override
  void paint(Canvas canvas, Size size) {
    _drawSpaceBackground(canvas, size);
    _drawNebula(canvas, size);
    _drawStars(canvas, size);
    _drawTrail(canvas, size);
    _drawObstacles(canvas, size);
    _drawCoins(canvas, size);
    _drawPowerUps(canvas, size);
    _drawParticles(canvas, size);
    _drawShip(canvas, size);
    _drawSpeedLines(canvas, size);
  }

  void _drawSpaceBackground(Canvas canvas, Size size) {
    // Deep space gradient
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, Paint()..color = AppTheme.bg);
  }

  void _drawNebula(Canvas canvas, Size size) {
    // Soft nebula clouds in background
    final t = animTick * 0.15;
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80)
      ..style = PaintingStyle.fill;

    paint.color = AppTheme.purple.withOpacity(0.04 + sin(t) * 0.01);
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.35), 160, paint);

    paint.color = AppTheme.accentAlt.withOpacity(0.03 + cos(t * 0.8) * 0.01);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.6), 140, paint);

    paint.color = AppTheme.orange.withOpacity(0.025);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.15), 120, paint);
  }

  void _drawStars(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final star in game.stars) {
      // Twinkle effect for close stars
      double opacity = star.opacity;
      if (star.layer == 2) {
        opacity = star.opacity * (0.7 + sin(animTick * 3 + star.x * 10) * 0.3);
      }
      paint.color = Colors.white.withOpacity(opacity.clamp(0.0, 1.0));

      if (star.layer == 2 && star.size > 2.0) {
        // Draw as cross/sparkle for bright close stars
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
        canvas.drawCircle(
          Offset(star.x * size.width, star.y * size.height),
          star.size,
          paint,
        );
      }
    }
  }

  void _drawSpeedLines(Canvas canvas, Size size) {
    // Subtle motion lines at sides to show speed
    final speedProgress = (game.state.speed - 1.0) / 2.0;
    if (speedProgress <= 0.05) return;

    final paint = Paint()
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final rng = Random(42); // fixed seed for consistent lines
    for (int i = 0; i < 8; i++) {
      final x = rng.nextDouble() * size.width * 0.15;
      final y = (rng.nextDouble() * size.height + animTick * 200 * game.state.speed) % size.height;
      final len = 20.0 + rng.nextDouble() * 40;
      paint.color = AppTheme.accent.withOpacity(0.06 * speedProgress);
      canvas.drawLine(Offset(x, y), Offset(x, y + len), paint);
    }
    for (int i = 0; i < 8; i++) {
      final x = size.width - rng.nextDouble() * size.width * 0.15;
      final y = (rng.nextDouble() * size.height + animTick * 200 * game.state.speed) % size.height;
      final len = 20.0 + rng.nextDouble() * 40;
      paint.color = AppTheme.accent.withOpacity(0.06 * speedProgress);
      canvas.drawLine(Offset(x, y), Offset(x, y + len), paint);
    }
  }

  void _drawTrail(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final t in game.trail) {
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      paint.color = t.color.withOpacity(t.life * 0.6);
      canvas.drawCircle(
        Offset(t.x * size.width, t.y * size.height),
        t.size * t.life,
        paint,
      );
    }
    paint.maskFilter = null;
  }

  void _drawObstacles(Canvas canvas, Size size) {
    final paint = Paint();

    for (final obs in game.obstacles) {
      if (obs.type == ObstacleType.laserWall) {
        _drawLaserWall(canvas, size, obs, paint);
      } else if (obs.type == ObstacleType.asteroid) {
        _drawAsteroid(canvas, size, obs, paint);
      } else if (obs.type == ObstacleType.mine) {
        _drawMine(canvas, size, obs, paint);
      }
    }
  }

  void _drawLaserWall(Canvas canvas, Size size, Obstacle obs, Paint paint) {
    final rect = Rect.fromLTWH(
      obs.x * size.width,
      obs.y * size.height,
      obs.width * size.width,
      obs.height * size.height,
    );

    // Outer glow
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    paint.color = obs.color.withOpacity(0.4);
    canvas.drawRect(rect.inflate(3), paint);
    paint.maskFilter = null;

    // Energy field body
    paint.shader = LinearGradient(
      colors: [
        obs.color.withOpacity(0.9),
        obs.color.withOpacity(0.5),
        obs.color.withOpacity(0.9),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(rect);
    canvas.drawRect(rect, paint);
    paint.shader = null;

    // Scan line animation
    final scanY = rect.top + (rect.height * ((animTick * 1.5) % 1.0));
    paint.color = Colors.white.withOpacity(0.25);
    paint.strokeWidth = 1.5;
    paint.style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(rect.left, scanY),
      Offset(rect.right, scanY),
      paint,
    );
    paint.style = PaintingStyle.fill;

    // Warning stripes at edges
    paint.color = Colors.white.withOpacity(0.12);
    const stripeW = 4.0;
    const stripeGap = 10.0;
    var stripeX = rect.left;
    while (stripeX < rect.right) {
      canvas.drawRect(
        Rect.fromLTWH(stripeX, rect.top, stripeW, rect.height),
        paint,
      );
      stripeX += stripeGap;
    }
  }

  void _drawAsteroid(Canvas canvas, Size size, Obstacle obs, Paint paint) {
    if (obs.shape.isEmpty) return;

    final cx = (obs.x + obs.width / 2) * size.width;
    final cy = (obs.y + obs.height / 2) * size.height;
    final r = obs.width * size.width * 0.55;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(obs.rotation);

    // Build path from stored shape
    final path = Path();
    for (int i = 0; i < obs.shape.length; i++) {
      final pt = obs.shape[i];
      final px = pt.dx * r;
      final py = pt.dy * r;
      if (i == 0) path.moveTo(px, py); else path.lineTo(px, py);
    }
    path.close();

    // Glow
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    paint.color = obs.color.withOpacity(0.3);
    canvas.drawPath(path, paint);
    paint.maskFilter = null;

    // Main body gradient
    paint.shader = RadialGradient(
      colors: [
        const Color(0xFFA07850),
        const Color(0xFF6B4E30),
        const Color(0xFF3D2A15),
      ],
      center: const Alignment(-0.3, -0.4),
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));
    canvas.drawPath(path, paint);
    paint.shader = null;

    // Craters
    paint.color = const Color(0xFF2A1A08).withOpacity(0.5);
    canvas.drawCircle(Offset(-r * 0.25, -r * 0.15), r * 0.18, paint);
    canvas.drawCircle(Offset(r * 0.3, r * 0.2), r * 0.12, paint);
    canvas.drawCircle(Offset(-r * 0.1, r * 0.3), r * 0.09, paint);

    // Highlight
    paint.color = Colors.white.withOpacity(0.15);
    canvas.drawCircle(Offset(-r * 0.3, -r * 0.3), r * 0.2, paint);

    canvas.restore();
  }

  void _drawMine(Canvas canvas, Size size, Obstacle obs, Paint paint) {
    final cx = (obs.x + obs.width / 2) * size.width;
    final cy = (obs.y + obs.height / 2) * size.height;
    final r = obs.width * size.width * 0.5;
    final pulse = sin(animTick * 5) * 0.3 + 0.7;

    // Danger pulse
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    paint.color = obs.color.withOpacity(0.4 * pulse);
    canvas.drawCircle(Offset(cx, cy), r + 8, paint);
    paint.maskFilter = null;

    // Body
    paint.color = const Color(0xFF2A1208);
    canvas.drawCircle(Offset(cx, cy), r, paint);
    paint.color = obs.color;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;
    canvas.drawCircle(Offset(cx, cy), r, paint);
    paint.style = PaintingStyle.fill;

    // Spikes
    for (int i = 0; i < 8; i++) {
      final angle = (pi / 4 * i) + animTick * 0.5;
      paint.color = obs.color.withOpacity(0.8 * pulse);
      paint.strokeWidth = 1.5;
      paint.style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(cx + cos(angle) * r, cy + sin(angle) * r),
        Offset(cx + cos(angle) * (r + 7), cy + sin(angle) * (r + 7)),
        paint,
      );
    }
    paint.style = PaintingStyle.fill;

    // Core
    paint.color = obs.color.withOpacity(pulse);
    canvas.drawCircle(Offset(cx, cy), r * 0.35, paint);
  }

  void _drawCoins(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final coin in game.coins) {
      if (coin.collected) continue;
      final cx = coin.x * size.width;
      final cy = coin.y * size.height;
      final pulse = sin(coin.pulsePhase) * 0.15 + 1.0;
      final r = 9.0 * pulse;

      // Glow
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      paint.color = AppTheme.coinColor.withOpacity(0.35);
      canvas.drawCircle(Offset(cx, cy), r + 5, paint);
      paint.maskFilter = null;

      // Coin
      paint.shader = RadialGradient(
        colors: [const Color(0xFFFFF176), AppTheme.coinColor, const Color(0xFFFF8F00)],
        center: const Alignment(-0.35, -0.35),
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      canvas.drawCircle(Offset(cx, cy), r, paint);
      paint.shader = null;

      // Inner ring
      paint.color = const Color(0xFFFF8F00).withOpacity(0.5);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 1.5;
      canvas.drawCircle(Offset(cx, cy), r * 0.65, paint);
      paint.style = PaintingStyle.fill;

      // Highlight
      paint.color = Colors.white.withOpacity(0.5);
      canvas.drawCircle(Offset(cx - r * 0.28, cy - r * 0.28), r * 0.25, paint);
    }
  }

  void _drawPowerUps(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

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
          label = 'LIFE';
          break;
      }

      // Rotating outer ring
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(pu.pulsePhase * 0.5);

      // Glow
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      paint.color = color.withOpacity(0.4);
      canvas.drawCircle(Offset.zero, r * pulse + 6, paint);
      paint.maskFilter = null;

      // Hexagon shape
      final path = Path();
      for (int i = 0; i < 6; i++) {
        final angle = (pi / 3 * i) - pi / 6;
        final x = cos(angle) * r * pulse;
        final y = sin(angle) * r * pulse;
        if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
      }
      path.close();
      paint.color = color.withOpacity(0.25);
      canvas.drawPath(path, paint);
      paint.color = color.withOpacity(0.9);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2;
      canvas.drawPath(path, paint);
      paint.style = PaintingStyle.fill;

      canvas.restore();

      // Label
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: color,
            fontSize: 7,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    }
  }

  void _drawParticles(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    for (final p in game.particles) {
      final life = p['life'] as double;
      paint.color = (p['color'] as Color).withOpacity(life.clamp(0.0, 1.0));
      canvas.drawCircle(
        Offset((p['x'] as double) * size.width, (p['y'] as double) * size.height),
        (p['size'] as double) * life,
        paint,
      );
    }
    paint.maskFilter = null;
  }

  void _drawShip(Canvas canvas, Size size) {
    final p = game.player;
    final cx = p.x * size.width;
    final cy = p.y * size.height;
    final r = p.size.toDouble();
    final color = p.color;

    // Lean based on movement direction
    final lean = game.player.velocityX * 80;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.skew(lean * 0.02, 0);

    // Shield bubble
    if (game.state.isShieldActive) {
      final shieldPulse = sin(animTick * 6) * 0.2 + 0.8;
      final shieldPaint = Paint()
        ..color = AppTheme.accentAlt.withOpacity(0.15 * shieldPulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset.zero, r + 16, shieldPaint);
      shieldPaint.maskFilter = null;
      shieldPaint.color = AppTheme.accentAlt.withOpacity(0.6 * shieldPulse);
      shieldPaint.style = PaintingStyle.stroke;
      shieldPaint.strokeWidth = 1.5;
      canvas.drawCircle(Offset.zero, r + 14, shieldPaint);
    }

    // Engine glow
    final enginePaint = Paint()
      ..color = color.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawCircle(Offset(0, r * 0.5), r * 0.8, enginePaint);
    enginePaint.maskFilter = null;

    // Wing nozzles
    final nozzle1 = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
      ..color = color.withOpacity(0.7);
    canvas.drawCircle(Offset(-r * 0.55, r * 0.5), r * 0.22, nozzle1);
    canvas.drawCircle(Offset(r * 0.55, r * 0.5), r * 0.22, nozzle1);
    nozzle1.maskFilter = null;

    // Ship body — sleek futuristic shape
    final bodyPath = Path();
    // Nose
    bodyPath.moveTo(0, -r * 1.2);
    // Right wing curve
    bodyPath.cubicTo(r * 0.8, -r * 0.2, r * 1.0, r * 0.3, r * 0.6, r * 0.8);
    // Right engine
    bodyPath.lineTo(r * 0.6, r * 1.1);
    bodyPath.lineTo(r * 0.35, r * 0.9);
    // Bottom center
    bodyPath.lineTo(0, r * 0.7);
    bodyPath.lineTo(-r * 0.35, r * 0.9);
    // Left engine
    bodyPath.lineTo(-r * 0.6, r * 1.1);
    bodyPath.lineTo(-r * 0.6, r * 0.8);
    // Left wing curve
    bodyPath.cubicTo(-r * 1.0, r * 0.3, -r * 0.8, -r * 0.2, 0, -r * 1.2);
    bodyPath.close();

    // Body gradient fill
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withOpacity(0.9),
          color.withOpacity(0.8),
          color.withOpacity(0.4),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: r * 1.2));
    canvas.drawPath(bodyPath, bodyPaint);

    // Cockpit window
    final cockpitPath = Path();
    cockpitPath.moveTo(0, -r * 0.7);
    cockpitPath.cubicTo(r * 0.35, -r * 0.3, r * 0.35, r * 0.1, 0, r * 0.2);
    cockpitPath.cubicTo(-r * 0.35, r * 0.1, -r * 0.35, -r * 0.3, 0, -r * 0.7);

    canvas.drawPath(cockpitPath, Paint()
      ..shader = RadialGradient(
        colors: [
          AppTheme.accentAlt.withOpacity(0.9),
          AppTheme.accentAlt.withOpacity(0.4),
          Colors.black.withOpacity(0.6),
        ],
        center: const Alignment(0, -0.3),
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)));

    // Cockpit highlight
    canvas.drawPath(cockpitPath, Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8);

    // Wing stripe / racing line
    canvas.drawLine(
      Offset(-r * 0.5, -r * 0.1),
      Offset(-r * 0.5, r * 0.6),
      Paint()..color = color.withOpacity(0.6)..strokeWidth = 1.5..style = PaintingStyle.stroke,
    );
    canvas.drawLine(
      Offset(r * 0.5, -r * 0.1),
      Offset(r * 0.5, r * 0.6),
      Paint()..color = color.withOpacity(0.6)..strokeWidth = 1.5..style = PaintingStyle.stroke,
    );

    // Engine flame
    final flameFlicker = 0.8 + sin(animTick * 15) * 0.2;
    final flamePaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
      ..shader = LinearGradient(
        colors: [Colors.white, color, color.withOpacity(0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(-r * 0.3, r * 0.7, r * 0.6, r * 0.8 * flameFlicker));

    final flamePath = Path()
      ..moveTo(-r * 0.25, r * 0.85)
      ..quadraticBezierTo(0, r * (1.5 + flameFlicker * 0.3), r * 0.25, r * 0.85)
      ..close();
    canvas.drawPath(flamePath, flamePaint);

    // Side flames
    final flamePath2 = Path()
      ..moveTo(-r * 0.7, r * 0.95)
      ..quadraticBezierTo(-r * 0.6, r * (1.3 + flameFlicker * 0.2), -r * 0.5, r * 0.95)
      ..close();
    canvas.drawPath(flamePath2, flamePaint);

    final flamePath3 = Path()
      ..moveTo(r * 0.5, r * 0.95)
      ..quadraticBezierTo(r * 0.6, r * (1.3 + flameFlicker * 0.2), r * 0.7, r * 0.95)
      ..close();
    canvas.drawPath(flamePath3, flamePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(GamePainter old) => true;
}
