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
  List<Map<String, dynamic>> particles = [];
  List<StarParticle> stars = [];
  List<TrailPoint> trail = [];

  // Screen shake
  double shakeIntensity = 0;
  Offset shakeOffset = Offset.zero;

  double _timeSinceLastObstacle = 0;
  double _timeSinceLastCoin = 0;
  double _timeSinceLastPowerUp = 0;
  double _gameTime = 0;
  double _animTick = 0;

  double screenWidth = 400;
  double screenHeight = 800;
  double? _targetX;

  VoidCallback? onGameOver;
  VoidCallback? onHit;
  VoidCallback? onCoinCollected;
  VoidCallback? onScoreUpdate;

  static const double _tickRate = 1 / 60;
  static const double _obstacleInterval = 1.1;
  static const double _coinInterval = 1.8;
  static const double _powerUpInterval = 7.0;

  double get animTick => _animTick;

  void _initStars() {
    stars.clear();
    // Far layer - many tiny dim stars
    for (int i = 0; i < 80; i++) {
      stars.add(StarParticle(
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        speed: 0.0004,
        size: 0.5 + _rng.nextDouble() * 0.8,
        opacity: 0.2 + _rng.nextDouble() * 0.3,
        layer: 0,
      ));
    }
    // Mid layer
    for (int i = 0; i < 40; i++) {
      stars.add(StarParticle(
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        speed: 0.001,
        size: 0.8 + _rng.nextDouble() * 1.2,
        opacity: 0.3 + _rng.nextDouble() * 0.4,
        layer: 1,
      ));
    }
    // Close layer - few bright fast stars
    for (int i = 0; i < 15; i++) {
      stars.add(StarParticle(
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        speed: 0.003,
        size: 1.2 + _rng.nextDouble() * 1.5,
        opacity: 0.6 + _rng.nextDouble() * 0.4,
        layer: 2,
      ));
    }
  }

  void startGame({SkinType skin = SkinType.phantom}) {
    state = RunState(isPlaying: true);
    player = Player(x: 0.5, y: 0.80, skin: skin);
    obstacles.clear();
    coins.clear();
    powerUps.clear();
    particles.clear();
    trail.clear();
    shakeIntensity = 0;
    _timeSinceLastObstacle = 0;
    _timeSinceLastCoin = 0;
    _timeSinceLastPowerUp = 0;
    _gameTime = 0;
    _animTick = 0;
    _targetX = null;
    _initStars();
    _gameLoop?.cancel();
    _gameLoop = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
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

  void moveTo(double normalizedX) {
    _targetX = normalizedX.clamp(0.06, 0.94);
  }

  void _tick() {
    if (state.isPaused || !state.isPlaying) return;
    _gameTime += _tickRate;
    _animTick += _tickRate;
    state.difficulty = min(_gameTime / 60.0, 5.0);
    state.speed = 1.0 + state.difficulty * 0.45;
    state.score = (_gameTime * 12).floor();
    state.sector = (state.difficulty / 1.0).floor() + 1;

    // Smooth player movement with inertia
    if (_targetX != null) {
      final dx = _targetX! - player.x;
      player.velocityX += dx * 0.08;
      player.velocityX *= 0.75;
      player.x = (player.x + player.velocityX).clamp(0.05, 0.95);
    }

    // Update stars (parallax)
    final speedMult = state.isSlowActive ? 0.4 : 1.0;
    for (final star in stars) {
      star.y += star.speed * state.speed * speedMult;
      if (star.y > 1.05) {
        star.y = -0.05;
        star.x = _rng.nextDouble();
      }
    }

    // Engine trail
    trail.add(TrailPoint(
      x: player.x,
      y: player.y + 0.025,
      life: 1.0,
      size: 6.0 + _rng.nextDouble() * 4,
      color: player.color,
    ));
    // Secondary exhaust
    if (_rng.nextDouble() < 0.6) {
      trail.add(TrailPoint(
        x: player.x + (_rng.nextDouble() - 0.5) * 0.02,
        y: player.y + 0.025,
        life: 0.7,
        size: 3.0 + _rng.nextDouble() * 3,
        color: Colors.white,
      ));
    }
    for (final t in trail) {
      t.y += 0.004 * state.speed * speedMult;
      t.life -= 0.06;
    }
    trail.removeWhere((t) => t.life <= 0);

    // Spawn
    _timeSinceLastObstacle += _tickRate;
    _timeSinceLastCoin += _tickRate;
    _timeSinceLastPowerUp += _tickRate;

    if (_timeSinceLastObstacle >= _obstacleInterval / state.speed) {
      _spawnObstacles();
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

    // Power-up timers
    if (state.isShieldActive) {
      state.shieldTimer -= _tickRate;
      if (state.shieldTimer <= 0) state.isShieldActive = false;
    }
    if (state.isSlowActive) {
      state.slowTimer -= _tickRate;
      if (state.slowTimer <= 0) state.isSlowActive = false;
    }

    // Move obstacles
    for (final obs in obstacles) {
      obs.y += obs.speed * state.speed * speedMult;
      obs.rotation += obs.rotationSpeed * speedMult;
    }
    obstacles.removeWhere((o) => o.y > 1.15);

    // Coins
    for (final coin in coins) {
      coin.y += coin.speed * state.speed * speedMult;
      coin.pulsePhase += _tickRate * 3;
    }
    coins.removeWhere((c) => c.y > 1.1 || c.collected);

    // Power-ups
    for (final pu in powerUps) {
      pu.y += pu.speed * state.speed * speedMult;
      pu.pulsePhase += _tickRate * 2;
    }
    powerUps.removeWhere((p) => p.y > 1.1 || p.collected);

    // Particles
    for (final p in particles) {
      p['y'] = (p['y'] as double) + (p['vy'] as double);
      p['x'] = (p['x'] as double) + (p['vx'] as double);
      p['vy'] = (p['vy'] as double) + 0.0002; // gravity
      p['life'] = (p['life'] as double) - 0.035;
    }
    particles.removeWhere((p) => (p['life'] as double) <= 0);

    // Screen shake decay
    if (shakeIntensity > 0) {
      shakeIntensity *= 0.82;
      shakeOffset = Offset(
        (_rng.nextDouble() - 0.5) * shakeIntensity,
        (_rng.nextDouble() - 0.5) * shakeIntensity,
      );
      if (shakeIntensity < 0.3) {
        shakeIntensity = 0;
        shakeOffset = Offset.zero;
      }
    }

    _checkCollisions();
    onScoreUpdate?.call();
    notifyListeners();
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

  void _spawnObstacles() {
    final gapPos = 0.08 + _rng.nextDouble() * 0.55;
    final gapWidth = (0.28 - state.difficulty * 0.018).clamp(0.15, 0.28);
    final spd = 0.0045 + state.difficulty * 0.0018;

    // Laser wall left
    obstacles.add(Obstacle(
      x: 0, y: -0.06,
      width: gapPos, height: 0.045,
      speed: spd,
      type: ObstacleType.laserWall,
      color: const Color(0xFFFF2D55),
    ));
    // Laser wall right
    obstacles.add(Obstacle(
      x: gapPos + gapWidth, y: -0.06,
      width: 1.0 - (gapPos + gapWidth), height: 0.045,
      speed: spd,
      type: ObstacleType.laserWall,
      color: const Color(0xFFFF2D55),
    ));

    // Asteroids
    if (state.difficulty > 0.5) {
      final numAsteroids = _rng.nextInt(2) + 1;
      for (int i = 0; i < numAsteroids; i++) {
        if (_rng.nextDouble() < 0.35 + state.difficulty * 0.08) {
          final size = 0.028 + _rng.nextDouble() * 0.025;
          obstacles.add(Obstacle(
            x: _rng.nextDouble() * 0.9 + 0.05,
            y: -0.12 - _rng.nextDouble() * 0.1,
            width: size, height: size,
            speed: spd * (0.8 + _rng.nextDouble() * 0.6),
            type: ObstacleType.asteroid,
            color: const Color(0xFF8B6E4E),
            rotationSpeed: (_rng.nextDouble() - 0.5) * 0.08,
            shape: _generateAsteroidShape(1.0),
          ));
        }
      }
    }

    // Mines at high difficulty
    if (state.difficulty > 2.5 && _rng.nextDouble() < 0.25) {
      obstacles.add(Obstacle(
        x: _rng.nextDouble() * 0.85 + 0.05,
        y: -0.2,
        width: 0.035, height: 0.035,
        speed: spd * 0.7,
        type: ObstacleType.mine,
        color: const Color(0xFFFF6B2B),
      ));
    }
  }

  void _spawnCoin() {
    // Spawn in clusters sometimes
    if (_rng.nextDouble() < 0.3) {
      // Line of coins
      final baseX = 0.15 + _rng.nextDouble() * 0.7;
      for (int i = 0; i < 4; i++) {
        coins.add(Coin(
          x: baseX,
          y: -0.05 - i * 0.06,
          speed: 0.0032 + state.difficulty * 0.0008,
          pulsePhase: i * 0.5,
        ));
      }
    } else {
      coins.add(Coin(
        x: 0.1 + _rng.nextDouble() * 0.8,
        y: -0.05,
        speed: 0.0032 + state.difficulty * 0.0008,
      ));
    }
  }

  void _spawnPowerUp() {
    if (_rng.nextDouble() < 0.55) {
      powerUps.add(PowerUp(
        x: 0.1 + _rng.nextDouble() * 0.8,
        y: -0.05,
        speed: 0.003,
        type: PowerUpType.values[_rng.nextInt(PowerUpType.values.length)],
      ));
    }
  }

  void _checkCollisions() {
    final pw = player.size / screenWidth;
    final ph = player.size / screenHeight;
    final px = player.x, py = player.y;

    if (!state.isShieldActive) {
      for (final obs in obstacles) {
        const margin = 0.01;
        if (obs.type == ObstacleType.asteroid || obs.type == ObstacleType.mine) {
          final dist = sqrt(pow(px - (obs.x + obs.width / 2), 2) + pow(py - (obs.y + obs.height / 2), 2));
          if (dist < obs.width * 0.55 + pw * 0.5) {
            _handleHit();
            return;
          }
        } else {
          if (px + pw / 2 - margin > obs.x &&
              px - pw / 2 + margin < obs.x + obs.width &&
              py + ph / 2 - margin > obs.y &&
              py - ph / 2 + margin < obs.y + obs.height) {
            _handleHit();
            return;
          }
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
          _spawnCoinParticles(coin.x, coin.y);
          onCoinCollected?.call();
        }
      }
    }

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
        'size': 3.0 + _rng.nextDouble() * 3,
      });
    }
  }

  void _spawnExplosionParticles(double x, double y) {
    for (int i = 0; i < 20; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 0.006 + _rng.nextDouble() * 0.016;
      final colors = [const Color(0xFFFF2D55), const Color(0xFFFF6B2B), const Color(0xFFFFB020), Colors.white];
      particles.add({
        'x': x, 'y': y,
        'vx': cos(angle) * speed,
        'vy': sin(angle) * speed,
        'life': 1.0,
        'color': colors[_rng.nextInt(colors.length)],
        'size': 4.0 + _rng.nextDouble() * 7,
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
        'size': 3.0 + _rng.nextDouble() * 4,
      });
    }
  }

  @override
  void dispose() {
    _gameLoop?.cancel();
    super.dispose();
  }
}
