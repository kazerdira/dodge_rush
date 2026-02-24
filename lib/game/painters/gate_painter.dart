import 'package:flutter/material.dart';
import 'dart:math';
import '../../models/game_models.dart';
import '../../utils/safe_color.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GATE PAINTER — Grounded pulse gate
// Pillars are solid metal housing with a coil recess. Electric arcs in the
// gap are the ONLY glow — they're justified as actual energy discharge.
// ─────────────────────────────────────────────────────────────────────────────

void drawPulseGate(Canvas canvas, Size size, Obstacle obs) {
  final openness = (sin(obs.pulsePhase) + 1) / 2;
  final gapHalf = obs.gapHalfWidth * openness * size.width;
  final gapCX = obs.gapCenterX * size.width;
  final wallY = obs.y * size.height;
  final wallH = obs.height * 2.5 * size.height;
  final paint = Paint();

  // ── PILLAR ────────────────────────────────────────────────────────────────
  void drawGatePillar(Rect rect, bool isLeft) {
    // Main housing — lit top-left vs shadow right
    paint.shader = LinearGradient(
      colors: [const Color(0xFF2A2A38), const Color(0xFF141418), const Color(0xFF080810)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(rect);
    paint.style = PaintingStyle.fill;
    canvas.drawRect(rect, paint);
    paint.shader = null;

    // Structural ribs — engraved horizontal lines
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 0.7;
    paint.color = const Color(0xFF0A0A10);
    canvas.drawRect(rect, paint);
    for (double y = rect.top + wallH * 0.25; y < rect.bottom; y += wallH * 0.25) {
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
    }
    paint.style = PaintingStyle.fill;

    // Top-edge specular
    paint.color = Colors.white.o(0.08);
    canvas.drawRect(Rect.fromLTWH(rect.left, rect.top, rect.width, 2), paint);

    // Energy coil recess — inset cavity
    final edgeX = isLeft ? rect.right - 14 : rect.left;
    final coilRect = Rect.fromLTWH(edgeX, rect.top + 6, 14, rect.height - 12);

    // Coil cavity — dark inset
    paint.color = const Color(0xFF050508);
    canvas.drawRect(coilRect, paint);

    // Coil bars — lit metal rings
    paint.color = Colors.grey.shade700.o(0.9);
    for (double y = coilRect.top + 5; y < coilRect.bottom; y += 9) {
      canvas.drawRect(Rect.fromLTWH(coilRect.left + 1, y, coilRect.width - 2, 2.5), paint);
      // Top sheen on each bar
      paint.color = Colors.white.o(0.25);
      canvas.drawRect(Rect.fromLTWH(coilRect.left + 1, y, coilRect.width - 2, 0.8), paint);
      paint.color = Colors.grey.shade700.o(0.9);
    }

    // Coil active glow — energised core, one controlled blur
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    paint.color = obs.color.o(0.65);
    canvas.drawRect(coilRect.deflate(3), paint);
    paint.maskFilter = null;
  }

  final leftW = gapCX - gapHalf;
  if (leftW > 0) drawGatePillar(Rect.fromLTWH(0, wallY, leftW, wallH), true);
  final rightStart = gapCX + gapHalf;
  if (rightStart < size.width) {
    drawGatePillar(
      Rect.fromLTWH(rightStart, wallY, size.width - rightStart, wallH),
      false,
    );
  }

  // ── ELECTRIC ARCS in the gap when closing ────────────────────────────────
  // These are justified glows — actual energy discharge
  if (openness < 0.75) {
    final webIntensity = (1.0 - openness / 0.75).clamp(0.0, 1.0);
    paint.style = PaintingStyle.stroke;

    for (int i = 0; i < 3; i++) {
      final yOffset = wallY + wallH * (0.22 + i * 0.22);
      final path = Path()..moveTo(gapCX - gapHalf, yOffset);
      for (double x = gapCX - gapHalf; x <= gapCX + gapHalf; x += 8) {
        final erratic = (Random((x * yOffset * (i + 1)).floor()).nextDouble() - 0.5) * 12 * webIntensity;
        path.lineTo(x, yOffset + erratic);
      }
      // Outer glow
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      paint.strokeWidth = 2.5;
      paint.color = obs.color.o(webIntensity * 0.55);
      canvas.drawPath(path, paint);
      paint.maskFilter = null;
      // Crisp white core
      paint.strokeWidth = 1.0;
      paint.color = Colors.white.o(webIntensity * 0.75);
      canvas.drawPath(path, paint);
    }
    paint.style = PaintingStyle.fill;
  }

  // ── STATUS LABEL ──────────────────────────────────────────────────────────
  final isOpen = openness > 0.4;
  final tp = TextPainter(
    text: TextSpan(
      text: isOpen ? '>>> CLEAR <<<' : '!!! LOCK !!!',
      style: TextStyle(
        color: (isOpen ? Colors.greenAccent : Colors.redAccent).o(0.75),
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  tp.layout();
  tp.paint(canvas, Offset(gapCX - tp.width / 2, wallY - 20));
}
