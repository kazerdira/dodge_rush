import 'package:flutter/material.dart';

enum SkinType { phantom, nova, inferno, specter, titan }
enum ObstacleType { asteroid, debris, laserWall, mine }
enum PowerUpType { shield, slowTime, extraLife }

Color skinColor(SkinType skin) {
  switch (skin) {
    case SkinType.phantom:  return const Color(0xFF00FFD1);
    case SkinType.nova:     return const Color(0xFF4D7CFF);
    case SkinType.inferno:  return const Color(0xFFFF6B2B);
    case SkinType.specter:  return const Color(0xFF8B5CF6);
    case SkinType.titan:    return const Color(0xFFFFD60A);
  }
}

class Player {
  double x;
  double y;
  SkinType skin;
  double size;
  double velocityX;
  Color get color => skinColor(skin);

  Player({
    this.x = 0.5,
    this.y = 0.80,
    this.skin = SkinType.phantom,
    this.size = 18,
    this.velocityX = 0,
  });
}

class Obstacle {
  double x, y, width, height, speed;
  ObstacleType type;
  Color color;
  double rotation;
  double rotationSpeed;
  List<Offset> shape; // polygon points for asteroids

  Obstacle({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.speed,
    required this.type,
    required this.color,
    this.rotation = 0,
    this.rotationSpeed = 0,
    this.shape = const [],
  });
}

class Coin {
  double x, y, speed;
  bool collected;
  double pulsePhase;
  Coin({
    required this.x,
    required this.y,
    required this.speed,
    this.collected = false,
    this.pulsePhase = 0,
  });
}

class PowerUp {
  double x, y, speed;
  PowerUpType type;
  bool collected;
  double pulsePhase;
  PowerUp({
    required this.x,
    required this.y,
    required this.speed,
    required this.type,
    this.collected = false,
    this.pulsePhase = 0,
  });
}

class StarParticle {
  double x, y, speed, size, opacity;
  int layer; // 0=far, 1=mid, 2=close
  StarParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.opacity,
    required this.layer,
  });
}

class TrailPoint {
  double x, y, life, size;
  Color color;
  TrailPoint({
    required this.x,
    required this.y,
    required this.life,
    required this.size,
    required this.color,
  });
}

class RunState {
  bool isPlaying;
  bool isPaused;
  bool isGameOver;
  int score;
  int coins;
  int lives;
  int combo;
  int maxCombo;
  double difficulty;
  double speed;
  bool isShieldActive;
  double shieldTimer;
  bool isSlowActive;
  double slowTimer;
  int sector;

  RunState({
    this.isPlaying = false,
    this.isPaused = false,
    this.isGameOver = false,
    this.score = 0,
    this.coins = 0,
    this.lives = 3,
    this.combo = 0,
    this.maxCombo = 0,
    this.difficulty = 0,
    this.speed = 1.0,
    this.isShieldActive = false,
    this.shieldTimer = 0,
    this.isSlowActive = false,
    this.slowTimer = 0,
    this.sector = 1,
  });
}
