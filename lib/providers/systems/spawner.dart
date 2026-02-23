part of '../game_provider.dart';

// ── SPAWNING SYSTEM ──────────────────────────────────────────────────────────
// All obstacle, coin, power-up, and pattern spawning logic.
// Extracted from GameProvider to keep the main file manageable.

extension SpawnerSystem on GameProvider {
  // ── SECTOR-SPECIFIC OBSTACLE INTERVALS ──────────────────────────────────
  // Moved to game_provider.dart as a getter (needs state.lastPattern)

  // ── PATTERN SPAWNER ────────────────────────────────────────────────────────
  void spawnPattern() {
    _waveCount++;

    // BREATH WINDOW: after N waves, send a sparse wave and open the gap
    if (!isBreathWindow &&
        _waveCount >= GameProvider._waveBeforeBreathe &&
        _breathCooldown > 8.0) {
      isBreathWindow = true;
      breathTimer = 2.2;
      _breathCooldown = 0;
      tensionLevel *= 0.3;
      spawnGapWall(forceTier: WallTier.fragile);
      state.lastPattern = PatternType.gapWall;
      onRewardCollected?.call('◎  CLEAR  +300');
      state.score += 300;
      return;
    }

    final pattern = _pickPattern();
    state.lastPattern = pattern;
    switch (pattern) {
      case PatternType.gapWall:
        spawnGapWall();
        break;
      case PatternType.zigzag:
        spawnZigzag();
        break;
      case PatternType.minefield:
        spawnMinefield();
        break;
      case PatternType.sweepBeam:
        spawnSweepBeam();
        break;
      case PatternType.pulseGate:
        spawnPulseGate();
        break;
    }

    // Sector bonuses — extra obstacles per sector
    if (state.sector >= 3 &&
        pattern == PatternType.gapWall &&
        _rng.nextDouble() < 0.4) {
      spawnFloatingAsteroid();
    }
    if (state.sector >= 4 && _rng.nextDouble() < 0.35) {
      spawnExtraMine();
    }
    if (state.sector >= 5 && _rng.nextDouble() < 0.4) {
      spawnGapWall();
    }
  }

  void spawnExtraMine() {
    final mType = _pickMineType();
    obstacles.add(Obstacle(
      x: 0.05 + _rng.nextDouble() * 0.9,
      y: -0.08 - _rng.nextDouble() * 0.1,
      width: 0.055,
      height: 0.055,
      speed: 0.003 + state.difficulty * 0.0008,
      type: ObstacleType.mine,
      color: _mineColor(mType),
      mineType: mType,
      rotationSpeed: (_rng.nextDouble() - 0.5) * 0.08,
    ));
  }

  WallTier _pickWallTier() {
    final d = state.difficulty;
    final s = state.sector;
    final roll = _rng.nextDouble();
    if (s >= 5) {
      if (roll < 0.05) return WallTier.fragile;
      if (roll < 0.20) return WallTier.standard;
      if (roll < 0.55) return WallTier.reinforced;
      return WallTier.armored;
    }
    if (s >= 4 || d >= 3.0) {
      if (roll < 0.10) return WallTier.fragile;
      if (roll < 0.30) return WallTier.standard;
      if (roll < 0.65) return WallTier.reinforced;
      return WallTier.armored;
    }
    if (s >= 3 || d >= 1.5) {
      if (roll < 0.15) return WallTier.fragile;
      if (roll < 0.45) return WallTier.standard;
      if (roll < 0.82) return WallTier.reinforced;
      return WallTier.armored;
    }
    if (s >= 2 || d >= 0.5) {
      if (roll < 0.3) return WallTier.fragile;
      if (roll < 0.75) return WallTier.standard;
      return WallTier.reinforced;
    }
    return roll < 0.6 ? WallTier.fragile : WallTier.standard;
  }

  MineType _pickMineType() {
    final d = state.difficulty;
    final s = state.sector;
    final roll = _rng.nextDouble();
    if (s >= 4 || d >= 2.0) {
      if (roll < 0.35) return MineType.proximity;
      if (roll < 0.65) return MineType.tracker;
      return MineType.cluster;
    }
    if (s >= 3 || d >= 1.0)
      return roll < 0.55 ? MineType.proximity : MineType.tracker;
    return MineType.proximity;
  }

  Color _mineColor(MineType type) {
    switch (type) {
      case MineType.proximity:
        return const Color(0xFFFF6B2B);
      case MineType.tracker:
        return const Color(0xFF00CFFF);
      case MineType.cluster:
        return const Color(0xFFFF2D55);
    }
  }

  void spawnGapWall({WallTier? forceTier}) {
    final tier = forceTier ?? _pickWallTier();
    final tierData = wallTierData(tier);
    final pal = sectorPalette(state.sector);
    final wallCol = pal.wallColor;
    final gapWidth =
        (0.28 - state.difficulty * 0.012 - (state.sector - 1) * 0.008)
            .clamp(0.18, 0.28);

    double referenceCenter = _lastGapCenter;
    double bestY = -999.0;
    for (final obs in obstacles) {
      if (obs.type != ObstacleType.laserWall) continue;
      if (obs.x < 0.02) {
        for (final obs2 in obstacles) {
          if (obs2.type == ObstacleType.laserWall &&
              obs2.x > 0.05 &&
              (obs2.y - obs.y).abs() < 0.015) {
            final gc = (obs.width + obs2.x) / 2.0;
            if (obs.y > bestY) {
              bestY = obs.y;
              referenceCenter = gc;
            }
            break;
          }
        }
      }
    }

    final minC =
        (referenceCenter - GameProvider._maxGapShift).clamp(0.14, 0.86);
    final maxC =
        (referenceCenter + GameProvider._maxGapShift).clamp(0.14, 0.86);
    double gapCenter = minC + _rng.nextDouble() * (maxC - minC);
    gapCenter = gapCenter.clamp(gapWidth / 2 + 0.04, 1.0 - gapWidth / 2 - 0.04);
    _lastGapCenter = gapCenter;

    double lowestSpawnY = -0.055;
    for (final obs in obstacles) {
      if (obs.type != ObstacleType.laserWall) continue;
      if (obs.y < 0.0 && obs.y < lowestSpawnY) lowestSpawnY = obs.y;
    }
    final spawnY = lowestSpawnY - _minRowSeparation;
    final gapLeft = (gapCenter - gapWidth / 2).clamp(0.03, 0.75);
    final spd =
        0.0042 + state.difficulty * 0.0016 + (state.sector - 1) * 0.0008;
    final h = tierData.thickness;

    if (gapLeft > 0.02) {
      obstacles.add(Obstacle(
          x: 0,
          y: spawnY,
          width: gapLeft,
          height: h,
          speed: spd,
          type: ObstacleType.laserWall,
          color: wallCol,
          wallTier: tier,
          sectorIndex: state.sector));
    }
    final rightStart = gapLeft + gapWidth;
    if (rightStart < 0.98) {
      obstacles.add(Obstacle(
          x: rightStart,
          y: spawnY,
          width: 1.0 - rightStart,
          height: h,
          speed: spd,
          type: ObstacleType.laserWall,
          color: wallCol,
          wallTier: tier,
          sectorIndex: state.sector));
    }
  }

  void spawnZigzag() {
    final tier = _pickWallTier();
    final tierData = wallTierData(tier);
    final pal = sectorPalette(state.sector);
    final wallCol = pal.wallColor;
    final spd =
        0.0038 + state.difficulty * 0.0014 + (state.sector - 1) * 0.0006;
    final h = tierData.thickness;
    final leftSide = _rng.nextBool();
    final gw = state.sector >= 4 ? 0.26 : 0.30;

    final gap1Center = leftSide ? 0.20 : 0.70;
    final gap1Left = gap1Center - gw / 2;
    if (gap1Left > 0.02)
      obstacles.add(Obstacle(
          x: 0,
          y: -0.06,
          width: gap1Left,
          height: h,
          speed: spd,
          type: ObstacleType.laserWall,
          color: wallCol,
          wallTier: tier,
          sectorIndex: state.sector));
    final gap1Right = gap1Left + gw;
    if (gap1Right < 0.98)
      obstacles.add(Obstacle(
          x: gap1Right,
          y: -0.06,
          width: 1.0 - gap1Right,
          height: h,
          speed: spd,
          type: ObstacleType.laserWall,
          color: wallCol,
          wallTier: tier,
          sectorIndex: state.sector));

    final gap2Center = leftSide ? 0.70 : 0.20;
    final gap2Left = gap2Center - gw / 2;
    if (gap2Left > 0.02)
      obstacles.add(Obstacle(
          x: 0,
          y: -0.42,
          width: gap2Left,
          height: h,
          speed: spd,
          type: ObstacleType.laserWall,
          color: wallCol,
          wallTier: tier,
          sectorIndex: state.sector));
    final gap2Right = gap2Left + gw;
    if (gap2Right < 0.98)
      obstacles.add(Obstacle(
          x: gap2Right,
          y: -0.42,
          width: 1.0 - gap2Right,
          height: h,
          speed: spd,
          type: ObstacleType.laserWall,
          color: wallCol,
          wallTier: tier,
          sectorIndex: state.sector));
  }

  void spawnMinefield() {
    final spd = 0.003 + state.difficulty * 0.0008 + (state.sector - 1) * 0.0005;
    const mineSize = 0.055;
    const cols = 6;
    const colW = 1.0 / cols;
    final colIndices = List.generate(cols, (i) => i)..shuffle(_rng);
    final mineCount = state.sector >= 4
        ? 5
        : state.sector >= 3
            ? 4
            : 3;
    final usedCols = colIndices.take(mineCount).toList();
    for (int i = 0; i < usedCols.length; i++) {
      final col = usedCols[i];
      final x =
          colW * col + colW * 0.5 + (_rng.nextDouble() - 0.5) * colW * 0.3;
      final yOffset = -0.06 - (i * 0.09) - _rng.nextDouble() * 0.03;
      final mType = _pickMineType();
      obstacles.add(Obstacle(
        x: x.clamp(0.05, 0.95),
        y: yOffset,
        width: mineSize,
        height: mineSize,
        speed: spd,
        type: ObstacleType.mine,
        color: _mineColor(mType),
        mineType: mType,
        rotationSpeed: (_rng.nextDouble() - 0.5) * 0.08,
      ));
    }
  }

  void spawnSweepBeam() {
    final yPos = player.y - 0.12 + _rng.nextDouble() * 0.08;
    final fromLeft = _rng.nextBool();
    final sweepSpd = 0.28 + state.difficulty * 0.04 + (state.sector - 1) * 0.04;
    obstacles.add(Obstacle(
      x: 0,
      y: yPos.clamp(0.15, 0.75),
      width: 1.0,
      height: 0.032,
      speed: 0.0008,
      type: ObstacleType.sweepBeam,
      color: const Color(0xFFFF0080),
      sweepFromLeft: fromLeft,
      sweepSpeed: sweepSpd,
    ));
  }

  void spawnPulseGate() {
    final centerX = 0.22 + _rng.nextDouble() * 0.56;
    final spd = 0.003 + state.difficulty * 0.0008 + (state.sector - 1) * 0.0006;
    const startPhase = pi / 2;
    final halfGap =
        (0.16 - state.difficulty * 0.008 - (state.sector - 1) * 0.006)
            .clamp(0.10, 0.16);
    obstacles.add(Obstacle(
      x: 0,
      y: -0.06,
      width: 1.0,
      height: 0.05,
      speed: spd,
      type: ObstacleType.pulseGate,
      color: const Color(0xFF00CFFF),
      gapCenterX: centerX,
      gapHalfWidth: halfGap,
      pulsePhase: startPhase,
    ));
  }

  void spawnFloatingAsteroid() {
    final size = 0.025 + _rng.nextDouble() * 0.022;
    final spd = 0.004 + state.difficulty * 0.0015 + (state.sector - 1) * 0.0005;
    obstacles.add(Obstacle(
      x: 0.06 + _rng.nextDouble() * 0.88,
      y: -0.15 - _rng.nextDouble() * 0.1,
      width: size,
      height: size,
      speed: spd * (0.8 + _rng.nextDouble() * 0.5),
      type: ObstacleType.asteroid,
      color: const Color(0xFF8B6E4E),
      rotationSpeed: (_rng.nextDouble() - 0.5) * 0.09,
      shape: _generateAsteroidShape(1.0),
    ));
  }

  List<Offset> _generateAsteroidShape(double radius) {
    final points = <Offset>[];
    final numPoints = 7 + _rng.nextInt(4);
    for (int i = 0; i < numPoints; i++) {
      final angle = (2 * pi / numPoints) * i;
      final r = radius * (0.65 + _rng.nextDouble() * 0.4);
      points.add(Offset(cos(angle) * r, sin(angle) * r));
    }
    return points;
  }

  void spawnCoin() {
    if (_rng.nextDouble() < 0.3) {
      final baseX = 0.2 + _rng.nextDouble() * 0.6;
      for (int i = 0; i < 5; i++) {
        final offset = (i - 2) * 0.06;
        coins.add(Coin(
            x: (baseX + offset).clamp(0.1, 0.9),
            y: -0.05 - i * 0.001,
            speed: 0.003 + state.difficulty * 0.0008,
            pulsePhase: i * 0.4));
      }
    } else {
      coins.add(Coin(
          x: 0.1 + _rng.nextDouble() * 0.8,
          y: -0.05,
          speed: 0.003 + state.difficulty * 0.0008));
    }
  }

  void spawnPowerUp() {
    if (_rng.nextDouble() < 0.55) {
      powerUps.add(PowerUp(
          x: 0.1 + _rng.nextDouble() * 0.8,
          y: -0.05,
          speed: 0.003,
          type: PowerUpType.values[_rng.nextInt(PowerUpType.values.length)]));
    }
  }

  void spawnChest(double x, double y) {
    TreasureReward reward;
    final roll = _rng.nextDouble();
    if (roll < 0.08)
      reward = TreasureReward.bomb;
    else if (roll < 0.12)
      reward = TreasureReward.weaponRapid;
    else if (roll < 0.16)
      reward = TreasureReward.weaponSpread;
    else if (roll < 0.20)
      reward = TreasureReward.weaponLaser;
    else {
      const basics = [
        TreasureReward.slowTime,
        TreasureReward.extraLife,
        TreasureReward.coins,
        TreasureReward.shield
      ];
      reward = basics[_rng.nextInt(basics.length)];
    }
    final coinAmt = reward == TreasureReward.coins ? (3 + _rng.nextInt(8)) : 0;
    chests.add(TreasureChest(
      x: x.clamp(0.05, 0.95),
      y: y,
      speed: 0.002,
      reward: reward,
      coinAmount: coinAmt,
      sectorIndex: state.sector,
    ));
  }
}
