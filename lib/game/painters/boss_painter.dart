import 'package:flutter/material.dart';
import 'dart:math';
import '../../providers/game_provider.dart';

// ── BOSS PAINTER ─────────────────────────────────────────────────────────────
// Draws the boss ship, HP bar, and boss missiles.

void drawBossShip(
    Canvas canvas,
    Size size,
    GameProvider game,
    double animTick,
    void Function(Canvas, String, Offset, Color, double, {double letterSpacing})
        drawText) {
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
    canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: w * 2.8, height: h * 2.2),
        paint);
    paint.maskFilter = null;
  }

  // Main hull path — angular warship, nose pointing DOWN toward player
  final hull = Path();
  hull.moveTo(0, h * 0.75);
  hull.lineTo(w * 0.45, h * 0.25);
  hull.lineTo(w, -h * 0.2);
  hull.lineTo(w * 0.65, -h * 0.55);
  hull.lineTo(w * 0.18, -h * 0.75);
  hull.lineTo(-w * 0.18, -h * 0.75);
  hull.lineTo(-w * 0.65, -h * 0.55);
  hull.lineTo(-w, -h * 0.2);
  hull.lineTo(-w * 0.45, h * 0.25);
  hull.close();

  // Glow behind hull
  paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 16);
  paint.color =
      const Color(0xFFFF2D55).withOpacity((0.25 + pulse * 0.18) * opacity);
  canvas.drawPath(hull, paint);
  paint.maskFilter = null;

  // Hull fill
  final hullDark = Color.lerp(
      const Color(0xFF1A0005), const Color(0xFF5A0000), 1.0 - hpRatio)!;
  final hullMid = Color.lerp(
      const Color(0xFF080003), const Color(0xFF2A0000), 1.0 - hpRatio)!;
  paint.shader = RadialGradient(
    colors: [hullDark, hullMid, const Color(0xFF030001)],
    center: const Alignment(0.0, -0.2),
    radius: 1.0,
  ).createShader(
      Rect.fromCenter(center: Offset.zero, width: w * 2, height: h * 2));
  paint.color = Colors.white.withOpacity(opacity);
  canvas.drawPath(hull, paint);
  paint.shader = null;

  // Hull outline
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 2.0;
  paint.color =
      const Color(0xFFFF2D55).withOpacity((0.75 + pulse * 0.25) * opacity);
  canvas.drawPath(hull, paint);
  paint.style = PaintingStyle.fill;

  // Engine vents on wings
  for (final dx in [-w * 0.58, w * 0.58]) {
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 10);
    paint.color =
        const Color(0xFF8B0000).withOpacity((0.5 + pulse * 0.5) * opacity);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(dx, -h * 0.5), width: w * 0.28, height: h * 0.2),
        paint);
    paint.maskFilter = null;
    paint.color =
        Color.lerp(const Color(0xFFFF2D55), Colors.white, pulse * 0.4)!
            .withOpacity(opacity);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(dx, -h * 0.5), width: w * 0.15, height: h * 0.1),
        paint);
  }

  // Central cannon barrel pointing DOWN
  paint.color = const Color(0xFF0D0003).withOpacity(opacity);
  canvas.drawRect(
      Rect.fromCenter(
          center: Offset(0, h * 0.35), width: w * 0.14, height: h * 0.45),
      paint);
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 1.2;
  paint.color = const Color(0xFFFF2D55).withOpacity(0.5 * opacity);
  canvas.drawRect(
      Rect.fromCenter(
          center: Offset(0, h * 0.35), width: w * 0.14, height: h * 0.45),
      paint);
  paint.style = PaintingStyle.fill;

  // Cannon tip glow
  if (boss.warningFlash > 0.05) {
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 14);
    paint.color =
        const Color(0xFFFF0040).withOpacity(boss.warningFlash * opacity);
    canvas.drawCircle(Offset(0, h * 0.62), w * 0.1, paint);
    paint.maskFilter = null;
    paint.color = Colors.white.withOpacity(boss.warningFlash * 0.8 * opacity);
    canvas.drawCircle(Offset(0, h * 0.62), w * 0.045, paint);
  }

  // HP bar
  if (!boss.isDead) {
    final barW = w * 1.7;
    final barActualY = -h * 0.95;
    paint.color = const Color(0xFF2A0008).withOpacity(0.85 * opacity);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(0, barActualY), width: barW, height: 5),
            const Radius.circular(2)),
        paint);
    paint.color =
        Color.lerp(const Color(0xFFFF2D55), const Color(0xFF00FF88), hpRatio)!
            .withOpacity(opacity);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset((hpRatio - 1.0) * barW / 2, barActualY),
                width: barW * hpRatio,
                height: 5),
            const Radius.circular(2)),
        paint);

    drawText(canvas, 'IMPERIAL HUNTER', Offset(0, barActualY - 14),
        const Color(0xFFFF2D55).withOpacity(opacity), 9,
        letterSpacing: 3);
  }

  canvas.restore();
}

void drawBossMissiles(Canvas canvas, Size size, GameProvider game) {
  if (game.bossMissiles.isEmpty) return;
  final paint = Paint()..style = PaintingStyle.fill;
  for (final m in game.bossMissiles) {
    if (!m.active) continue;
    final mx = m.x * size.width;
    final my = m.y * size.height;
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    paint.color = m.color.withOpacity(m.life * 0.55);
    canvas.drawCircle(Offset(mx, my), 11, paint);
    paint.maskFilter = null;
    paint.color = m.color.withOpacity(m.life * 0.9);
    canvas.drawCircle(Offset(mx, my), 6, paint);
    paint.color = Colors.white.withOpacity(m.life * 0.9);
    canvas.drawCircle(Offset(mx, my), 3, paint);
    final ang = atan2(m.vy, m.vx);
    paint.color = m.color.withOpacity(m.life * 0.35);
    const trailLen = 18.0;
    canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
              mx - cos(ang) * trailLen * 0.5, my - sin(ang) * trailLen * 0.5),
          width: 5,
          height: trailLen,
        ),
        paint);
  }
  paint.maskFilter = null;
}
