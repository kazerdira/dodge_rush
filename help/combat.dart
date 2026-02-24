part of '../game_provider.dart';

// ── COMBAT SYSTEM ────────────────────────────────────────────────────────────

extension CombatSystem on GameProvider {
  // ── REBALANCED FIRE RATES ─────────────────────────────────────────────────
  // Slightly slower than original to prevent rapid-fire feeling too easy.
  double getFireRate() {
    if (player.skin == SkinType.titan) return 0.16;  // was 0.14
    switch (state.currentWeapon) {
      case WeaponType.rapidFire: return 0.09;          // was 0.07
      case WeaponType.spread:    return 0.22;          // was 0.20
      case WeaponType.laser:     return 0.06;          // was 0.05
      default:                   return GameProvider._fireRate; // 0.18 unchanged
    }
  }

  void spawnBullets() {
    final color = player.color;

    void flash(double bx, double by) {
      for (int i = 0; i < 4; i++) {
        final angle = -pi / 2 + (_rng.nextDouble() - 0.5) * 0.8;
        particles.add({
          'x': bx, 'y': by,
          'vx': cos(angle) * 0.006, 'vy': sin(angle) * 0.006,
          'life': 0.4, 'color': Colors.white,
          'size': 2.5, 'decay': 0.06,
          'shape': 'spark', 'angle': angle, 'spin': 0.0,
        });
      }
    }

    switch (player.skin) {
      case SkinType.phantom:
        bullets.add(Bullet(
            x: player.x, y: player.y - 0.03,
            vy: state.currentWeapon == WeaponType.rapidFire ? -0.030 : -0.025,
            color: state.currentWeapon == WeaponType.rapidFire ? Colors.yellowAccent : color,
            shape: BulletShape.needle));
        flash(player.x, player.y - 0.03);
        break;

      case SkinType.nova:
        final shots = state.currentWeapon == WeaponType.spread ? 5 : 3;
        for (int i = 0; i < shots; i++) {
          final offset = (i - shots ~/ 2);
          final angle = -pi / 2 + offset * 0.22;
          bullets.add(Bullet(
              x: player.x, y: player.y - 0.03,
              vx: cos(angle) * 0.012, vy: sin(angle) * 0.022,
              color: color, shape: BulletShape.plasma));
        }
        flash(player.x, player.y - 0.03);
        break;

      case SkinType.inferno:
        bullets.add(Bullet(
            x: player.x + (_rng.nextDouble() - 0.5) * 0.015,
            y: player.y - 0.03,
            vy: state.currentWeapon == WeaponType.rapidFire ? -0.030 : -0.025,
            color: color, shape: BulletShape.shell));
        flash(player.x, player.y - 0.03);
        break;

      case SkinType.specter:
        if (state.currentWeapon == WeaponType.laser) {
          bullets.add(Bullet(x: player.x - 0.025, y: player.y - 0.03, vy: -0.045, color: color, shape: BulletShape.beam));
          bullets.add(Bullet(x: player.x + 0.025, y: player.y - 0.03, vy: -0.045, color: color, shape: BulletShape.beam));
        } else {
          bullets.add(Bullet(x: player.x, y: player.y - 0.03, vy: -0.045, color: color, shape: BulletShape.beam));
        }
        flash(player.x, player.y - 0.03);
        break;

      case SkinType.titan:
        bullets.add(Bullet(x: player.x - 0.04, y: player.y - 0.03, vy: -0.022, color: color, shape: BulletShape.cannon));
        bullets.add(Bullet(x: player.x + 0.04, y: player.y - 0.03, vy: -0.022, color: color, shape: BulletShape.cannon));
        if (state.currentWeapon == WeaponType.spread) {
          bullets.add(Bullet(x: player.x - 0.07, y: player.y - 0.01, vx: -0.006, vy: -0.018, color: color, shape: BulletShape.cannon));
          bullets.add(Bullet(x: player.x + 0.07, y: player.y - 0.01, vx: 0.006, vy: -0.018, color: color, shape: BulletShape.cannon));
        }
        flash(player.x - 0.04, player.y - 0.03);
        flash(player.x + 0.04, player.y - 0.03);
        break;
    }
  }

  void checkBulletCollisions() {
    for (final bullet in bullets) {
      if (!bullet.active) continue;
      for (final obs in obstacles) {
        if (!obs.isShootable || obs.isDying || obs.hp <= 0) continue;
        bool hit = false;
        switch (obs.type) {
          case ObstacleType.asteroid:
            final cx = obs.x + obs.width / 2;
            final cy = obs.y + obs.height / 2;
            hit = sqrt(pow(bullet.x - cx, 2) + pow(bullet.y - cy, 2)) < obs.width * 0.55;
            break;
          case ObstacleType.mine:
            final cx = obs.x + obs.width / 2;
            final cy = obs.y + obs.height / 2;
            hit = sqrt(pow(bullet.x - cx, 2) + pow(bullet.y - cy, 2)) < obs.width * 0.7;
            break;
          case ObstacleType.laserWall:
            hit = bullet.x >= obs.x &&
                bullet.x <= obs.x + obs.width &&
                bullet.y >= obs.y &&
                bullet.y <= obs.y + obs.height;
            break;
          case ObstacleType.sweepBeam:
          case ObstacleType.pulseGate:
            break;
        }
        if (hit) {
          bullet.active = false;
          damageObstacle(obs);
          break;
        }
      }
    }
  }

  void damageObstacle(Obstacle obs) {
    obs.hp--;
    final cx = obs.x + obs.width / 2;
    final cy = obs.y + obs.height / 2;

    spawnHitSparks(cx, cy, obs.color);

    if (obs.hp <= 0) {
      shakeIntensity = (obs.wallTier == WallTier.armored)
          ? 14.0
          : (obs.wallTier == WallTier.reinforced)
              ? 10.0
              : 5.0;

      if (obs.type == ObstacleType.laserWall) {
        if (obs.wallTier != null) spawnDebrisParticles(cx, cy, obs.color, obs.wallTier!);
        spawnExplosionParticles(cx, cy);
        if (obs.wallTier == WallTier.reinforced || obs.wallTier == WallTier.armored) {
          shockwaves.add(Shockwave(x: cx, y: cy, radius: 0.02, life: 1.0, color: obs.color));
        }
      } else if (obs.type == ObstacleType.asteroid) {
        spawnStoneDebris(cx, cy);
      } else if (obs.type == ObstacleType.mine) {
        spawnMineExplosion(cx, cy, obs.color);
        shockwaves.add(Shockwave(x: cx, y: cy, radius: 0.015, life: 1.0, color: obs.color));
        if (obs.mineType == MineType.cluster) spawnClusterChildren(cx, cy);
      } else {
        spawnExplosionParticles(cx, cy);
      }

      double dropChance = 0.30;
      if (obs.wallTier == WallTier.reinforced) dropChance = 0.55;
      if (obs.wallTier == WallTier.armored) dropChance = 0.80;
      if (obs.type == ObstacleType.asteroid) dropChance = 0.40;
      if (obs.type == ObstacleType.mine) dropChance = 0.25;
      if (_rng.nextDouble() < dropChance) spawnChest(cx, cy);

      int bonus = 50;
      if (obs.wallTier == WallTier.fragile) bonus = 20;
      if (obs.wallTier == WallTier.standard) bonus = 50;
      if (obs.wallTier == WallTier.reinforced) bonus = 150;
      if (obs.wallTier == WallTier.armored) bonus = 400;
      if (obs.type == ObstacleType.mine) {
        bonus = obs.mineType == MineType.cluster ? 60 : obs.mineType == MineType.tracker ? 80 : 30;
      }
      if (obs.type == ObstacleType.asteroid) bonus = 60;
      state.score += bonus;

      if (!rampage.isActive) {
        final charge = obs.wallTier == WallTier.armored ? 0.12
            : obs.wallTier == WallTier.reinforced ? 0.07
            : obs.type == ObstacleType.mine ? 0.05
            : 0.03;
        rampage.chargeLevel = (rampage.chargeLevel + charge).clamp(0.0, 1.0);
      }
    }
  }

  void spawnClusterChildren(double cx, double cy) {
    for (int i = 0; i < 3; i++) {
      final angle = (2 * pi / 3) * i + _rng.nextDouble() * 0.5;
      final dist = 0.04 + _rng.nextDouble() * 0.03;
      obstacles.add(Obstacle(
        x: cx + cos(angle) * dist - 0.018,
        y: cy + sin(angle) * dist,
        width: 0.035, height: 0.035,
        speed: 0.002 + state.difficulty * 0.0005,
        type: ObstacleType.mine,
        color: const Color(0xFFFF9900),
        mineType: MineType.proximity,
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
        bool hit = false;
        const margin = 0.01;
        switch (obs.type) {
          case ObstacleType.asteroid:
          case ObstacleType.mine:
            final dist = sqrt(pow(px - (obs.x + obs.width / 2), 2) +
                pow(py - (obs.y + obs.height / 2), 2));
            hit = dist < obs.width * 0.5 + pw * 0.45;
            break;
          case ObstacleType.laserWall:
            hit = px + pw / 2 - margin > obs.x &&
                px - pw / 2 + margin < obs.x + obs.width &&
                py + ph / 2 - margin > obs.y &&
                py - ph / 2 + margin < obs.y + obs.height;
            break;
          case ObstacleType.sweepBeam:
            if (!obs.sweepDone) {
              final beamX = obs.sweepFromLeft ? obs.sweepProgress : (1.0 - obs.sweepProgress);
              const beamW = 0.055;
              hit = (beamX - px).abs() < beamW + pw &&
                  py + ph / 2 > obs.y &&
                  py - ph / 2 < obs.y + obs.height;
            }
            break;
          case ObstacleType.pulseGate:
            final openness = ((sin(obs.pulsePhase) + 1) / 2).clamp(0.0, 1.0);
            final halfGap = obs.gapHalfWidth * max(openness, 0.08);
            final distFromCenter = (px - obs.gapCenterX).abs();
            final inGapZone = py + ph / 2 > obs.y && py - ph / 2 < obs.y + obs.height;
            hit = inGapZone && distFromCenter > halfGap + pw * 0.4 && openness < 0.15;
            break;
        }
        if (hit) { handleHit(); return; }
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
      case TreasureReward.slowTime:
        state.isSlowActive = true; state.slowTimer = 5.0;
        onRewardCollected?.call('⏱ SLOW TIME'); break;
      case TreasureReward.extraLife:
        state.lives = min(state.lives + 1, 5);
        onRewardCollected?.call('♥ EXTRA LIFE'); break;
      case TreasureReward.coins:
        state.coins += chest.coinAmount;
        onRewardCollected?.call('✦ ${chest.coinAmount} CREDITS'); break;
      case TreasureReward.shield:
        state.isShieldActive = true; state.shieldTimer = 6.0;
        onRewardCollected?.call('◉ SHIELD'); break;
      case TreasureReward.bomb:
        state.bombs = min(state.bombs + 1, 9);
        onRewardCollected?.call('💥 BOMB +1');
        shakeIntensity = 6.0; break;
      case TreasureReward.weaponRapid:
        state.currentWeapon = WeaponType.rapidFire; state.weaponTimer = 8.0;
        onRewardCollected?.call('⚡ RAPID FIRE'); break;
      case TreasureReward.weaponSpread:
        state.currentWeapon = WeaponType.spread; state.weaponTimer = 8.0;
        onRewardCollected?.call('✦ SPREAD SHOT'); break;
      case TreasureReward.weaponLaser:
        state.currentWeapon = WeaponType.laser; state.weaponTimer = 8.0;
        onRewardCollected?.call('⟐ LASER BEAM'); break;
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
        state.isShieldActive = true; state.shieldTimer = 6.0; break;
      case PowerUpType.slowTime:
        state.isSlowActive = true; state.slowTimer = 5.0; break;
      case PowerUpType.extraLife:
        state.lives = min(state.lives + 1, 5); break;
    }
  }
}
