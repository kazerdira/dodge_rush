import 'package:flutter/material.dart';
import '../../models/game_models.dart';

/// Draws each bullet with the shape tied to its originating ship.
void drawBullets(Canvas canvas, Size size, List<Bullet> bullets) {
  final paint = Paint()..style = PaintingStyle.fill;
  for (final b in bullets) {
    if (!b.active) continue;
    final cx = b.x * size.width;
    final cy = b.y * size.height;
    switch (b.shape) {
      case BulletShape.needle:
        _drawNeedle(canvas, cx, cy, b.color, paint);
        break;
      case BulletShape.plasma:
        _drawPlasma(canvas, cx, cy, b.color, paint);
        break;
      case BulletShape.shell:
        _drawShell(canvas, cx, cy, b.color, paint);
        break;
      case BulletShape.beam:
        _drawBeam(canvas, cx, cy, b.color, paint);
        break;
      case BulletShape.cannon:
        _drawCannon(canvas, cx, cy, b.color, paint);
        break;
    }
  }
  paint.maskFilter = null;
}

// ── PHANTOM: Precision needle ─────────────────────────────────────────────
// Slim cyan lance — very fast, bright white tip
void _drawNeedle(
    Canvas canvas, double cx, double cy, Color color, Paint paint) {
  // Outer glow
  paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
  paint.color = color.withOpacity(0.45);
  canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: 5, height: 20), paint);
  paint.maskFilter = null;
  // Core shaft
  paint.color = color;
  canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: 2.5, height: 14), paint);
  // Hot tip
  paint.color = Colors.white;
  canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy - 5), width: 2.5, height: 6),
      paint);
  // Tip bright point
  paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  paint.color = Colors.white;
  canvas.drawCircle(Offset(cx, cy - 8), 2.5, paint);
  paint.maskFilter = null;
}

// ── NOVA: Plasma blob ─────────────────────────────────────────────────────
// Wide glowing energy sphere that tapers into a comet tail
void _drawPlasma(
    Canvas canvas, double cx, double cy, Color color, Paint paint) {
  // Soft outer glow
  paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
  paint.color = color.withOpacity(0.4);
  canvas.drawCircle(Offset(cx, cy), 8, paint);
  paint.maskFilter = null;
  // Comet tail
  paint.shader = LinearGradient(
    colors: [color.withOpacity(0.0), color.withOpacity(0.6)],
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
  ).createShader(
      Rect.fromCenter(center: Offset(cx, cy + 6), width: 8, height: 14));
  canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 5), width: 8, height: 12), paint);
  paint.shader = null;
  // Core orb
  paint.shader = RadialGradient(
    colors: [Colors.white, color, color.withOpacity(0.5)],
  ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 6));
  canvas.drawCircle(Offset(cx, cy), 6, paint);
  paint.shader = null;
  // Center sparkle
  paint.color = Colors.white;
  canvas.drawCircle(Offset(cx, cy - 1), 2.5, paint);
}

// ── INFERNO: Heavy shell ──────────────────────────────────────────────────
// Thick orange artillery round with metallic casing and fire wake
void _drawShell(Canvas canvas, double cx, double cy, Color color, Paint paint) {
  // Fire wake
  paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
  paint.color = const Color(0xFFFF4400).withOpacity(0.5);
  canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 8), width: 10, height: 16),
      paint);
  paint.maskFilter = null;
  // Shell body — dark metallic
  paint.shader = LinearGradient(
    colors: [
      const Color(0xFFCCCCDD),
      const Color(0xFF555566),
      const Color(0xFF222233)
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ).createShader(Rect.fromCenter(center: Offset(cx, cy), width: 8, height: 16));
  canvas.drawRRect(
    RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + 2), width: 7, height: 13),
        const Radius.circular(3)),
    paint,
  );
  paint.shader = null;
  // Tip — copper/bronze warhead
  paint.shader = LinearGradient(
    colors: [color, const Color(0xFFCC4400)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ).createShader(
      Rect.fromCenter(center: Offset(cx, cy - 6), width: 7, height: 8));
  canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy - 5), width: 7, height: 10), paint);
  paint.shader = null;
  // Tip gleam
  paint.color = Colors.white.withOpacity(0.6);
  canvas.drawCircle(Offset(cx - 1.5, cy - 8), 1.5, paint);
  // Propellant ring
  paint.color = const Color(0xFF888899);
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 1.5;
  canvas.drawLine(Offset(cx - 3.5, cy + 5), Offset(cx + 3.5, cy + 5), paint);
  paint.style = PaintingStyle.fill;
}

// ── SPECTER: Ghost beam ───────────────────────────────────────────────────
// Semi-transparent flickering column with ethereal wisps on the sides
void _drawBeam(Canvas canvas, double cx, double cy, Color color, Paint paint) {
  // Outer spectral aura
  paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
  paint.color = color.withOpacity(0.30);
  canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: 14, height: 28), paint);
  paint.maskFilter = null;

  // Transparent beam shaft
  paint.shader = LinearGradient(
    colors: [
      color.withOpacity(0.0),
      color.withOpacity(0.55),
      color.withOpacity(0.0)
    ],
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
  ).createShader(Rect.fromCenter(center: Offset(cx, cy), width: 6, height: 26));
  canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: 6, height: 26), paint);
  paint.shader = null;

  // Inner bright core (semi-translucent)
  paint.color = Colors.white.withOpacity(0.50);
  canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: 3, height: 18), paint);

  // Side wisps (2 small orbs floating alongside)
  for (final offset in [-7.0, 7.0]) {
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    paint.color = color.withOpacity(0.35);
    canvas.drawCircle(Offset(cx + offset, cy + 4), 3, paint);
    paint.maskFilter = null;
  }

  // Top dissolve
  paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
  paint.color = Colors.white.withOpacity(0.4);
  canvas.drawCircle(Offset(cx, cy - 12), 3, paint);
  paint.maskFilter = null;
}

// ── TITAN: Heavy cannon ball ──────────────────────────────────────────────
// Big metal sphere with a glowing energy core and trailing shockwave ring
void _drawCannon(
    Canvas canvas, double cx, double cy, Color color, Paint paint) {
  // Distant wake glow
  paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
  paint.color = color.withOpacity(0.35);
  canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 6), width: 16, height: 14),
      paint);
  paint.maskFilter = null;

  // Metallic sphere body
  paint.shader = RadialGradient(
    colors: [
      const Color(0xFF888899),
      const Color(0xFF333344),
      const Color(0xFF0A0A14)
    ],
    center: const Alignment(-0.3, -0.3),
  ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 7));
  canvas.drawCircle(Offset(cx, cy), 7, paint);
  paint.shader = null;

  // Glowing energy core ring
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 2.0;
  paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
  paint.color = color.withOpacity(0.85);
  canvas.drawCircle(Offset(cx, cy), 5, paint);
  paint.maskFilter = null;
  paint.style = PaintingStyle.fill;

  // Trailing shockwave ring (flat ellipse behind)
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 1.5;
  paint.color = color.withOpacity(0.40);
  canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 9), width: 14, height: 4), paint);
  paint.style = PaintingStyle.fill;

  // Specular highlight
  paint.color = Colors.white.withOpacity(0.55);
  canvas.drawCircle(Offset(cx - 2.5, cy - 2.5), 2.5, paint);

  // Inner glow dot
  paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  paint.color = color.withOpacity(0.9);
  canvas.drawCircle(Offset(cx, cy), 3, paint);
  paint.maskFilter = null;
}
