part of '../game_provider.dart';

// ── BOSS SYSTEM ──────────────────────────────────────────────────────────────

extension BossSystem on GameProvider {
  // ── BOSS FIRE (data-driven via archetype phase) ────────────────────────────
  void bossFire() {
    if (boss == null || boss!.isDead) return;
    final bx = boss!.x;
    final pattern = boss!.firePattern;

    // Aim at player from muzzle line
    final muzzleY = boss!.y + 0.09;
    final dx = player.x - bx;
    final dy = player.y - muzzleY;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist < 0.01) return;
    final aimX = (dx / dist) * pattern.aimSpeed;
    final aimY = (dy / dist) * pattern.aimSpeed;

    // Spawn one missile per port
    for (final port in pattern.ports) {
      bossMissiles.add(BossMissile(
        x: bx + port.dx,
        y: boss!.y + port.dy,
        vx: aimX + port.dvx,
        vy: aimY + port.dvy,
        color: port.color,
      ));
    }
    shakeIntensity = max(shakeIntensity, 5.0);

    // Muzzle flash sparks — directional, not generic dots
    final muzzleAngle = atan2(aimY, aimX);
    for (int i = 0; i < 6; i++) {
      final a = muzzleAngle + (_rng.nextDouble() - 0.5) * 0.7;
      particles.add(Particle(
        x: bx,
        y: muzzleY,
        vx: cos(a) * (0.006 + _rng.nextDouble() * 0.009),
        vy: sin(a) * (0.006 + _rng.nextDouble() * 0.009),
        life: 0.45,
        color: const Color(0xFFFF6B00),
        size: 2.5 + _rng.nextDouble() * 3.5,
        decay: 0.07,
        shape: ParticleShape.spark,
        angle: a,
      ));
    }
  }

  // ── BOSS ARRIVAL — cinematic entrance burst ───────────────────────────────
  // Called once when the boss is first spawned.
  // Three staggered shockwave rings + fire embers + dark hull shards.
  void bossArrivalEffect() {
    final bx = boss!.x;
    final by = boss!.y;

    // Staggered shockwave rings
    for (int i = 0; i < 3; i++) {
      shockwaves.add(Shockwave(
        x: bx + (_rng.nextDouble() - 0.5) * 0.06,
        y: by,
        radius: 0.01 + i * 0.009,
        life: 1.0,
        color: i == 0 ? Colors.white : const Color(0xFFFF2D55),
      ));
    }

    spawnBossArrivalParticles(bx, by);
    shakeIntensity = 28.0;
  }

  // ── RAMPAGE ACTIVATE ──────────────────────────────────────────────────────
  void rampageActivate() {
    if (!isRampageReady) return;
    rampage.isActive = true;
    rampage.timer = 10.0;
    rampage.chargeLevel = 0;
    shakeIntensity = 20.0;
    onRewardCollected?.call('🔥 RAMPAGE — 10s INVINCIBLE');

    for (int i = 0; i < 30; i++) {
      final a = _rng.nextDouble() * 2 * pi;
      final spd = 0.01 + _rng.nextDouble() * 0.025;
      particles.add(Particle(
        x: player.x,
        y: player.y,
        vx: cos(a) * spd,
        vy: sin(a) * spd,
        life: 1.0,
        color: const Color(0xFFFF6B00),
        size: 5.0 + _rng.nextDouble() * 12.0,
        decay: 0.02,
        shape: ParticleShape.ember,
        angle: a,
      ));
    }
    for (int i = 0; i < 3; i++) {
      shockwaves.add(Shockwave(
          x: player.x,
          y: player.y,
          radius: 0.01 + i * 0.01,
          life: 1.0,
          color: i == 0 ? Colors.white : const Color(0xFFFF6B00)));
    }
  }
}
