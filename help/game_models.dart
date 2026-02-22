import 'package:flutter/material.dart';

enum SkinType { phantom, nova, inferno, specter, titan }

enum ObstacleType { asteroid, laserWall, mine, sweepBeam, pulseGate }

enum PowerUpType { shield, slowTime, extraLife }

enum TrailStyle { clean, ghost, fire, scatter, wide }

// Damage states — obstacles degrade visually before dying
enum DamageState { healthy, damaged, critical, destroyed }

enum TreasureReward { slowTime, extraLife, coins, shield }

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
  double velocityY;

  // Vertical movement bounds — player stays in lower 60% of screen
  static const double minY = 0.35;
  static const double maxY = 0.92;

  Color get color => skinColor(skin);
  TrailStyle get trailStyle => skinTrail(skin);

  Player({
    this.x = 0.5,
    this.y = 0.80,
    this.skin = SkinType.phantom,
    this.size = 18,
    this.velocityX = 0,
    this.velocityY = 0,
  });
}

// ── BULLET ───────────────────────────────────────────────────────────────────
class Bullet {
  double x, y;
  double vy; // normalized units per tick (negative = upward)
  bool active;
  Color color;

  Bullet({
    required this.x,
    required this.y,
    this.vy = -0.022,
    this.active = true,
    this.color = const Color(0xFF00FFD1),
  });
}

// ── TREASURE CHEST ──────────────────────────────────────────────────────────
class TreasureChest {
  double x, y, speed;
  bool collected;
  double pulsePhase;
  TreasureReward reward;
  int coinAmount; // only used when reward == coins

  TreasureChest({
    required this.x,
    required this.y,
    required this.speed,
    required this.reward,
    this.collected = false,
    this.pulsePhase = 0,
    this.coinAmount = 5,
  });
}

class Obstacle {
  double x, y, width, height, speed;
  ObstacleType type;
  Color color;
  double rotation;
  double rotationSpeed;
  List<Offset> shape;

  // Damage system
  int maxHp;
  int hp;
  DamageState get damageState {
    if (hp <= 0) return DamageState.destroyed;
    final ratio = hp / maxHp;
    if (ratio > 0.66) return DamageState.healthy;
    if (ratio > 0.33) return DamageState.damaged;
    return DamageState.critical;
  }

  // Visual death animation
  double deathTimer; // counts up after hp <= 0, obstacle removed when > 1.0
  bool get isDying => hp <= 0 && deathTimer < 1.0;
  bool get isFullyDead => hp <= 0 && deathTimer >= 1.0;

  // sweep beam
  double sweepProgress;
  double sweepSpeed;
  bool sweepFromLeft;
  bool sweepDone;
  // pulse gate
  double pulsePhase;
  double gapCenterX;
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
    int? hp,
    this.sweepProgress = 0,
    this.sweepSpeed = 0.35,
    this.sweepFromLeft = true,
    this.sweepDone = false,
    this.pulsePhase = 0,
    this.gapCenterX = 0.5,
    this.gapHalfWidth = 0.12,
    this.deathTimer = 0,
  })  : maxHp = _defaultHp(type),
        hp = hp ?? _defaultHp(type);

  static int _defaultHp(ObstacleType type) {
    switch (type) {
      case ObstacleType.asteroid:
        return 3;
      case ObstacleType.mine:
        return 1;
      case ObstacleType.laserWall:
        return 0; // laser walls are NOT shootable
      case ObstacleType.sweepBeam:
        return 0; // not shootable
      case ObstacleType.pulseGate:
        return 0; // not shootable
    }
  }

  bool get isShootable => maxHp > 0;

  /// Returns opacity multiplier based on damage state for color fade effect
  double get damageOpacity {
    if (hp <= 0) return deathTimer < 0.5 ? (1.0 - deathTimer * 2) : 0.0;
    switch (damageState) {
      case DamageState.healthy:
        return 1.0;
      case DamageState.damaged:
        return 0.75;
      case DamageState.critical:
        return 0.5;
      default:
        return 0.0;
    }
  }

  /// Grey-shift amount: 0 = original color, 1 = fully grey
  double get greyShift {
    switch (damageState) {
      case DamageState.healthy:
        return 0.0;
      case DamageState.damaged:
        return 0.3;
      case DamageState.critical:
        return 0.65;
      default:
        return 1.0;
    }
  }
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
  int bulletsAvailable; // unlimited for now but tracked for future upgrades

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
    this.bulletsAvailable = 999,
  });
}
