import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/game_models.dart';

class GameProvider extends ChangeNotifier {
  final Random _rng = Random();
  Timer? _gameLoop;

  RunState state = RunState();
  Player player = Player();
  List<Obstacle> obstacles = [];
  List<Coin> coins = [];
  List<PowerUp> powerUps = [];
  List<Bullet> bullets = [];
  List<TreasureChest> chests = [];
  List<Map<String, dynamic>> particles = [];
  List<StarParticle> stars = [];
  List<TrailPoint> trail = [];

  // Ghost after-images for specter skin
  List<Map<String, dynamic>> ghostImages = [];

  double shakeIntensity = 0;
  Offset shakeOffset = Offset.zero;

  double _timeSinceLastObstacle = 0;
  double _timeSinceLastCoin = 0;
  double _timeSinceLastPowerUp = 0;
  double _timeSinceLastShot = 0;
  double _gameTime = 0;
  double _animTick = 0;
  double _ghostTimer = 0;

  // Auto-fire state
  bool _isFiring = false;
  static const double _fireRate = 0.18; // seconds between shots

  double screenWidth = 400;
  double screenHeight = 800;
  double? _targetX;
  double? _targetY;

  double _lastGapCenter = 0.5;
  static const double _maxGapShift = 0.26;

  double get _minRowSeparation {
    return (0.30 + state.difficulty * 0.04).clamp(0.30, 0.55);
  }

  VoidCallback? onGameOver;
  VoidCallback? onHit;
  VoidCallback? onCoinCollected;
  VoidCallback? onScoreUpdate;
  Function(String)? onRewardCollected; // chest reward notification

  static const double _tickRate = 1 / 60;
  static const double _coinInterval = 1.8;
  static const double _powerUpInterval = 7.0;

  double get animTick => _animTick;

  PatternType _pickPattern() {
    final d = state.difficulty;
    final available = <PatternType>[];
    available.add(PatternType.gapWall);
    available.add(PatternType.gapWall);
    if (d > 0.3) available.add(PatternType.zigzag);
    if (d > 0.8) available.add(PatternType.minefield);
    if (d > 1.2) available.add(PatternType.sweepBeam);
    if (d > 1.8) available.add(PatternType.pulseGate);
    final filtered = available.where((p) => p != state.lastPattern).toList();
    final pool = filtered.isEmpty ? available : filtered;
    return pool[_rng.nextInt(pool.length)];
  }

  double get _obstacleInterval {
    switch (state.lastPattern) {
      case PatternType.sweepBeam:
        return 2.2;
      case PatternType.pulseGate:
        return 2.0;
      case PatternType.minefield:
        return 1.8;
      default:
        return 1.1;
    }
  }

  void _initStars() {
    stars.clear();
    for (int i = 0; i < 80; i++) {
      stars.add(StarParticle(
          x: _rng.nextDouble(),
          y: _rng.nextDouble(),
          speed: 0.0004,
          size: 0.5 + _rng.nextDouble() * 0.8,
          opacity: 0.2 + _rng.nextDouble() * 0.3,
          layer: 0));
    }
    for (int i = 0; i < 40; i++) {
      stars.add(StarParticle(
          x: _rng.nextDouble(),
          y: _rng.nextDouble(),
          speed: 0.001,
          size: 0.8 + _rng.nextDouble() * 1.2,
          opacity: 0.3 + _rng.nextDouble() * 0.4,
          layer: 1));
    }
    for (int i = 0; i < 15; i++) {
      stars.add(StarParticle(
          x: _rng.nextDouble(),
          y: _rng.nextDouble(),
          speed: 0.003,
          size: 1.2 + _rng.nextDouble() * 1.5,
          opacity: 0.6 + _rng.nextDouble() * 0.4,
          layer: 2));
    }
  }

  void startGame({SkinType skin = SkinType.phantom}) {
    state = RunState(isPlaying: true);
    player = Player(x: 0.5, y: 0.80, skin: skin);
    obstacles.clear();
    coins.clear();
    powerUps.clear();
    bullets.clear();
    chests.clear();
    particles.clear();
    trail.clear();
    ghostImages.clear();
    shakeIntensity = 0;
    _timeSinceLastObstacle = 0;
    _timeSinceLastCoin = 0;
    _timeSinceLastPowerUp = 0;
    _timeSinceLastShot = 0;
    _gameTime = 0;
    _animTick = 0;
    _ghostTimer = 0;
    _targetX = null;
    _targetY = null;
    _isFiring = false;
    _lastGapCenter = 0.5;
    _initStars();
    _gameLoop?.cancel();
    _gameLoop =
        Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
    notifyListeners();
  }

  void pauseGame() {
    state.isPaused = !state.isPaused;
    notifyListeners();
  }

  void stopGame() {
    _gameLoop?.cancel();
    _gameLoop = null;
    state.isPlaying = false;
    state.isGameOver = true;
    notifyListeners();
    onGameOver?.call();
  }

  // ── INPUT ─────────────────────────────────────────────────────────────────

  void moveTo(double normalizedX, double normalizedY) {
    _targetX = normalizedX.clamp(0.06, 0.94);
    _targetY = normalizedY.clamp(Player.minY, Player.maxY);
  }

  void startFiring() => _isFiring = true;
  void stopFiring() => _isFiring = false;

  void fireSingleShot() {
    _spawnBullet();
    _timeSinceLastShot = 0;
  }

  // ── MAIN TICK ─────────────────────────────────────────────────────────────

  void _tick() {
    if (state.isPaused || !state.isPlaying) return;
    _gameTime += _tickRate;
    _animTick += _tickRate;
    state.difficulty = min(_gameTime / 60.0, 5.0);
    state.speed = 1.0 + state.difficulty * 0.45;
    state.score = (_gameTime * 12).floor();
    state.sector = state.difficulty.floor() + 1;

    // ── Player 2D movement with inertia ──────────────────────────────────────
    if (_targetX != null) {
      final dx = _targetX! - player.x;
      player.velocityX += dx * 0.08;
      player.velocityX *= 0.75;
      player.x = (player.x + player.velocityX).clamp(0.05, 0.95);
    }
    if (_targetY != null) {
      final dy = _targetY! - player.y;
      player.velocityY += dy * 0.08;
      player.velocityY *= 0.75;
      player.y = (player.y + player.velocityY).clamp(Player.minY, Player.maxY);
    }

    final speedMult = state.isSlowActive ? 0.4 : 1.0;

    // ── Auto-fire ────────────────────────────────────────────────────────────
    _timeSinceLastShot += _tickRate;
    if (_isFiring && _timeSinceLastShot >= _fireRate) {
      _spawnBullet();
      _timeSinceLastShot = 0;
    }

    // ── Stars parallax ───────────────────────────────────────────────────────
    for (final star in stars) {
      star.y += star.speed * state.speed * speedMult;
      if (star.y > 1.05) {
        star.y = -0.05;
        star.x = _rng.nextDouble();
      }
    }

    // ── Trail ────────────────────────────────────────────────────────────────
    _updateTrail(speedMult);

    // ── Ghost after-images (specter only) ────────────────────────────────────
    if (player.trailStyle == TrailStyle.ghost) {
      _ghostTimer += _tickRate;
      if (_ghostTimer > 0.08) {
        _ghostTimer = 0;
        ghostImages.add({
          'x': player.x,
          'y': player.y,
          'life': 1.0,
          'size': player.size.toDouble()
        });
      }
      for (final g in ghostImages) g['life'] = (g['life'] as double) - 0.07;
      ghostImages.removeWhere((g) => (g['life'] as double) <= 0);
    } else {
      ghostImages.clear();
    }

    // ── Spawn timers ─────────────────────────────────────────────────────────
    _timeSinceLastObstacle += _tickRate;
    _timeSinceLastCoin += _tickRate;
    _timeSinceLastPowerUp += _tickRate;

    if (_timeSinceLastObstacle >= _obstacleInterval) {
      _spawnPattern();
      _timeSinceLastObstacle = 0;
    }
    if (_timeSinceLastCoin >= _coinInterval) {
      _spawnCoin();
      _timeSinceLastCoin = 0;
    }
    if (_timeSinceLastPowerUp >= _powerUpInterval) {
      _spawnPowerUp();
      _timeSinceLastPowerUp = 0;
    }

    // ── Power-up timers ──────────────────────────────────────────────────────
    if (state.isShieldActive) {
      state.shieldTimer -= _tickRate;
      if (state.shieldTimer <= 0) state.isShieldActive = false;
    }
    if (state.isSlowActive) {
      state.slowTimer -= _tickRate;
      if (state.slowTimer <= 0) state.isSlowActive = false;
    }

    // ── Move bullets ─────────────────────────────────────────────────────────
    for (final b in bullets) {
      b.y += b.vy * speedMult;
      if (b.y < -0.05 || b.y > 1.05) b.active = false;
    }
    bullets.removeWhere((b) => !b.active);

    // ── Move obstacles + damage ticks ────────────────────────────────────────
    for (final obs in obstacles) {
      if (!obs.isDying) {
        obs.y += obs.speed * state.speed * speedMult;
        obs.rotation += obs.rotationSpeed * speedMult;
      }
      if (obs.isDying) {
        obs.deathTimer += _tickRate * 3.0; // death anim speed
      }
      if (obs.type == ObstacleType.sweepBeam && !obs.sweepDone) {
        obs.sweepProgress +=
            obs.sweepSpeed * _tickRate * (state.isSlowActive ? 0.4 : 1.0);
        if (obs.sweepProgress >= 1.0) obs.sweepDone = true;
      }
      if (obs.type == ObstacleType.pulseGate) {
        obs.pulsePhase += _tickRate * 2.8;
      }
    }
    obstacles.removeWhere((o) =>
        o.isFullyDead ||
        o.y > 1.2 ||
        (o.type == ObstacleType.sweepBeam && o.sweepDone && o.y > 0.2));

    // ── Move coins ───────────────────────────────────────────────────────────
    for (final coin in coins) {
      coin.y += coin.speed * state.speed * speedMult;
      coin.pulsePhase += _tickRate * 3;
    }
    coins.removeWhere((c) => c.y > 1.1 || c.collected);

    // ── Move power-ups ───────────────────────────────────────────────────────
    for (final pu in powerUps) {
      pu.y += pu.speed * state.speed * speedMult;
      pu.pulsePhase += _tickRate * 2;
    }
    powerUps.removeWhere((p) => p.y > 1.1 || p.collected);

    // ── Move chests ──────────────────────────────────────────────────────────
    for (final c in chests) {
      c.y += c.speed * state.speed * speedMult;
      c.pulsePhase += _tickRate * 2.5;
    }
    chests.removeWhere((c) => c.y > 1.1 || c.collected);

    // ── Particles ────────────────────────────────────────────────────────────
    for (final p in particles) {
      p['y'] = (p['y'] as double) + (p['vy'] as double);
      p['x'] = (p['x'] as double) + (p['vx'] as double);
      p['vy'] = (p['vy'] as double) + 0.0002;
      p['life'] = (p['life'] as double) - 0.035;
    }
    particles.removeWhere((p) => (p['life'] as double) <= 0);

    // ── Screen shake ─────────────────────────────────────────────────────────
    if (shakeIntensity > 0) {
      shakeIntensity *= 0.82;
      shakeOffset = Offset((_rng.nextDouble() - 0.5) * shakeIntensity,
          (_rng.nextDouble() - 0.5) * shakeIntensity);
      if (shakeIntensity < 0.3) {
        shakeIntensity = 0;
        shakeOffset = Offset.zero;
      }
    }

    _checkBulletCollisions();
    _checkCollisions();
    onScoreUpdate?.call();
    notifyListeners();
  }

  // ── BULLET SPAWN ──────────────────────────────────────────────────────────

  void _spawnBullet() {
    final color = player.color;
    // For Titan (wide ship) spawn two side bullets
    if (player.skin == SkinType.titan) {
      bullets.add(Bullet(x: player.x - 0.04, y: player.y - 0.03, color: color));
      bullets.add(Bullet(x: player.x + 0.04, y: player.y - 0.03, color: color));
    } else {
      bullets.add(Bullet(x: player.x, y: player.y - 0.03, color: color));
    }
    // Tiny muzzle flash particles
    for (int i = 0; i < 4; i++) {
      final angle = -pi / 2 + (_rng.nextDouble() - 0.5) * 0.8;
      particles.add({
        'x': player.x,
        'y': player.y - 0.03,
        'vx': cos(angle) * 0.006,
        'vy': sin(angle) * 0.006,
        'life': 0.4,
        'color': Colors.white,
        'size': 2.5,
      });
    }
  }

  // ── BULLET vs OBSTACLE COLLISIONS ────────────────────────────────────────

  void _checkBulletCollisions() {
    for (final bullet in bullets) {
      if (!bullet.active) continue;
      for (final obs in obstacles) {
        if (!obs.isShootable || obs.isDying || obs.hp <= 0) continue;

        bool hit = false;
        switch (obs.type) {
          case ObstacleType.asteroid:
            final cx = obs.x + obs.width / 2;
            final cy = obs.y + obs.height / 2;
            final dist = sqrt(pow(bullet.x - cx, 2) + pow(bullet.y - cy, 2));
            hit = dist < obs.width * 0.55;
            break;
          case ObstacleType.mine:
            final cx = obs.x + obs.width / 2;
            final cy = obs.y + obs.height / 2;
            final dist = sqrt(pow(bullet.x - cx, 2) + pow(bullet.y - cy, 2));
            hit = dist < obs.width * 0.6;
            break;
          default:
            break;
        }

        if (hit) {
          bullet.active = false;
          _damageObstacle(obs);
          break;
        }
      }
    }
  }

  void _damageObstacle(Obstacle obs) {
    obs.hp--;
    // Hit spark particles
    final cx = obs.x + obs.width / 2;
    final cy = obs.y + obs.height / 2;
    _spawnHitSparks(cx, cy, obs.color);

    if (obs.hp <= 0) {
      // Trigger death animation
      shakeIntensity = 5.0;
      _spawnExplosionParticles(cx, cy);
      // Chance to drop a treasure chest
      if ((obs.type == ObstacleType.asteroid || obs.type == ObstacleType.mine) &&
          _rng.nextDouble() < 0.45) {
        _spawnChest(cx, cy);
      }
      // Bonus score
      state.score += obs.type == ObstacleType.asteroid ? 50 : 30;
    }
  }

  void _spawnHitSparks(double x, double y, Color color) {
    for (int i = 0; i < 6; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 0.005 + _rng.nextDouble() * 0.008;
      particles.add({
        'x': x,
        'y': y,
        'vx': cos(angle) * speed,
        'vy': sin(angle) * speed,
        'life': 0.6,
        'color': Color.lerp(color, Colors.white, 0.5)!,
        'size': 2.5 + _rng.nextDouble() * 2,
      });
    }
  }

  // ── CHEST SPAWN ───────────────────────────────────────────────────────────

  void _spawnChest(double x, double y) {
    final rewards = TreasureReward.values;
    final reward = rewards[_rng.nextInt(rewards.length)];
    int coins = reward == TreasureReward.coins ? (3 + _rng.nextInt(8)) : 0;
    chests.add(TreasureChest(
      x: x.clamp(0.05, 0.95),
      y: y,
      speed: 0.002,
      reward: reward,
      coinAmount: coins,
    ));
  }

  // ── TRAIL ─────────────────────────────────────────────────────────────────

  void _updateTrail(double speedMult) {
    final color = player.color;
    switch (player.trailStyle) {
      case TrailStyle.clean:
        trail.add(TrailPoint(
            x: player.x,
            y: player.y + 0.022,
            life: 1.0,
            size: 5.0 + _rng.nextDouble() * 3,
            color: color));
        if (_rng.nextDouble() < 0.5) {
          trail.add(TrailPoint(
              x: player.x,
              y: player.y + 0.022,
              life: 0.6,
              size: 2.5,
              color: Colors.white));
        }
        break;
      case TrailStyle.scatter:
        for (int i = 0; i < 3; i++) {
          final vx = (_rng.nextDouble() - 0.5) * 0.012;
          trail.add(TrailPoint(
              x: player.x,
              y: player.y + 0.02,
              life: 0.8,
              size: 2.5 + _rng.nextDouble() * 2,
              color: color,
              vx: vx));
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

  // ── PATTERN SPAWNER ───────────────────────────────────────────────────────

  void _spawnPattern() {
    final pattern = _pickPattern();
    state.lastPattern = pattern;
    switch (pattern) {
      case PatternType.gapWall:
        _spawnGapWall();
        break;
      case PatternType.zigzag:
        _spawnZigzag();
        break;
      case PatternType.minefield:
        _spawnMinefield();
        break;
      case PatternType.sweepBeam:
        _spawnSweepBeam();
        break;
      case PatternType.pulseGate:
        _spawnPulseGate();
        break;
    }
    if (pattern == PatternType.gapWall &&
        state.difficulty > 1.5 &&
        _rng.nextDouble() < 0.25) {
      _spawnFloatingAsteroid();
    }
  }

  void _spawnGapWall() {
    final gapWidth = (0.28 - state.difficulty * 0.012).clamp(0.22, 0.28);
    double referenceCenter = _lastGapCenter;
    double bestY = -999.0;
    for (final obs in obstacles) {
      if (obs.type != ObstacleType.laserWall) continue;
      if (obs.y < -0.1 || obs.y > 0.85) continue;
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
    final minC = (referenceCenter - _maxGapShift).clamp(0.14, 0.86);
    final maxC = (referenceCenter + _maxGapShift).clamp(0.14, 0.86);
    double gapCenter = minC + _rng.nextDouble() * (maxC - minC);
    gapCenter =
        gapCenter.clamp(gapWidth / 2 + 0.04, 1.0 - gapWidth / 2 - 0.04);
    _lastGapCenter = gapCenter;

    double lowestSpawnY = -0.055;
    for (final obs in obstacles) {
      if (obs.type != ObstacleType.laserWall) continue;
      if (obs.y < 0.0 && obs.y < lowestSpawnY) lowestSpawnY = obs.y;
    }
    final spawnY = lowestSpawnY - _minRowSeparation;
    final gapLeft = (gapCenter - gapWidth / 2).clamp(0.03, 0.75);
    final spd = 0.0042 + state.difficulty * 0.0016;
    const color = Color(0xFFFF2D55);

    if (gapLeft > 0.02) {
      obstacles.add(Obstacle(
        x: 0, y: spawnY, width: gapLeft, height: 0.042,
        speed: spd, type: ObstacleType.laserWall, color: color,
      ));
    }
    final rightStart = gapLeft + gapWidth;
    if (rightStart < 0.98) {
      obstacles.add(Obstacle(
        x: rightStart, y: spawnY, width: 1.0 - rightStart, height: 0.042,
        speed: spd, type: ObstacleType.laserWall, color: color,
      ));
    }
  }

  void _spawnZigzag() {
    final spd = 0.0038 + state.difficulty * 0.0014;
    const color = Color(0xFFFF8C00);
    final leftSide = _rng.nextBool();
    const gw = 0.30;
    final gap1Center = leftSide ? 0.20 : 0.70;
    final gap1Left = gap1Center - gw / 2;
    if (gap1Left > 0.02)
      obstacles.add(Obstacle(
          x: 0, y: -0.06, width: gap1Left, height: 0.04,
          speed: spd, type: ObstacleType.laserWall, color: color));
    final gap1Right = gap1Left + gw;
    if (gap1Right < 0.98)
      obstacles.add(Obstacle(
          x: gap1Right, y: -0.06, width: 1.0 - gap1Right, height: 0.04,
          speed: spd, type: ObstacleType.laserWall, color: color));
    final gap2Center = leftSide ? 0.70 : 0.20;
    final gap2Left = gap2Center - gw / 2;
    if (gap2Left > 0.02)
      obstacles.add(Obstacle(
          x: 0, y: -0.42, width: gap2Left, height: 0.04,
          speed: spd, type: ObstacleType.laserWall, color: color));
    final gap2Right = gap2Left + gw;
    if (gap2Right < 0.98)
      obstacles.add(Obstacle(
          x: gap2Right, y: -0.42, width: 1.0 - gap2Right, height: 0.04,
          speed: spd, type: ObstacleType.laserWall, color: color));
  }

  void _spawnMinefield() {
    final spd = 0.003 + state.difficulty * 0.0008;
    const mineColor = Color(0xFFFF6B2B);
    const mineSize = 0.030;
    const cols = 6;
    const colW = 1.0 / cols;
    final colIndices = List.generate(cols, (i) => i)..shuffle(_rng);
    final usedCols = colIndices.take(4).toList();
    for (int i = 0; i < usedCols.length; i++) {
      final col = usedCols[i];
      final x = colW * col + colW * 0.5 + (_rng.nextDouble() - 0.5) * colW * 0.3;
      final yOffset = -0.06 - (i * 0.09) - _rng.nextDouble() * 0.03;
      obstacles.add(Obstacle(
        x: x.clamp(0.05, 0.95), y: yOffset,
        width: mineSize, height: mineSize,
        speed: spd, type: ObstacleType.mine, color: mineColor,
        rotationSpeed: (_rng.nextDouble() - 0.5) * 0.08,
      ));
    }
  }

  void _spawnSweepBeam() {
    final yPos = player.y - 0.12 + _rng.nextDouble() * 0.08;
    final fromLeft = _rng.nextBool();
    final sweepSpd = 0.30 + state.difficulty * 0.04;
    obstacles.add(Obstacle(
      x: 0, y: yPos.clamp(0.15, 0.75),
      width: 1.0, height: 0.032,
      speed: 0.0008, type: ObstacleType.sweepBeam,
      color: const Color(0xFFFF0080),
      sweepFromLeft: fromLeft, sweepSpeed: sweepSpd,
    ));
  }

  void _spawnPulseGate() {
    final centerX = 0.22 + _rng.nextDouble() * 0.56;
    final spd = 0.003 + state.difficulty * 0.0008;
    const startPhase = pi / 2;
    final halfGap = (0.16 - state.difficulty * 0.008).clamp(0.12, 0.16);
    obstacles.add(Obstacle(
      x: 0, y: -0.06, width: 1.0, height: 0.05,
      speed: spd, type: ObstacleType.pulseGate,
      color: const Color(0xFF00CFFF),
      gapCenterX: centerX, gapHalfWidth: halfGap, pulsePhase: startPhase,
    ));
  }

  void _spawnFloatingAsteroid() {
    final size = 0.025 + _rng.nextDouble() * 0.022;
    final spd = 0.004 + state.difficulty * 0.0015;
    obstacles.add(Obstacle(
      x: 0.06 + _rng.nextDouble() * 0.88,
      y: -0.15 - _rng.nextDouble() * 0.1,
      width: size, height: size,
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

  void _spawnCoin() {
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

  void _spawnPowerUp() {
    if (_rng.nextDouble() < 0.55) {
      powerUps.add(PowerUp(
          x: 0.1 + _rng.nextDouble() * 0.8,
          y: -0.05,
          speed: 0.003,
          type: PowerUpType.values[_rng.nextInt(PowerUpType.values.length)]));
    }
  }

  // ── COLLISIONS ────────────────────────────────────────────────────────────

  void _checkCollisions() {
    final pw = player.size / screenWidth;
    final ph = player.size / screenHeight;
    final px = player.x, py = player.y;

    if (!state.isShieldActive) {
      for (final obs in obstacles) {
        if (obs.isDying || obs.hp <= 0 && obs.isShootable) continue;
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
              final beamX = obs.sweepFromLeft
                  ? obs.sweepProgress
                  : (1.0 - obs.sweepProgress);
              const beamW = 0.055;
              final beamOnPlayer = (beamX - px).abs() < beamW + pw;
              final beamAtPlayerY =
                  py + ph / 2 > obs.y && py - ph / 2 < obs.y + obs.height;
              hit = beamOnPlayer && beamAtPlayerY;
            }
            break;
          case ObstacleType.pulseGate:
            final openness = (sin(obs.pulsePhase) + 1) / 2;
            final halfGap = obs.gapHalfWidth * max(openness, 0.08);
            final distFromCenter = (px - obs.gapCenterX).abs();
            final inGapZone =
                py + ph / 2 > obs.y && py - ph / 2 < obs.y + obs.height;
            hit = inGapZone &&
                distFromCenter > halfGap + pw * 0.4 &&
                openness < 0.15;
            break;
        }

        if (hit) {
          _handleHit();
          return;
        }
      }
    }

    // Coins
    for (final coin in coins) {
      if (!coin.collected) {
        final dist = sqrt(pow(px - coin.x, 2) + pow(py - coin.y, 2));
        if (dist < 0.028 + pw) {
          coin.collected = true;
          state.coins++;
          state.combo++;
          state.maxCombo = max(state.maxCombo, state.combo);
          _spawnCoinParticles(coin.x, coin.y);
          onCoinCollected?.call();
        }
      }
    }

    // Power-ups
    for (final pu in powerUps) {
      if (!pu.collected) {
        final dist = sqrt(pow(px - pu.x, 2) + pow(py - pu.y, 2));
        if (dist < 0.04 + pw) {
          pu.collected = true;
          _applyPowerUp(pu.type);
          _spawnPowerUpParticles(pu.x, pu.y, pu.type);
        }
      }
    }

    // Treasure chests
    for (final chest in chests) {
      if (!chest.collected) {
        final dist = sqrt(pow(px - chest.x, 2) + pow(py - chest.y, 2));
        if (dist < 0.045 + pw) {
          chest.collected = true;
          _applyChestReward(chest);
          _spawnChestParticles(chest.x, chest.y);
        }
      }
    }
  }

  void _applyChestReward(TreasureChest chest) {
    switch (chest.reward) {
      case TreasureReward.slowTime:
        state.isSlowActive = true;
        state.slowTimer = 5.0;
        onRewardCollected?.call('⏱ SLOW TIME');
        break;
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
    }
  }

  void _handleHit() {
    state.combo = 0;
    state.lives--;
    onHit?.call();
    shakeIntensity = 12.0;
    _spawnExplosionParticles(player.x, player.y);
    if (state.lives <= 0) {
      stopGame();
    } else {
      state.isShieldActive = true;
      state.shieldTimer = 2.5;
    }
  }

  void _applyPowerUp(PowerUpType type) {
    switch (type) {
      case PowerUpType.shield:
        state.isShieldActive = true;
        state.shieldTimer = 6.0;
        break;
      case PowerUpType.slowTime:
        state.isSlowActive = true;
        state.slowTimer = 5.0;
        break;
      case PowerUpType.extraLife:
        state.lives = min(state.lives + 1, 5);
        break;
    }
  }

  void _spawnCoinParticles(double x, double y) {
    for (int i = 0; i < 10; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 0.004 + _rng.nextDouble() * 0.008;
      particles.add({
        'x': x, 'y': y,
        'vx': cos(angle) * speed,
        'vy': sin(angle) * speed - 0.012,
        'life': 1.0,
        'color': const Color(0xFFFFD60A),
        'size': 3.0 + _rng.nextDouble() * 3
      });
    }
  }

  void _spawnExplosionParticles(double x, double y) {
    for (int i = 0; i < 22; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 0.006 + _rng.nextDouble() * 0.016;
      final colors = [
        const Color(0xFFFF2D55),
        const Color(0xFFFF6B2B),
        const Color(0xFFFFB020),
        Colors.white
      ];
      particles.add({
        'x': x, 'y': y,
        'vx': cos(angle) * speed,
        'vy': sin(angle) * speed,
        'life': 1.0,
        'color': colors[_rng.nextInt(colors.length)],
        'size': 4.0 + _rng.nextDouble() * 7
      });
    }
  }

  void _spawnPowerUpParticles(double x, double y, PowerUpType type) {
    final color = type == PowerUpType.shield
        ? const Color(0xFF4D7CFF)
        : type == PowerUpType.slowTime
            ? const Color(0xFF8B5CF6)
            : const Color(0xFFFF2D55);
    for (int i = 0; i < 14; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 0.005 + _rng.nextDouble() * 0.01;
      particles.add({
        'x': x, 'y': y,
        'vx': cos(angle) * speed,
        'vy': sin(angle) * speed - 0.008,
        'life': 1.0,
        'color': color,
        'size': 3.0 + _rng.nextDouble() * 4
      });
    }
  }

  void _spawnChestParticles(double x, double y) {
    for (int i = 0; i < 18; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 0.005 + _rng.nextDouble() * 0.014;
      final colors = [
        const Color(0xFFFFD60A),
        const Color(0xFFFFB020),
        Colors.white,
        const Color(0xFF00FFD1),
      ];
      particles.add({
        'x': x, 'y': y,
        'vx': cos(angle) * speed,
        'vy': sin(angle) * speed - 0.01,
        'life': 1.0,
        'color': colors[_rng.nextInt(colors.length)],
        'size': 3.0 + _rng.nextDouble() * 5
      });
    }
  }

  @override
  void dispose() {
    _gameLoop?.cancel();
    super.dispose();
  }
}
