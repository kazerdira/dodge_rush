import 'package:flutter/material.dart';
import 'dart:math';
import '../../models/game_models.dart';
import '../../theme/app_theme.dart';
import '../../utils/safe_color.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CHEST PAINTER — Grounded, readable treasure chests
// Philosophy: A treasure chest should look like a PHYSICAL OBJECT floating
// in space, not a glowing blob. The gem/lock is the single light source.
// Top face lit, bottom in shadow. Metal bands are brushed steel.
// ─────────────────────────────────────────────────────────────────────────────

void drawChests(Canvas canvas, Size size, List<TreasureChest> chests) {
  final paint = Paint()..style = PaintingStyle.fill;
  for (final chest in chests) {
    if (chest.collected) continue;
    final cx = chest.x * size.width;
    final cy = chest.y * size.height;
    // Gentle float — keep it but reduce amplitude
    final float = sin(chest.pulsePhase * 0.8) * 2.5;
    final isBomb = chest.reward == TreasureReward.bomb;
    final isWeapon = chest.reward == TreasureReward.weaponRapid ||
        chest.reward == TreasureReward.weaponSpread ||
        chest.reward == TreasureReward.weaponLaser;

    final pal = sectorPalette(chest.sectorIndex);

    Color gemColor;
    String rewardLabel;
    switch (chest.reward) {
      case TreasureReward.slowTime:
        gemColor = AppTheme.slowColor;
        rewardLabel = '⏱';
        break;
      case TreasureReward.extraLife:
        gemColor = AppTheme.danger;
        rewardLabel = '♥';
        break;
      case TreasureReward.coins:
        gemColor = AppTheme.coinColor;
        rewardLabel = '✦${chest.coinAmount}';
        break;
      case TreasureReward.shield:
        gemColor = AppTheme.accentAlt;
        rewardLabel = '◉';
        break;
      case TreasureReward.bomb:
        gemColor = const Color(0xFFFF6B00);
        rewardLabel = '💥';
        break;
      case TreasureReward.weaponRapid:
        gemColor = Colors.yellowAccent;
        rewardLabel = '⚡';
        break;
      case TreasureReward.weaponSpread:
        gemColor = Colors.orangeAccent;
        rewardLabel = '✦';
        break;
      case TreasureReward.weaponLaser:
        gemColor = Colors.redAccent;
        rewardLabel = '⟐';
        break;
    }

    if (!isBomb && !isWeapon) {
      gemColor = Color.lerp(gemColor, pal.chestColor, 0.30)!;
    }

    canvas.save();
    canvas.translate(cx, cy + float);

    // ── SUBTLE FLOOR SHADOW (not a bloom — a contact shadow below the chest)
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    paint.color = Colors.black.o(0.35);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 22), width: 36, height: 6),
      paint,
    );
    paint.maskFilter = null;

    // ── CHEST BODY ────────────────────────────────────────────────────────
    // Dark base wood/metal color derived from isBomb/isWeapon/sector
    final bodyBase = isBomb
        ? const Color(0xFF3A1500)
        : isWeapon
            ? const Color(0xFF1A1A00)
            : Color.lerp(const Color(0xFF6B4E12), pal.chestColor, 0.25)!;

    // Bottom box
    paint.shader = LinearGradient(
      colors: [
        Color.lerp(bodyBase, Colors.white, 0.08)!, // top edge of box (slightly lit)
        bodyBase,
        Color.lerp(bodyBase, Colors.black, 0.40)!, // bottom in shadow
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(
      Rect.fromCenter(center: const Offset(0, 6), width: 40, height: 22),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, 6), width: 40, height: 20),
        const Radius.circular(3),
      ),
      paint,
    );
    paint.shader = null;

    // ── LID ───────────────────────────────────────────────────────────────
    final lidBase = Color.lerp(bodyBase, Colors.white, 0.15)!;
    paint.shader = LinearGradient(
      colors: [
        Color.lerp(lidBase, Colors.white, 0.22)!, // front top face (top-lit)
        lidBase,
        Color.lerp(lidBase, Colors.black, 0.18)!,
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(
      Rect.fromCenter(center: const Offset(0, -7), width: 40, height: 14),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, -7), width: 40, height: 12),
        const Radius.circular(3),
      ),
      paint,
    );
    paint.shader = null;

    // ── METAL BANDS ───────────────────────────────────────────────────────
    // Brushed steel look — gradient from slightly lighter to darker
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2.2;
    paint.shader = LinearGradient(
      colors: [
        Colors.grey.shade400.o(0.85),
        Colors.grey.shade700.o(0.85),
      ],
    ).createShader(const Rect.fromLTWH(-20, -3, 40, 4));
    canvas.drawLine(const Offset(-20, -3), const Offset(20, -3), paint);
    paint.shader = null;

    paint.strokeWidth = 1.5;
    paint.color = Colors.grey.shade600.o(0.70);
    canvas.drawLine(const Offset(-20, -13), const Offset(-20, 13), paint);
    canvas.drawLine(const Offset(20, -13), const Offset(20, 13), paint);
    canvas.drawLine(const Offset(0, -13), const Offset(0, 13), paint);
    paint.style = PaintingStyle.fill;

    // Band rivet nubs at band/corner intersections
    paint.color = Colors.grey.shade400.o(0.6);
    for (final bx in [-20.0, 0.0, 20.0]) {
      canvas.drawCircle(Offset(bx, -3), 1.5, paint);
      canvas.drawCircle(Offset(bx, 13), 1.5, paint);
    }

    // ── GEM / PADLOCK ─────────────────────────────────────────────────────
    // Socket
    paint.color = Colors.black.o(0.7);
    canvas.drawCircle(Offset.zero, 6.5, paint);

    // Gem body — radial gradient (jewel-like, physically real)
    paint.shader = RadialGradient(
      colors: [
        Color.lerp(gemColor, Colors.white, 0.5)!,
        gemColor,
        Color.lerp(gemColor, Colors.black, 0.4)!,
      ],
      center: const Alignment(-0.3, -0.35),
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: 5.5));
    canvas.drawCircle(Offset.zero, 5.0, paint);
    paint.shader = null;

    // Gem glint — single bright highlight, no blur needed
    paint.color = Colors.white.o(0.75);
    canvas.drawCircle(const Offset(-1.8, -1.8), 1.5, paint);

    // ── WEAPON CHEST BOLT PATTERN ─────────────────────────────────────────
    if (isWeapon) {
      paint.color = gemColor.o(0.60);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 1.5;
      final bolt = Path()
        ..moveTo(-3.5, -13)
        ..lineTo(1, -7)
        ..lineTo(-2, -7)
        ..lineTo(3.5, -1)
        ..lineTo(-1, -5)
        ..lineTo(2.5, -5)
        ..lineTo(-3.5, -13);
      canvas.drawPath(bolt, paint);
      paint.style = PaintingStyle.fill;
    }

    // ── DANGER BORDER for bomb ────────────────────────────────────────────
    if (isBomb) {
      paint.color = gemColor.o(0.40);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 1.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 44, height: 36),
          const Radius.circular(5),
        ),
        paint,
      );
      paint.style = PaintingStyle.fill;
    }

    canvas.restore();

    // Reward label below
    final tp = TextPainter(
      text: TextSpan(
        text: rewardLabel,
        style: TextStyle(
          color: gemColor,
          fontSize: chest.reward == TreasureReward.coins ? 9 : 11,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy + float + 19));

    if (isBomb) {
      _smallTag(canvas, 'RARE', cx, cy + float + 32, gemColor);
    }
    if (isWeapon) {
      _smallTag(canvas, 'WEAPON', cx, cy + float + 32, gemColor);
    }
  }
}

void _smallTag(Canvas canvas, String text, double cx, double cy, Color color) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color.o(0.75),
        fontSize: 7,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  tp.layout();
  tp.paint(canvas, Offset(cx - tp.width / 2, cy));
}
