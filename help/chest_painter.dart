import 'package:flutter/material.dart';
import 'dart:math';
import '../../models/game_models.dart';
import '../../theme/app_theme.dart';

/// Renders treasure chests colored by sector palette + reward type.
void drawChests(Canvas canvas, Size size, List<TreasureChest> chests) {
  final paint = Paint()..style = PaintingStyle.fill;
  for (final chest in chests) {
    if (chest.collected) continue;
    final cx = chest.x * size.width;
    final cy = chest.y * size.height;
    final pulse = sin(chest.pulsePhase) * 0.12 + 1.0;
    final float = sin(chest.pulsePhase * 0.8) * 4.0;
    final isBomb = chest.reward == TreasureReward.bomb;
    final isWeapon = chest.reward == TreasureReward.weaponRapid ||
        chest.reward == TreasureReward.weaponSpread ||
        chest.reward == TreasureReward.weaponLaser;

    // Sector palette drives chest base color for non-special chests
    final pal = sectorPalette(chest.sectorIndex);

    Color chestColor;
    String rewardLabel;
    switch (chest.reward) {
      case TreasureReward.slowTime:
        chestColor = AppTheme.slowColor;
        rewardLabel = '⏱';
        break;
      case TreasureReward.extraLife:
        chestColor = AppTheme.danger;
        rewardLabel = '♥';
        break;
      case TreasureReward.coins:
        chestColor = AppTheme.coinColor;
        rewardLabel = '✦${chest.coinAmount}';
        break;
      case TreasureReward.shield:
        chestColor = AppTheme.accentAlt;
        rewardLabel = '◉';
        break;
      case TreasureReward.bomb:
        chestColor = const Color(0xFFFF6B00);
        rewardLabel = '💥';
        break;
      case TreasureReward.weaponRapid:
        chestColor = Colors.yellowAccent;
        rewardLabel = '⚡';
        break;
      case TreasureReward.weaponSpread:
        chestColor = Colors.orangeAccent;
        rewardLabel = '✦';
        break;
      case TreasureReward.weaponLaser:
        chestColor = Colors.redAccent;
        rewardLabel = '⟐';
        break;
    }

    // For non-special chests, blend with sector color
    if (!isBomb && !isWeapon) {
      chestColor = Color.lerp(chestColor, pal.chestColor, 0.35)!;
    }

    canvas.save();
    canvas.translate(cx, cy + float);

    // Outer glow
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, isBomb ? 26 : isWeapon ? 22 : 18);
    paint.color = chestColor.withOpacity(isBomb ? 0.75 : 0.55);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 44 * pulse, height: 36 * pulse),
        const Radius.circular(6),
      ),
      paint,
    );
    paint.maskFilter = null;

    // Chest body (base)
    paint.shader = LinearGradient(
      colors: isBomb
          ? [const Color(0xFF3A1500), const Color(0xFF1A0800), const Color(0xFF0A0400)]
          : isWeapon
              ? [const Color(0xFF1A1A00), const Color(0xFF0D0D00), const Color(0xFF050500)]
              : [
                  Color.lerp(const Color(0xFF8B6914), pal.chestColor, 0.3)!,
                  Color.lerp(const Color(0xFF5C4409), pal.chestColor, 0.2)!,
                  Color.lerp(const Color(0xFF3A2A05), pal.chestColor, 0.1)!,
                ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromCenter(center: const Offset(0, 3), width: 40, height: 24));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, 3), width: 40, height: 22),
        const Radius.circular(4),
      ),
      paint,
    );
    paint.shader = null;

    // Chest lid
    paint.shader = LinearGradient(
      colors: isBomb
          ? [const Color(0xFF5A2200), const Color(0xFF3A1400)]
          : isWeapon
              ? [const Color(0xFF333300), const Color(0xFF1A1A00)]
              : [
                  Color.lerp(const Color(0xFFB8860B), pal.chestColor, 0.4)!,
                  Color.lerp(const Color(0xFF8B6914), pal.chestColor, 0.3)!,
                ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromCenter(center: const Offset(0, -9), width: 40, height: 14));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, -9), width: 40, height: 12),
        const Radius.circular(4),
      ),
      paint,
    );
    paint.shader = null;

    // Metal band
    paint.color = chestColor.withOpacity(0.85);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2.0;
    canvas.drawLine(const Offset(-20, -3), const Offset(20, -3), paint);

    // Corner bands
    paint.strokeWidth = 1.5;
    paint.color = chestColor.withOpacity(0.6);
    canvas.drawLine(const Offset(-20, -14), const Offset(-20, 14), paint);
    canvas.drawLine(const Offset(20, -14), const Offset(20, 14), paint);
    canvas.drawLine(const Offset(0, -14), const Offset(0, 14), paint);

    // Padlock gem
    paint.style = PaintingStyle.fill;
    paint.color = chestColor;
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, isBomb ? 9 : 5);
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
        paint,
      );
    }
    paint.style = PaintingStyle.fill;

    // Bomb chest extra: danger border
    if (isBomb) {
      paint.color = chestColor.withOpacity(0.5);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 1.0;
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: 44 * pulse, height: 36 * pulse),
        paint,
      );
      paint.style = PaintingStyle.fill;
    }

    // Weapon chest extra: lightning bolt pattern on lid
    if (isWeapon) {
      paint.color = chestColor.withOpacity(0.7);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 1.5;
      final boltPath = Path()
        ..moveTo(-4, -14)
        ..lineTo(1, -7)
        ..lineTo(-2, -7)
        ..lineTo(4, 0)
        ..lineTo(-1, -4)
        ..lineTo(3, -4)
        ..lineTo(-4, -14);
      canvas.drawPath(boltPath, paint);
      paint.style = PaintingStyle.fill;
    }

    canvas.restore();

    // Reward label below chest
    final tp = TextPainter(
      text: TextSpan(
        text: rewardLabel,
        style: TextStyle(
          color: chestColor,
          fontSize: chest.reward == TreasureReward.coins ? 9 : 12,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy + float + 20));

    // Special tags
    if (isBomb) {
      final rareTp = TextPainter(
        text: TextSpan(
          text: 'RARE',
          style: TextStyle(color: chestColor.withOpacity(0.8), fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        textDirection: TextDirection.ltr,
      );
      rareTp.layout();
      rareTp.paint(canvas, Offset(cx - rareTp.width / 2, cy + float + 34));
    }
    if (isWeapon) {
      final wepTp = TextPainter(
        text: TextSpan(
          text: 'WEAPON',
          style: TextStyle(color: chestColor.withOpacity(0.8), fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 1.5),
        ),
        textDirection: TextDirection.ltr,
      );
      wepTp.layout();
      wepTp.paint(canvas, Offset(cx - wepTp.width / 2, cy + float + 34));
    }
  }
}
