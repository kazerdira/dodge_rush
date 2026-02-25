part of '../game_provider.dart';

// ═════════════════════════════════════════════════════════════════════════════
// SCENARIO / EVENT SYSTEM  — Phase 8
// Composable game scenarios that own their state and tick logic.
// Each scenario is a self-contained event layer:  gauntlet, boss encounter,
// environmental hazard, etc.  GameProvider holds a list of scenarios and
// delegates to them every frame.
// ═════════════════════════════════════════════════════════════════════════════

// ── ABSTRACT ─────────────────────────────────────────────────────────────────

/// A composable scenario that can activate, tick, and complete.
/// Multiple scenarios may be active simultaneously (boss + gauntlet).
abstract class GameScenario {
  /// Whether this scenario is currently running.
  bool get isActive;

  /// Whether this scenario has finished (won't tick again).
  bool get isComplete;

  /// Test whether this scenario should activate this frame.
  bool canActivate(GameProvider gp);

  /// Called once when the scenario activates.
  void onActivate(GameProvider gp);

  /// Called every frame while active.
  void update(GameProvider gp, double dt);

  /// Called once when the scenario completes.
  void onComplete(GameProvider gp);

  /// Reset all internal state (called on game restart).
  void reset();
}

// ── ENVIRONMENTAL EFFECTS ────────────────────────────────────────────────────

/// Stub enum for future environmental hazards.
/// Each effect modifies gameplay parameters during a scenario.
enum EnvironmentalEffect {
  none,

  /// Constant sideways push on the player.
  solarWind,

  /// Reduced visibility — fog overlay.
  lowVisibility,

  /// Pulls player toward a point each frame.
  gravityWell,
}

// ── GAUNTLET SCENARIO ────────────────────────────────────────────────────────

/// Final 30-second survival challenge at sector 5.
/// Replaces the inline gauntlet flags that were scattered through _tick().
class GauntletScenario extends GameScenario {
  bool _active = false;
  double timer = 0.0;
  static const double duration = 30.0;
  bool escaped = false;
  double escapeFlashTimer = 0.0;

  @override
  bool get isActive => _active;
  @override
  bool get isComplete => escaped;

  @override
  bool canActivate(GameProvider gp) =>
      gp.state.sector >= 5 && !_active && !escaped;

  @override
  void onActivate(GameProvider gp) {
    _active = true;
    timer = 0;
    gp.onRewardCollected?.call('⚡  FINAL GAUNTLET — SURVIVE 30s');
    gp.shakeIntensity = 10.0;
  }

  @override
  void update(GameProvider gp, double dt) {
    // Fade escape flash even after escape — must run before early-return
    if (escapeFlashTimer > 0) escapeFlashTimer -= dt * 1.2;

    if (!_active || escaped) return;

    timer += dt;
    if (timer >= duration) {
      escaped = true;
      escapeFlashTimer = 1.0;
      gp.state.score += 10000;
      gp.onRewardCollected?.call('★★★  ESCAPED  +10000  ★★★');
      gp.shakeIntensity = 12.0;

      // Celebration burst
      for (int i = 0; i < 18; i++) {
        final a = gp._rng.nextDouble() * 2 * pi;
        final spd = 0.01 + gp._rng.nextDouble() * 0.028;
        const cols = [Colors.white, Color(0xFF00FFD1), Color(0xFFFFD60A)];
        gp.particles.add(Particle(
          x: gp.player.x,
          y: gp.player.y,
          vx: cos(a) * spd,
          vy: sin(a) * spd - 0.01,
          life: 1.0,
          color: cols[gp._rng.nextInt(cols.length)],
          size: 6.0 + gp._rng.nextDouble() * 12,
          decay: 0.012,
          shape: ParticleShape.ember,
          angle: a,
        ));
      }
      // Gauntlet survived — game continues at max difficulty.
      // Player plays until lives run out (no forced game-over).
    }
  }

  @override
  void onComplete(GameProvider gp) {
    // No-op: gauntlet escape is a reward, not a game-ending event.
  }

  @override
  void reset() {
    _active = false;
    timer = 0;
    escaped = false;
    escapeFlashTimer = 0;
  }
}

// ── BOSS ENCOUNTER SCENARIO ──────────────────────────────────────────────────

/// Manages the boss spawn / respawn cycle and per-frame boss tick.
/// Boss data (boss, bossMissiles) stays on GameProvider for painter access;
/// this scenario controls the lifecycle and all tick logic.
class BossEncounterScenario extends GameScenario {
  bool _active = false;
  double timeSinceLastBoss = 0;
  int killCount = 0;
  bool spawned = false;
  bool defeated = false;
  static const double respawnInterval = 45.0;

  @override
  bool get isActive => _active;
  @override
  bool get isComplete => false; // recurring — never truly completes

  @override
  bool canActivate(GameProvider gp) => gp.state.sector >= 2 && !_active;

  @override
  void onActivate(GameProvider gp) {
    _active = true;
  }

  @override
  void update(GameProvider gp, double dt) {
    if (!_active) return;

    timeSinceLastBoss += dt;

    // ── SPAWN / RESPAWN CONDITIONS ──────────────────────────────
    final bossFullyGone = gp.boss == null || gp.boss!.isFullyDead;
    final firstSpawnReady = !spawned && gp._gameTime > 40.0;
    final respawnReady =
        bossFullyGone && killCount > 0 && timeSinceLastBoss > respawnInterval;

    if (firstSpawnReady || respawnReady) {
      _spawnBoss(gp);
    }

    // ── BOSS TICK ───────────────────────────────────────────────
    if (gp.boss != null && !gp.boss!.isFullyDead) {
      _tickBoss(gp, dt);
    }
  }

  void _spawnBoss(GameProvider gp) {
    timeSinceLastBoss = 0;
    spawned = true;
    final archetype = BossRegistry.resolve(gp.state.sector, killCount);
    final hp = archetype.baseHp(gp.state.sector, killCount);
    gp.boss = BossShip(
      archetype: archetype,
      hp: hp,
      maxHp: hp,
      fireRate: archetype.baseFireRate(gp.state.sector, killCount),
      fireTimer: 4.0,
    );
    gp.onRewardCollected?.call(archetype.arrivalMessage(killCount));
    gp.shakeIntensity = 9.0;
  }

  void _tickBoss(GameProvider gp, double dt) {
    final boss = gp.boss!;
    boss.pulsePhase += dt * 2.5;

    if (!boss.isDead) {
      // Entrance glide — cap sector contribution so high sectors don't
      // make the boss slam in instantly.
      final sectorMult = 1.0 + gp.state.sector.clamp(1, 6) * 0.3;
      if (boss.y < 0.12) {
        boss.y += boss.enterSpeed * sectorMult;
      }
      // Track player
      boss.x += (gp.player.x - boss.x) * boss.trackingSpeed;

      // Fire timer
      boss.fireTimer -= dt;
      if (boss.fireTimer < 0.8) {
        boss.warningFlash = (boss.warningFlash + dt * 3).clamp(0.0, 1.0);
      }
      if (boss.fireTimer <= 0) {
        boss.warningFlash = 0;
        gp.bossFire();
        boss.fireTimer = boss.fireRate;
      }

      // Rampage burns boss
      if (gp.rampage.isActive) boss.hp -= dt * 8;

      // Boss death
      if (boss.hp <= 0) {
        _onBossDeath(gp, boss);
      }
    } else {
      boss.deathTimer += dt * 1.8;
    }

    // Move missiles
    for (final m in gp.bossMissiles) {
      m.x += m.vx;
      m.y += m.vy;
      m.life -= dt * 0.35;
      if (m.y > 1.1 || m.x < -0.05 || m.x > 1.05 || m.life <= 0) {
        m.active = false;
      }
    }
    gp.bossMissiles.removeWhere((m) => !m.active);

    // Missile vs player
    if (!gp.state.isShieldActive) {
      for (final m in gp.bossMissiles) {
        if (!m.active) continue;
        if (sqrt(pow(m.x - gp.player.x, 2) + pow(m.y - gp.player.y, 2)) <
            0.055) {
          m.active = false;
          gp.spawnExplosionParticles(m.x, m.y);
          gp.handleHit();
          break;
        }
      }
    }

    // Bullets vs boss
    if (!boss.isDead && boss.y > -0.05) {
      const bossW = 0.22;
      const bossH = 0.14;
      for (final b in gp.bullets) {
        if (!b.active) continue;
        if (b.x > boss.x - bossW / 2 &&
            b.x < boss.x + bossW / 2 &&
            b.y > boss.y - bossH / 2 &&
            b.y < boss.y + bossH / 2) {
          b.active = false;
          boss.hp -= b.damage;
          gp.rampage.chargeLevel =
              (gp.rampage.chargeLevel + 0.018).clamp(0, 1.0);
          gp.spawnHitSparks(boss.x + (gp._rng.nextDouble() - 0.5) * 0.12,
              boss.y, const Color(0xFFFF2D55));
          gp.shakeIntensity = max(gp.shakeIntensity, 3.0);
        }
      }
    }
  }

  void _onBossDeath(GameProvider gp, BossShip boss) {
    boss.isDead = true;
    defeated = true;
    killCount++;
    timeSinceLastBoss = 0;
    gp.shakeIntensity = 12.0;
    gp.rampage.chargeLevel = 1.0;

    // Death particles
    for (int i = 0; i < 8; i++) {
      final a = gp._rng.nextDouble() * 2 * pi;
      final spd = 0.008 + gp._rng.nextDouble() * 0.022;
      const cols = [
        Colors.white,
        Color(0xFFFF2D55),
        Color(0xFFFF6B00),
        Color(0xFFFFD60A),
      ];
      gp.particles.add(Particle(
        x: boss.x,
        y: boss.y,
        vx: cos(a) * spd,
        vy: sin(a) * spd,
        life: 1.0,
        color: cols[gp._rng.nextInt(cols.length)],
        size: 8.0 + gp._rng.nextDouble() * 16,
        decay: 0.014,
        shape: ParticleShape.ember,
        angle: a,
      ));
    }

    // Shockwave rings
    gp.shockwaves.add(Shockwave(
        x: boss.x, y: boss.y, radius: 0.01, life: 1.0, color: Colors.white));
    gp.shockwaves.add(Shockwave(
        x: boss.x,
        y: boss.y,
        radius: 0.02,
        life: 1.0,
        color: const Color(0xFFFF2D55)));

    gp.state.score += boss.archetype.defeatScore;
    gp.onRewardCollected?.call(boss.archetype.defeatMessage(killCount));
  }

  @override
  void onComplete(GameProvider gp) {
    // Recurring scenario — never truly completes.
  }

  @override
  void reset() {
    _active = false;
    timeSinceLastBoss = 0;
    killCount = 0;
    spawned = false;
    defeated = false;
  }
}

// ── ENVIRONMENT SCENARIO (stub) ──────────────────────────────────────────────

/// Applies an environmental effect for a set duration.
/// Usage:  add an EnvironmentScenario to `_scenarios` when a sector or event
///         triggers a hazard; the scenario modifies gameplay each frame and
///         auto-deactivates when the timer expires.
class EnvironmentScenario extends GameScenario {
  final EnvironmentalEffect effect;
  final double duration;
  final double strength;

  bool _active = false;
  double _timer = 0;

  EnvironmentScenario({
    required this.effect,
    this.duration = 10.0,
    this.strength = 1.0,
  });

  @override
  bool get isActive => _active;
  @override
  bool get isComplete => _timer >= duration;

  /// Environment scenarios are activated externally (not auto-detected).
  @override
  bool canActivate(GameProvider gp) => false;

  @override
  void onActivate(GameProvider gp) {
    _active = true;
    _timer = 0;
  }

  @override
  void update(GameProvider gp, double dt) {
    if (!_active) return;
    _timer += dt;

    switch (effect) {
      case EnvironmentalEffect.solarWind:
        // Push player sideways
        gp.player.x =
            (gp.player.x + strength * 0.0008 * dt * 60).clamp(0.05, 0.95);
      case EnvironmentalEffect.lowVisibility:
        // Painter reads this via activeEnvironment — no tick logic needed.
        break;
      case EnvironmentalEffect.gravityWell:
        // Pull toward screen centre
        final dx = 0.5 - gp.player.x;
        final dy = 0.5 - gp.player.y;
        gp.player.x += dx * strength * 0.001 * dt * 60;
        gp.player.y += dy * strength * 0.001 * dt * 60;
      case EnvironmentalEffect.none:
        break;
    }

    if (_timer >= duration) {
      _active = false;
      onComplete(gp);
    }
  }

  @override
  void onComplete(GameProvider gp) {}

  @override
  void reset() {
    _active = false;
    _timer = 0;
  }
}
