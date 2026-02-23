part of '../game_provider.dart';

// ── PARTICLE SYSTEM ──────────────────────────────────────────────────────────
// Each particle carries a 'shape' key that game_painter uses to decide how
// to draw it:
//   'dot'   — filled circle (coins, power-ups, generic glow)
//   'spark' — tiny bright needle, fast decay (bullet impact, metal graze)
//   'ember' — round glowing orb, hot core (fire, energy bursts)
//   'shard' — thin elongated rectangle, spins fast (metal wall panels)
//   'chunk' — wider rounded rect, tumbles slowly (stone/asteroid rubble)
//
// 'angle' holds the live rotation in radians — updated each tick by 'spin'.

extension ParticleSystem on GameProvider {
  // ── HIT SPARKS ─────────────────────────────────────────────────────────────
  // Bright directional sparks: bullet striking armour or metal surface.
  void spawnHitSparks(double x, double y, Color color) {
    for (int i = 0; i < 7; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 0.006 + _rng.nextDouble() * 0.014;
      particles.add({
        'x': x,
        'y': y,
        'vx': cos(angle) * speed,
        'vy': sin(angle) * speed,
        'life': 0.55,
        'color': Color.lerp(color, Colors.white, 0.75)!,
        'size': 1.8 + _rng.nextDouble() * 1.8,
        'decay': 0.07,
        'shape': 'spark',
        'angle': angle,
        'spin': 0.0,
      });
    }
  }

  // ── WALL DEBRIS ────────────────────────────────────────────────────────────
  // Angular metal shards. Size/count scale with tier.
  // ~35% energy-colour shards, rest are raw grey armour steel.
  void spawnDebrisParticles(double x, double y, Color color, WallTier tier) {
    final count = tier == WallTier.armored
        ? 22
        : tier == WallTier.reinforced
            ? 14
            : 7;
    final maxSize = tier == WallTier.armored
        ? 13.0
        : tier == WallTier.reinforced
            ? 9.0
            : 5.0;
    final topSpeed =
        tier == WallTier.armored ? 0.022 : tier == WallTier.reinforced ? 0.016 : 0.012;

    for (int i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final spd = 0.003 + _rng.nextDouble() * topSpeed;
      final useEnergy = _rng.nextDouble() < 0.35;
      final col = useEnergy
          ? color
          : Color.lerp(const Color(0xFF8A8A9A), const Color(0xFF42424E),
              _rng.nextDouble())!;
      final w = 2.5 + _rng.nextDouble() * maxSize;
      particles.add({
        'x': x,
        'y': y,
        'vx': cos(angle) * spd,
        'vy': sin(angle) * spd - 0.002,
        'life': 1.0,
        'color': col,
        'size': w,
        'aspect': 0.18 + _rng.nextDouble() * 0.18,
        'decay': tier == WallTier.armored ? 0.011 : 0.016,
        'shape': 'shard',
        'angle': angle,
        'spin': (_rng.nextDouble() - 0.5) * 0.30,
      });
    }
  }

  // ── STONE DEBRIS ──────────────────────────────────────────────────────────
  // Chunky brownish-grey pieces for asteroids + crystal sparks from the veins.
  void spawnStoneDebris(double x, double y) {
    for (int i = 0; i < 14; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final spd = 0.004 + _rng.nextDouble() * 0.018;
      final col = Color.lerp(
          const Color(0xFF6A5A48), const Color(0xFF9A8A78), _rng.nextDouble())!;
      particles.add({
        'x': x,
        'y': y,
        'vx': cos(angle) * spd,
        'vy': sin(angle) * spd,
        'life': 1.0,
        'color': col,
        'size': 4.5 + _rng.nextDouble() * 9.0,
        'aspect': 0.55 + _rng.nextDouble() * 0.50,
        'decay': 0.016,
        'shape': 'chunk',
        'angle': angle,
        'spin': (_rng.nextDouble() - 0.5) * 0.10,
      });
    }
    // Cyan crystal sparks from energy veins
    for (int i = 0; i < 5; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      particles.add({
        'x': x,
        'y': y,
        'vx': cos(angle) * (0.010 + _rng.nextDouble() * 0.016),
        'vy': sin(angle) * (0.010 + _rng.nextDouble() * 0.016),
        'life': 0.6,
        'color': const Color(0xFF00E5FF),
        'size': 2.0,
        'decay': 0.055,
        'shape': 'spark',
        'angle': angle,
        'spin': 0.0,
      });
    }
  }

  // ── MINE EXPLOSION ────────────────────────────────────────────────────────
  // Energy embers + metal spike shards flung outward.
  void spawnMineExplosion(double x, double y, Color color) {
    for (int i = 0; i < 18; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final spd = 0.007 + _rng.nextDouble() * 0.020;
      particles.add({
        'x': x,
        'y': y,
        'vx': cos(angle) * spd,
        'vy': sin(angle) * spd,
        'life': 0.9,
        'color': Color.lerp(color, Colors.white, 0.4)!,
        'size': 4.0 + _rng.nextDouble() * 5.0,
        'decay': 0.024,
        'shape': 'ember',
        'angle': angle,
        'spin': 0.0,
      });
    }
    for (int i = 0; i < 8; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      particles.add({
        'x': x,
        'y': y,
        'vx': cos(angle) * (0.010 + _rng.nextDouble() * 0.014),
        'vy': sin(angle) * (0.010 + _rng.nextDouble() * 0.014),
        'life': 0.8,
        'color': const Color(0xFF888898),
        'size': 3.5 + _rng.nextDouble() * 4.0,
        'aspect': 0.20,
        'decay': 0.035,
        'shape': 'shard',
        'angle': angle,
        'spin': (_rng.nextDouble() - 0.5) * 0.28,
      });
    }
  }

  // ── GENERIC EXPLOSION ─────────────────────────────────────────────────────
  // Fire embers. intense=true adds hull shards (player death).
  void spawnExplosionParticles(double x, double y, {bool intense = false}) {
    final count = intense ? 32 : 16;
    const fireColors = [
      Color(0xFFFF2D55),
      Color(0xFFFF6B2B),
      Color(0xFFFFB020),
      Colors.white,
    ];
    for (int i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final spd = intense
          ? (0.008 + _rng.nextDouble() * 0.028)
          : (0.005 + _rng.nextDouble() * 0.018);
      particles.add({
        'x': x,
        'y': y,
        'vx': cos(angle) * spd,
        'vy': sin(angle) * spd - 0.003,
        'life': 1.0,
        'color': fireColors[_rng.nextInt(fireColors.length)],
        'size': intense
            ? (5.0 + _rng.nextDouble() * 11.0)
            : (3.5 + _rng.nextDouble() * 7.0),
        'decay': intense ? 0.022 : 0.032,
        'shape': 'ember',
        'angle': angle,
        'spin': 0.0,
      });
    }
    if (intense) {
      for (int i = 0; i < 8; i++) {
        final angle = _rng.nextDouble() * 2 * pi;
        particles.add({
          'x': x,
          'y': y,
          'vx': cos(angle) * (0.005 + _rng.nextDouble() * 0.016),
          'vy': sin(angle) * (0.005 + _rng.nextDouble() * 0.016),
          'life': 1.0,
          'color': const Color(0xFF666678),
          'size': 5.0 + _rng.nextDouble() * 7.0,
          'aspect': 0.25,
          'decay': 0.018,
          'shape': 'shard',
          'angle': angle,
          'spin': (_rng.nextDouble() - 0.5) * 0.24,
        });
      }
    }
  }

  // ── BOMB EXPLOSION ────────────────────────────────────────────────────────
  void spawnBombExplosionParticles(double x, double y) {
    const bombColors = [
      Colors.white,
      Color(0xFFFF6B2B),
      Color(0xFFFFD60A),
      Color(0xFFFF00FF),
      Color(0xFF00FFFF),
    ];
    for (int i = 0; i < 50; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final spd = 0.005 + _rng.nextDouble() * 0.036;
      particles.add({
        'x': x,
        'y': y,
        'vx': cos(angle) * spd,
        'vy': sin(angle) * spd,
        'life': 1.0,
        'color': bombColors[_rng.nextInt(bombColors.length)],
        'size': 4.0 + _rng.nextDouble() * 14.0,
        'decay': 0.013,
        'shape': 'ember',
        'angle': angle,
        'spin': 0.0,
      });
    }
    for (int i = 0; i < 20; i++) {
      particles.add({
        'x': x + (_rng.nextDouble() - 0.5) * 0.14,
        'y': y,
        'vx': (_rng.nextDouble() - 0.5) * 0.007,
        'vy': -0.009 - _rng.nextDouble() * 0.020,
        'life': 1.0,
        'color': const Color(0xFFFF4400),
        'size': 5.0 + _rng.nextDouble() * 9.0,
        'decay': 0.011,
        'shape': 'ember',
        'angle': 0.0,
        'spin': 0.0,
      });
    }
    for (int i = 0; i < 16; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      particles.add({
        'x': x,
        'y': y,
        'vx': cos(angle) * (0.013 + _rng.nextDouble() * 0.022),
        'vy': sin(angle) * (0.013 + _rng.nextDouble() * 0.022),
        'life': 1.0,
        'color': const Color(0xFF8888AA),
        'size': 6.0 + _rng.nextDouble() * 10.0,
        'aspect': 0.20,
        'decay': 0.013,
        'shape': 'shard',
        'angle': angle,
        'spin': (_rng.nextDouble() - 0.5) * 0.38,
      });
    }
  }

  // ── COLLECTION EFFECTS ────────────────────────────────────────────────────
  void spawnCoinParticles(double x, double y) {
    for (int i = 0; i < 10; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      particles.add({
        'x': x,
        'y': y,
        'vx': cos(angle) * (0.004 + _rng.nextDouble() * 0.009),
        'vy': sin(angle) * (0.004 + _rng.nextDouble() * 0.009) - 0.013,
        'life': 1.0,
        'color': const Color(0xFFFFD60A),
        'size': 3.0 + _rng.nextDouble() * 3.0,
        'decay': 0.042,
        'shape': 'dot',
        'angle': 0.0,
        'spin': 0.0,
      });
    }
  }

  void spawnPowerUpParticles(double x, double y, PowerUpType type) {
    final color = type == PowerUpType.shield
        ? const Color(0xFF4D7CFF)
        : type == PowerUpType.slowTime
            ? const Color(0xFF8B5CF6)
            : const Color(0xFFFF2D55);
    for (int i = 0; i < 14; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      particles.add({
        'x': x,
        'y': y,
        'vx': cos(angle) * (0.005 + _rng.nextDouble() * 0.010),
        'vy': sin(angle) * (0.005 + _rng.nextDouble() * 0.010) - 0.008,
        'life': 1.0,
        'color': color,
        'size': 3.0 + _rng.nextDouble() * 4.0,
        'decay': 0.035,
        'shape': 'dot',
        'angle': 0.0,
        'spin': 0.0,
      });
    }
  }

  void spawnChestParticles(double x, double y) {
    const chestColors = [
      Color(0xFFFFD60A),
      Color(0xFFFFB020),
      Colors.white,
      Color(0xFF00FFD1),
    ];
    for (int i = 0; i < 18; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      particles.add({
        'x': x,
        'y': y,
        'vx': cos(angle) * (0.005 + _rng.nextDouble() * 0.015),
        'vy': sin(angle) * (0.005 + _rng.nextDouble() * 0.015) - 0.012,
        'life': 1.0,
        'color': chestColors[_rng.nextInt(chestColors.length)],
        'size': 4.0 + _rng.nextDouble() * 6.0,
        'decay': 0.025,
        'shape': 'dot',
        'angle': 0.0,
        'spin': 0.0,
      });
    }
    // Small wood fragments from the lid
    for (int i = 0; i < 5; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      particles.add({
        'x': x,
        'y': y,
        'vx': cos(angle) * (0.006 + _rng.nextDouble() * 0.010),
        'vy': sin(angle) * (0.006 + _rng.nextDouble() * 0.010) - 0.008,
        'life': 0.8,
        'color': const Color(0xFF6B4E12),
        'size': 4.0 + _rng.nextDouble() * 5.0,
        'aspect': 0.40,
        'decay': 0.035,
        'shape': 'chunk',
        'angle': angle,
        'spin': (_rng.nextDouble() - 0.5) * 0.18,
      });
    }
  }

  // ── BOSS ARRIVAL BURST ────────────────────────────────────────────────────
  // Called once on boss spawn. Fire embers + dark hull shards raining down.
  void spawnBossArrivalParticles(double x, double y) {
    const arrivalColors = [Color(0xFFFF2D55), Color(0xFFFF6B00), Colors.white];
    for (int i = 0; i < 35; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final spd = 0.009 + _rng.nextDouble() * 0.026;
      particles.add({
        'x': x,
        'y': y,
        'vx': cos(angle) * spd,
        'vy': sin(angle) * spd,
        'life': 1.0,
        'color': arrivalColors[_rng.nextInt(arrivalColors.length)],
        'size': 5.0 + _rng.nextDouble() * 14.0,
        'decay': 0.015,
        'shape': 'ember',
        'angle': angle,
        'spin': 0.0,
      });
    }
    for (int i = 0; i < 14; i++) {
      final angle = pi / 2 + (_rng.nextDouble() - 0.5) * pi;
      particles.add({
        'x': x + (_rng.nextDouble() - 0.5) * 0.18,
        'y': y,
        'vx': cos(angle) * (0.005 + _rng.nextDouble() * 0.013),
        'vy': sin(angle) * (0.005 + _rng.nextDouble() * 0.013),
        'life': 1.0,
        'color': const Color(0xFF555562),
        'size': 7.0 + _rng.nextDouble() * 12.0,
        'aspect': 0.22,
        'decay': 0.012,
        'shape': 'shard',
        'angle': angle,
        'spin': (_rng.nextDouble() - 0.5) * 0.28,
      });
    }
  }

  // ── TRAIL ──────────────────────────────────────────────────────────────────
  void updateTrail(double speedMult) {
    final color = player.color;
    switch (player.trailStyle) {
      case TrailStyle.clean:
        trail.add(TrailPoint(
            x: player.x,
            y: player.y + 0.022,
            life: 1.0,
            size: 5.0 + _rng.nextDouble() * 3,
            color: color));
        if (_rng.nextDouble() < 0.5)
          trail.add(TrailPoint(
              x: player.x,
              y: player.y + 0.022,
              life: 0.6,
              size: 2.5,
              color: Colors.white));
        break;
      case TrailStyle.scatter:
        for (int i = 0; i < 3; i++) {
          trail.add(TrailPoint(
              x: player.x,
              y: player.y + 0.02,
              life: 0.8,
              size: 2.5 + _rng.nextDouble() * 2,
              color: color,
              vx: (_rng.nextDouble() - 0.5) * 0.012));
        }
        break;
      case TrailStyle.fire:
        for (final dx in [-0.025, 0.0, 0.025]) {
          trail.add(TrailPoint(
              x: player.x + dx,
              y: player.y + 0.025,
              life: 1.0,
              size: 7.0 + _rng.nextDouble() * 5,
              color: color));
          trail.add(TrailPoint(
              x: player.x + dx + (_rng.nextDouble() - 0.5) * 0.01,
              y: player.y + 0.025,
              life: 0.7,
              size: 4.0,
              color: const Color(0xFFFF2D00)));
        }
        break;
      case TrailStyle.ghost:
        trail.add(TrailPoint(
            x: player.x + (_rng.nextDouble() - 0.5) * 0.015,
            y: player.y + 0.02,
            life: 0.5,
            size: 4.0,
            color: color.withOpacity(0.4)));
        break;
      case TrailStyle.wide:
        for (final dx in [-0.04, 0.0, 0.04]) {
          trail.add(TrailPoint(
              x: player.x + dx,
              y: player.y + 0.03,
              life: 1.0,
              size: 8.0 + _rng.nextDouble() * 4,
              color: color));
          trail.add(TrailPoint(
              x: player.x + dx,
              y: player.y + 0.03,
              life: 0.8,
              size: 5.0,
              color: Colors.white.withOpacity(0.5)));
        }
        break;
    }
    for (final t in trail) {
      t.y += 0.004 * state.speed * speedMult;
      if (player.trailStyle == TrailStyle.scatter) t.x += t.vx;
      t.life -= player.trailStyle == TrailStyle.fire ? 0.05 : 0.055;
    }
    trail.removeWhere((t) => t.life <= 0);
  }
}
