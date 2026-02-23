import 'package:flutter/material.dart';
import 'dart:math';
import '../../providers/game_provider.dart';

// ── OVERLAY PAINTER ──────────────────────────────────────────────────────────
// HUD overlays: danger vignette, sweep warning, near-miss flash, combo flash,
// rampage meter/overlay, and gauntlet progress bar.

void drawDangerVignette(
    Canvas canvas, Size size, GameProvider game, double animTick) {
  final v = game.dangerVignette;
  if (v < 0.02) return;
  final pulse = 0.7 + sin(animTick * 12) * 0.3;
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

void drawSweepWarning(Canvas canvas, Size size, GameProvider game) {
  final f = game.sweepWarningFlash;
  if (f < 0.02) return;
  final barH = size.height * 0.035;
  final paint = Paint()..color = const Color(0xFFFFD60A).withOpacity(f * 0.7);
  canvas.drawRect(Rect.fromLTWH(0, 0, size.width, barH), paint);
  canvas.drawRect(
      Rect.fromLTWH(0, size.height - barH, size.width, barH), paint);
  paint.color = Colors.black.withOpacity(f * 0.5);
  const stripeW = 28.0;
  for (double x = 0; x < size.width; x += stripeW * 2) {
    canvas.drawRect(Rect.fromLTWH(x, 0, stripeW, barH), paint);
    canvas.drawRect(Rect.fromLTWH(x, size.height - barH, stripeW, barH), paint);
  }
}

void drawNearMissFlash(
    Canvas canvas,
    Size size,
    GameProvider game,
    void Function(Canvas, String, Offset, Color, double, {double letterSpacing})
        drawText) {
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
  if (f > 0.5) {
    drawText(
        canvas,
        '✓ NEAR MISS',
        Offset(size.width * 0.5, size.height * 0.42),
        const Color(0xFF00FFD1),
        14,
        letterSpacing: 3);
  }
}

void drawComboFlash(Canvas canvas, Size size, GameProvider game) {
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

void drawRampageOverlay(
    Canvas canvas,
    Size size,
    GameProvider game,
    void Function(Canvas, String, Offset, Color, double, {double letterSpacing})
        drawText) {
  final r = game.rampage;
  if (r.chargeLevel <= 0.01 && !r.isActive) return;

  final barW = size.width * 0.42;
  final barH = 6.0;
  final barX = size.width / 2 - barW / 2;
  final barY = size.height - 88.0;
  final paint = Paint()..style = PaintingStyle.fill;

  if (r.isActive) {
    final pulse = sin(r.flashPhase * 2) * 0.5 + 0.5;
    paint.shader = RadialGradient(
      colors: [
        Colors.transparent,
        Colors.transparent,
        const Color(0xFFFF6B00).withOpacity(0.22 + pulse * 0.14)
      ],
      center: Alignment.center,
      radius: 0.78,
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    paint.shader = null;

    final timeRatio = (r.timer / 10.0).clamp(0.0, 1.0);
    paint.color = const Color(0xFF1A0800).withOpacity(0.8);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(barX, barY, barW, barH), const Radius.circular(3)),
        paint);
    paint.color = Color.lerp(
        const Color(0xFFFF2D55), const Color(0xFFFF8C00), timeRatio)!;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(barX, barY, barW * timeRatio, barH),
            const Radius.circular(3)),
        paint);
    drawText(canvas, 'RAMPAGE', Offset(size.width / 2, barY - 13),
        const Color(0xFFFF6B00), 10,
        letterSpacing: 4);
  } else {
    paint.color = const Color(0xFF1A0800).withOpacity(0.65);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(barX, barY, barW, barH), const Radius.circular(3)),
        paint);
    final filled = r.chargeLevel;
    final barColor = filled >= 1.0
        ? const Color(0xFFFF6B00)
        : const Color(0xFFFF8C00).withOpacity(0.65);
    paint.color = barColor;
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(barX, barY, barW * filled, barH),
            const Radius.circular(3)),
        paint);
    if (filled >= 1.0) {
      final pulse = sin(r.flashPhase) * 0.5 + 0.5;
      drawText(
          canvas,
          '🔥 RAMPAGE READY — TAP',
          Offset(size.width / 2, barY - 13),
          const Color(0xFFFF6B00).withOpacity(0.65 + pulse * 0.35),
          9,
          letterSpacing: 2);
    } else {
      drawText(canvas, 'CHARGE', Offset(size.width / 2, barY - 13),
          const Color(0xFFFF8C00).withOpacity(0.5), 8,
          letterSpacing: 2);
    }
  }
}

void drawGauntletOverlay(
    Canvas canvas,
    Size size,
    GameProvider game,
    void Function(Canvas, String, Offset, Color, double, {double letterSpacing})
        drawText) {
  final paint = Paint()..style = PaintingStyle.fill;

  if (game.escapeFlashTimer > 0) {
    paint.color = Colors.white.withOpacity(game.escapeFlashTimer * 0.85);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  if (!game.gauntletActive || game.escaped) return;

  final progress = (game.gauntletTimer / 30.0).clamp(0.0, 1.0);
  final barW = size.width * 0.68;
  final barX = size.width / 2 - barW / 2;
  const barY = 54.0;

  paint.color = const Color(0xFF150008).withOpacity(0.8);
  canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(barX, barY, barW, 5), const Radius.circular(2)),
      paint);
  paint.color =
      Color.lerp(const Color(0xFFFF2D55), const Color(0xFF00FF88), progress)!;
  canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(barX, barY, barW * progress, 5),
          const Radius.circular(2)),
      paint);

  final secs = (30 - game.gauntletTimer).ceil().clamp(0, 30);
  drawText(canvas, 'ESCAPE IN  ${secs}s', Offset(size.width / 2, barY - 12),
      const Color(0xFFFFD60A), 10,
      letterSpacing: 2);
}
