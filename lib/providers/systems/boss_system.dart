part of '../game_provider.dart';

// ── BOSS SYSTEM ──────────────────────────────────────────────────────────────
// Boss firing patterns, rampage activation, and boss-related visual effects.

extension BossSystem on GameProvider {
  void bossFire() {
    if (boss == null || boss!.isDead) return;
    final bx = boss!.x;
    final by = boss!.y + 0.09;
    final dx = player.x - bx;
    final dy = player.y - by;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist < 0.01) return;
    final bvx = (dx / dist) * 0.013;
    final bvy = (dy / dist) * 0.013;
    bossMissiles.add(BossMissile(x: bx, y: by, vx: bvx, vy: bvy));
    bossMissiles.add(BossMissile(
        x: bx - 0.06,
        y: by,
        vx: bvx - 0.004,
        vy: bvy + 0.002,
        color: const Color(0xFFFF6B00)));
    bossMissiles.add(BossMissile(
        x: bx + 0.06,
        y: by,
        vx: bvx + 0.004,
        vy: bvy + 0.002,
        color: const Color(0xFFFF6B00)));
    shakeIntensity = max(shakeIntensity, 5.0);
    for (int i = 0; i < 8; i++) {
      final a = _rng.nextDouble() * 2 * pi;
      particles.add({
        'x': bx,
        'y': by,
        'vx': cos(a) * 0.008,
        'vy': sin(a) * 0.008,
        'life': 0.5,
        'color': const Color(0xFFFF2D55),
        'size': 3.0 + _rng.nextDouble() * 5,
        'decay': 0.06
      });
    }
  }

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
      particles.add({
        'x': player.x,
        'y': player.y,
        'vx': cos(a) * spd,
        'vy': sin(a) * spd,
        'life': 1.0,
        'color': const Color(0xFFFF6B00),
        'size': 5.0 + _rng.nextDouble() * 12,
        'decay': 0.02
      });
    }
    for (int i = 0; i < 3; i++)
      shockwaves.add(Shockwave(
          x: player.x,
          y: player.y,
          radius: 0.01 + i * 0.01,
          life: 1.0,
          color: i == 0 ? Colors.white : const Color(0xFFFF6B00)));
  }
}
