part of '../game_provider.dart';

// ── COMBAT SYSTEM ────────────────────────────────────────────────────────────

extension CombatSystem on GameProvider {
  // ── FIRE RATE (data-driven via WeaponSlot) ────────────────────────────────
  double getFireRate() =>
      resolveWeaponSlot(player.skin, state.currentWeapon).fireRate;

  // ── BULLET SPAWNING (data-driven via WeaponSlot) ──────────────────────────
  void spawnBullets() {
    final slot = resolveWeaponSlot(player.skin, state.currentWeapon);
    final baseColor = player.color;

    // Muzzle-flash helper — 4 spark particles at a point.
    void flash(double bx, double by) {
      for (int i = 0; i < 4; i++) {
        final angle = -pi / 2 + (_rng.nextDouble() - 0.5) * 0.8;
        particles.add(Particle(
          x: bx,
          y: by,
          vx: cos(angle) * 0.006,
          vy: sin(angle) * 0.006,
          life: 0.4,
          color: Colors.white,
          size: 2.5,
          decay: 0.06,
          shape: ParticleShape.spark,
          angle: angle,
        ));
      }
    }

    // Spawn one bullet per port.
    final flashedDx = <double>{};
    for (final port in slot.ports) {
      final bx = player.x +
          port.dx +
          (port.xJitter > 0 ? (_rng.nextDouble() - 0.5) * port.xJitter : 0);
      final by = player.y + port.dy;

      bullets.add(Bullet(
        x: bx,
        y: by,
        vx: port.vx,
        vy: port.vy,
        color: port.color ?? baseColor,
        shape: port.shape,
        damage: port.damage,
      ));

      // One muzzle flash per unique dx column.
      if (flashedDx.add(port.dx)) flash(player.x + port.dx, by);
    }
  }

  void checkBulletCollisions() {
    for (final bullet in bullets) {
      if (!bullet.active) continue;
      for (final obs in obstacles) {
        if (!obs.isShootable || obs.isDying || obs.hp <= 0) continue;
        if (obs.checkBulletHit(bullet.x, bullet.y)) {
          bullet.active = false;
          damageObstacle(obs, bullet.damage);
          break;
        }
      }
    }
  }

  void damageObstacle(GameEntity obs, [int damage = 1]) {
    obs.hp -= damage;
    final cx = obs.x + obs.width / 2;
    final cy = obs.y + obs.height / 2;

    // Always show impact sparks on hit (regardless of whether it dies)
    spawnHitSparks(cx, cy, obs.color);

    if (obs.hp <= 0) {
      // ── Trigger composable death effects ──────────────────────────────
      for (final fx in obs.deathEffects) {
        switch (fx) {
          case ShakeEffect():
            shakeIntensity = fx.intensity;
            break;
          case ExplosionEffect():
            switch (fx.style) {
              case ExplosionStyle.fire:
                spawnExplosionParticles(cx, cy);
                break;
              case ExplosionStyle.stone:
                spawnStoneDebris(cx, cy);
                break;
              case ExplosionStyle.mine:
                spawnMineExplosion(cx, cy, obs.color);
                break;
              case ExplosionStyle.wallDebris:
                if (fx.wallTier != null) {
                  spawnDebrisParticles(cx, cy, obs.color, fx.wallTier!);
                }
                break;
            }
            break;
          case ShockwaveEffect():
            shockwaves.add(Shockwave(
                x: cx, y: cy, radius: fx.radius, life: 1.0, color: obs.color));
            break;
          case ChestDropEffect():
            if (_rng.nextDouble() < fx.chance) spawnChest(cx, cy);
            break;
          case ScoreEffect():
            state.score += fx.points;
            break;
          case RampageChargeEffect():
            if (!rampage.isActive) {
              rampage.chargeLevel =
                  (rampage.chargeLevel + fx.charge).clamp(0.0, 1.0);
            }
            break;
          case SplitEffect():
            spawnClusterChildren(cx, cy, fx.count, fx.childType);
            break;
        }
      }
    }
  }

  void spawnClusterChildren(
      double cx, double cy, int count, MineType childType) {
    for (int i = 0; i < count; i++) {
      final angle = (2 * pi / count) * i + _rng.nextDouble() * 0.5;
      final dist = 0.04 + _rng.nextDouble() * 0.03;
      obstacles.add(MineEntity(
        x: cx + cos(angle) * dist - 0.018,
        y: cy + sin(angle) * dist,
        width: 0.035,
        height: 0.035,
        speed: 0.002 + state.difficulty * 0.0005,
        color: const Color(0xFFFF9900),
        mineType: childType,
        rotationSpeed: (_rng.nextDouble() - 0.5) * 0.1,
        hp: 1,
      ));
    }
  }

  void checkCollisions() {
    final pw = player.size / screenWidth;
    final ph = player.size / screenHeight;
    final px = player.x, py = player.y;

    if (!state.isShieldActive) {
      for (final obs in obstacles) {
        if (obs.isDying || (obs.hp <= 0 && obs.isShootable)) continue;
        if (obs.checkPlayerHit(px, py, pw, ph)) {
          handleHit();
          return;
        }
      }
    }

    for (final coin in coins) {
      if (!coin.collected) {
        final dist = sqrt(pow(px - coin.x, 2) + pow(py - coin.y, 2));
        if (dist < 0.028 + pw) {
          coin.collected = true;
          state.coins++;
          state.combo++;
          state.maxCombo = max(state.maxCombo, state.combo);
          spawnCoinParticles(coin.x, coin.y);
          onCoinCollected?.call();
          if (state.combo == 10 || state.combo == 25 || state.combo == 50) {
            comboFlash = 1.0;
            onRewardCollected?.call('🔥 COMBO ×${state.combo}  INSANE!');
          }
        }
      }
    }

    for (final pu in powerUps) {
      if (!pu.collected) {
        final dist = sqrt(pow(px - pu.x, 2) + pow(py - pu.y, 2));
        if (dist < 0.04 + pw) {
          pu.collected = true;
          applyPowerUp(pu.type);
          spawnPowerUpParticles(pu.x, pu.y, pu.type);
        }
      }
    }

    for (final chest in chests) {
      if (!chest.collected) {
        final dist = sqrt(pow(px - chest.x, 2) + pow(py - chest.y, 2));
        if (dist < 0.05 + pw) {
          chest.collected = true;
          applyChestReward(chest);
          spawnChestParticles(chest.x, chest.y);
        }
      }
    }
  }

  void applyChestReward(TreasureChest chest) {
    switch (chest.reward) {
      case TreasureReward.extraLife:
        state.lives = min(state.lives + 1, 5);
        onRewardCollected?.call('♥ EXTRA LIFE');
        break;
      case TreasureReward.coins:
        state.coins += chest.coinAmount;
        onRewardCollected?.call('✦ ${chest.coinAmount} CREDITS');
        break;
      case TreasureReward.shield:
        state.isShieldActive = true;
        state.shieldTimer = 6.0;
        onRewardCollected?.call('◉ SHIELD');
        break;
      case TreasureReward.bomb:
        state.bombs = min(state.bombs + 1, 9);
        onRewardCollected?.call('💥 BOMB +1');
        shakeIntensity = 6.0;
        break;
      case TreasureReward.weaponRapid:
        state.currentWeapon = WeaponType.rapidFire;
        state.weaponTimer = 8.0;
        onRewardCollected?.call('⚡ RAPID FIRE');
        break;
      case TreasureReward.weaponSpread:
        state.currentWeapon = WeaponType.spread;
        state.weaponTimer = 8.0;
        onRewardCollected?.call('✦ SPREAD SHOT');
        break;
      case TreasureReward.weaponLaser:
        state.currentWeapon = WeaponType.laser;
        state.weaponTimer = 8.0;
        onRewardCollected?.call('⟐ LASER BEAM');
        break;
    }
  }

  void handleHit() {
    state.combo = 0;
    nearMissStreak = 0;
    state.lives--;
    onHit?.call();
    shakeIntensity = 18.0;
    tensionLevel = 1.0;
    spawnExplosionParticles(player.x, player.y, intense: true);
    if (state.lives <= 0) {
      stopGame();
    } else {
      state.isShieldActive = true;
      state.shieldTimer = 2.5;
      if (state.lives == 1) {
        nearDeathSlowTimer = 1.8;
        onRewardCollected?.call('⚠  LAST LIFE — SLOW TIME');
      }
    }
  }

  void applyPowerUp(PowerUpType type) {
    switch (type) {
      case PowerUpType.shield:
        state.isShieldActive = true;
        state.shieldTimer = 6.0;
        break;
      case PowerUpType.extraLife:
        state.lives = min(state.lives + 1, 5);
        break;
    }
  }
}
