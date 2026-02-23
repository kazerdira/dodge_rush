import 'package:flutter/material.dart';
import 'ship_painter_helpers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TITAN — Massive Dreadnought / Carrier
// Boxy military-grey hull with thick armour plates, riveted seams, and
// illuminated windows. NO ambient glows — only tiny window lights and
// engine exhaust. Think battleship, not disco ball.
// Light: top-left.
// ─────────────────────────────────────────────────────────────────────────────
void drawTitanShip(Canvas canvas, double r, Color color, double animTick) {
  final paint = Paint()..style = PaintingStyle.fill;

  // ── MAIN HULL ─────────────────────────────────────────────────────────────
  final hull = Path()
    ..moveTo(-r * 0.58, -r * 1.08)
    ..lineTo(r * 0.58, -r * 1.08)
    ..lineTo(r * 0.88, -r * 0.58)
    ..lineTo(r * 0.88, r * 0.48)
    ..lineTo(r * 1.18, r * 0.78)
    ..lineTo(r * 0.78, r * 1.08)
    ..lineTo(-r * 0.78, r * 1.08)
    ..lineTo(-r * 1.18, r * 0.78)
    ..lineTo(-r * 0.88, r * 0.48)
    ..lineTo(-r * 0.88, -r * 0.58)
    ..close();

  // Top face (lit)
  final hullTop = Path()
    ..moveTo(-r * 0.58, -r * 1.08)
    ..lineTo(r * 0.58, -r * 1.08)
    ..lineTo(r * 0.88, -r * 0.58)
    ..lineTo(-r * 0.88, -r * 0.58)
    ..close();
  paint.shader = LinearGradient(
    colors: [const Color(0xFF7A7A8C), const Color(0xFF4A4A5C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ).createShader(Rect.fromLTWH(-r * 0.9, -r * 1.1, r * 1.8, r * 0.55));
  canvas.drawPath(hullTop, paint);
  paint.shader = null;

  // Front face (slightly lit)
  paint.color = const Color(0xFF5A5A6A);
  canvas.drawRect(Rect.fromLTWH(-r * 0.88, -r * 0.58, r * 1.76, r * 1.06), paint);

  // Side recessed panels (give depth to the hull sides)
  // Left flange (lit)
  final leftFlange = Path()
    ..moveTo(-r * 0.88, -r * 0.58)
    ..lineTo(-r * 0.88, r * 0.48)
    ..lineTo(-r * 1.18, r * 0.78)
    ..lineTo(-r * 0.78, r * 1.08)
    ..lineTo(-r * 0.78, r * 0.48)
    ..lineTo(-r * 0.58, r * 0.48)
    ..close();
  paint.shader = LinearGradient(
    colors: [const Color(0xFF4E4E5E), const Color(0xFF28282E)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  ).createShader(Rect.fromLTWH(-r * 1.2, -r * 0.6, r * 0.6, r * 1.72));
  canvas.drawPath(leftFlange, paint);
  paint.shader = null;

  // Right flange (shadow)
  final rightFlange = Path()
    ..moveTo(r * 0.88, -r * 0.58)
    ..lineTo(r * 0.88, r * 0.48)
    ..lineTo(r * 1.18, r * 0.78)
    ..lineTo(r * 0.78, r * 1.08)
    ..lineTo(r * 0.78, r * 0.48)
    ..lineTo(r * 0.58, r * 0.48)
    ..close();
  paint.shader = LinearGradient(
    colors: [const Color(0xFF303038), const Color(0xFF181818)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ).createShader(Rect.fromLTWH(r * 0.55, -r * 0.6, r * 0.65, r * 1.72));
  canvas.drawPath(rightFlange, paint);
  paint.shader = null;

  // ── HULL STRUCTURAL RIBS ──────────────────────────────────────────────────
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 1.2;
  paint.color = const Color(0xFF28282E);
  // Horizontal armour bands
  for (final y in [-r * 0.20, r * 0.18, r * 0.56]) {
    canvas.drawLine(Offset(-r * 0.88, y), Offset(r * 0.88, y), paint);
  }
  // Vertical structural members
  for (final x in [-r * 0.55, -r * 0.18, r * 0.18, r * 0.55]) {
    canvas.drawLine(Offset(x, -r * 0.58), Offset(x, r * 1.08), paint);
  }
  // Side panel seams
  paint.strokeWidth = 0.8;
  paint.color = const Color(0xFF1E1E24);
  canvas.drawLine(Offset(-r * 0.88, -r * 0.58), Offset(-r * 0.88, r * 0.48), paint);
  canvas.drawLine(Offset(r * 0.88, -r * 0.58), Offset(r * 0.88, r * 0.48), paint);
  paint.style = PaintingStyle.fill;

  // ── RIVETS — row of small circles along ribs ──────────────────────────────
  paint.color = const Color(0xFF3A3A42);
  for (int i = -3; i <= 3; i++) {
    canvas.drawCircle(Offset(i * r * 0.22, -r * 0.56), r * 0.035, paint);
    canvas.drawCircle(Offset(i * r * 0.22, r * 1.05), r * 0.035, paint);
  }
  // Rivet highlight
  paint.color = Colors.white.withOpacity(0.15);
  for (int i = -3; i <= 3; i++) {
    canvas.drawCircle(Offset(i * r * 0.22 - r * 0.012, -r * 0.574), r * 0.018, paint);
  }

  // ── HULL OUTLINE ──────────────────────────────────────────────────────────
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 1.4;
  paint.color = const Color(0xFF0C0C12);
  canvas.drawPath(hull, paint);
  paint.style = PaintingStyle.fill;

  // ── PORTHOLE WINDOWS — scale illusion ─────────────────────────────────────
  // These make it look massive. Small, tightly controlled — no ambient glow.
  const windowColor = Color(0xFFAACCDD);
  for (int i = -2; i <= 2; i++) {
    final wx = i * r * 0.22;
    for (final wy in [-r * 0.08, r * 0.30]) {
      // Porthole socket
      paint.color = const Color(0xFF1A1A22);
      canvas.drawCircle(Offset(wx, wy), r * 0.065, paint);
      // Window glass — tiny, no glow radius
      paint.color = windowColor.withOpacity(0.85);
      canvas.drawCircle(Offset(wx, wy), r * 0.042, paint);
      // Glare dot — single pixel-size highlight
      paint.color = Colors.white.withOpacity(0.7);
      canvas.drawCircle(Offset(wx - r * 0.015, wy - r * 0.015), r * 0.015, paint);
    }
  }

  // ── COMMAND TOWER / BRIDGE ────────────────────────────────────────────────
  // Raised box — darker base, brighter top face to show height
  paint.color = const Color(0xFF3A3A48);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(-r * 0.26, -r * 0.42, r * 0.52, r * 0.32),
      const Radius.circular(3),
    ),
    paint,
  );
  // Top face of tower (lit)
  paint.color = const Color(0xFF5A5A68);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(-r * 0.24, -r * 0.44, r * 0.48, r * 0.10),
      const Radius.circular(2),
    ),
    paint,
  );
  // Tower outline
  paint.style = PaintingStyle.stroke;
  paint.strokeWidth = 0.8;
  paint.color = const Color(0xFF0C0C14);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(-r * 0.26, -r * 0.42, r * 0.52, r * 0.32),
      const Radius.circular(3),
    ),
    paint,
  );
  paint.style = PaintingStyle.fill;

  // Bridge windows (3 tiny slots on tower)
  paint.color = windowColor.withOpacity(0.75);
  for (int i = -1; i <= 1; i++) {
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(i * r * 0.12, -r * 0.28),
        width: r * 0.08,
        height: r * 0.04,
      ),
      paint,
    );
  }

  // ── ENGINE NOZZLE HOUSINGS ────────────────────────────────────────────────
  final nozzleXs = [-r * 0.58, -r * 0.20, r * 0.20, r * 0.58];
  for (final nx in nozzleXs) {
    paint.color = const Color(0xFF181820);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(nx, r * 1.08), width: r * 0.26, height: r * 0.12),
      paint,
    );
    paint.color = const Color(0xFF242430);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(nx, r * 1.06), width: r * 0.18, height: r * 0.08),
      paint,
    );
  }

  drawEngineFlame(
    canvas,
    r,
    color,
    [
      Offset(-r * 0.58, r * 1.06),
      Offset(-r * 0.20, r * 1.06),
      Offset(r * 0.20, r * 1.06),
      Offset(r * 0.58, r * 1.06),
    ],
    [0.14, 0.14, 0.14, 0.14],
    animTick,
  );
}
