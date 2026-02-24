import 'package:flutter/material.dart';
import '../../models/game_models.dart';
import '../../utils/safe_color.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BULLET PAINTER — Physically grounded projectiles
// Rule: each bullet has ONE justified glow (the hot tip / plasma core).
// Everything else is matte metal / translucent energy shaft with NO blur.
// Trails are painted with a simple gradient, not a blur stack.
// ─────────────────────────────────────────────────────────────────────────────

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
// Slim tungsten dart. Trail = gradient oval. Tip = one small glow.
void _drawNeedle(Canvas canvas, double cx, double cy, Color color, Paint paint) {
  // Motion trail — gradient, no blur
  paint.shader = LinearGradient(
    colors: [Colors.transparent, color.o(0.35)],
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
  ).createShader(Rect.fromCenter(center: Offset(cx, cy + 6), width: 3, height: 16));
  canvas.drawOval(
    Rect.fromCenter(center: Offset(cx, cy + 5), width: 3, height: 14),
    paint,
  );
  paint.shader = null;

  // Shaft — crisp, no blur
  paint.color = color;
  canvas.drawOval(
    Rect.fromCenter(center: Offset(cx, cy), width: 2.2, height: 12),
    paint,
  );

  // Hot tip — single tight glow (one blur is justified here)
  paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
  paint.color = Colors.white.o(0.9);
  canvas.drawCircle(Offset(cx, cy - 6), 2.2, paint);
  paint.maskFilter = null;
  paint.color = Colors.white;
  canvas.drawCircle(Offset(cx, cy - 6), 1.2, paint);
}

// ── NOVA: Plasma bolt ─────────────────────────────────────────────────────
// Energy sphere with comet tail. Core = one glow. Tail = gradient only.
void _drawPlasma(Canvas canvas, double cx, double cy, Color color, Paint paint) {
  // Comet tail — gradient, no blur
  paint.shader = LinearGradient(
    colors: [Colors.transparent, color.o(0.5)],
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
  ).createShader(
      Rect.fromCenter(center: Offset(cx, cy + 5), width: 7, height: 13));
  canvas.drawOval(
    Rect.fromCenter(center: Offset(cx, cy + 5), width: 7, height: 12),
    paint,
  );
  paint.shader = null;

  // Orb body — radial gradient, no blur
  paint.shader = RadialGradient(
    colors: [Colors.white, color, color.o(0.6)],
  ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 5.5));
  canvas.drawCircle(Offset(cx, cy), 5.5, paint);
  paint.shader = null;

  // Hot centre — one tight glow
  paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  paint.color = Colors.white.o(0.8);
  canvas.drawCircle(Offset(cx, cy - 1), 2, paint);
  paint.maskFilter = null;
}

// ── INFERNO: Artillery shell ──────────────────────────────────────────────
// Metallic casing, no fire-wake blur — just a gradient tail.
void _drawShell(Canvas canvas, double cx, double cy, Color color, Paint paint) {
  // Propellant tail — gradient oval, no blur
  paint.shader = LinearGradient(
    colors: [Colors.transparent, color.o(0.45)],
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
  ).createShader(Rect.fromCenter(center: Offset(cx, cy + 8), width: 6, height: 14));
  canvas.drawOval(
    Rect.fromCenter(center: Offset(cx, cy + 7), width: 6, height: 13),
    paint,
  );
  paint.shader = null;

  // Shell body — metallic gradient, sharp
  paint.shader = const LinearGradient(
    colors: [Color(0xFFCCCCCC), Color(0xFF666666), Color(0xFF222222)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ).createShader(Rect.fromCenter(center: Offset(cx, cy + 1), width: 7, height: 14));
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + 1), width: 6.5, height: 12),
      const Radius.circular(2),
    ),
    paint,
  );
  paint.shader = null;

  // Copper warhead tip — just a gradient, no blur
  paint.shader = LinearGradient(
    colors: [color, const Color(0xFFAA3300)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ).createShader(Rect.fromCenter(center: Offset(cx, cy - 5.5), width: 6.5, height: 9));
  canvas.drawOval(
    Rect.fromCenter(center: Offset(cx, cy - 5), width: 6.5, height: 9),
    paint,
  );
  paint.shader = null;

  // Specular gleam on tip — no blur needed, just bright dot
  paint.color = Colors.white.o(0.6);
  canvas.drawCircle(Offset(cx - 1.5, cy - 7.5), 1.3, paint);

  // Base band
  paint.color = const Color(0xFF888888);
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 1.5;
  canvas.drawLine(Offset(cx - 3, cy + 6), Offset(cx + 3, cy + 6), paint);
  paint.style = PaintingStyle.fill;
}

// ── SPECTER: Ghost beam ───────────────────────────────────────────────────
// Translucent shaft, no stacked blurs. Semi-transparent is enough.
void _drawBeam(Canvas canvas, double cx, double cy, Color color, Paint paint) {
  // Outer shaft — translucent gradient, NO blur
  paint.shader = LinearGradient(
    colors: [
      Colors.transparent,
      color.o(0.45),
      Colors.transparent,
    ],
    stops: const [0.0, 0.5, 1.0],
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
  ).createShader(Rect.fromCenter(center: Offset(cx, cy), width: 6, height: 24));
  canvas.drawOval(
    Rect.fromCenter(center: Offset(cx, cy), width: 6, height: 24),
    paint,
  );
  paint.shader = null;

  // Inner bright core — no blur, just semi-transparent white
  paint.color = Colors.white.o(0.42);
  canvas.drawOval(
    Rect.fromCenter(center: Offset(cx, cy), width: 2.5, height: 16),
    paint,
  );

  // Leading tip — one glow
  paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  paint.color = color.o(0.7);
  canvas.drawCircle(Offset(cx, cy - 11), 2.5, paint);
  paint.maskFilter = null;
}

// ── TITAN: Cannon ball ────────────────────────────────────────────────────
// Dense metal sphere. Physical shading. One glow: the energy core ring.
void _drawCannon(Canvas canvas, double cx, double cy, Color color, Paint paint) {
  // Wake — gradient oval, no blur
  paint.shader = LinearGradient(
    colors: [Colors.transparent, color.o(0.30)],
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
  ).createShader(
      Rect.fromCenter(center: Offset(cx, cy + 7), width: 10, height: 12));
  canvas.drawOval(
    Rect.fromCenter(center: Offset(cx, cy + 7), width: 10, height: 11),
    paint,
  );
  paint.shader = null;

  // Metallic sphere — radial gradient gives 3D feel without any blur
  paint.shader = const RadialGradient(
    colors: [Color(0xFF9A9AAC), Color(0xFF404050), Color(0xFF0C0C14)],
    center: Alignment(-0.35, -0.35),
  ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 7));
  canvas.drawCircle(Offset(cx, cy), 7, paint);
  paint.shader = null;

  // Specular highlight — crisp, no blur
  paint.color = Colors.white.o(0.5);
  canvas.drawCircle(Offset(cx - 2.5, cy - 2.5), 2.2, paint);

  // Energy core ring — this IS glowing, one tight blur
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 1.8;
  paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  paint.color = color.o(0.85);
  canvas.drawCircle(Offset(cx, cy), 4.5, paint);
  paint.maskFilter = null;
  paint.style = PaintingStyle.fill;
}
