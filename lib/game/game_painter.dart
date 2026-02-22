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
    _drawBackground(canvas, size);
    _drawObstacles(canvas, size);
    _drawCoins(canvas, size);
    _drawPowerUps(canvas, size);
    _drawParticles(canvas, size);
    _drawPlayer(canvas, size);
    _drawTrail(canvas, size);
  }

  void _drawBackground(Canvas canvas, Size size) {
    // Subtle grid lines
    final paint = Paint()
      ..color = AppTheme.accent.withOpacity(0.03)
      ..strokeWidth = 0.5;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawObstacles(Canvas canvas, Size size) {
    for (final obs in game.obstacles) {
      final rect = Rect.fromLTWH(
        obs.x * size.width,
        obs.y * size.height,
        obs.width * size.width,
        obs.height * size.height,
      );

      // Glow effect
      final glowPaint = Paint()
        ..color = obs.color.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawRRect(RRect.fromRectAndRadius(rect.inflate(4), const Radius.circular(4)), glowPaint);

      // Main body
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [obs.color, obs.color.withOpacity(0.7)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), paint);

      // Highlight strip
      final highlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.15)
        ..style = PaintingStyle.fill;
      final highlightRect = Rect.fromLTWH(rect.left, rect.top, rect.width, 3);
      canvas.drawRRect(RRect.fromRectAndRadius(highlightRect, const Radius.circular(2)), highlightPaint);
    }
  }

  void _drawCoins(Canvas canvas, Size size) {
    for (final coin in game.coins) {
      if (coin.collected) continue;
      final center = Offset(coin.x * size.width, coin.y * size.height);
      const radius = 10.0;

      // Glow
      canvas.drawCircle(center, radius + 4, Paint()
        ..color = AppTheme.coinColor.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

      // Coin body
      canvas.drawCircle(center, radius, Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFE066), Color(0xFFFFB800)],
          center: Alignment(-0.3, -0.3),
        ).createShader(Rect.fromCircle(center: center, radius: radius)));

      // Star symbol
      final textPainter = TextPainter(
        text: const TextSpan(text: '✦', style: TextStyle(fontSize: 10, color: Colors.white)),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, center - Offset(textPainter.width / 2, textPainter.height / 2));
    }
  }

  void _drawPowerUps(Canvas canvas, Size size) {
    for (final pu in game.powerUps) {
      if (pu.collected) continue;
      final center = Offset(pu.x * size.width, pu.y * size.height);
      const radius = 14.0;

      Color color;
      String icon;
      switch (pu.type) {
        case PowerUpType.shield:
          color = AppTheme.shieldColor;
          icon = '🛡';
          break;
        case PowerUpType.slowTime:
          color = AppTheme.slowColor;
          icon = '⏱';
          break;
        case PowerUpType.extraLife:
          color = AppTheme.danger;
          icon = '❤';
          break;
      }

      // Glow
      canvas.drawCircle(center, radius + 6, Paint()
        ..color = color.withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));

      // Body
      canvas.drawCircle(center, radius, Paint()..color = color.withOpacity(0.8));
      canvas.drawCircle(center, radius, Paint()
        ..color = Colors.white.withOpacity(0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);

      // Icon
      final textPainter = TextPainter(
        text: TextSpan(text: icon, style: const TextStyle(fontSize: 14)),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, center - Offset(textPainter.width / 2, textPainter.height / 2));
    }
  }

  void _drawParticles(Canvas canvas, Size size) {
    for (final p in game.particles) {
      final life = p['life'] as double;
      final x = (p['x'] as double) * size.width;
      final y = (p['y'] as double) * size.height;
      final color = (p['color'] as Color).withOpacity(life);
      final pSize = (p['size'] as double) * life;
      canvas.drawCircle(Offset(x, y), pSize, Paint()..color = color);
    }
  }

  void _drawPlayer(Canvas canvas, Size size) {
    final p = game.player;
    final center = Offset(p.x * size.width, p.y * size.height);
    final r = p.size / 2;

    // Get skin color
    const skinColors = [
      Color(0xFF00F5FF), Color(0xFFFF4500), Color(0xFFBF00FF),
      Color(0xFF39FF14), Color(0xFFFFD700),
    ];
    final skinIndex = p.skin.index;
    final color = skinColors[skinIndex % skinColors.length];

    // Shield effect
    if (game.state.isShieldActive) {
      final shieldProgress = sin(animTick * 5) * 0.3 + 0.7;
      canvas.drawCircle(center, r + 10, Paint()
        ..color = AppTheme.shieldColor.withOpacity(0.25 * shieldProgress)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      canvas.drawCircle(center, r + 8, Paint()
        ..color = AppTheme.shieldColor.withOpacity(0.6 * shieldProgress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }

    // Outer glow
    canvas.drawCircle(center, r + 5, Paint()
      ..color = color.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));

    // Core body - hexagon shape
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (pi / 3 * i) - pi / 6;
      final x = center.dx + cos(angle) * r;
      final y = center.dy + sin(angle) * r;
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    path.close();

    // Gradient fill
    canvas.drawPath(path, Paint()
      ..shader = RadialGradient(
        colors: [Colors.white.withOpacity(0.9), color],
        center: const Alignment(-0.3, -0.3),
      ).createShader(Rect.fromCircle(center: center, radius: r)));

    // Inner highlight
    canvas.drawCircle(center - Offset(r * 0.25, r * 0.25), r * 0.3, Paint()
      ..color = Colors.white.withOpacity(0.4));
  }

  // Trail not needed separately since player draws itself
  void _drawTrail(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(GamePainter old) => true;
}
