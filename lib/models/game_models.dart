import 'package:flutter/material.dart';

enum SkinType { phantom, nova, inferno, specter, titan }

enum ObstacleType { asteroid, laserWall, mine, sweepBeam, pulseGate }

enum PowerUpType { shield, slowTime, extraLife }

enum TrailStyle { clean, ghost, fire, scatter, wide }

enum DamageState { healthy, damaged, critical, destroyed }

enum TreasureReward {
  slowTime,
  extraLife,
  coins,
  shield,
  bomb,
  weaponRapid,
  weaponSpread,
  weaponLaser
}

// Mine varieties
enum MineType {
  proximity,  // Classic spiky — explodes on contact
  tracker,    // Slowly homes toward player
  cluster,    // On death splits into 3 smaller mines
}

// Wall difficulty tiers
enum WallTier { fragile, standard, reinforced, armored }

enum WeaponType { basic, rapidFire, spread, laser }

// ── SECTOR PALETTE ────────────────────────────────────────────────────────────
SectorPalette sectorPalette(int sector) {
  switch (sector) {
    case 1:
      return const SectorPalette(
        name: 'VOID EXPANSE',
        wallColor: Color(0xFF00FFD1),
        wallGlow: Color(0xFF00FFAA),
        chestColor: Color(0xFF00E5C0),
        nebulaColor: Color(0xFF001A11),
        accentA: Color(0xFF00FFD1),
        accentB: Color(0xFF00AAFF),
      );
    case 2:
      return const SectorPalette(
        name: 'ASTEROID BELT',
        wallColor: Color(0xFFFF8C00),
        wallGlow: Color(0xFFFFB040),
        chestColor: Color(0xFFFF6B2B),
        nebulaColor: Color(0xFF1A0800),
        accentA: Color(0xFFFF8C00),
        accentB: Color(0xFFFF4400),
      );
    case 3:
      return const SectorPalette(
        name: 'NEBULA CORE',
        wallColor: Color(0xFF8B5CF6),
        wallGlow: Color(0xFFBB80FF),
        chestColor: Color(0xFF7C3AED),
        nebulaColor: Color(0xFF0D0022),
        accentA: Color(0xFF8B5CF6),
        accentB: Color(0xFFFF00FF),
      );
    case 4:
      return const SectorPalette(
        name: 'DEBRIS FIELD',
        wallColor: Color(0xFFFF2D55),
        wallGlow: Color(0xFFFF6080),
        chestColor: Color(0xFFCC1133),
        nebulaColor: Color(0xFF1A0008),
        accentA: Color(0xFFFF2D55),
        accentB: Color(0xFFFF8800),
      );
    default:
      return const SectorPalette(
        name: 'DEEP SPACE',
        wallColor: Color(0xFFFFD60A),
        wallGlow: Color(0xFFFFFF44),
        chestColor: Color(0xFFCC9900),
        nebulaColor: Color(0xFF1A1100),
        accentA: Color(0xFFFFD60A),
        accentB: Color(0xFFFF6B00),
      );
  }
}

class SectorPalette {
  final String name;
  final Color wallColor;
  final Color wallGlow;
  final Color chestColor;
  final Color nebulaColor;
  final Color accentA;
  final Color accentB;
  const SectorPalette({
    required this.name,
    required this.wallColor,
    required this.wallGlow,
    required this.chestColor,
    required this.nebulaColor,
    required this.accentA,
    required this.accentB,
  });
}

Color skinColor(SkinType skin) {
  switch (skin) {
    case SkinType.phantom: return const Color(0xFF00FFD1);
    case SkinType.nova: return const Color(0xFF4D7CFF);
    case SkinType.inferno: return const Color(0xFFFF6B2B);
    case SkinType.specter: return const Color(0xFF8B5CF6);
    case SkinType.titan: return const Color(0xFFFFD60A);
  }
}

TrailStyle skinTrail(SkinType skin) {
  switch (skin) {
    case SkinType.phantom: return TrailStyle.clean;
    case SkinType.nova: return TrailStyle.scatter;
    case SkinType.inferno: return TrailStyle.fire;
    case SkinType.specter: return TrailStyle.ghost;
    case SkinType.titan: return TrailStyle.wide;
  }
}

/// Each ship has a unique base weapon
WeaponType skinBaseWeapon(SkinType skin) {
  switch (skin) {
    case SkinType.phantom: return WeaponType.basic;
    case SkinType.nova: return WeaponType.spread;
    case SkinType.inferno: return WeaponType.rapidFire;
    case SkinType.specter: return WeaponType.laser;
    case SkinType.titan: return WeaponType.basic; // twin cannons variant
  }
}

WallTierData wallTierData(WallTier tier) {
  switch (tier) {
    case WallTier.fragile:
      return WallTierData(hp: 1, color: const Color(0xFF00FFAA), glowColor: const Color(0xFF00FFAA), label: 'FRAGILE', thickness: 0.028, armorPlates: 0);
    case WallTier.standard:
      return WallTierData(hp: 3, color: const Color(0xFF00CFFF), glowColor: const Color(0xFF00EFFF), label: 'STANDARD', thickness: 0.042, armorPlates: 1);
    case WallTier.reinforced:
      return WallTierData(hp: 6, color: const Color(0xFFFF8C00), glowColor: const Color(0xFFFFB020), label: 'REINFORCED', thickness: 0.055, armorPlates: 3);
    case WallTier.armored:
      return WallTierData(hp: 12, color: const Color(0xFFCC00FF), glowColor: const Color(0xFFFF00FF), label: 'ARMORED', thickness: 0.068, armorPlates: 5);
  }
}

class WallTierData {
  final int hp;
  final Color color;
  final Color glowColor;
  final String label;
  final double thickness;
  final int armorPlates;
  const WallTierData({required this.hp, required this.color, required this.glowColor, required this.label, required this.thickness, required this.armorPlates});
}

enum PatternType { gapWall, minefield, sweepBeam, pulseGate, zigzag }

// ── BULLET SHAPES ─────────────────────────────────────────────────────────────
enum BulletShape { needle, plasma, shell, beam, cannon }

class Player {
  double x;
  double y;
  SkinType skin;
  double size;
  double velocityX;
  double velocityY;
  WeaponType weapon;

  static const double minY = 0.35;
  static const double maxY = 0.92;

  Color get color => skinColor(skin);
  TrailStyle get trailStyle => skinTrail(skin);
  WeaponType get baseWeapon => skinBaseWeapon(skin);

  Player({
    this.x = 0.5,
    this.y = 0.80,
    this.skin = SkinType.phantom,
    this.size = 18,
    this.velocityX = 0,
    this.velocityY = 0,
    this.weapon = WeaponType.basic,
  });
}

class Bullet {
  double x, y;
  double vx;
  double vy;
  bool active;
  Color color;
  BulletShape shape;

  Bullet({
    required this.x,
    required this.y,
    this.vx = 0,
    this.vy = -0.022,
    this.active = true,
    this.color = const Color(0xFF00FFD1),
    this.shape = BulletShape.needle,
  });
}

// ── BOMB ─────────────────────────────────────────────────────────────────────
class Bomb {
  double x, y;
  double radius;
  bool detonated;
  double detonationTimer;
  bool active;
  Bomb({required this.x, required this.y, this.radius = 0, this.detonated = false, this.detonationTimer = 0, this.active = true});
}

// ── SHOCKWAVE ─────────────────────────────────────────────────────────────────
class Shockwave {
  double x, y;
  double radius;
  double life;
  Color color;
  Shockwave({required this.x, required this.y, this.radius = 0, this.life = 1.0, this.color = Colors.white});
}

class TreasureChest {
  double x, y, speed;
  bool collected;
  double pulsePhase;
  TreasureReward reward;
  int coinAmount;
  int sectorIndex;

  TreasureChest({
    required this.x,
    required this.y,
    required this.speed,
    required this.reward,
    this.collected = false,
    this.pulsePhase = 0,
    this.coinAmount = 5,
    this.sectorIndex = 1,
  });
}

class Obstacle {
  double x, y, width, height, speed;
  ObstacleType type;
  Color color;
  double rotation;
  double rotationSpeed;
  List<Offset> shape;

  int maxHp;
  int hp;
  WallTier? wallTier;
  MineType? mineType;
  int sectorIndex;

  DamageState get damageState {
    if (maxHp == 0) return DamageState.healthy;
    if (hp <= 0) return DamageState.destroyed;
    final ratio = hp / maxHp;
    if (ratio > 0.66) return DamageState.healthy;
    if (ratio > 0.33) return DamageState.damaged;
    return DamageState.critical;
  }

  double deathTimer;
  bool get isDying => maxHp > 0 && hp <= 0 && deathTimer < 1.0;
  bool get isFullyDead => maxHp > 0 && hp <= 0 && deathTimer >= 1.0;

  // sweep beam
  double sweepProgress;
  double sweepSpeed;
  bool sweepFromLeft;
  bool sweepDone;
  // pulse gate
  double pulsePhase;
  double gapCenterX;
  double gapHalfWidth;
  // tracker mine velocity
  double trackerVX;
  double trackerVY;

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
    this.wallTier,
    this.mineType,
    this.sectorIndex = 1,
    this.sweepProgress = 0,
    this.sweepSpeed = 0.35,
    this.sweepFromLeft = true,
    this.sweepDone = false,
    this.pulsePhase = 0,
    this.gapCenterX = 0.5,
    this.gapHalfWidth = 0.12,
    this.deathTimer = 0,
    this.trackerVX = 0,
    this.trackerVY = 0,
  })  : maxHp = _resolveHp(type, hp, wallTier),
        hp = _resolveHp(type, hp, wallTier);

  static int _resolveHp(ObstacleType type, int? override, WallTier? tier) {
    if (override != null) return override;
    switch (type) {
      case ObstacleType.asteroid: return 3;
      case ObstacleType.mine: return 1;
      case ObstacleType.laserWall: return tier != null ? wallTierData(tier).hp : 3;
      case ObstacleType.sweepBeam: return 0;
      case ObstacleType.pulseGate: return 0;
    }
  }

  bool get isShootable => maxHp > 0;

  double get damageOpacity {
    if (maxHp == 0) return 1.0;
    if (hp <= 0) return deathTimer < 0.5 ? (1.0 - deathTimer * 2) : 0.0;
    switch (damageState) {
      case DamageState.healthy: return 1.0;
      case DamageState.damaged: return 0.8;
      case DamageState.critical: return 0.6;
      default: return 0.0;
    }
  }

  double get greyShift {
    switch (damageState) {
      case DamageState.healthy: return 0.0;
      case DamageState.damaged: return 0.25;
      case DamageState.critical: return 0.55;
      default: return 1.0;
    }
  }
}

class Coin {
  double x, y, speed;
  bool collected;
  double pulsePhase;
  Coin({required this.x, required this.y, required this.speed, this.collected = false, this.pulsePhase = 0});
}

class PowerUp {
  double x, y, speed;
  PowerUpType type;
  bool collected;
  double pulsePhase;
  PowerUp({required this.x, required this.y, required this.speed, required this.type, this.collected = false, this.pulsePhase = 0});
}

class StarParticle {
  double x, y, speed, size, opacity;
  int layer;
  StarParticle({required this.x, required this.y, required this.speed, required this.size, required this.opacity, required this.layer});
}

class TrailPoint {
  double x, y, life, size;
  Color color;
  double vx;
  TrailPoint({required this.x, required this.y, required this.life, required this.size, required this.color, this.vx = 0});
}

class RunState {
  bool isPlaying;
  bool isPaused;
  bool isGameOver;
  int score;
  int coins;
  int lives;
  int bombs;
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
  WeaponType currentWeapon;
  double weaponTimer;

  RunState({
    this.isPlaying = false,
    this.isPaused = false,
    this.isGameOver = false,
    this.score = 0,
    this.coins = 0,
    this.lives = 3,
    this.bombs = 3,
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
    this.currentWeapon = WeaponType.basic,
    this.weaponTimer = 0,
  });
}

// ── BOSS SHIP ─────────────────────────────────────────────────────────────────
class BossShip {
  double x;
  double y;
  double targetX;
  double hp;
  double maxHp;
  double enterSpeed;
  bool isActive;
  bool isDead;
  double deathTimer;
  double fireTimer;
  double fireRate;
  double warningFlash;
  double pulsePhase;

  BossShip({
    this.x = 0.5,
    this.y = -0.35,
    this.targetX = 0.5,
    this.hp = 80,
    this.maxHp = 80,
    this.enterSpeed = 0.0004,
    this.isActive = true,
    this.isDead = false,
    this.deathTimer = 0,
    this.fireTimer = 3.0,
    this.fireRate = 3.5,
    this.warningFlash = 0,
    this.pulsePhase = 0,
  });

  double get hpRatio => (hp / maxHp).clamp(0.0, 1.0);
  bool get isFullyDead => isDead && deathTimer >= 1.0;
  bool get isOnScreen => y > -0.25;
}

// ── BOSS MISSILE ──────────────────────────────────────────────────────────────
class BossMissile {
  double x, y;
  double vx, vy;
  bool active;
  double life;
  Color color;
  BossMissile({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    this.active = true,
    this.life = 1.0,
    this.color = const Color(0xFFFF2D55),
  });
}

// ── RAMPAGE STATE ─────────────────────────────────────────────────────────────
class RampageState {
  bool isActive;
  double timer;
  double chargeLevel;
  double flashPhase;

  RampageState({
    this.isActive = false,
    this.timer = 0,
    this.chargeLevel = 0,
    this.flashPhase = 0,
  });
}
