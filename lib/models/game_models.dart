import 'package:flutter/material.dart';

enum SkinType { phantom, nova, inferno, specter, titan }

enum ObstacleType { asteroid, laserWall, mine, sweepBeam, pulseGate }

enum PowerUpType { shield, slowTime, extraLife }

enum TrailStyle { clean, ghost, fire, scatter, wide }

Color skinColor(SkinType skin) {
  switch (skin) {
    case SkinType.phantom:
      return const Color(0xFF00FFD1);
    case SkinType.nova:
      return const Color(0xFF4D7CFF);
    case SkinType.inferno:
      return const Color(0xFFFF6B2B);
    case SkinType.specter:
      return const Color(0xFF8B5CF6);
    case SkinType.titan:
      return const Color(0xFFFFD60A);
  }
}

TrailStyle skinTrail(SkinType skin) {
  switch (skin) {
    case SkinType.phantom:
      return TrailStyle.clean;
    case SkinType.nova:
      return TrailStyle.scatter;
    case SkinType.inferno:
      return TrailStyle.fire;
    case SkinType.specter:
      return TrailStyle.ghost;
    case SkinType.titan:
      return TrailStyle.wide;
  }
}

enum PatternType { gapWall, minefield, sweepBeam, pulseGate, zigzag }

class Player {
  double x;
  double y;
  SkinType skin;
  double size;
  double velocityX;
  Color get color => skinColor(skin);
  TrailStyle get trailStyle => skinTrail(skin);

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
  List<Offset> shape;
  // sweep beam
  double sweepProgress;
  double sweepSpeed;
  bool sweepFromLeft;
  bool sweepDone;
  // pulse gate
  double pulsePhase;
  double gapCenterX; // normalized 0-1
  double gapHalfWidth;

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
    this.sweepProgress = 0,
    this.sweepSpeed = 0.35,
    this.sweepFromLeft = true,
    this.sweepDone = false,
    this.pulsePhase = 0,
    this.gapCenterX = 0.5,
    this.gapHalfWidth = 0.12,
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
  int layer;
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
  double vx;
  TrailPoint({
    required this.x,
    required this.y,
    required this.life,
    required this.size,
    required this.color,
    this.vx = 0,
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
  PatternType? lastPattern;

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
    this.lastPattern,
  });
}
