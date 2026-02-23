part of '../game_provider.dart';

// ── PARTICLE SYSTEM ──────────────────────────────────────────────────────────
// All visual feedback particles: explosions, debris, sparks, coin/powerup/chest
// collection effects, bomb explosion particles, and trail updates.

extension ParticleSystem on GameProvider {
  void spawnHitSparks(double x, double y, Color color) {
    for (int i = 0; i < 8; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 0.005 + _rng.nextDouble() * 0.01;
      particles.add({
        'x': x,
        'y': y,
        'vx': cos(angle) * speed,
        'vy': sin(angle) * speed,
        'life': 0.7,
        'color': Color.lerp(color, Colors.white, 0.6)!,
        'size': 2.5 + _rng.nextDouble() * 2,
        'decay': 0.05
      });
    }
  }

  void spawnExplosionParticles(double x, double y, {bool intense = false}) {
    final count = intense ? 35 : 18;
    for (int i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = intense
          ? (0.008 + _rng.nextDouble() * 0.025)
          : (0.006 + _rng.nextDouble() * 0.016);
      final colors = [
        const Color(0xFFFF2D55),
        const Color(0xFFFF6B2B),
        const Color(0xFFFFB020),
        Colors.white,
        const Color(0xFFFFFF00)
      ];
      particles.add({
        'x': x,
        'y': y,
        'vx': cos(angle) * speed,
        'vy': sin(angle) * speed - 0.003,
        'life': 1.0,
        'color': colors[_rng.nextInt(colors.length)],
        'size': intense
            ? (5.0 + _rng.nextDouble() * 10)
            : (4.0 + _rng.nextDouble() * 7),
        'decay': intense ? 0.025 : 0.035
      });
    }
  }

  void spawnDebrisParticles(double x, double y, Color color, WallTier tier) {
    final count = tier == WallTier.armored
        ? 18
        : tier == WallTier.reinforced
            ? 12
            : 6;
    for (int i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 0.004 + _rng.nextDouble() * 0.018;
      final size = tier == WallTier.armored
          ? (6.0 + _rng.nextDouble() * 10)
          : tier == WallTier.reinforced
              ? (4.0 + _rng.nextDouble() * 7)
              : (2.0 + _rng.nextDouble() * 4);
      particles.add({
        'x': x,
        'y': y,
        'vx': cos(angle) * speed,
        'vy': sin(angle) * speed,
        'life': 1.0,
        'color': color,
        'size': size,
        'decay': 0.015,
        'isDebris': true
      });
    }
  }

  // Bomb particles: reduced count to avoid lag
  // ignore: unused_element
  void spawnBombExplosionParticles(double x, double y) {
    for (int i = 0; i < 50; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 0.005 + _rng.nextDouble() * 0.035;
      final colors = [
        Colors.white,
        const Color(0xFFFF6B2B),
        const Color(0xFFFFD60A),
        const Color(0xFFFF00FF),
        const Color(0xFF00FFFF)
      ];
      particles.add({
        'x': x,
        'y': y,
        'vx': cos(angle) * speed,
        'vy': sin(angle) * speed,
        'life': 1.0,
        'color': colors[_rng.nextInt(colors.length)],
        'size': 4.0 + _rng.nextDouble() * 12,
        'decay': 0.015
      });
    }
    for (int i = 0; i < 20; i++) {
      particles.add({
        'x': x + (_rng.nextDouble() - 0.5) * 0.15,
        'y': y,
        'vx': (_rng.nextDouble() - 0.5) * 0.008,
        'vy': -0.008 - _rng.nextDouble() * 0.018,
        'life': 1.0,
        'color': const Color(0xFFFF4400),
        'size': 5.0 + _rng.nextDouble() * 8,
        'decay': 0.012
      });
    }
  }

  void spawnCoinParticles(double x, double y) {
    for (int i = 0; i < 10; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 0.004 + _rng.nextDouble() * 0.008;
      particles.add({
        'x': x,
        'y': y,
        'vx': cos(angle) * speed,
        'vy': sin(angle) * speed - 0.012,
        'life': 1.0,
        'color': const Color(0xFFFFD60A),
        'size': 3.0 + _rng.nextDouble() * 3,
        'decay': 0.04
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
      final speed = 0.005 + _rng.nextDouble() * 0.01;
      particles.add({
        'x': x,
        'y': y,
        'vx': cos(angle) * speed,
        'vy': sin(angle) * speed - 0.008,
        'life': 1.0,
        'color': color,
        'size': 3.0 + _rng.nextDouble() * 4,
        'decay': 0.035
      });
    }
  }

  void spawnChestParticles(double x, double y) {
    for (int i = 0; i < 20; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 0.005 + _rng.nextDouble() * 0.016;
      final colors = [
        const Color(0xFFFFD60A),
        const Color(0xFFFFB020),
        Colors.white,
        const Color(0xFF00FFD1)
      ];
      particles.add({
        'x': x,
        'y': y,
        'vx': cos(angle) * speed,
        'vy': sin(angle) * speed - 0.012,
        'life': 1.0,
        'color': colors[_rng.nextInt(colors.length)],
        'size': 4.0 + _rng.nextDouble() * 6,
        'decay': 0.025
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
