import 'dart:math';
import 'package:flutter/material.dart';

enum SkinType { phantom, nova, inferno, specter, titan, sovereign }

// ObstacleType removed — replaced by GameEntity subclass hierarchy (Phase 2)

enum PowerUpType { shield, extraLife }

enum TrailStyle { clean, ghost, fire, scatter, wide }

enum DamageState { healthy, damaged, critical, destroyed }

// ── TYPED PARTICLE SYSTEM ─────────────────────────────────────────────────────
enum ParticleShape { dot, spark, ember, shard, chunk }

class Particle {
  double x, y;
  double vx, vy;
  double life;
  double decay;
  Color color;
  double size;
  ParticleShape shape;
  double angle;
  double spin;
  double aspect; // width ratio for shard/chunk (1.0 = square)

  Particle({
    required this.x,
    required this.y,
    this.vx = 0,
    this.vy = 0,
    this.life = 1.0,
    this.decay = 0.035,
    required this.color,
    this.size = 3.0,
    this.shape = ParticleShape.dot,
    this.angle = 0,
    this.spin = 0,
    this.aspect = 1.0,
  });
}

// ── TYPED GHOST IMAGE ─────────────────────────────────────────────────────────
class GhostImage {
  double x, y, life, size;
  GhostImage({
    required this.x,
    required this.y,
    this.life = 1.0,
    this.size = 18.0,
  });
}

enum TreasureReward {
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
  proximity, // Classic spiky — explodes on contact
  tracker, // Slowly homes toward player
  cluster, // On death splits into 3 smaller mines
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

// ═════════════════════════════════════════════════════════════════════════════
// SECTOR CONFIG — Data-driven sector definitions
// ═════════════════════════════════════════════════════════════════════════════

/// Weighted entry for pattern selection.
class PatternEntry {
  final PatternType type;
  final double weight;
  final double minDifficulty; // pattern unlocks when difficulty >= this
  const PatternEntry(this.type, this.weight, {this.minDifficulty = 0});
}

/// Weighted entry for wall tier selection.
class TierEntry {
  final WallTier tier;
  final double weight;
  const TierEntry(this.tier, this.weight);
}

/// Weighted entry for mine type selection.
class MineEntry {
  final MineType type;
  final double weight;
  const MineEntry(this.type, this.weight);
}

/// Describes an extra obstacle that may spawn after the main pattern.
class SectorBonus {
  final String kind; // 'asteroid', 'mine', 'gapWall'
  final double chance;
  const SectorBonus(this.kind, this.chance);
}

/// Full configuration for one sector. Adding a sector = adding one instance.
class SectorConfig {
  final int index;
  final List<PatternEntry> patterns;
  final List<TierEntry> tiers;
  final List<MineEntry> mines;
  final Map<PatternType, double> patternIntervals;
  final double intervalPerSector; // subtracted from base per sector
  final double minInterval;
  final double maxInterval;
  final int minefieldCount;
  final double gapShrink; // 0.008 → gap narrowing per sector
  final double speedPerSector; // added to base speed per sector
  final List<SectorBonus> bonuses;

  const SectorConfig({
    required this.index,
    required this.patterns,
    required this.tiers,
    required this.mines,
    this.patternIntervals = const {},
    this.intervalPerSector = 0.08,
    this.minInterval = 0.80,
    this.maxInterval = 2.2,
    this.minefieldCount = 3,
    this.gapShrink = 0.008,
    this.speedPerSector = 0.15,
    this.bonuses = const [],
  });
}

// ── The 5 sector definitions ────────────────────────────────────────────────

const _sector1 = SectorConfig(
  index: 1,
  patterns: [
    PatternEntry(PatternType.gapWall, 3),
    PatternEntry(PatternType.zigzag, 1, minDifficulty: 0.2),
    PatternEntry(PatternType.minefield, 1, minDifficulty: 0.5),
  ],
  tiers: [
    TierEntry(WallTier.fragile, 0.6),
    TierEntry(WallTier.standard, 0.4),
  ],
  mines: [
    MineEntry(MineType.proximity, 1),
  ],
  minefieldCount: 3,
);

const _sector2 = SectorConfig(
  index: 2,
  patterns: [
    PatternEntry(PatternType.gapWall, 2),
    PatternEntry(PatternType.zigzag, 1.5),
    PatternEntry(PatternType.minefield, 1),
    PatternEntry(PatternType.sweepBeam, 0.8, minDifficulty: 1.0),
  ],
  tiers: [
    TierEntry(WallTier.fragile, 0.30),
    TierEntry(WallTier.standard, 0.45),
    TierEntry(WallTier.reinforced, 0.25),
  ],
  mines: [
    MineEntry(MineType.proximity, 0.55),
    MineEntry(MineType.tracker, 0.45),
  ],
  minefieldCount: 3,
);

const _sector3 = SectorConfig(
  index: 3,
  patterns: [
    PatternEntry(PatternType.gapWall, 2),
    PatternEntry(PatternType.zigzag, 2),
    PatternEntry(PatternType.minefield, 1.2),
    PatternEntry(PatternType.sweepBeam, 1),
  ],
  tiers: [
    TierEntry(WallTier.fragile, 0.15),
    TierEntry(WallTier.standard, 0.30),
    TierEntry(WallTier.reinforced, 0.37),
    TierEntry(WallTier.armored, 0.18),
  ],
  mines: [
    MineEntry(MineType.proximity, 0.35),
    MineEntry(MineType.tracker, 0.35),
    MineEntry(MineType.cluster, 0.30),
  ],
  minefieldCount: 4,
  bonuses: [
    SectorBonus('asteroid', 0.4),
  ],
);

const _sector4 = SectorConfig(
  index: 4,
  patterns: [
    PatternEntry(PatternType.gapWall, 2),
    PatternEntry(PatternType.zigzag, 1.5),
    PatternEntry(PatternType.minefield, 1.5),
    PatternEntry(PatternType.sweepBeam, 1.5),
    PatternEntry(PatternType.pulseGate, 1),
  ],
  tiers: [
    TierEntry(WallTier.fragile, 0.10),
    TierEntry(WallTier.standard, 0.20),
    TierEntry(WallTier.reinforced, 0.35),
    TierEntry(WallTier.armored, 0.35),
  ],
  mines: [
    MineEntry(MineType.proximity, 0.35),
    MineEntry(MineType.tracker, 0.30),
    MineEntry(MineType.cluster, 0.35),
  ],
  minefieldCount: 5,
  bonuses: [
    SectorBonus('asteroid', 0.4),
    SectorBonus('mine', 0.35),
  ],
);

const _sector5 = SectorConfig(
  index: 5,
  patterns: [
    PatternEntry(PatternType.gapWall, 3),
    PatternEntry(PatternType.zigzag, 1.5),
    PatternEntry(PatternType.minefield, 1.5),
    PatternEntry(PatternType.sweepBeam, 1.5),
    PatternEntry(PatternType.pulseGate, 1.5),
  ],
  tiers: [
    TierEntry(WallTier.fragile, 0.05),
    TierEntry(WallTier.standard, 0.15),
    TierEntry(WallTier.reinforced, 0.35),
    TierEntry(WallTier.armored, 0.45),
  ],
  mines: [
    MineEntry(MineType.proximity, 0.35),
    MineEntry(MineType.tracker, 0.30),
    MineEntry(MineType.cluster, 0.35),
  ],
  minefieldCount: 5,
  bonuses: [
    SectorBonus('asteroid', 0.4),
    SectorBonus('mine', 0.35),
    SectorBonus('gapWall', 0.4),
  ],
);

const _sectors = [_sector1, _sector2, _sector3, _sector4, _sector5];

/// Resolve the sector config for a given sector number (1-based, clamped).
SectorConfig resolveSectorConfig(int sector) =>
    _sectors[(sector.clamp(1, _sectors.length)) - 1];

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
    case SkinType.sovereign:
      return const Color(0xFF4D9AFF);
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
    case SkinType.sovereign:
      return TrailStyle.clean;
  }
}

/// Each ship has a unique base weapon
WeaponType skinBaseWeapon(SkinType skin) {
  switch (skin) {
    case SkinType.phantom:
      return WeaponType.basic;
    case SkinType.nova:
      return WeaponType.spread;
    case SkinType.inferno:
      return WeaponType.rapidFire;
    case SkinType.specter:
      return WeaponType.laser;
    case SkinType.titan:
      return WeaponType.basic; // twin cannons variant
    case SkinType.sovereign:
      return WeaponType.spread; // spine + inner barrels + missile pods
  }
}

WallTierData wallTierData(WallTier tier) {
  switch (tier) {
    case WallTier.fragile:
      return WallTierData(
          hp: 1,
          color: const Color(0xFF00FFAA),
          glowColor: const Color(0xFF00FFAA),
          label: 'FRAGILE',
          thickness: 0.028,
          armorPlates: 0);
    case WallTier.standard:
      return WallTierData(
          hp: 3,
          color: const Color(0xFF00CFFF),
          glowColor: const Color(0xFF00EFFF),
          label: 'STANDARD',
          thickness: 0.042,
          armorPlates: 1);
    case WallTier.reinforced:
      return WallTierData(
          hp: 6,
          color: const Color(0xFFFF8C00),
          glowColor: const Color(0xFFFFB020),
          label: 'REINFORCED',
          thickness: 0.055,
          armorPlates: 3);
    case WallTier.armored:
      return WallTierData(
          hp: 12,
          color: const Color(0xFFCC00FF),
          glowColor: const Color(0xFFFF00FF),
          label: 'ARMORED',
          thickness: 0.068,
          armorPlates: 5);
  }
}

class WallTierData {
  final int hp;
  final Color color;
  final Color glowColor;
  final String label;
  final double thickness;
  final int armorPlates;
  const WallTierData(
      {required this.hp,
      required this.color,
      required this.glowColor,
      required this.label,
      required this.thickness,
      required this.armorPlates});
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
  int damage;

  Bullet({
    required this.x,
    required this.y,
    this.vx = 0,
    this.vy = -0.022,
    this.active = true,
    this.color = const Color(0xFF00FFD1),
    this.shape = BulletShape.needle,
    this.damage = 1,
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// WEAPON SLOT SYSTEM — Data-driven weapon configurations
// ═════════════════════════════════════════════════════════════════════════════

/// A single bullet emission point relative to the ship.
class BulletPort {
  final double dx, dy; // offset from ship center
  final double vx, vy; // velocity
  final BulletShape shape;
  final Color? color; // null = use player.color
  final double xJitter; // random x offset range (inferno scatter)
  final int damage; // hp removed per hit (default 1)

  const BulletPort({
    this.dx = 0,
    this.dy = -0.03,
    this.vx = 0,
    this.vy = -0.025,
    this.shape = BulletShape.needle,
    this.color,
    this.xJitter = 0,
    this.damage = 1,
  });
}

/// A weapon configuration: fire rate + list of bullet ports.
class WeaponSlot {
  final double fireRate;
  final List<BulletPort> ports;

  const WeaponSlot({required this.fireRate, required this.ports});

  /// Generate a spread weapon with evenly-spaced angular ports.
  factory WeaponSlot.spread({
    required double fireRate,
    required int count,
    required double spreadAngle,
    required double speedH,
    required double speedV,
    required BulletShape shape,
    double dy = -0.03,
  }) {
    final ports = List.generate(count, (i) {
      final offset = i - count ~/ 2;
      final angle = -pi / 2 + offset * spreadAngle;
      return BulletPort(
        dy: dy,
        vx: cos(angle) * speedH,
        vy: sin(angle) * speedV,
        shape: shape,
      );
    });
    return WeaponSlot(fireRate: fireRate, ports: ports);
  }
}

/// Resolve the active weapon slot for a given ship + weapon type combo.
/// This is the single source of truth for all weapon configurations.
WeaponSlot resolveWeaponSlot(SkinType skin, WeaponType weapon) {
  switch (skin) {
    case SkinType.phantom:
      final rapid = weapon == WeaponType.rapidFire;
      return WeaponSlot(fireRate: rapid ? 0.09 : 0.18, ports: [
        BulletPort(
          vy: rapid ? -0.030 : -0.025,
          shape: BulletShape.needle,
          color: rapid ? const Color(0xFFFFFF00) : null, // yellowAccent
        ),
      ]);

    case SkinType.nova:
      final count = weapon == WeaponType.spread ? 5 : 3;
      return WeaponSlot.spread(
        fireRate: weapon == WeaponType.spread ? 0.22 : 0.18,
        count: count,
        spreadAngle: 0.22,
        speedH: 0.012,
        speedV: 0.022,
        shape: BulletShape.plasma,
      );

    case SkinType.inferno:
      final rapid = weapon == WeaponType.rapidFire;
      return WeaponSlot(fireRate: rapid ? 0.09 : 0.18, ports: [
        BulletPort(
          vy: rapid ? -0.030 : -0.025,
          shape: BulletShape.shell,
          xJitter: 0.015,
        ),
      ]);

    case SkinType.specter:
      if (weapon == WeaponType.laser) {
        return const WeaponSlot(fireRate: 0.06, ports: [
          BulletPort(dx: -0.025, vy: -0.045, shape: BulletShape.beam, damage: 2),
          BulletPort(dx: 0.025, vy: -0.045, shape: BulletShape.beam, damage: 2),
        ]);
      }
      return const WeaponSlot(fireRate: 0.18, ports: [
        BulletPort(vy: -0.045, shape: BulletShape.beam, damage: 2),
      ]);

    case SkinType.titan:
      final spread = weapon == WeaponType.spread;
      return WeaponSlot(fireRate: 0.16, ports: [
        const BulletPort(dx: -0.04, vy: -0.022, shape: BulletShape.cannon, damage: 2),
        const BulletPort(dx: 0.04, vy: -0.022, shape: BulletShape.cannon, damage: 2),
        if (spread)
          const BulletPort(
              dx: -0.07,
              dy: -0.01,
              vx: -0.006,
              vy: -0.018,
              shape: BulletShape.cannon,
              damage: 2),
        if (spread)
          const BulletPort(
              dx: 0.07,
              dy: -0.01,
              vx: 0.006,
              vy: -0.018,
              shape: BulletShape.cannon,
              damage: 2),
      ]);

    case SkinType.sovereign:
      final spread = weapon == WeaponType.spread;
      return WeaponSlot(fireRate: 0.15, ports: [
        // Spine cannon (gold centre beam)
        const BulletPort(
            dy: -0.055,
            vy: -0.028,
            shape: BulletShape.cannon,
            color: Color(0xFFFFD700),
            damage: 2),
        // Inner barrels
        const BulletPort(
            dx: -0.038, dy: -0.022, vy: -0.024, shape: BulletShape.needle),
        const BulletPort(
            dx: 0.038, dy: -0.022, vy: -0.024, shape: BulletShape.needle),
        // Missile pods (only with spread pickup)
        if (spread)
          const BulletPort(
              dx: -0.105,
              dy: -0.012,
              vx: -0.004,
              vy: -0.020,
              shape: BulletShape.shell,
              color: Color(0xFF4D9AFF)),
        if (spread)
          const BulletPort(
              dx: 0.105,
              dy: -0.012,
              vx: 0.004,
              vy: -0.020,
              shape: BulletShape.shell,
              color: Color(0xFF4D9AFF)),
      ]);
  }
}

// ── BOMB ─────────────────────────────────────────────────────────────────────
class Bomb {
  double x, y;
  double radius;
  bool detonated;
  double detonationTimer;
  bool active;
  Bomb(
      {required this.x,
      required this.y,
      this.radius = 0,
      this.detonated = false,
      this.detonationTimer = 0,
      this.active = true});
}

// ── SHOCKWAVE ─────────────────────────────────────────────────────────────────
class Shockwave {
  double x, y;
  double radius;
  double life;
  Color color;
  Shockwave(
      {required this.x,
      required this.y,
      this.radius = 0,
      this.life = 1.0,
      this.color = Colors.white});
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

// ── HITBOX SYSTEM ─────────────────────────────────────────────────────────────
sealed class Hitbox {}

class CircleHitbox extends Hitbox {
  final double cx, cy, radius;
  CircleHitbox(this.cx, this.cy, this.radius);
}

class RectHitbox extends Hitbox {
  final double x, y, width, height;
  RectHitbox(this.x, this.y, this.width, this.height);
}

class LineHitbox extends Hitbox {
  final double x, y, width, height;
  LineHitbox(this.x, this.y, this.width, this.height);
}

// ── GAME ENTITY BASE CLASS ───────────────────────────────────────────────────
// Shared foundation for all in-game obstacles / hazards.
// Each subclass owns its type-specific fields and overrides update/collision.

abstract class GameEntity {
  double x, y;
  double width, height;
  double speed;
  Color color;
  int maxHp;
  int hp;
  int sectorIndex;
  double deathTimer;

  GameEntity({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.speed,
    required this.color,
    required this.maxHp,
    required this.hp,
    this.sectorIndex = 1,
    this.deathTimer = 0,
  });

  // ── Shared computed properties (from old Obstacle) ──────────────────────
  DamageState get damageState {
    if (maxHp == 0) return DamageState.healthy;
    if (hp <= 0) return DamageState.destroyed;
    final ratio = hp / maxHp;
    if (ratio > 0.66) return DamageState.healthy;
    if (ratio > 0.33) return DamageState.damaged;
    return DamageState.critical;
  }

  bool get isDying => maxHp > 0 && hp <= 0 && deathTimer < 1.0;
  bool get isFullyDead => maxHp > 0 && hp <= 0 && deathTimer >= 1.0;
  bool get isShootable => maxHp > 0;

  double get damageOpacity {
    if (maxHp == 0) return 1.0;
    if (hp <= 0) return deathTimer < 0.5 ? (1.0 - deathTimer * 2) : 0.0;
    switch (damageState) {
      case DamageState.healthy:
        return 1.0;
      case DamageState.damaged:
        return 0.8;
      case DamageState.critical:
        return 0.6;
      default:
        return 0.0;
    }
  }

  double get greyShift {
    switch (damageState) {
      case DamageState.healthy:
        return 0.0;
      case DamageState.damaged:
        return 0.25;
      case DamageState.critical:
        return 0.55;
      default:
        return 1.0;
    }
  }

  // ── Abstract methods — each subclass owns its own logic ─────────────────
  /// Advance this entity one tick. Called when NOT dying.
  void update(double dt, double speedMult, double effectiveSpeedMult,
      double playerX, double playerY, double difficulty);

  /// Can a bullet at (bx,by) hit this entity?
  bool checkBulletHit(double bx, double by);

  /// Does this entity collide with the player rect?
  bool checkPlayerHit(double px, double py, double pw, double ph);

  /// Whether this entity should be removed from the world.
  bool shouldRemove() => isFullyDead || y > 1.2 || x < -0.15 || x > 1.15;

  /// Unique type key used by PainterRegistry for render dispatch.
  String get renderType;

  /// Composable death effects — triggered when hp reaches 0.
  List<DeathEffect> get deathEffects;
}

// ── ASTEROID ENTITY ──────────────────────────────────────────────────────────
class AsteroidEntity extends GameEntity {
  @override
  String get renderType => 'asteroid';

  double rotation;
  double rotationSpeed;
  List<Offset> shape;

  AsteroidEntity({
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required super.speed,
    required super.color,
    this.rotation = 0,
    this.rotationSpeed = 0,
    this.shape = const [],
    int? hp,
    super.sectorIndex,
  }) : super(maxHp: hp ?? 3, hp: hp ?? 3);

  @override
  List<DeathEffect> get deathEffects => const [
        ShakeEffect(5.0),
        ExplosionEffect(ExplosionStyle.stone),
        ChestDropEffect(0.40),
        ScoreEffect(60),
        RampageChargeEffect(0.03),
      ];

  @override
  void update(double dt, double speedMult, double effectiveSpeedMult,
      double playerX, double playerY, double difficulty) {
    y += speed * speedMult;
    rotation += rotationSpeed * effectiveSpeedMult;
  }

  @override
  bool checkBulletHit(double bx, double by) {
    final cx = x + width / 2;
    final cy = y + height / 2;
    return sqrt(pow(bx - cx, 2) + pow(by - cy, 2)) < width * 0.55;
  }

  @override
  bool checkPlayerHit(double px, double py, double pw, double ph) {
    final dist =
        sqrt(pow(px - (x + width / 2), 2) + pow(py - (y + height / 2), 2));
    return dist < width * 0.5 + pw * 0.45;
  }
}

// ── LASER WALL ENTITY ────────────────────────────────────────────────────────
class LaserWallEntity extends GameEntity {
  @override
  String get renderType => 'laserWall';

  WallTier? wallTier;

  LaserWallEntity({
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required super.speed,
    required super.color,
    this.wallTier,
    int? hp,
    super.sectorIndex,
  }) : super(
          maxHp: hp ?? _resolveWallHp(wallTier),
          hp: hp ?? _resolveWallHp(wallTier),
        );

  static int _resolveWallHp(WallTier? tier) {
    return tier != null ? wallTierData(tier).hp : 3;
  }

  @override
  List<DeathEffect> get deathEffects {
    final t = wallTier ?? WallTier.standard;
    return [
      ShakeEffect(t == WallTier.armored
          ? 14.0
          : t == WallTier.reinforced
              ? 10.0
              : 5.0),
      ExplosionEffect(ExplosionStyle.wallDebris, wallTier: wallTier),
      ExplosionEffect(ExplosionStyle.fire),
      if (t == WallTier.reinforced || t == WallTier.armored)
        const ShockwaveEffect(radius: 0.02),
      ChestDropEffect(t == WallTier.armored
          ? 0.80
          : t == WallTier.reinforced
              ? 0.55
              : 0.30),
      ScoreEffect(t == WallTier.fragile
          ? 20
          : t == WallTier.standard
              ? 50
              : t == WallTier.reinforced
                  ? 150
                  : 400),
      RampageChargeEffect(t == WallTier.armored
          ? 0.12
          : t == WallTier.reinforced
              ? 0.07
              : 0.03),
    ];
  }

  @override
  void update(double dt, double speedMult, double effectiveSpeedMult,
      double playerX, double playerY, double difficulty) {
    y += speed * speedMult;
  }

  @override
  bool checkBulletHit(double bx, double by) {
    return bx >= x && bx <= x + width && by >= y && by <= y + height;
  }

  @override
  bool checkPlayerHit(double px, double py, double pw, double ph) {
    const margin = 0.01;
    return px + pw / 2 - margin > x &&
        px - pw / 2 + margin < x + width &&
        py + ph / 2 - margin > y &&
        py - ph / 2 + margin < y + height;
  }
}

// ── MINE ENTITY ──────────────────────────────────────────────────────────────
class MineEntity extends GameEntity {
  @override
  String get renderType => 'mine';

  MineType mineType;
  double rotation;
  double rotationSpeed;
  double pulsePhase;
  double trackerVX;
  double trackerVY;

  MineEntity({
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required super.speed,
    required super.color,
    required this.mineType,
    this.rotation = 0,
    this.rotationSpeed = 0,
    this.pulsePhase = 0,
    this.trackerVX = 0,
    this.trackerVY = 0,
    int? hp,
    super.sectorIndex,
  }) : super(maxHp: hp ?? 1, hp: hp ?? 1);

  @override
  List<DeathEffect> get deathEffects => [
        const ShakeEffect(5.0),
        ExplosionEffect(ExplosionStyle.mine),
        const ShockwaveEffect(radius: 0.015),
        if (mineType == MineType.cluster)
          const SplitEffect(3, MineType.proximity),
        const ChestDropEffect(0.25),
        ScoreEffect(mineType == MineType.cluster
            ? 60
            : mineType == MineType.tracker
                ? 80
                : 30),
        const RampageChargeEffect(0.05),
      ];

  @override
  void update(double dt, double speedMult, double effectiveSpeedMult,
      double playerX, double playerY, double difficulty) {
    y += speed * speedMult;
    rotation += rotationSpeed * effectiveSpeedMult;
    pulsePhase += dt * 3;

    // Tracker mine homing
    if (mineType == MineType.tracker) {
      final dx = playerX - x;
      final dy = playerY - y;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist > 0.02) {
        final trackSpeed = 0.0006 + difficulty * 0.0002;
        trackerVX += (dx / dist) * trackSpeed;
        trackerVY += (dy / dist) * trackSpeed;
        final vmag = sqrt(trackerVX * trackerVX + trackerVY * trackerVY);
        const vmax = 0.004;
        if (vmag > vmax) {
          trackerVX = trackerVX / vmag * vmax;
          trackerVY = trackerVY / vmag * vmax;
        }
      }
      x += trackerVX * effectiveSpeedMult;
      y += trackerVY * effectiveSpeedMult;
    }
  }

  @override
  bool checkBulletHit(double bx, double by) {
    final cx = x + width / 2;
    final cy = y + height / 2;
    return sqrt(pow(bx - cx, 2) + pow(by - cy, 2)) < width * 0.7;
  }

  @override
  bool checkPlayerHit(double px, double py, double pw, double ph) {
    final dist =
        sqrt(pow(px - (x + width / 2), 2) + pow(py - (y + height / 2), 2));
    return dist < width * 0.5 + pw * 0.45;
  }
}

// ── SWEEP BEAM ENTITY ────────────────────────────────────────────────────────
class SweepBeamEntity extends GameEntity {
  @override
  String get renderType => 'sweepBeam';

  double sweepProgress;
  double sweepSpeed;
  bool sweepFromLeft;
  bool sweepDone;

  SweepBeamEntity({
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required super.speed,
    required super.color,
    this.sweepProgress = 0,
    this.sweepSpeed = 0.35,
    this.sweepFromLeft = true,
    this.sweepDone = false,
  }) : super(maxHp: 0, hp: 0);

  @override
  List<DeathEffect> get deathEffects => const [];

  @override
  void update(double dt, double speedMult, double effectiveSpeedMult,
      double playerX, double playerY, double difficulty) {
    y += speed * speedMult;
    if (!sweepDone) {
      sweepProgress += sweepSpeed * dt;
      if (sweepProgress >= 1.0) sweepDone = true;
    }
  }

  @override
  bool checkBulletHit(double bx, double by) => false; // not shootable

  @override
  bool checkPlayerHit(double px, double py, double pw, double ph) {
    if (sweepDone) return false;
    final beamX = sweepFromLeft ? sweepProgress : (1.0 - sweepProgress);
    const beamW = 0.032;
    return (beamX - px).abs() < beamW &&
        py + ph / 2 > y &&
        py - ph / 2 < y + height;
  }

  @override
  bool shouldRemove() => super.shouldRemove() || (sweepDone && y > 0.2);
}

// ── PULSE GATE ENTITY ────────────────────────────────────────────────────────
class PulseGateEntity extends GameEntity {
  @override
  String get renderType => 'pulseGate';

  double pulsePhase;
  double gapCenterX;
  double gapHalfWidth;

  PulseGateEntity({
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required super.speed,
    required super.color,
    this.pulsePhase = 0,
    this.gapCenterX = 0.5,
    this.gapHalfWidth = 0.12,
  }) : super(maxHp: 0, hp: 0);

  @override
  List<DeathEffect> get deathEffects => const [];

  @override
  void update(double dt, double speedMult, double effectiveSpeedMult,
      double playerX, double playerY, double difficulty) {
    y += speed * speedMult;
    pulsePhase += dt * 2.8;
  }

  @override
  bool checkBulletHit(double bx, double by) => false; // not shootable

  @override
  bool checkPlayerHit(double px, double py, double pw, double ph) {
    final openness = (sin(pulsePhase) + 1) / 2;
    final halfGap = gapHalfWidth * max(openness, 0.05);
    final distFromCenter = (px - gapCenterX).abs();
    final inGapZone = py + ph / 2 > y && py - ph / 2 < y + height;
    return inGapZone && distFromCenter > halfGap + pw * 0.5 && openness < 0.08;
  }
}

class Coin {
  double x, y, speed;
  bool collected;
  double pulsePhase;
  Coin(
      {required this.x,
      required this.y,
      required this.speed,
      this.collected = false,
      this.pulsePhase = 0});
}

class PowerUp {
  double x, y, speed;
  PowerUpType type;
  bool collected;
  double pulsePhase;
  PowerUp(
      {required this.x,
      required this.y,
      required this.speed,
      required this.type,
      this.collected = false,
      this.pulsePhase = 0});
}

class StarParticle {
  double x, y, speed, size, opacity;
  int layer;
  StarParticle(
      {required this.x,
      required this.y,
      required this.speed,
      required this.size,
      required this.opacity,
      required this.layer});
}

class TrailPoint {
  double x, y, life, size;
  Color color;
  double vx;
  TrailPoint(
      {required this.x,
      required this.y,
      required this.life,
      required this.size,
      required this.color,
      this.vx = 0});
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
    this.sector = 1,
    this.lastPattern,
    this.currentWeapon = WeaponType.basic,
    this.weaponTimer = 0,
  });
}

// ── BOSS SHIP ─────────────────────────────────────────────────────────────────
class BossShip {
  final BossArchetype archetype;
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
  double _baseFireRate;
  double warningFlash;
  double pulsePhase;

  BossShip({
    required this.archetype,
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
    double fireRate = 3.5,
    this.warningFlash = 0,
    this.pulsePhase = 0,
  }) : _baseFireRate = fireRate;

  double get hpRatio => (hp / maxHp).clamp(0.0, 1.0);
  BossPhase get activePhase => archetype.activePhase(hpRatio);
  double get fireRate => _baseFireRate * activePhase.fireRateScale;
  double get trackingSpeed => activePhase.trackingSpeed;
  BossFirePattern get firePattern => activePhase.pattern;
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

// ═════════════════════════════════════════════════════════════════════════════
// BOSS ARCHETYPE SYSTEM — Data-driven boss types with phase transitions
// ═════════════════════════════════════════════════════════════════════════════

/// A single missile emission point relative to the boss.
class BossMissilePort {
  final double dx; // x offset from boss center
  final double dy; // y offset from boss center (0.09 = muzzle line)
  final double dvx, dvy; // velocity offset added to aimed direction
  final Color color;

  const BossMissilePort({
    this.dx = 0,
    this.dy = 0.09,
    this.dvx = 0,
    this.dvy = 0,
    this.color = const Color(0xFFFF2D55),
  });
}

/// A boss's fire pattern: aim speed + missile layout.
class BossFirePattern {
  final double aimSpeed; // missile speed toward player
  final List<BossMissilePort> ports;

  const BossFirePattern({this.aimSpeed = 0.013, required this.ports});
}

/// One phase of a boss fight, active while hpRatio > [hpThreshold].
class BossPhase {
  final double hpThreshold; // phase active when hpRatio > this (0.0 = final)
  final double fireRateScale; // multiplied by base fire rate
  final double trackingSpeed; // how fast boss follows player.x
  final BossFirePattern pattern;

  const BossPhase({
    required this.hpThreshold,
    this.fireRateScale = 1.0,
    this.trackingSpeed = 0.008,
    required this.pattern,
  });
}

/// Abstract template for a boss type. Subclass to define new bosses.
abstract class BossArchetype {
  const BossArchetype();

  String get name;
  String get painterId;
  List<BossPhase> get phases; // ordered by hpThreshold descending
  int get defeatScore;

  double baseHp(int sector, int killCount);
  double baseFireRate(int sector, int killCount);
  String arrivalMessage(int killCount);
  String defeatMessage(int killCount);

  /// Resolve the active phase for a given HP ratio.
  BossPhase activePhase(double hpRatio) {
    for (final phase in phases) {
      if (hpRatio > phase.hpThreshold) return phase;
    }
    return phases.last;
  }
}

/// The original boss migrated to an archetype.
/// Phase 1 (> 50 % HP): 3-missile volley, normal tracking.
/// Phase 2 (≤ 50 % HP): 5-missile volley, faster fire, aggressive tracking.
class ImperialHunterArchetype extends BossArchetype {
  const ImperialHunterArchetype();

  @override
  String get name => 'Imperial Hunter';
  @override
  String get painterId => 'imperial_hunter';
  @override
  int get defeatScore => 5000;

  // ── Phase 1: standard 3-missile volley (matches original behavior)
  static const _standardVolley = BossFirePattern(aimSpeed: 0.013, ports: [
    BossMissilePort(), // center, red
    BossMissilePort(
        dx: -0.06, dvx: -0.004, dvy: 0.002, color: Color(0xFFFF6B00)),
    BossMissilePort(dx: 0.06, dvx: 0.004, dvy: 0.002, color: Color(0xFFFF6B00)),
  ]);

  // ── Phase 2: enraged 5-missile volley (new content)
  static const _enragedVolley = BossFirePattern(aimSpeed: 0.015, ports: [
    BossMissilePort(), // center, red
    BossMissilePort(
        dx: -0.06, dvx: -0.004, dvy: 0.002, color: Color(0xFFFF6B00)),
    BossMissilePort(dx: 0.06, dvx: 0.004, dvy: 0.002, color: Color(0xFFFF6B00)),
    BossMissilePort(
        dx: -0.10, dvx: -0.008, dvy: 0.004, color: Color(0xFFFF4400)),
    BossMissilePort(dx: 0.10, dvx: 0.008, dvy: 0.004, color: Color(0xFFFF4400)),
  ]);

  @override
  List<BossPhase> get phases => const [
        BossPhase(
          hpThreshold: 0.5,
          fireRateScale: 1.0,
          trackingSpeed: 0.008,
          pattern: _standardVolley,
        ),
        BossPhase(
          hpThreshold: 0.0,
          fireRateScale: 0.7,
          trackingSpeed: 0.015,
          pattern: _enragedVolley,
        ),
      ];

  @override
  double baseHp(int sector, int killCount) =>
      60.0 + sector * 15 + killCount * 20.0;

  @override
  double baseFireRate(int sector, int killCount) {
    final rateScale = max(1.2, 3.5 - sector * 0.3 - killCount * 0.2);
    return killCount >= 1 ? max(0.9, rateScale - 0.3) : rateScale;
  }

  @override
  String arrivalMessage(int killCount) {
    if (killCount == 0) return '⚠  IMPERIAL HUNTER DETECTED';
    return '⚠  HUNTER ${romanNumeral(killCount + 1)} — UPGRADED';
  }

  @override
  String defeatMessage(int killCount) {
    if (killCount == 1) return '★  HUNTER DESTROYED  +5000';
    return '★  HUNTER ${romanNumeral(killCount)} DESTROYED  +5000';
  }
}

/// Registry mapping sector + wave to boss archetype.
class BossRegistry {
  static const _hunter = ImperialHunterArchetype();

  /// Resolve which boss archetype to spawn.
  /// Future: return different archetypes per sector.
  static BossArchetype resolve(int sector, int killCount) => _hunter;
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

// ═════════════════════════════════════════════════════════════════════════════
// DEATH EFFECT SYSTEM — Composable death behaviors snapped onto entities
// ═════════════════════════════════════════════════════════════════════════════

/// Marker base class for all death effects.
/// Each concrete effect is a pure data class describing WHAT should happen.
/// The GameProvider reads these and executes the actual logic.
sealed class DeathEffect {
  const DeathEffect();
}

/// Screen shake on death.
class ShakeEffect extends DeathEffect {
  final double intensity;
  const ShakeEffect(this.intensity);
}

/// Spawn explosion/debris particles at death position.
enum ExplosionStyle { fire, stone, mine, wallDebris }

class ExplosionEffect extends DeathEffect {
  final ExplosionStyle style;
  final WallTier? wallTier; // only for wallDebris style
  const ExplosionEffect(this.style, {this.wallTier});
}

/// Spawn a shockwave ring at death position.
class ShockwaveEffect extends DeathEffect {
  final double radius;
  const ShockwaveEffect({this.radius = 0.015});
}

/// Chance to drop a treasure chest.
class ChestDropEffect extends DeathEffect {
  final double chance;
  const ChestDropEffect(this.chance);
}

/// Award score points on kill.
class ScoreEffect extends DeathEffect {
  final int points;
  const ScoreEffect(this.points);
}

/// Charge the rampage meter on kill.
class RampageChargeEffect extends DeathEffect {
  final double charge;
  const RampageChargeEffect(this.charge);
}

/// Spawn child entities on death (cluster mine split).
class SplitEffect extends DeathEffect {
  final int count;
  final MineType childType;
  const SplitEffect(this.count, this.childType);
}

// ── HELPERS ───────────────────────────────────────────────────────────────────

/// Small Roman numeral helper for boss wave labels.
String romanNumeral(int n) {
  const numerals = [
    'I',
    'II',
    'III',
    'IV',
    'V',
    'VI',
    'VII',
    'VIII',
    'IX',
    'X'
  ];
  return n >= 1 && n <= numerals.length ? numerals[n - 1] : '$n';
}
