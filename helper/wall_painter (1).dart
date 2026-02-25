import 'package:flutter/material.dart';
import 'dart:math';
import '../../models/game_models.dart';
import '../../utils/safe_color.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WALL PAINTER — Living Space Station Cross-Section  (3-D Enhanced)
//
// Every wall is a SLICE through a real structure.  Visible layers:
//   outer hull skin → structural frame → interior room → floor/ceiling strips
//
// 3-D techniques used:
//   • Hull plates: top-left bright bevel, bottom-right dark bevel + drop shadow
//   • Layered armour plates: offset rectangles with shadow gaps between them
//   • I-beams: true H cross-section (3 rects) with per-face lighting
//   • Pipes: strong cylindrical gradient + specular catch-light + cast shadow
//   • Recessed rooms: inset border that reads as depth
//   • All surfaces have a bright highlight edge and dark shadow edge
//
// GPU safety: ALL MaskFilter.blur radii <= 10 (Adreno safe).
//   HP bar glow: 2  |  Interior bloom: <= 5  |  Death flash: <= 10
// ─────────────────────────────────────────────────────────────────────────────

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _hullMid = Color(0xFF262D36);
const Color _hullLight = Color(0xFF3E4A58);
const Color _hullHighest = Color(0xFF5E6E82);
const Color _seamDark = Color(0xFF0C0E11);
const Color _roomFloor = Color(0xFF1C2230);
const Color _roomCeiling = Color(0xFF18202C);
const Color _pipeClean = Color(0xFF2A6090);
const Color _pipeRed = Color(0xFF8B1A1A);
const Color _pipeCopper = Color(0xFF7A4A20);
const Color _pipeCopperLit = Color(0xFFB06830);
const Color _pipeGrey = Color(0xFF3A3E44);
const Color _rivShadow = Color(0xFF07090B);

// ── Entry point ───────────────────────────────────────────────────────────────
void drawLaserWall(
    Canvas canvas, Size size, LaserWallEntity obs, double animTick) {
  final rect = Rect.fromLTWH(
    obs.x * size.width,
    obs.y * size.height,
    obs.width * size.width,
    obs.height * size.height,
  );
  if (!(rect.width > 0 && rect.height > 0)) return;

  final p = Paint();
  final opacity = obs.damageOpacity;
  final tier = obs.wallTier ?? WallTier.standard;
  final td = wallTierData(tier);
  final effectiveColor =
      Color.lerp(td.color, const Color(0xFF446655), obs.greyShift)!;

  // ── DEATH EXPLOSION ──────────────────────────────────────────────────────────
  if (obs.isDying) {
    final t = obs.deathTimer;
    p.maskFilter =
        MaskFilter.blur(BlurStyle.normal, (10 * (1 - t)).clamp(0.1, 10.0));
    p.color = const Color(0xFFFF7722).o(((1.0 - t) * 0.65).clamp(0.0, 0.9999));
    canvas.drawRect(rect.inflate(8 * (1 - t)), p);
    p.maskFilter = null;

    final debrisCount = tier == WallTier.armored
        ? 16
        : tier == WallTier.reinforced
            ? 10
            : tier == WallTier.standard
                ? 6
                : 4;
    final rng = Random(obs.hashCode);
    for (int i = 0; i < debrisCount; i++) {
      final dx = sin(i * 1.7 + t * 10) * 52 * t;
      final dy = -70 * t * (0.3 + i * 0.16) + sin(i * 2.3) * 24 * t;
      final cW = rect.width * (0.04 + rng.nextDouble() * 0.10) * (1 - t);
      final cH = rect.height * (0.40 + rng.nextDouble() * 0.50) * (1 - t);
      p.color = _hullMid.o(((1 - t) * 0.9).clamp(0.0, 0.9999));
      canvas.save();
      canvas.translate(rect.center.dx + dx, rect.center.dy + dy);
      canvas.rotate(t * i * 2.2);
      canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: cW, height: cH), p);
      p.style = PaintingStyle.stroke;
      p.strokeWidth = 1.0;
      p.color = const Color(0xFFFF5500).o(((1 - t) * 0.7).clamp(0.0, 0.9999));
      canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: cW, height: cH), p);
      p.style = PaintingStyle.fill;
      canvas.restore();
    }
    return;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // FRAGILE — Transparent pressurised glass corridor
  //   Cross-section shows: metal top/bottom rails (3-D extruded) | glass interior
  //   with ceiling light fixture | support struts | floor plating | stars visible
  // ─────────────────────────────────────────────────────────────────────────────
  if (tier == WallTier.fragile) {
    final railH = (rect.height * 0.22).clamp(2.0, 9.0);
    final innerRect = Rect.fromLTWH(
        rect.left, rect.top + railH, rect.width, rect.height - railH * 2);

    if (!(innerRect.width > 0 && innerRect.height > 0)) return;

    // ── Glass interior — deep space corridor gradient ──
    p.shader = LinearGradient(
      colors: [
        const Color(0xFF0E1E38),
        const Color(0xFF0A1628),
        const Color(0xFF06101E),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(innerRect);
    canvas.drawRect(innerRect, p);
    p.shader = null;

    // ── Ceiling fluorescent light fixture — extruded housing ──
    final lightW = (innerRect.width * 0.45).clamp(20.0, 120.0);
    final lightH = (innerRect.height * 0.18).clamp(2.0, 7.0);
    final lightRect = Rect.fromLTWH(innerRect.center.dx - lightW / 2,
        innerRect.top, lightW, lightH);
    // Fixture housing — 3-D box with top highlight
    p.color = const Color(0xFF2A3C52).o((0.90 * opacity).clamp(0.0, 0.9999));
    canvas.drawRect(lightRect, p);
    // Fixture top highlight (raised top face)
    p.color = const Color(0xFF4A6080).o((0.55 * opacity).clamp(0.0, 0.9999));
    canvas.drawRect(
        Rect.fromLTWH(lightRect.left, lightRect.top, lightRect.width, 1.2), p);
    // Fixture left highlight
    p.color = const Color(0xFF3A5070).o((0.35 * opacity).clamp(0.0, 0.9999));
    canvas.drawRect(
        Rect.fromLTWH(lightRect.left, lightRect.top, 1.2, lightH), p);
    // Fixture bottom shadow
    p.color = Colors.black.o((0.65 * opacity).clamp(0.0, 0.9999));
    canvas.drawRect(
        Rect.fromLTWH(lightRect.left, lightRect.bottom - 1.2, lightRect.width, 1.2), p);

    // Tube glow inside fixture
    final tubeRect = lightRect.deflate(1.5);
    if (tubeRect.width > 0 && tubeRect.height > 0) {
      p.shader = LinearGradient(
        colors: [
          const Color(0xFFB0D8FF).o((0.80 * opacity).clamp(0.0, 0.9999)),
          const Color(0xFF70A8D8).o((0.60 * opacity).clamp(0.0, 0.9999)),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(tubeRect);
      canvas.drawRect(tubeRect, p);
      p.shader = null;
    }

    // ── Light spill downward from fixture ──
    if (innerRect.height > 5.0) {
      final spillRect = Rect.fromLTWH(
          innerRect.center.dx - lightW * 0.6,
          innerRect.top + lightH,
          lightW * 1.2,
          innerRect.height * 0.55);
      if (spillRect.width > 0 && spillRect.height > 0) {
        p.shader = LinearGradient(
          colors: [
            const Color(0xFF4A78A8).o((0.48 * opacity).clamp(0.0, 0.9999)),
            Colors.transparent.o(0.0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(spillRect);
        canvas.drawRect(spillRect, p);
        p.shader = null;
      }
    }

    // ── Support struts — I-beam cross-sections (H shape) ──
    for (int r = 1; r <= 2; r++) {
      final sx = innerRect.left + innerRect.width * (r / 3.0);
      _drawIBeam(canvas, sx, innerRect.top, innerRect.bottom, p, opacity,
          webW: 1.5, flangeW: 4.0, flangeH: 1.5,
          webColor: const Color(0xFF2E3E52),
          flangeColor: const Color(0xFF3A4E62));
    }

    // ── Floor plating with panel gaps ──
    final floorH = (innerRect.height * 0.18).clamp(2.0, 7.0);
    final floorRect = Rect.fromLTWH(
        innerRect.left, innerRect.bottom - floorH, innerRect.width, floorH);
    if (floorRect.width > 0 && floorRect.height > 0) {
      p.shader = LinearGradient(
        colors: [
          const Color(0xFF1A2436).o(opacity.clamp(0.0, 0.9999)),
          const Color(0xFF0C141E).o(opacity.clamp(0.0, 0.9999)),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(floorRect);
      canvas.drawRect(floorRect, p);
      p.shader = null;
    }
    // Floor raised lip
    p.color = const Color(0xFF4A6882).o((0.45 * opacity).clamp(0.0, 0.9999));
    canvas.drawRect(
        Rect.fromLTWH(floorRect.left, floorRect.top, floorRect.width, 1.2), p);
    // Panel gaps with bevel
    _drawFloorPanelGaps(canvas, floorRect, p, opacity,
        gapColor: const Color(0xFF06090E), panelW: 18.0);
    // Drain grate center
    final drainW = (innerRect.width * 0.12).clamp(8.0, 30.0);
    final drainRect = Rect.fromLTWH(
        innerRect.center.dx - drainW / 2, floorRect.top + 1.0, drainW, floorH - 2.0);
    _drawDrainGrate(canvas, drainRect, p, opacity);

    // ── Cable conduit — horizontal run along mid-height ──
    final conduitY = innerRect.top + innerRect.height * 0.55;
    _drawCableConduit(canvas, innerRect.left + 2, innerRect.right - 2,
        conduitY, p, opacity, color: const Color(0xFF1E2C3E));

    // ── Emergency panel box — right wall ──
    final panelW = (innerRect.width * 0.04).clamp(4.0, 10.0);
    final panelH = (innerRect.height * 0.25).clamp(4.0, 12.0);
    _drawEquipmentBox(canvas,
        Rect.fromLTWH(innerRect.right - panelW - 2,
            innerRect.top + innerRect.height * 0.3, panelW, panelH),
        p, opacity,
        color: const Color(0xFF1A2C1A), accentColor: const Color(0xFF225522));

    // ── Stars visible through glass — damage-reactive ──
    final rng2 = Random(obs.hashCode);
    final isCritical = obs.damageState == DamageState.critical;
    final isDamaged = obs.damageState == DamageState.damaged;
    for (int i = 0; i < 14; i++) {
      final sx = innerRect.left + rng2.nextDouble() * innerRect.width;
      final sy = innerRect.top + rng2.nextDouble() * innerRect.height * 0.75;
      final base = 0.07 + rng2.nextDouble() * 0.16;
      double shimmer;
      if (isCritical) {
        final f = sin(animTick * 6.0 + i * 1.7) * 0.12 +
            sin(animTick * 11.0 + i * 0.9) * 0.08;
        final winkOut = sin(animTick * 17.0 + i * 2.3) > 0.55 ? 0.0 : 1.0;
        shimmer = (base + f) * winkOut;
      } else if (isDamaged) {
        shimmer = base + sin(animTick * 3.5 + i) * 0.08;
      } else {
        shimmer = base + sin(animTick * 1.5 + i) * 0.05;
      }
      p.color = Colors.white.o((shimmer * opacity).clamp(0.0, 0.9999));
      canvas.drawCircle(Offset(sx, sy), 0.6, p);
    }

    // ── Top rail — 3-D extruded metal bar ──
    _draw3DRail(canvas, Rect.fromLTWH(rect.left, rect.top, rect.width, railH),
        p, opacity,
        topColor: const Color(0xFF3E5068),
        midColor: const Color(0xFF2A3848),
        bottomColor: const Color(0xFF121820));

    // ── Bottom rail ──
    _draw3DRail(canvas,
        Rect.fromLTWH(rect.left, rect.bottom - railH, rect.width, railH),
        p, opacity,
        topColor: const Color(0xFF2C3E50),
        midColor: const Color(0xFF1E2C3A),
        bottomColor: const Color(0xFF0C141E));

    // Rail/glass seam engraving
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 0.8;
    p.color = _seamDark.o(opacity.clamp(0.0, 0.9999));
    canvas.drawLine(Offset(rect.left, rect.top + railH),
        Offset(rect.right, rect.top + railH), p);
    canvas.drawLine(Offset(rect.left, rect.bottom - railH),
        Offset(rect.right, rect.bottom - railH), p);
    p.color = _hullHighest.o((0.20 * opacity).clamp(0.0, 0.9999));
    canvas.drawLine(Offset(rect.left, rect.top + railH + 1.2),
        Offset(rect.right, rect.top + railH + 1.2), p);
    p.style = PaintingStyle.fill;

    _draw3DRivets(canvas, rect, p, opacity,
        rivetColor: const Color(0xFF38465A),
        highlightColor: const Color(0xFF8AAAC8),
        spacing: 22.0,
        railOffset: railH * 0.48);
    _drawHpBar(canvas, rect, obs, effectiveColor, opacity);
    return;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // STANDARD — Brushed steel military hull cross-section
  //   Layers: outer hull skin (3-D plates) | ceiling strip | interior room
  //           (recessed) | floor plate | blue coolant pipe | viewport slit
  //           I-beam ribs visible on hull face
  // ─────────────────────────────────────────────────────────────────────────────
  if (tier == WallTier.standard) {
    final skinT = (rect.height * 0.15).clamp(3.0, 10.0);
    final floorT = (rect.height * 0.17).clamp(3.0, 10.0);
    final ceilT = (rect.height * 0.12).clamp(2.0, 8.0);
    final roomRect = Rect.fromLTWH(
      rect.left + skinT,
      rect.top + skinT + ceilT,
      rect.width - skinT * 2,
      rect.height - skinT * 2 - ceilT - floorT,
    );

    // ── Outer hull — layered plates with shadow gaps ──
    _draw3DHullBody(canvas, rect, p, opacity,
        topColor: const Color(0xFF2A3240),
        midColor: const Color(0xFF1E2830),
        bottomColor: const Color(0xFF10151E));

    _drawLayeredPlates(canvas, rect, p, opacity,
        plateColor: const Color(0xFF24303E),
        highlightColor: const Color(0xFF3A4A5E),
        shadowColor: const Color(0xFF0A0E14),
        plateCount: 3);

    _drawPanelSeams(canvas, rect, p, opacity, spacing: 38.0);

    // ── Hull I-beam ribs on face ──
    final ribStep = (rect.width / 5).clamp(15.0, 50.0);
    for (double x = rect.left + ribStep; x < rect.right - ribStep * 0.4; x += ribStep) {
      _drawIBeam(canvas, x, rect.top + skinT * 0.3, rect.bottom - skinT * 0.3,
          p, opacity,
          webW: 2.0, flangeW: 6.0, flangeH: 2.0,
          webColor: const Color(0xFF1C2636),
          flangeColor: const Color(0xFF2A3A4E));
    }

    // ── Ceiling strip ──
    final ceilRect = Rect.fromLTWH(
        rect.left + skinT, rect.top + skinT, rect.width - skinT * 2, ceilT);
    if (ceilRect.width > 0 && ceilRect.height > 0) {
      p.shader = LinearGradient(
        colors: [const Color(0xFF1A2230), const Color(0xFF0E1620)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(ceilRect);
      canvas.drawRect(ceilRect, p);
      p.shader = null;
      // Pipe runs in ceiling
      if (ceilT > 3.5) {
        _drawSmallPipe(canvas, ceilRect.left + 4, ceilRect.right - 4,
            ceilRect.center.dy - 1.0, p, opacity,
            r: (ceilT * 0.30).clamp(1.0, 3.5),
            pipeColor: _pipeClean, litColor: const Color(0xFF4080B0));
        _drawSmallPipe(canvas, ceilRect.left + 4, ceilRect.right - 4,
            ceilRect.center.dy + (ceilT * 0.22).clamp(1.0, 3.0), p, opacity,
            r: (ceilT * 0.18).clamp(0.8, 2.5),
            pipeColor: _pipeGrey, litColor: const Color(0xFF5A6070));
      }
    }
    p.color = const Color(0xFF4A6888).o((0.48 * opacity).clamp(0.0, 0.9999));
    if (ceilRect.width > 0) {
      canvas.drawRect(
          Rect.fromLTWH(ceilRect.left, ceilRect.bottom - 1.5, ceilRect.width, 1.5), p);
    }

    // ── Interior room — recessed with depth border ──
    if (roomRect.width > 3.0 && roomRect.height > 3.0) {
      _drawRecessedFrame(canvas, roomRect, p, opacity, depth: 3.0);

      final innerRoom = roomRect.deflate(2.0);
      if (innerRoom.width > 0 && innerRoom.height > 0) {
        p.shader = LinearGradient(
          colors: [
            const Color(0xFF1E2C44),
            const Color(0xFF142038),
            const Color(0xFF0E182C)
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(innerRoom);
        canvas.drawRect(innerRoom, p);
        p.shader = null;

        final spillH = innerRoom.height * 0.45;
        if (spillH > 0 && innerRoom.width > 0) {
          final spillRect = Rect.fromLTWH(
              innerRoom.left, innerRoom.top, innerRoom.width, spillH);
          if (spillRect.width > 0 && spillRect.height > 0) {
            p.shader = LinearGradient(
              colors: [
                const Color(0xFF3A5880).o((0.48 * opacity).clamp(0.0, 0.9999)),
                Colors.transparent.o(0.0),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(spillRect);
            canvas.drawRect(spillRect, p);
            p.shader = null;
          }
        }

        // Junction box silhouette
        _drawEquipmentBox(canvas,
            Rect.fromLTWH(innerRoom.left + 1,
                innerRoom.top + innerRoom.height * 0.25,
                (innerRoom.width * 0.04).clamp(3.0, 8.0),
                (innerRoom.height * 0.30).clamp(4.0, 14.0)),
            p, opacity,
            color: const Color(0xFF1A2434), accentColor: const Color(0xFF203050));

        // Valve wheel circle
        final vx = innerRoom.right - (innerRoom.width * 0.04).clamp(3.0, 8.0) - 2;
        final vy = innerRoom.top + innerRoom.height * 0.5;
        final vr = (innerRoom.height * 0.15).clamp(2.0, 7.0);
        p.color = const Color(0xFF1C2C40).o((0.70 * opacity).clamp(0.0, 0.9999));
        canvas.drawCircle(Offset(vx, vy), vr, p);
        p.style = PaintingStyle.stroke;
        p.strokeWidth = 0.8;
        p.color = const Color(0xFF2A3E56).o((0.55 * opacity).clamp(0.0, 0.9999));
        canvas.drawCircle(Offset(vx, vy), vr, p);
        canvas.drawLine(Offset(vx - vr, vy), Offset(vx + vr, vy), p);
        canvas.drawLine(Offset(vx, vy - vr), Offset(vx, vy + vr), p);
        p.style = PaintingStyle.fill;

        // Interior panel lines
        p.style = PaintingStyle.stroke;
        p.strokeWidth = 0.5;
        final panelStep = (innerRoom.height / 3).clamp(3.0, 20.0);
        for (double y = innerRoom.top + panelStep;
            y < innerRoom.bottom - 1;
            y += panelStep) {
          p.color = _seamDark.o((0.55 * opacity).clamp(0.0, 0.9999));
          canvas.drawLine(
              Offset(innerRoom.left, y), Offset(innerRoom.right, y), p);
          p.color = _hullLight.o((0.08 * opacity).clamp(0.0, 0.9999));
          canvas.drawLine(Offset(innerRoom.left, y + 0.7),
              Offset(innerRoom.right, y + 0.7), p);
        }
        p.style = PaintingStyle.fill;
      }
    }

    // ── Floor plate — raised grating look ──
    final floorRect = Rect.fromLTWH(rect.left + skinT,
        rect.bottom - skinT - floorT, rect.width - skinT * 2, floorT);
    if (floorRect.width > 0 && floorRect.height > 0) {
      p.shader = LinearGradient(
        colors: [const Color(0xFF1E2A3C), const Color(0xFF0E1624)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(floorRect);
      canvas.drawRect(floorRect, p);
      p.shader = null;
      // Raised lip
      p.color = _hullLight.o((0.30 * opacity).clamp(0.0, 0.9999));
      canvas.drawRect(
          Rect.fromLTWH(floorRect.left, floorRect.top, floorRect.width, 1.5), p);
      p.color = Colors.black.o((0.45 * opacity).clamp(0.0, 0.9999));
      canvas.drawRect(
          Rect.fromLTWH(floorRect.left, floorRect.bottom - 1.5, floorRect.width, 1.5), p);
      _drawFloorTiles(canvas, floorRect, p, opacity,
          tileColor: const Color(0xFF1A2636));
    }

    // ── Blue coolant pipe — 3-D cylinder ──
    final pipeR = (rect.height * 0.07).clamp(1.5, 6.0);
    _drawPipeLine(canvas, rect, p, opacity,
        pipeColor: _pipeClean,
        litColor: const Color(0xFF4090C0),
        radius: pipeR,
        edgeOffset: skinT * 0.5,
        onBottom: true);

    // ── Viewport slit ──
    final vpH = (rect.height * 0.14).clamp(2.0, 8.0);
    final vpY = rect.top + (rect.height - vpH) * 0.38;
    final vpRect = Rect.fromLTWH(rect.left + 8, vpY, rect.width - 16, vpH);
    _drawViewportSlit(canvas, vpRect, p, opacity, animTick,
        glowStrength: 0.18, glowColor: const Color(0xFF3080C0),
        damageState: obs.damageState);

    _drawCornerBrackets(canvas, rect, p, opacity);
    _draw3DRivets(canvas, rect, p, opacity,
        rivetColor: const Color(0xFF303C4A),
        highlightColor: const Color(0xFF607080),
        spacing: 30.0,
        railOffset: skinT * 0.6);
    _drawCracks(canvas, rect, p, obs, crackColor: const Color(0xFF886644));
    _drawHpBar(canvas, rect, obs, effectiveColor, opacity);
    return;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // REINFORCED — ONI-style heavy blast door / engineering section
  //   Layers: thick multi-layer burnt-bronze hull with welded seam plates
  //           heavy mechanical room: grating floor + warm amber up-glow
  //           machinery silhouettes (pump, tank) | prominent pipe bundle
  //           hazard striping on ceiling edge | I-beam ribs
  // ─────────────────────────────────────────────────────────────────────────────
  if (tier == WallTier.reinforced) {
    final skinT = (rect.height * 0.16).clamp(3.5, 12.0);
    final floorT = (rect.height * 0.18).clamp(3.5, 12.0);
    final ceilT = (rect.height * 0.13).clamp(2.5, 9.0);
    final roomRect = Rect.fromLTWH(
      rect.left + skinT,
      rect.top + skinT + ceilT,
      rect.width - skinT * 2,
      rect.height - skinT * 2 - ceilT - floorT,
    );

    // ── Outer hull — thick multi-layer burnt-bronze plates ──
    _draw3DHullBody(canvas, rect, p, opacity,
        topColor: const Color(0xFF2E2412),
        midColor: const Color(0xFF1E1608),
        bottomColor: const Color(0xFF0C0A04));

    _drawLayeredPlates(canvas, rect, p, opacity,
        plateColor: const Color(0xFF28200A),
        highlightColor: const Color(0xFF42321A),
        shadowColor: const Color(0xFF080602),
        plateCount: 4);

    _drawPanelSeams(canvas, rect, p, opacity,
        spacing: 32.0, seamColor: const Color(0xFF090705));

    p.style = PaintingStyle.stroke;
    p.strokeWidth = 2.5;
    p.color = const Color(0xFF38260A).o(opacity.clamp(0.0, 0.9999));
    canvas.drawRect(rect, p);
    p.style = PaintingStyle.fill;

    // ── I-beam structural ribs on hull face ──
    final ribStep2 = (rect.width / 4).clamp(20.0, 60.0);
    for (double x = rect.left + ribStep2;
        x < rect.right - ribStep2 * 0.4;
        x += ribStep2) {
      _drawIBeam(canvas, x, rect.top + skinT * 0.2, rect.bottom - skinT * 0.2,
          p, opacity,
          webW: 2.5, flangeW: 8.0, flangeH: 2.5,
          webColor: const Color(0xFF1C1608),
          flangeColor: const Color(0xFF2E2210));
    }

    // ── Mechanical room — dark, oily, warm amber from below ──
    if (roomRect.width > 2.0 && roomRect.height > 2.0) {
      _drawRecessedFrame(canvas, roomRect, p, opacity, depth: 4.0,
          shadowColor: Colors.black);

      final innerRoom = roomRect.deflate(2.5);
      if (innerRoom.width > 0 && innerRoom.height > 0) {
        p.shader = LinearGradient(
          colors: [
            const Color(0xFF1A1408),
            const Color(0xFF120E06),
            const Color(0xFF0A0804)
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(innerRoom);
        canvas.drawRect(innerRoom, p);
        p.shader = null;

        // Strong amber up-glow
        final glowH = innerRoom.height * 0.55;
        if (glowH > 0 && innerRoom.width > 0) {
          final glowRect = Rect.fromLTWH(
              innerRoom.left, innerRoom.bottom - glowH, innerRoom.width, glowH);
          if (glowRect.width > 0 && glowRect.height > 0) {
            p.shader = LinearGradient(
              colors: [
                Colors.transparent.o(0.0),
                const Color(0xFF703018).o((0.55 * opacity).clamp(0.0, 0.9999)),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(glowRect);
            canvas.drawRect(glowRect, p);
            p.shader = null;
          }
        }

        _drawGrating(canvas, innerRoom, p, opacity,
            lineColor: const Color(0xFF1E1610));

        // Pump body silhouette
        final pumpW = (innerRoom.width * 0.08).clamp(5.0, 16.0);
        final pumpH = (innerRoom.height * 0.55).clamp(5.0, 20.0);
        final pumpX = innerRoom.left + innerRoom.width * 0.22;
        p.color = const Color(0xFF0E0C06).o((0.80 * opacity).clamp(0.0, 0.9999));
        canvas.drawRect(
            Rect.fromLTWH(pumpX, innerRoom.bottom - pumpH, pumpW, pumpH), p);
        p.color = const Color(0xFF1A1208).o((0.40 * opacity).clamp(0.0, 0.9999));
        canvas.drawRect(
            Rect.fromLTWH(pumpX, innerRoom.bottom - pumpH, pumpW, 1.5), p);

        // Tank cylinder silhouette
        final tankW = (innerRoom.width * 0.12).clamp(7.0, 22.0);
        final tankH = (innerRoom.height * 0.65).clamp(7.0, 24.0);
        final tankX = innerRoom.right - innerRoom.width * 0.25 - tankW / 2;
        final tankRect = Rect.fromLTWH(
            tankX, innerRoom.bottom - tankH, tankW, tankH);
        p.color = const Color(0xFF0C0A06).o((0.80 * opacity).clamp(0.0, 0.9999));
        canvas.drawRRect(
            RRect.fromRectAndRadius(tankRect, Radius.circular(tankW * 0.3)), p);
        p.color = const Color(0xFF201808).o((0.28 * opacity).clamp(0.0, 0.9999));
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(tankX, innerRoom.bottom - tankH, tankW, 2.0),
                Radius.circular(1.0)),
            p);
      }
    }

    // ── Ceiling — hazard stripe edge ──
    final ceilRect = Rect.fromLTWH(
        rect.left + skinT, rect.top + skinT, rect.width - skinT * 2, ceilT);
    if (ceilRect.width > 0 && ceilRect.height > 0) {
      p.color = const Color(0xFF1A1408).o(opacity.clamp(0.0, 0.9999));
      canvas.drawRect(ceilRect, p);
      final stripeH = (ceilT * 0.45).clamp(2.0, 5.0);
      final stripeRect = Rect.fromLTWH(
          ceilRect.left, ceilRect.bottom - stripeH, ceilRect.width, stripeH);
      _drawDiagonalHazardStripes(canvas, stripeRect, p, opacity,
          colorA: const Color(0xFF4A3800),
          colorB: const Color(0xFF1A1200),
          stripeW: 6.0);
    }

    // ── Floor grating — actual grid pattern ──
    final floorRect = Rect.fromLTWH(rect.left + skinT,
        rect.bottom - skinT - floorT, rect.width - skinT * 2, floorT);
    if (floorRect.width > 0 && floorRect.height > 0) {
      p.color = const Color(0xFF1E1608).o(opacity.clamp(0.0, 0.9999));
      canvas.drawRect(floorRect, p);
      p.color = const Color(0xFF3A2C12).o((0.65 * opacity).clamp(0.0, 0.9999));
      canvas.drawRect(
          Rect.fromLTWH(floorRect.left, floorRect.top, floorRect.width, 1.5), p);
      p.color = Colors.black.o((0.50 * opacity).clamp(0.0, 0.9999));
      canvas.drawRect(
          Rect.fromLTWH(floorRect.left, floorRect.bottom - 1.0, floorRect.width, 1.0), p);
      _drawActualGrating(canvas, floorRect, p, opacity,
          lineColor: const Color(0xFF2A2010));
    }

    // ── Cross-beams x 2 ──
    _drawReinforcementBands(canvas, rect, p, opacity,
        bandColor: const Color(0xFF1E1508), count: 2);

    // ── Copper pipe top + red pipe bottom ──
    final pipeR = (rect.height * 0.08).clamp(2.0, 7.0);
    _drawPipeLine(canvas, rect, p, opacity,
        pipeColor: _pipeCopper,
        litColor: _pipeCopperLit,
        radius: pipeR,
        edgeOffset: skinT * 0.4,
        onBottom: false);
    _drawPipeLine(canvas, rect, p, opacity,
        pipeColor: _pipeRed,
        litColor: const Color(0xFFCC3018),
        radius: pipeR * 0.72,
        edgeOffset: skinT * 0.5,
        onBottom: true);

    _drawWeldingMarks(canvas, rect, p, opacity,
        seed: obs.hashCode, weldColor: const Color(0xFF3A2C10));
    _drawCornerBrackets(canvas, rect, p, opacity,
        bracketColor: const Color(0xFF5A3C1C), bracketSize: 10.0);
    _draw3DRivets(canvas, rect, p, opacity,
        rivetColor: const Color(0xFF583C18),
        highlightColor: const Color(0xFF906030),
        spacing: 24.0,
        railOffset: 5.0,
        doubleRow: true);
    _drawCracks(canvas, rect, p, obs, crackColor: const Color(0xFFAA5522));
    _drawHpBar(canvas, rect, obs, effectiveColor, opacity);
    return;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // ARMORED — Military bunker / reactor containment
  //   Layers: nearly-opaque multi-layer hull | hex bolts | weld scarring
  //           heavy machinery room with reactor vessel + coolant manifold
  //           sub-floor crawlspace | triple pipe bundle with couplings
  //           warning chevrons | red emergency glow from below
  //           triple cross-beams | vertical structural I-beam ribs
  // ─────────────────────────────────────────────────────────────────────────────
  if (tier == WallTier.armored) {
    final skinT = (rect.height * 0.17).clamp(4.5, 14.0);
    final subFloorT = (rect.height * 0.12).clamp(2.0, 9.0);
    final ceilT = (rect.height * 0.14).clamp(2.5, 10.0);
    final roomRect = Rect.fromLTWH(
      rect.left + skinT,
      rect.top + skinT + ceilT,
      rect.width - skinT * 2,
      rect.height - skinT * 2 - ceilT - subFloorT,
    );

    // ── Outer hull — near-black, layered purple-tinted plates ──
    _draw3DHullBody(canvas, rect, p, opacity,
        topColor: const Color(0xFF1C1020),
        midColor: const Color(0xFF120C18),
        bottomColor: const Color(0xFF08060C));

    _drawLayeredPlates(canvas, rect, p, opacity,
        plateColor: const Color(0xFF181020),
        highlightColor: const Color(0xFF302040),
        shadowColor: const Color(0xFF060408),
        plateCount: 5);

    _drawPanelSeams(canvas, rect, p, opacity,
        spacing: 26.0, seamColor: const Color(0xFF0E0A0E));

    p.style = PaintingStyle.stroke;
    p.strokeWidth = 3.5;
    p.color = const Color(0xFF281828).o(opacity.clamp(0.0, 0.9999));
    canvas.drawRect(rect, p);
    p.strokeWidth = 0.8;
    p.color = const Color(0xFF503860).o((0.22 * opacity).clamp(0.0, 0.9999));
    canvas.drawRect(rect.deflate(3.0), p);
    p.style = PaintingStyle.fill;

    _drawWeldingMarks(canvas, rect, p, opacity,
        seed: obs.hashCode ^ 0xF00D, weldColor: const Color(0xFF2A1830));

    // ── I-beam structural ribs on hull face ──
    final ribStep3 = (rect.width / 5).clamp(14.0, 42.0);
    for (double x = rect.left + ribStep3;
        x < rect.right - ribStep3 * 0.4;
        x += ribStep3) {
      _drawIBeam(canvas, x, rect.top + skinT * 0.15, rect.bottom - skinT * 0.15,
          p, opacity,
          webW: 3.0, flangeW: 9.0, flangeH: 3.0,
          webColor: const Color(0xFF130A1A),
          flangeColor: const Color(0xFF201428));
    }

    // ── Heavy machinery room ──
    if (roomRect.width > 2.0 && roomRect.height > 2.0) {
      _drawRecessedFrame(canvas, roomRect, p, opacity, depth: 5.0,
          shadowColor: Colors.black);

      final innerRoom = roomRect.deflate(3.0);
      if (innerRoom.width > 0 && innerRoom.height > 0) {
        p.shader = LinearGradient(
          colors: [
            const Color(0xFF100C10),
            const Color(0xFF0C0A0E),
            const Color(0xFF080608)
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(innerRoom);
        canvas.drawRect(innerRoom, p);
        p.shader = null;

        // Red up-glow from reactor
        final redGlowH = innerRoom.height * 0.60;
        if (redGlowH > 0 && innerRoom.width > 0) {
          final glowRect = Rect.fromLTWH(
              innerRoom.left, innerRoom.bottom - redGlowH,
              innerRoom.width, redGlowH);
          if (glowRect.width > 0 && glowRect.height > 0) {
            p.shader = LinearGradient(
              colors: [
                Colors.transparent.o(0.0),
                const Color(0xFF601010).o((0.60 * opacity).clamp(0.0, 0.9999)),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(glowRect);
            canvas.drawRect(glowRect, p);
            p.shader = null;
          }
        }

        _drawGrating(canvas, innerRoom, p, opacity,
            lineColor: const Color(0xFF160E16), dense: true);

        // Vertical structural ribs in room
        p.style = PaintingStyle.stroke;
        p.strokeWidth = 1.2;
        final ribRoomStep = (innerRoom.width / 4).clamp(8.0, 30.0);
        for (double x = innerRoom.left + ribRoomStep;
            x < innerRoom.right - ribRoomStep * 0.3;
            x += ribRoomStep) {
          p.color = const Color(0xFF201820).o((0.50 * opacity).clamp(0.0, 0.9999));
          canvas.drawLine(
              Offset(x, innerRoom.top), Offset(x, innerRoom.bottom), p);
          p.color = const Color(0xFF3A2C3A).o((0.12 * opacity).clamp(0.0, 0.9999));
          canvas.drawLine(Offset(x + 1.0, innerRoom.top),
              Offset(x + 1.0, innerRoom.bottom), p);
        }
        p.style = PaintingStyle.fill;

        // Reactor vessel outline
        final rvW = (innerRoom.width * 0.22).clamp(8.0, 30.0);
        final rvH = (innerRoom.height * 0.70).clamp(8.0, 28.0);
        final rvX = innerRoom.center.dx - rvW / 2;
        final rvRect = Rect.fromLTWH(rvX, innerRoom.bottom - rvH, rvW, rvH);
        p.color = const Color(0xFF0A0810).o((0.85 * opacity).clamp(0.0, 0.9999));
        canvas.drawRRect(
            RRect.fromRectAndRadius(rvRect, Radius.circular(rvW * 0.35)), p);
        p.style = PaintingStyle.stroke;
        p.strokeWidth = 0.8;
        p.color = const Color(0xFF301030).o((0.40 * opacity).clamp(0.0, 0.9999));
        canvas.drawRRect(
            RRect.fromRectAndRadius(rvRect, Radius.circular(rvW * 0.35)), p);
        p.style = PaintingStyle.fill;

        // Coolant manifold
        if (rvW > 6.0 && rvRect.top > innerRoom.top) {
          _drawSmallPipe(canvas, rvX - 4, rvX + rvW + 4,
              rvRect.top + 2.0, p, opacity,
              r: (rvH * 0.06).clamp(1.0, 4.0),
              pipeColor: _pipeClean, litColor: const Color(0xFF3060A0));
        }
      }
    }

    // ── Cable ceiling ──
    final ceilRect = Rect.fromLTWH(
        rect.left + skinT, rect.top + skinT, rect.width - skinT * 2, ceilT);
    if (ceilRect.width > 0 && ceilRect.height > 0) {
      p.color = const Color(0xFF0E0810).o(opacity.clamp(0.0, 0.9999));
      canvas.drawRect(ceilRect, p);
      if (ceilT > 3.0) {
        p.style = PaintingStyle.stroke;
        p.strokeWidth = 1.2;
        for (double x = ceilRect.left + 10; x < ceilRect.right - 5; x += 16) {
          p.color = const Color(0xFF1E1420).o((0.45 * opacity).clamp(0.0, 0.9999));
          canvas.drawLine(
              Offset(x, ceilRect.top + 1), Offset(x, ceilRect.bottom - 1), p);
        }
        p.style = PaintingStyle.fill;
      }
    }

    // ── Sub-floor crawlspace with cable runs ──
    final subFloorRect = Rect.fromLTWH(rect.left + skinT,
        rect.bottom - skinT - subFloorT, rect.width - skinT * 2, subFloorT);
    if (subFloorRect.width > 0 && subFloorRect.height > 0) {
      p.color = const Color(0xFF08060C).o(opacity.clamp(0.0, 0.9999));
      canvas.drawRect(subFloorRect, p);
      p.color = const Color(0xFF2A1828).o((0.40 * opacity).clamp(0.0, 0.9999));
      canvas.drawRect(
          Rect.fromLTWH(
              subFloorRect.left, subFloorRect.top, subFloorRect.width, 1.5),
          p);
      _drawFloorTiles(canvas, subFloorRect, p, opacity,
          tileColor: const Color(0xFF140A14), tileW: 6.0);
      if (subFloorT > 4.0) {
        for (int ci = 0; ci < 3; ci++) {
          final cy = subFloorRect.top + subFloorT * (0.3 + ci * 0.25);
          _drawSmallPipe(canvas, subFloorRect.left + 2, subFloorRect.right - 2,
              cy, p, opacity,
              r: (subFloorT * 0.06).clamp(0.6, 2.0),
              pipeColor: const Color(0xFF1A1020),
              litColor: const Color(0xFF2A1830));
        }
      }
    }

    // ── Triple cross-beams ──
    _drawReinforcementBands(canvas, rect, p, opacity,
        bandColor: const Color(0xFF160E18), count: 3, thicker: true);

    // ── Triple pipe bundle ──
    final pipeR = (rect.height * 0.09).clamp(2.5, 8.0);
    _drawPipeLine(canvas, rect, p, opacity,
        pipeColor: _pipeGrey,
        litColor: const Color(0xFF5A6070),
        radius: pipeR * 1.1,
        edgeOffset: skinT * 0.25,
        onBottom: false);
    _drawPipeLine(canvas, rect, p, opacity,
        pipeColor: _pipeCopper,
        litColor: _pipeCopperLit,
        radius: pipeR * 0.72,
        edgeOffset: skinT * 0.25 + pipeR * 0.55,
        onBottom: false);
    _drawPipeLine(canvas, rect, p, opacity,
        pipeColor: _pipeRed,
        litColor: const Color(0xFFCC2810),
        radius: pipeR * 0.65,
        edgeOffset: skinT * 0.35,
        onBottom: true);

    _drawWarningChevrons(canvas, rect, p, opacity);

    _draw3DHexBolts(canvas, rect, p, opacity,
        boltColor: const Color(0xFF3A2840),
        highlightColor: const Color(0xFF604860),
        spacing: 22.0);

    final slitH = (rect.height * 0.10).clamp(3.0, 10.0);
    final slitY = rect.top + (rect.height - slitH) * 0.44;
    final slitRect =
        Rect.fromLTWH(rect.left + 10, slitY, rect.width - 20, slitH);
    _drawViewportSlit(canvas, slitRect, p, opacity, animTick,
        glowStrength: 0.24,
        glowColor: const Color(0xFF5030A0),
        damageState: obs.damageState);

    _drawCornerBrackets(canvas, rect, p, opacity,
        bracketColor: const Color(0xFF4A3850),
        bracketSize: 11.0,
        metalHighlight: true);
    _drawArmoredLabel(canvas, rect, opacity, effectiveColor);
    _drawCracks(canvas, rect, p, obs,
        crackColor: const Color(0xFFBB2020),
        severe: true,
        redBleed: obs.damageState == DamageState.critical,
        damageOpacity: obs.damageOpacity);
    _drawHpBar(canvas, rect, obs, effectiveColor, opacity);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3-D COMPONENT HELPERS
// ─────────────────────────────────────────────────────────────────────────────

/// 3-D hull body: top-left bright, bottom-right dark — angled lighting.
void _draw3DHullBody(
  Canvas canvas,
  Rect rect,
  Paint p,
  double opacity, {
  required Color topColor,
  required Color midColor,
  required Color bottomColor,
}) {
  p.shader = LinearGradient(
    colors: [topColor, midColor, bottomColor],
    stops: const [0.0, 0.45, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ).createShader(rect);
  canvas.drawRect(rect, p);
  p.shader = null;

  // Top highlight — light hitting top face
  p.color = _hullHighest.o((0.35 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(Rect.fromLTWH(rect.left, rect.top, rect.width, 2.0), p);
  p.color = _hullHighest.o((0.15 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(Rect.fromLTWH(rect.left, rect.top + 2.0, rect.width, 1.5), p);

  // Left highlight — vertical edge catch-light
  p.color = _hullLight.o((0.28 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(Rect.fromLTWH(rect.left, rect.top, 2.0, rect.height), p);

  // Bottom shadow — dark face
  p.color = Colors.black.o((0.65 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.bottom - 2.0, rect.width, 2.0), p);
  p.color = Colors.black.o((0.35 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.bottom - 4.0, rect.width, 2.0), p);

  // Right shadow
  p.color = Colors.black.o((0.45 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(
      Rect.fromLTWH(rect.right - 2.0, rect.top, 2.0, rect.height), p);
}

/// Overlapping armour plates with shadow gaps for depth.
void _drawLayeredPlates(
  Canvas canvas,
  Rect rect,
  Paint p,
  double opacity, {
  required Color plateColor,
  required Color highlightColor,
  required Color shadowColor,
  int plateCount = 3,
}) {
  final plateH = (rect.height / (plateCount + 0.5)).clamp(3.0, 18.0);
  for (int i = 0; i < plateCount; i++) {
    final y = rect.top + i * plateH;
    final h = plateH - 1.0;
    if (y + h > rect.bottom) break;

    p.color = plateColor.o((0.22 * opacity).clamp(0.0, 0.9999));
    canvas.drawRect(Rect.fromLTWH(rect.left + 1.5, y + 0.5, rect.width - 3.0, h), p);

    // Plate top highlight — raised edge catch-light
    p.color = highlightColor.o((0.25 * opacity).clamp(0.0, 0.9999));
    canvas.drawRect(
        Rect.fromLTWH(rect.left + 1.5, y + 0.5, rect.width - 3.0, 1.2), p);

    // Plate bottom shadow gap
    p.color = shadowColor.o((0.55 * opacity).clamp(0.0, 0.9999));
    canvas.drawRect(
        Rect.fromLTWH(rect.left + 1.5, y + h - 0.5, rect.width - 3.0, 1.5), p);
  }
}

/// Recessed frame — makes interior rooms look sunken into the hull.
void _drawRecessedFrame(
  Canvas canvas,
  Rect rect,
  Paint p,
  double opacity, {
  double depth = 3.0,
  Color? shadowColor,
}) {
  final sc = shadowColor ?? Colors.black;
  // Top — dark shadow cast by hull lip above
  p.color = sc.o((0.70 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(Rect.fromLTWH(rect.left, rect.top, rect.width, depth), p);
  // Left — dark shadow
  p.color = sc.o((0.50 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(Rect.fromLTWH(rect.left, rect.top, depth, rect.height), p);
  // Bottom — highlight (light bouncing up from floor)
  p.color = _hullLight.o((0.15 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.bottom - depth, rect.width, depth), p);
  // Right — light edge
  p.color = _hullLight.o((0.12 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(
      Rect.fromLTWH(rect.right - depth, rect.top, depth, rect.height), p);
}

/// True I-beam cross-section drawn as H shape.
/// webW/flangeW/flangeH define the proportions. Each face lit separately.
void _drawIBeam(
  Canvas canvas,
  double cx,
  double top,
  double bottom,
  Paint p,
  double opacity, {
  required double webW,
  required double flangeW,
  required double flangeH,
  required Color webColor,
  required Color flangeColor,
}) {
  if (bottom - top < flangeH * 2 + 2) return;
  final webLeft = cx - webW / 2;

  // ── Web (vertical spine) ──
  p.color = webColor.o(opacity.clamp(0.0, 0.9999));
  canvas.drawRect(
      Rect.fromLTWH(webLeft, top + flangeH, webW, bottom - top - flangeH * 2), p);
  // Web left highlight
  p.color = _hullLight.o((0.20 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(
      Rect.fromLTWH(webLeft, top + flangeH, 0.7, bottom - top - flangeH * 2), p);
  // Web right shadow
  p.color = Colors.black.o((0.35 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(
      Rect.fromLTWH(webLeft + webW - 0.7, top + flangeH, 0.7,
          bottom - top - flangeH * 2), p);

  // ── Top flange ──
  final flangeLeft = cx - flangeW / 2;
  p.color = flangeColor.o(opacity.clamp(0.0, 0.9999));
  canvas.drawRect(Rect.fromLTWH(flangeLeft, top, flangeW, flangeH), p);
  // Top highlight
  p.color = _hullHighest.o((0.30 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(Rect.fromLTWH(flangeLeft, top, flangeW, 0.8), p);
  // Left bevel
  p.color = _hullLight.o((0.18 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(Rect.fromLTWH(flangeLeft, top, 0.8, flangeH), p);
  // Bottom shadow (underside of flange)
  p.color = Colors.black.o((0.45 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(
      Rect.fromLTWH(flangeLeft, top + flangeH - 0.8, flangeW, 0.8), p);

  // ── Bottom flange ──
  p.color = flangeColor.o(opacity.clamp(0.0, 0.9999));
  canvas.drawRect(Rect.fromLTWH(flangeLeft, bottom - flangeH, flangeW, flangeH), p);
  // Top highlight
  p.color = _hullLight.o((0.20 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(
      Rect.fromLTWH(flangeLeft, bottom - flangeH, flangeW, 0.8), p);
  // Bottom shadow
  p.color = Colors.black.o((0.50 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(
      Rect.fromLTWH(flangeLeft, bottom - 0.8, flangeW, 0.8), p);
}

/// 3-D metal rail bar — used for fragile tier top/bottom rails.
void _draw3DRail(
  Canvas canvas,
  Rect rect,
  Paint p,
  double opacity, {
  required Color topColor,
  required Color midColor,
  required Color bottomColor,
}) {
  if (!(rect.width > 0 && rect.height > 0)) return;
  p.shader = LinearGradient(
    colors: [topColor, midColor, bottomColor],
    stops: const [0.0, 0.5, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ).createShader(rect);
  canvas.drawRect(rect, p);
  p.shader = null;

  // Top highlight bevel
  p.color = _hullHighest.o((0.45 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(Rect.fromLTWH(rect.left, rect.top, rect.width, 1.5), p);
  // Left catch-light
  p.color = _hullLight.o((0.22 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(Rect.fromLTWH(rect.left, rect.top, 2.0, rect.height), p);
  // Bottom shadow
  p.color = Colors.black.o((0.60 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.bottom - 1.5, rect.width, 1.5), p);
  // Right shadow
  p.color = Colors.black.o((0.30 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(
      Rect.fromLTWH(rect.right - 1.5, rect.top, 1.5, rect.height), p);
}

/// 3-D rivets with sphere shading and specular highlight.
void _draw3DRivets(
  Canvas canvas,
  Rect rect,
  Paint p,
  double opacity, {
  Color rivetColor = _hullMid,
  Color highlightColor = _hullHighest,
  double spacing = 28.0,
  bool doubleRow = false,
  double railOffset = 4.5,
}) {
  for (double x = rect.left + spacing * 0.55;
      x < rect.right - spacing * 0.3;
      x += spacing) {
    for (final yOff
        in doubleRow ? [railOffset, railOffset + 4.5] : [railOffset]) {
      for (final base in [rect.top, rect.bottom]) {
        final sign = (base == rect.top) ? 1.0 : -1.0;
        final cy = base + sign * yOff;

        // Drop shadow
        p.color = _rivShadow.o((0.70 * opacity).clamp(0.0, 0.9999));
        canvas.drawCircle(Offset(x + 0.8, cy + 0.8), 2.5, p);

        // Outer dark ring (makes sphere feel round)
        p.color = Color.lerp(rivetColor, Colors.black, 0.35)!
            .o((0.80 * opacity).clamp(0.0, 0.9999));
        canvas.drawCircle(Offset(x, cy), 2.5, p);

        // Inner body
        p.color = rivetColor.o(opacity.clamp(0.0, 0.9999));
        canvas.drawCircle(Offset(x, cy), 1.8, p);

        // Specular highlight — top-left bright spot
        p.color = highlightColor.o((0.72 * opacity).clamp(0.0, 0.9999));
        canvas.drawCircle(Offset(x - 0.8, cy - 0.8), 0.7, p);
      }
    }
  }
}

/// 3-D hex bolt heads with raised appearance and specular facets.
void _draw3DHexBolts(
  Canvas canvas,
  Rect rect,
  Paint p,
  double opacity, {
  Color boltColor = const Color(0xFF3C2C44),
  Color highlightColor = const Color(0xFF604860),
  double spacing = 22.0,
}) {
  const r = 3.0;
  for (double x = rect.left + spacing * 0.5;
      x < rect.right - spacing * 0.3;
      x += spacing) {
    for (final base in [rect.top + 5.5, rect.bottom - 5.5]) {
      final path = Path();
      for (int j = 0; j < 6; j++) {
        final angle = j * pi / 3 - pi / 6;
        if (j == 0) {
          path.moveTo(x + cos(angle) * r, base + sin(angle) * r);
        } else {
          path.lineTo(x + cos(angle) * r, base + sin(angle) * r);
        }
      }
      path.close();

      // Drop shadow
      p.color = _rivShadow.o((0.75 * opacity).clamp(0.0, 0.9999));
      canvas.save();
      canvas.translate(0.8, 0.8);
      canvas.drawPath(path, p);
      canvas.restore();

      // Bolt body
      p.color = boltColor.o(opacity.clamp(0.0, 0.9999));
      canvas.drawPath(path, p);

      // Top-left facet highlight
      p.style = PaintingStyle.stroke;
      p.strokeWidth = 0.8;
      p.color = highlightColor.o((0.45 * opacity).clamp(0.0, 0.9999));
      final hPath = Path();
      for (int j = 4; j < 7; j++) {
        final angle = (j % 6) * pi / 3 - pi / 6;
        if (j == 4) {
          hPath.moveTo(x + cos(angle) * r, base + sin(angle) * r);
        } else {
          hPath.lineTo(x + cos(angle) * r, base + sin(angle) * r);
        }
      }
      canvas.drawPath(hPath, p);
      p.style = PaintingStyle.fill;

      // Center socket hole
      p.color = Colors.black.o((0.65 * opacity).clamp(0.0, 0.9999));
      canvas.drawCircle(Offset(x, base), 1.2, p);
      // Socket specular
      p.color = highlightColor.o((0.25 * opacity).clamp(0.0, 0.9999));
      canvas.drawCircle(Offset(x - 0.5, base - 0.5), 0.5, p);
    }
  }
}

/// Small inline pipe for ceiling runs, sub-floor cables.
void _drawSmallPipe(
  Canvas canvas,
  double left,
  double right,
  double cy,
  Paint p,
  double opacity, {
  required double r,
  required Color pipeColor,
  required Color litColor,
}) {
  if (right <= left || r < 0.5) return;
  final pipeRect = Rect.fromLTRB(left, cy - r, right, cy + r);
  if (!(pipeRect.width > 0 && pipeRect.height > 0)) return;

  // Shadow
  p.color = Colors.black.o((0.45 * opacity).clamp(0.0, 0.9999));
  canvas.drawRRect(
      RRect.fromLTRBR(left, cy - r + 0.5, right, cy + r + 0.5, Radius.circular(r)), p);

  // Strong cylindrical gradient
  p.shader = LinearGradient(
    colors: [
      litColor.o((0.80 * opacity).clamp(0.0, 0.9999)),
      pipeColor.o(opacity.clamp(0.0, 0.9999)),
      Colors.black.o((0.55 * opacity).clamp(0.0, 0.9999)),
    ],
    stops: const [0.0, 0.45, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ).createShader(pipeRect);
  canvas.drawRRect(
      RRect.fromLTRBR(left, cy - r, right, cy + r, Radius.circular(r)), p);
  p.shader = null;

  // Specular streak
  p.color = Colors.white.o((0.22 * opacity).clamp(0.0, 0.9999));
  canvas.drawRRect(
      RRect.fromLTRBR(left + 3, cy - r + 0.4, right - 3, cy - r + r * 0.35,
          Radius.circular(r * 0.25)),
      p);
}

/// Floor panel gaps with bevel — raised plate depth effect.
void _drawFloorPanelGaps(
  Canvas canvas,
  Rect rect,
  Paint p,
  double opacity, {
  required Color gapColor,
  double panelW = 20.0,
}) {
  p.style = PaintingStyle.stroke;
  p.strokeWidth = 1.0;
  for (double x = rect.left + panelW; x < rect.right - 2; x += panelW) {
    p.color = gapColor.o((0.80 * opacity).clamp(0.0, 0.9999));
    canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), p);
    p.color = _hullHighest.o((0.18 * opacity).clamp(0.0, 0.9999));
    p.strokeWidth = 0.6;
    canvas.drawLine(Offset(x + 1.0, rect.top), Offset(x + 1.0, rect.bottom), p);
    p.strokeWidth = 1.0;
  }
  p.style = PaintingStyle.fill;
}

/// Drain grate — small grid.
void _drawDrainGrate(Canvas canvas, Rect rect, Paint p, double opacity) {
  if (rect.width < 2 || rect.height < 1.5) return;
  p.color = const Color(0xFF0A1020).o((0.80 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(rect, p);
  p.style = PaintingStyle.stroke;
  p.strokeWidth = 0.5;
  p.color = const Color(0xFF1E2C40).o((0.55 * opacity).clamp(0.0, 0.9999));
  canvas.save();
  canvas.clipRect(rect);
  final gStep = (rect.width / 3).clamp(2.0, 6.0);
  for (double x = rect.left + gStep; x < rect.right; x += gStep) {
    canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), p);
  }
  if (rect.height > 2.0) {
    canvas.drawLine(Offset(rect.left, rect.center.dy),
        Offset(rect.right, rect.center.dy), p);
  }
  canvas.restore();
  p.style = PaintingStyle.fill;
}

/// Horizontal cable conduit — thin extruded channel with bevel.
void _drawCableConduit(
  Canvas canvas,
  double left,
  double right,
  double cy,
  Paint p,
  double opacity, {
  required Color color,
}) {
  const h = 2.0;
  if (right <= left) return;
  p.color = color.o((0.65 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(Rect.fromLTWH(left, cy - h / 2, right - left, h), p);
  p.color = _hullLight.o((0.22 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(Rect.fromLTWH(left, cy - h / 2, right - left, 0.7), p);
  p.color = Colors.black.o((0.40 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(Rect.fromLTWH(left, cy + h / 2 - 0.7, right - left, 0.7), p);
}

/// Equipment box silhouette — junction box, panel, etc.
void _drawEquipmentBox(
  Canvas canvas,
  Rect rect,
  Paint p,
  double opacity, {
  required Color color,
  required Color accentColor,
}) {
  if (rect.width < 2 || rect.height < 2) return;
  p.color = color.o((0.75 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(rect, p);
  p.color = _hullLight.o((0.25 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(Rect.fromLTWH(rect.left, rect.top, rect.width, 1.0), p);
  p.color = _hullLight.o((0.15 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(Rect.fromLTWH(rect.left, rect.top, 0.8, rect.height), p);
  p.color = Colors.black.o((0.55 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.bottom - 1.0, rect.width, 1.0), p);
  if (rect.height > 5.0) {
    p.color = accentColor.o((0.60 * opacity).clamp(0.0, 0.9999));
    canvas.drawRect(
        Rect.fromLTWH(rect.left + 1.0, rect.top + 1.5, rect.width - 2.0, 1.2), p);
  }
}

/// Proper diagonal hazard stripes — alternating colored bands.
void _drawDiagonalHazardStripes(
  Canvas canvas,
  Rect rect,
  Paint p,
  double opacity, {
  required Color colorA,
  required Color colorB,
  double stripeW = 6.0,
}) {
  if (rect.width < 1 || rect.height < 1) return;
  canvas.save();
  canvas.clipRect(rect);
  p.style = PaintingStyle.fill;
  final total = rect.width + rect.height;
  int ci = 0;
  for (double d = -rect.height; d < total; d += stripeW) {
    p.color = (ci % 2 == 0 ? colorA : colorB)
        .o((0.85 * opacity).clamp(0.0, 0.9999));
    final path = Path()
      ..moveTo(rect.left + d, rect.top)
      ..lineTo(rect.left + d + stripeW, rect.top)
      ..lineTo(rect.left + d + stripeW + rect.height, rect.bottom)
      ..lineTo(rect.left + d + rect.height, rect.bottom)
      ..close();
    canvas.drawPath(path, p);
    ci++;
  }
  canvas.restore();
  p.color = const Color(0xFF6A5800).o((0.30 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(Rect.fromLTWH(rect.left, rect.top, rect.width, 0.8), p);
}

/// Actual grid grating — horizontal + vertical lines.
void _drawActualGrating(
  Canvas canvas,
  Rect rect,
  Paint p,
  double opacity, {
  Color lineColor = const Color(0xFF2A2010),
  double step = 5.0,
}) {
  if (rect.width < 2 || rect.height < 2) return;
  canvas.save();
  canvas.clipRect(rect);
  p.style = PaintingStyle.stroke;
  p.strokeWidth = 0.5;
  p.color = lineColor.o((0.55 * opacity).clamp(0.0, 0.9999));
  for (double x = rect.left + step; x < rect.right; x += step) {
    canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), p);
  }
  for (double y = rect.top + step; y < rect.bottom; y += step) {
    canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), p);
  }
  canvas.restore();
  p.style = PaintingStyle.fill;
}
/// Engraved vertical panel seams.
void _drawPanelSeams(
  Canvas canvas,
  Rect rect,
  Paint p,
  double opacity, {
  double spacing = 40.0,
  Color seamColor = _seamDark,
}) {
  p.style = PaintingStyle.stroke;
  p.strokeWidth = 1.0;
  for (double x = rect.left + spacing; x < rect.right - 4; x += spacing) {
    p.color = seamColor.o(opacity.clamp(0.0, 0.9999));
    canvas.drawLine(Offset(x, rect.top + 2), Offset(x, rect.bottom - 2), p);
    p.strokeWidth = 0.8;
    p.color = _hullLight.o((0.16 * opacity).clamp(0.0, 0.9999));
    canvas.drawLine(
        Offset(x + 1.2, rect.top + 2), Offset(x + 1.2, rect.bottom - 2), p);
    p.strokeWidth = 1.0;
  }
  p.style = PaintingStyle.fill;
}

/// Floor/sub-floor tile grid pattern.
void _drawFloorTiles(
  Canvas canvas,
  Rect rect,
  Paint p,
  double opacity, {
  Color tileColor = _roomFloor,
  double tileW = 10.0,
}) {
  if (rect.height < 2.0) return;
  p.style = PaintingStyle.stroke;
  p.strokeWidth = 0.5;
  p.color = tileColor.o((0.55 * opacity).clamp(0.0, 0.9999));
  for (double x = rect.left + tileW; x < rect.right; x += tileW) {
    canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), p);
  }
  if (rect.height > 4.0) {
    canvas.drawLine(Offset(rect.left, rect.center.dy),
        Offset(rect.right, rect.center.dy), p);
  }
  p.style = PaintingStyle.fill;
}

/// Diagonal metal grating — ONI style interior texture.
void _drawGrating(
  Canvas canvas,
  Rect rect,
  Paint p,
  double opacity, {
  Color lineColor = const Color(0xFF1A1410),
  bool dense = false,
}) {
  if (rect.isEmpty || rect.height < 2.0) return;
  p.style = PaintingStyle.stroke;
  p.strokeWidth = 0.5;
  p.color = lineColor.o((0.55 * opacity).clamp(0.0, 0.9999));
  canvas.save();
  canvas.clipRect(rect);
  final step = dense ? 6.0 : 9.0;
  for (double d = -rect.height; d < rect.width + rect.height; d += step) {
    canvas.drawLine(
      Offset(rect.left + d, rect.top),
      Offset(rect.left + d + rect.height, rect.bottom),
      p,
    );
  }
  canvas.restore();
  p.style = PaintingStyle.fill;
}

/// Cylindrical pipe running along a wall edge — enhanced 3-D cylinder.
void _drawPipeLine(
  Canvas canvas,
  Rect rect,
  Paint p,
  double opacity, {
  required Color pipeColor,
  required Color litColor,
  required double radius,
  required double edgeOffset,
  required bool onBottom,
}) {
  if (radius < 1.0) return;
  final cy = onBottom
      ? rect.bottom - edgeOffset - radius
      : rect.top + edgeOffset + radius;
  final left = rect.left + 3;
  final right = rect.right - 3;
  if (right <= left) return;

  // Cast shadow
  p.color = Colors.black.o((0.65 * opacity).clamp(0.0, 0.9999));
  canvas.drawRRect(
      RRect.fromLTRBR(left, cy - radius + 1.5, right, cy + radius + 2.0,
          Radius.circular(radius)),
      p);

  // Pipe body — 4-stop cylindrical gradient
  final pipeRect = Rect.fromLTRB(left, cy - radius, right, cy + radius);
  if (!(pipeRect.width > 0 && pipeRect.height > 0)) return;
  p.shader = LinearGradient(
    colors: [
      litColor.o((0.90 * opacity).clamp(0.0, 0.9999)),
      pipeColor.o(opacity.clamp(0.0, 0.9999)),
      Color.lerp(pipeColor, Colors.black, 0.5)!
          .o((0.85 * opacity).clamp(0.0, 0.9999)),
      Colors.black.o((0.70 * opacity).clamp(0.0, 0.9999)),
    ],
    stops: const [0.0, 0.35, 0.70, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ).createShader(pipeRect);
  canvas.drawRRect(
      RRect.fromLTRBR(
          left, cy - radius, right, cy + radius, Radius.circular(radius)),
      p);
  p.shader = null;

  // Specular catch-light streak
  p.color = Colors.white.o((0.38 * opacity).clamp(0.0, 0.9999));
  canvas.drawRRect(
      RRect.fromLTRBR(left + 5, cy - radius + 0.5, right - 5,
          cy - radius + radius * 0.32, Radius.circular(radius * 0.25)),
      p);
  // Secondary softer highlight
  p.color = Colors.white.o((0.12 * opacity).clamp(0.0, 0.9999));
  canvas.drawRRect(
      RRect.fromLTRBR(left + 8, cy - radius + radius * 0.32, right - 8,
          cy - radius + radius * 0.55, Radius.circular(radius * 0.2)),
      p);

  // Segment joints — coupling rings
  p.style = PaintingStyle.stroke;
  p.strokeWidth = 2.0;
  p.color = Colors.black.o((0.50 * opacity).clamp(0.0, 0.9999));
  final jointSpacing = (rect.width / 4).clamp(20.0, 65.0);
  for (double x = left + jointSpacing; x < right - 5; x += jointSpacing) {
    canvas.drawLine(Offset(x, cy - radius), Offset(x, cy + radius), p);
    p.color = litColor.o((0.22 * opacity).clamp(0.0, 0.9999));
    p.strokeWidth = 0.8;
    canvas.drawLine(Offset(x + 1.5, cy - radius), Offset(x + 1.5, cy + radius), p);
    p.strokeWidth = 2.0;
    p.color = Colors.black.o((0.50 * opacity).clamp(0.0, 0.9999));
  }
  p.style = PaintingStyle.fill;
}

/// L-shaped structural corner brackets.
void _drawCornerBrackets(
  Canvas canvas,
  Rect rect,
  Paint p,
  double opacity, {
  Color bracketColor = const Color(0xFF3A4560),
  double bracketSize = 8.0,
  bool metalHighlight = false,
}) {
  p.style = PaintingStyle.stroke;
  p.strokeWidth = 2.0;
  p.color = bracketColor.o(opacity.clamp(0.0, 0.9999));
  for (final corner in [
    rect.topLeft,
    rect.topRight,
    rect.bottomLeft,
    rect.bottomRight,
  ]) {
    final sx = (corner.dx == rect.left) ? 1.0 : -1.0;
    final sy = (corner.dy == rect.top) ? 1.0 : -1.0;
    canvas.drawLine(
        corner + Offset(sx * 0.5, 0), corner + Offset(sx * bracketSize, 0), p);
    canvas.drawLine(
        corner + Offset(0, sy * 0.5), corner + Offset(0, sy * bracketSize), p);
    if (metalHighlight) {
      p.color = _hullHighest.o((0.25 * opacity).clamp(0.0, 0.9999));
      p.strokeWidth = 0.8;
      canvas.drawLine(corner + Offset(sx * 0.5, sy * 0.5),
          corner + Offset(sx * bracketSize * 0.55, sy * 0.5), p);
      p.strokeWidth = 2.0;
      p.color = bracketColor.o(opacity.clamp(0.0, 0.9999));
    }
  }
  p.style = PaintingStyle.fill;
}

/// Horizontal reinforcement cross-beams.
void _drawReinforcementBands(
  Canvas canvas,
  Rect rect,
  Paint p,
  double opacity, {
  Color bandColor = const Color(0xFF1A1408),
  int count = 2,
  bool thicker = false,
}) {
  final bandH = thicker ? 5.0 : 3.5;
  final step = rect.height / (count + 1);
  for (int i = 0; i < count; i++) {
    final bandY = rect.top + step * (i + 1) - bandH / 2;
    p.color = bandColor.o(opacity.clamp(0.0, 0.9999));
    canvas.drawRect(
        Rect.fromLTWH(rect.left + 2, bandY, rect.width - 4, bandH), p);
    // Top bevel — raised band
    p.color = _hullLight.o((0.22 * opacity).clamp(0.0, 0.9999));
    canvas.drawRect(
        Rect.fromLTWH(rect.left + 2, bandY, rect.width - 4, 1.2), p);
    // Bottom shadow
    p.color = Colors.black.o((0.55 * opacity).clamp(0.0, 0.9999));
    canvas.drawRect(
        Rect.fromLTWH(rect.left + 2, bandY + bandH - 1.2, rect.width - 4, 1.2),
        p);
  }
}

/// Welding seam marks — diagonal dashes along top seam.
void _drawWeldingMarks(
  Canvas canvas,
  Rect rect,
  Paint p,
  double opacity, {
  required int seed,
  Color weldColor = const Color(0xFF3A2810),
}) {
  final rng = Random(seed ^ 0xDEAD);
  p.style = PaintingStyle.stroke;
  p.strokeWidth = 1.0;
  double x = rect.left + 6;
  while (x < rect.right - 8) {
    final len = 2.5 + rng.nextDouble() * 1.5;
    p.color = weldColor.o((0.55 * opacity).clamp(0.0, 0.9999));
    canvas.drawLine(
        Offset(x, rect.top + 2.5), Offset(x + len, rect.top + 5.5), p);
    p.color = _hullHighest.o((0.14 * opacity).clamp(0.0, 0.9999));
    canvas.drawLine(Offset(x + 0.8, rect.top + 2.5),
        Offset(x + len + 0.8, rect.top + 5.5), p);
    x += 6.0 + rng.nextDouble() * 3.0;
  }
  p.style = PaintingStyle.fill;
}

/// Warning chevron stripes on left edge — armored tier.
void _drawWarningChevrons(Canvas canvas, Rect rect, Paint p, double opacity) {
  const stripeW = 5.0;
  const stripeH = 7.0;
  const colA = Color(0xFF2A2008);
  const colB = Color(0xFF1A1505);
  double y = rect.top + 4;
  int ci = 0;
  while (y < rect.bottom - 4) {
    final h = stripeH.clamp(0.0, rect.bottom - 4 - y);
    if (h < 1.0) break;
    p.color =
        (ci % 2 == 0 ? colA : colB).o((0.58 * opacity).clamp(0.0, 0.9999));
    canvas.drawRect(Rect.fromLTWH(rect.left + 2, y, stripeW, h), p);
    y += stripeH;
    ci++;
  }
  p.style = PaintingStyle.stroke;
  p.strokeWidth = 0.5;
  p.color = _hullLight.o((0.12 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(
      Rect.fromLTWH(rect.left + 2, rect.top + 4, stripeW, rect.height - 8), p);
  p.style = PaintingStyle.fill;
}

/// Dark observation slit — interior is deep and dark, barely lit.
void _drawViewportSlit(
  Canvas canvas,
  Rect vpRect,
  Paint p,
  double opacity,
  double animTick, {
  double glowStrength = 0.10,
  Color glowColor = const Color(0xFF2A3845),
  DamageState? damageState,
}) {
  // Extruded frame — 3-D raised border
  // Shadow on top/left (hull overhangs viewport)
  p.color = Colors.black.o((0.70 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(
      Rect.fromLTWH(vpRect.left - 2, vpRect.top - 2, vpRect.width + 4, 2.0), p);
  canvas.drawRect(
      Rect.fromLTWH(vpRect.left - 2, vpRect.top - 2, 2.0, vpRect.height + 4), p);
  // Highlight on bottom/right (light catches lip)
  p.color = _hullLight.o((0.22 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(
      Rect.fromLTWH(vpRect.left - 2, vpRect.bottom, vpRect.width + 4, 2.0), p);

  p.color = Colors.black.o((0.85 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(vpRect, p);
  final inner = vpRect.deflate(2.0);
  if (!(inner.width > 0 && inner.height > 0)) return;

  double effectiveGlow = glowStrength;
  if (damageState == DamageState.critical) {
    final f = 0.15 +
        sin(animTick * 14.0) * 0.20 +
        sin(animTick * 8.7) * 0.15 +
        (sin(animTick * 23.0) > 0.7 ? -0.25 : 0.0);
    effectiveGlow = glowStrength * f.clamp(0.0, 1.0);
  } else if (damageState == DamageState.damaged) {
    final f = 0.55 + sin(animTick * 4.5) * 0.35 + sin(animTick * 7.3) * 0.10;
    effectiveGlow = glowStrength * f.clamp(0.15, 1.0);
  }

  p.shader = LinearGradient(
    colors: [
      const Color(0xFF08101C),
      const Color(0xFF050A12),
      const Color(0xFF020408)
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ).createShader(inner);
  canvas.drawRect(inner, p);
  p.shader = null;

  p.shader = LinearGradient(
    colors: [
      glowColor.o(0.0),
      glowColor.o((effectiveGlow * opacity).clamp(0.0, 0.9999)),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ).createShader(inner);
  canvas.drawRect(inner, p);
  p.shader = null;

  if (effectiveGlow > 0.15) {
    p.maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    p.color = glowColor.o((effectiveGlow * 0.28 * opacity).clamp(0.0, 0.9999));
    canvas.drawRect(inner.deflate(1.5), p);
    p.maskFilter = null;
  }

  p.style = PaintingStyle.stroke;
  p.strokeWidth = 1.0;
  p.color = Colors.black.o((0.80 * opacity).clamp(0.0, 0.9999));
  canvas.drawLine(vpRect.bottomLeft, vpRect.bottomRight, p);
  canvas.drawLine(vpRect.topRight, vpRect.bottomRight, p);
  p.color = _hullLight.o((0.28 * opacity).clamp(0.0, 0.9999));
  canvas.drawLine(vpRect.topLeft, vpRect.topRight, p);
  canvas.drawLine(vpRect.topLeft, vpRect.bottomLeft, p);
  p.style = PaintingStyle.fill;

  p.color = Colors.white.o((0.06 * opacity).clamp(0.0, 0.9999));
  canvas.drawRect(
      Rect.fromLTWH(inner.left + 4, inner.top + 1.0, inner.width - 8, 0.8), p);
}

/// "ARMORED" micro-stencil.
void _drawArmoredLabel(
    Canvas canvas, Rect rect, double opacity, Color toneColor) {
  if (rect.width < 24) return;
  final tp = TextPainter(
    text: TextSpan(
      text: '⬡ ARMORED',
      style: TextStyle(
        color: toneColor.o((0.42 * opacity).clamp(0.0, 0.9999)),
        fontSize: 6.0,
        fontWeight: FontWeight.w900,
        letterSpacing: 2.0,
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  tp.layout(maxWidth: rect.width - 20);
  tp.paint(
      canvas, Offset(rect.right - tp.width - 6, rect.bottom - tp.height - 5));
}

/// Damage cracks — seeded flat strokes, red bleed for armored critical.
void _drawCracks(
  Canvas canvas,
  Rect rect,
  Paint p,
  LaserWallEntity obs, {
  Color crackColor = const Color(0xFF886644),
  bool severe = false,
  bool redBleed = false,
  double damageOpacity = 1.0,
}) {
  if (obs.damageState == DamageState.healthy) return;
  final isCritical = obs.damageState == DamageState.critical;
  final count = isCritical ? (severe ? 7 : 5) : (severe ? 3 : 2);
  final alpha = isCritical ? (severe ? 0.85 : 0.65) : (severe ? 0.42 : 0.25);

  if (redBleed) {
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 2.8;
    p.color =
        const Color(0xFFCC0000).o((0.11 * damageOpacity).clamp(0.0, 0.9999));
    final rng2 = Random(obs.hashCode);
    for (int i = 0; i < count; i++) {
      final sx = rect.left + rng2.nextDouble() * rect.width;
      final mid = sx + (rng2.nextDouble() - 0.5) * 16;
      final ex = mid + (rng2.nextDouble() - 0.5) * 22;
      canvas.drawPath(
          Path()
            ..moveTo(sx, rect.top)
            ..lineTo(mid, rect.center.dy)
            ..lineTo(ex, rect.bottom),
          p);
    }
  }

  p.style = PaintingStyle.stroke;
  p.strokeWidth = isCritical ? 1.6 : 1.1;
  p.color = crackColor.o((alpha * damageOpacity).clamp(0.0, 0.9999));
  final rng = Random(obs.hashCode);
  for (int i = 0; i < count; i++) {
    final sx = rect.left + rng.nextDouble() * rect.width;
    final mid = sx + (rng.nextDouble() - 0.5) * 16;
    final ex = mid + (rng.nextDouble() - 0.5) * 22;
    canvas.drawPath(
        Path()
          ..moveTo(sx, rect.top)
          ..lineTo(mid, rect.center.dy)
          ..lineTo(ex, rect.bottom),
        p);
    if (isCritical) {
      p.strokeWidth = 0.7;
      canvas.drawPath(
          Path()
            ..moveTo(mid, rect.center.dy)
            ..lineTo(mid + (rng.nextDouble() - 0.5) * 20,
                rect.center.dy + rect.height * 0.28),
          p);
      p.strokeWidth = isCritical ? 1.6 : 1.1;
    }
  }
  p.style = PaintingStyle.fill;
}

// ─────────────────────────────────────────────────────────────────────────────
// HP BAR
// ─────────────────────────────────────────────────────────────────────────────
void _drawHpBar(
    Canvas canvas, Rect wallRect, GameEntity obs, Color color, double opacity) {
  if (obs.maxHp <= 1) return;
  final ratio = (obs.hp / obs.maxHp).clamp(0.0, 1.0);
  const barH = 3.0;
  final barY = wallRect.bottom + 2;
  final paint = Paint()..style = PaintingStyle.fill;
  paint.color = Colors.black.o(0.55);
  canvas.drawRect(
      Rect.fromLTWH(wallRect.left, barY, wallRect.width, barH), paint);
  final barColor = Color.lerp(Colors.red, color, ratio)!;
  paint.color = barColor.o(opacity.clamp(0.0, 0.9999));
  canvas.drawRect(
      Rect.fromLTWH(wallRect.left, barY, wallRect.width * ratio, barH), paint);
  paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
  paint.color = barColor.o((opacity * 0.45).clamp(0.0, 0.9999));
  canvas.drawRect(
      Rect.fromLTWH(wallRect.left, barY, wallRect.width * ratio, barH), paint);
  paint.maskFilter = null;
}
