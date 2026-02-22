import 'package:flutter/material.dart';
import 'dart:math';
import '../../models/game_models.dart';

/// Renders the pulse-gate obstacle: two pillars with energy coils, electric
/// webs across the gap when closing, and the CLEAR / LOCK status label.

void drawPulseGate(Canvas canvas, Size size, Obstacle obs) {
  final openness = (sin(obs.pulsePhase) + 1) / 2;
  final gapHalf = obs.gapHalfWidth * openness * size.width;
  final gapCX = obs.gapCenterX * size.width;
  final wallY = obs.y * size.height;
  final wallH = obs.height * 2.5 * size.height;
  final pulse = sin(obs.pulsePhase * 4) * 0.4 + 0.6;
  final paint = Paint();

  void drawGatePillar(Rect rect, bool isLeft) {
    paint.shader = LinearGradient(
      colors: [
        const Color(0xFF111115),
        const Color(0xFF333344),
        const Color(0xFF0A0A0E)
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(rect);
    canvas.drawRect(rect, paint);
    paint.shader = null;
    paint.color = Colors.black.withOpacity(0.5);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;
    canvas.drawRect(rect, paint);
    canvas.drawLine(Offset(rect.left, rect.top + wallH * 0.3),
        Offset(rect.right, rect.top + wallH * 0.3), paint);
    canvas.drawLine(Offset(rect.left, rect.top + wallH * 0.7),
        Offset(rect.right, rect.top + wallH * 0.7), paint);
    paint.style = PaintingStyle.fill;

    final edgeX = isLeft ? rect.right - 12 : rect.left;
    final coilRect = Rect.fromLTWH(edgeX, rect.top + 5, 12, rect.height - 10);
    paint.color = const Color(0xFF1A1A1A);
    canvas.drawRect(coilRect, paint);
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    paint.color = obs.color.withOpacity(0.8 * pulse);
    canvas.drawRect(coilRect.deflate(2), paint);
    paint.maskFilter = null;
    paint.color = Colors.white.withOpacity(0.8);
    for (double y = coilRect.top + 4; y < coilRect.bottom; y += 8) {
      canvas.drawRect(
          Rect.fromLTWH(coilRect.left, y, coilRect.width, 2), paint);
    }
  }

  final leftW = gapCX - gapHalf;
  if (leftW > 0) drawGatePillar(Rect.fromLTWH(0, wallY, leftW, wallH), true);
  final rightStart = gapCX + gapHalf;
  if (rightStart < size.width)
    drawGatePillar(
        Rect.fromLTWH(rightStart, wallY, size.width - rightStart, wallH),
        false);

  if (openness < 0.8) {
    final webIntensity = 1.0 - openness;
    paint.strokeWidth = 2.0;
    paint.style = PaintingStyle.stroke;
    for (int i = 0; i < 4; i++) {
      final yOffset = wallY + (wallH * 0.2 * (i + 1));
      final path = Path()..moveTo(gapCX - gapHalf, yOffset);
      for (double x = gapCX - gapHalf; x <= gapCX + gapHalf; x += 10) {
        final erratic = (Random((x * yOffset).floor()).nextDouble() - 0.5) *
            15 *
            webIntensity;
        path.lineTo(x, yOffset + erratic);
      }
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      paint.color = obs.color.withOpacity(webIntensity * pulse);
      canvas.drawPath(path, paint);
      paint.maskFilter = null;
      paint.color = Colors.white.withOpacity(webIntensity * 0.8);
      canvas.drawPath(path, paint);
    }
    paint.style = PaintingStyle.fill;
  }

  final isOpen = openness > 0.4;
  final textStr = isOpen ? '>>> CLEAR <<<' : '!!! LOCK !!!';
  final textColor = isOpen ? Colors.greenAccent : Colors.redAccent;
  final tp = TextPainter(
    text: TextSpan(
        text: textStr,
        style: TextStyle(
            color: textColor.withOpacity(0.8),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 2)),
    textDirection: TextDirection.ltr,
  );
  tp.layout();
  tp.paint(canvas, Offset(gapCX - tp.width / 2, wallY - 20));
}
