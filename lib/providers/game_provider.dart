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

  double _timeSinceLastObstacle = 0;
  double _timeSinceLastCoin = 0;
  double _timeSinceLastPowerUp = 0;
  double _gameTime = 0;

  double screenWidth = 400;
  double screenHeight = 800;
  double? _targetX;

  VoidCallback? onGameOver;
  VoidCallback? onHit;
  VoidCallback? onCoinCollected;
  VoidCallback? onScoreUpdate;

  static const double _tickRate = 1 / 60;
  static const double _obstacleInterval = 1.2;
  static const double _coinInterval = 2.0;
  static const double _powerUpInterval = 8.0;

  void startGame({SkinType skin = SkinType.neon}) {
    state = RunState(isPlaying: true);
    player = Player(x: 0.5, y: 0.82, skin: skin);
    obstacles.clear();
    coins.clear();
    powerUps.clear();
    particles.clear();
    _timeSinceLastObstacle = 0;
    _timeSinceLastCoin = 0;
    _timeSinceLastPowerUp = 0;
    _gameTime = 0;
    _targetX = null;
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
    state.difficulty = min(_gameTime / 60.0, 5.0);
    state.speed = 1.0 + state.difficulty * 0.4;
    state.score = (_gameTime * 10).floor();

    if (_targetX != null) {
      final dx = _targetX! - player.x;
      player.x += dx * 0.18;
    }

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

    if (state.isShieldActive) {
      state.shieldTimer -= _tickRate;
      if (state.shieldTimer <= 0) state.isShieldActive = false;
    }
    if (state.isSlowActive) {
      state.slowTimer -= _tickRate;
      if (state.slowTimer <= 0) state.isSlowActive = false;
    }

    final speedMult = state.isSlowActive ? 0.4 : 1.0;
    for (final obs in obstacles) obs.y += obs.speed * state.speed * speedMult;
    obstacles.removeWhere((o) => o.y > 1.1);
    for (final coin in coins) coin.y += coin.speed * state.speed * speedMult;
    coins.removeWhere((c) => c.y > 1.1 || c.collected);
    for (final pu in powerUps) pu.y += pu.speed * state.speed * speedMult;
    powerUps.removeWhere((p) => p.y > 1.1 || p.collected);

    for (final p in particles) {
      p['y'] = (p['y'] as double) + (p['vy'] as double);
      p['x'] = (p['x'] as double) + (p['vx'] as double);
      p['life'] = (p['life'] as double) - 0.04;
    }
    particles.removeWhere((p) => (p['life'] as double) <= 0);

    _checkCollisions();
    onScoreUpdate?.call();
    notifyListeners();
  }

  void _spawnObstacles() {
    final gapPos = 0.1 + _rng.nextDouble() * 0.5;
    final gapWidth = (0.25 - state.difficulty * 0.015).clamp(0.14, 0.25);
    final spd = 0.004 + state.difficulty * 0.0015;
    final color = const Color(0xFFFF3B5C);
    obstacles.add(Obstacle(x: 0, y: -0.06, width: gapPos, height: 0.05, speed: spd, type: ObstacleType.wall, color: color));
    obstacles.add(Obstacle(x: gapPos + gapWidth, y: -0.06, width: 1.0 - (gapPos + gapWidth), height: 0.05, speed: spd, type: ObstacleType.wall, color: color));
    if (state.difficulty > 1.5 && _rng.nextDouble() < 0.25) {
      obstacles.add(Obstacle(x: _rng.nextDouble() * 0.9, y: -0.15, width: 0.04, height: 0.04, speed: spd * 1.3, type: ObstacleType.spike, color: const Color(0xFFFF8C42)));
    }
  }

  void _spawnCoin() {
    coins.add(Coin(x: 0.1 + _rng.nextDouble() * 0.8, y: -0.05, speed: 0.003 + state.difficulty * 0.001));
  }

  void _spawnPowerUp() {
    if (_rng.nextDouble() < 0.5) {
      powerUps.add(PowerUp(x: 0.1 + _rng.nextDouble() * 0.8, y: -0.05, speed: 0.003, type: PowerUpType.values[_rng.nextInt(PowerUpType.values.length)]));
    }
  }

  void _checkCollisions() {
    final pw = player.size / screenWidth;
    final ph = player.size / screenHeight;
    final px = player.x, py = player.y;

    if (!state.isShieldActive) {
      for (final obs in obstacles) {
        const margin = 0.012;
        if (px + pw / 2 - margin > obs.x &&
            px - pw / 2 + margin < obs.x + obs.width &&
            py + ph / 2 - margin > obs.y &&
            py - ph / 2 + margin < obs.y + obs.height) {
          _handleHit();
          return;
        }
      }
    }

    for (final coin in coins) {
      if (!coin.collected) {
        final dist = sqrt(pow(px - coin.x, 2) + pow(py - coin.y, 2));
        if (dist < 0.025 + pw) {
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
        if (dist < 0.035 + pw) {
          pu.collected = true;
          _applyPowerUp(pu.type);
        }
      }
    }
  }

  void _handleHit() {
    state.combo = 0;
    state.lives--;
    onHit?.call();
    _spawnHitParticles(player.x, player.y);
    if (state.lives <= 0) {
      stopGame();
    } else {
      state.isShieldActive = true;
      state.shieldTimer = 2.0;
    }
  }

  void _applyPowerUp(PowerUpType type) {
    switch (type) {
      case PowerUpType.shield:
        state.isShieldActive = true;
        state.shieldTimer = 5.0;
        break;
      case PowerUpType.slowTime:
        state.isSlowActive = true;
        state.slowTimer = 4.0;
        break;
      case PowerUpType.extraLife:
        state.lives = min(state.lives + 1, 5);
        break;
    }
  }

  void _spawnCoinParticles(double x, double y) {
    for (int i = 0; i < 8; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      particles.add({'x': x, 'y': y, 'vx': cos(angle) * 0.008, 'vy': sin(angle) * 0.008 - 0.01, 'life': 1.0, 'color': const Color(0xFFFFB800), 'size': 4.0 + _rng.nextDouble() * 4});
    }
  }

  void _spawnHitParticles(double x, double y) {
    for (int i = 0; i < 14; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      particles.add({'x': x, 'y': y, 'vx': cos(angle) * 0.014, 'vy': sin(angle) * 0.014, 'life': 1.0, 'color': const Color(0xFFFF3B5C), 'size': 5.0 + _rng.nextDouble() * 6});
    }
  }

  @override
  void dispose() {
    _gameLoop?.cancel();
    super.dispose();
  }
}
