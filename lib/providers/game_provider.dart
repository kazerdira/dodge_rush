import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/game_models.dart';
import '../utils/safe_color.dart';

part 'systems/spawner.dart';
part 'systems/combat.dart';
part 'systems/particles.dart';
part 'systems/boss_system.dart';

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
  List<Shockwave> shockwaves = [];

  Bomb? activeBomb;
  List<Obstacle> _bombKillQueue = [];
  int _bombKillCursor = 0;
  List<Map<String, dynamic>> ghostImages = [];

  // ── BOSS ──────────────────────────────────────────────────────────────────
  BossShip? boss;
  List<BossMissile> bossMissiles = [];
  bool bossDefeated = false;
  bool bossSpawned = false;
  int bossKillCount = 0; // how many times boss has been killed
  double _timeSinceLastBoss = 0; // timer for respawn
  static const double _bossRespawnInterval =
      45.0; // respawn every 45s after kill

  // ── RAMPAGE ───────────────────────────────────────────────────────────────
  RampageState rampage = RampageState();
  bool get isRampageReady => rampage.chargeLevel >= 1.0 && !rampage.isActive;

  // ── GAUNTLET / ESCAPE ─────────────────────────────────────────────────────
  bool gauntletActive = false;
  double gauntletTimer = 0.0;
  static const double _gauntletDuration = 30.0;
  bool escaped = false;
  double escapeFlashTimer = 0.0;

  double shakeIntensity = 0;
  Offset shakeOffset = Offset.zero;

  double _timeSinceLastObstacle = 0;
  double _timeSinceLastCoin = 0;
  double _timeSinceLastPowerUp = 0;
  double _timeSinceLastShot = 0;
  double _gameTime = 0;
  double _animTick = 0;
  double _ghostTimer = 0;
  // Asteroid trickle timer — always some asteroids flying
  double _timeSinceLastAsteroid = 0;

  bool _isFiring = true;
  static const double _fireRate = 0.18;

  double screenWidth = 400;
  double screenHeight = 800;
  double? _targetX;
  double? _targetY;

  double _lastGapCenter = 0.5;
  static const double _maxGapShift = 0.26;

  // ── DRAMA / TENSION SYSTEM ────────────────────────────────────────────────
  double tensionLevel = 0.0; // 0..1 — how "oh shit" the moment feels
  double breathTimer = 0.0; // counts down a calm window
  bool isBreathWindow = false; // true = calm gap between waves
  double _breathCooldown = 0.0; // time since last breath
  int _waveCount = 0; // waves since last breath
  static const int _waveBeforeBreathe = 4;

  // Near-miss
  double nearMissFlash = 0.0; // 0..1, fades — painter reads this
  double nearMissCooldown = 0.0;
  int nearMissStreak = 0;

  // Freeze-frame on bomb
  double freezeFrameTimer = 0.0;
  static const double _freezeDuration = 0.055;

  // Sweep beam warning
  bool sweepWarningActive = false;
  double sweepWarningFlash = 0.0;

  // Combo milestone flash
  double comboFlash = 0.0;

  // Danger proximity vignette
  double dangerVignette = 0.0;

  // Near-death slow
  double nearDeathSlowTimer = 0.0;

  double get _minRowSeparation =>
      (0.30 + state.difficulty * 0.04).clamp(0.30, 0.55);

  VoidCallback? onGameOver;
  VoidCallback? onHit;
  VoidCallback? onCoinCollected;
  VoidCallback? onScoreUpdate;
  Function(String)? onRewardCollected;

  static const double _tickRate = 1 / 60;
  static const double _coinInterval = 1.6;
  static const double _powerUpInterval = 7.0;

  double get animTick => _animTick;

  SectorPalette get palette => sectorPalette(state.sector);

  // ── SECTOR-SPECIFIC OBSTACLE INTERVALS ────────────────────────────────────
  // Faster spawning as sectors increase, but also based on pattern type
  double get _obstacleInterval {
    // Base interval shrinks per sector
    double base;
    switch (state.lastPattern) {
      case PatternType.sweepBeam:
        base = 2.0;
        break;
      case PatternType.pulseGate:
        base = 1.8;
        break;
      case PatternType.minefield:
        base = 1.5;
        break;
      default:
        base = 1.0;
    }
    // Each sector reduces interval by 0.08 (more walls)
    base -= (state.sector - 1) * 0.08;
    return base.clamp(0.80, 2.2);
  }

  // ── SLOW MODE AWARENESS ───────────────────────────────────────────────────
  // During slow time, keep spawning obstacles so the game stays active
  double get _effectiveSpeedMult => state.isSlowActive ? 0.4 : 1.0;

  PatternType _pickPattern() {
    final d = state.difficulty;
    final s = state.sector;
    final available = <PatternType>[];

    // More variety per sector
    available.add(PatternType.gapWall);
    available.add(PatternType.gapWall);
    if (d > 0.2 || s >= 2) available.add(PatternType.zigzag);
    if (d > 0.5 || s >= 2) available.add(PatternType.minefield);
    if (d > 1.0 || s >= 3) available.add(PatternType.sweepBeam);
    if (d > 1.5 || s >= 4) available.add(PatternType.pulseGate);
    // Higher sectors get more wall variety
    if (s >= 3) available.add(PatternType.zigzag);
    if (s >= 4) {
      available.add(PatternType.minefield);
      available.add(PatternType.sweepBeam);
    }
    if (s >= 5) {
      available.add(PatternType.pulseGate);
      available.add(PatternType.gapWall); // double walls
    }

    final filtered = available.where((p) => p != state.lastPattern).toList();
    final pool = filtered.isEmpty ? available : filtered;
    return pool[_rng.nextInt(pool.length)];
  }

  void _initStars() {
    stars.clear();
    // More stars in deeper sectors (added at runtime)
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
    state.currentWeapon = player.baseWeapon;
    obstacles.clear();
    coins.clear();
    powerUps.clear();
    bullets.clear();
    chests.clear();
    particles.clear();
    trail.clear();
    ghostImages.clear();
    shockwaves.clear();
    activeBomb = null;
    _bombKillQueue = [];
    _bombKillCursor = 0;
    boss = null;
    bossMissiles = [];
    bossDefeated = false;
    bossSpawned = false;
    bossKillCount = 0;
    _timeSinceLastBoss = 0;
    rampage = RampageState();
    gauntletActive = false;
    gauntletTimer = 0;
    escaped = false;
    escapeFlashTimer = 0;
    shakeIntensity = 0;
    tensionLevel = 0;
    breathTimer = 0;
    isBreathWindow = false;
    _breathCooldown = 0;
    _waveCount = 0;
    nearMissFlash = 0;
    nearMissCooldown = 0;
    nearMissStreak = 0;
    freezeFrameTimer = 0;
    sweepWarningActive = false;
    sweepWarningFlash = 0;
    comboFlash = 0;
    dangerVignette = 0;
    nearDeathSlowTimer = 0;
    _timeSinceLastObstacle = 0;
    _timeSinceLastCoin = 0;
    _timeSinceLastPowerUp = 0;
    _timeSinceLastShot = 0;
    _timeSinceLastAsteroid = 0;
    _gameTime = 0;
    _animTick = 0;
    _ghostTimer = 0;
    _targetX = null;
    _targetY = null;
    _isFiring = true;
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

  void moveTo(double normalizedX, double normalizedY) {
    _targetX = normalizedX.clamp(0.06, 0.94);
    _targetY = normalizedY.clamp(Player.minY, Player.maxY);
  }

  void startFiring() => _isFiring = true;
  void stopFiring() => _isFiring = false;

  // ── BOMB — freeze-frame + gradual kill drain ─────────────────────────────
  void detonateBomb() {
    if (state.bombs <= 0 || activeBomb != null) return;
    state.bombs--;
    activeBomb = Bomb(x: player.x, y: player.y);
    freezeFrameTimer =
        _freezeDuration; // ← THE key juice trick: ~4 frame freeze
    shakeIntensity = 10.0;
    tensionLevel = 0.0; // bomb RESETS tension — this IS the release moment

    shockwaves.add(Shockwave(
        x: player.x,
        y: player.y,
        radius: 0.01,
        life: 1.0,
        color: Colors.white));
    shockwaves.add(Shockwave(
        x: player.x,
        y: player.y,
        radius: 0.015,
        life: 0.85,
        color: player.color));
    shockwaves.add(Shockwave(
        x: player.x,
        y: player.y,
        radius: 0.02,
        life: 0.65,
        color: const Color(0xFFFF6B00)));

    // Small burst up front — rest come during kill drain
    for (int i = 0; i < 12; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 0.014 + _rng.nextDouble() * 0.028;
      const cols = [
        Colors.white,
        Colors.white,
        Color(0xFFFF6B2B),
        Color(0xFFFFD60A),
      ];
      particles.add({
        'x': player.x,
        'y': player.y,
        'vx': cos(angle) * speed,
        'vy': sin(angle) * speed,
        'life': 1.0,
        'color': cols[_rng.nextInt(cols.length)],
        'size': 7.0 + _rng.nextDouble() * 14,
        'decay': 0.014,
        'shape': 'ember',
        'angle': angle,
        'spin': 0.0,
      });
    }

    // Queue kills — ticker drains 4/frame after freeze ends
    _bombKillQueue = obstacles.where((o) {
      if (o.isDying || o.isFullyDead) return false;
      if (o.type == ObstacleType.sweepBeam || o.type == ObstacleType.pulseGate)
        return false;
      return true;
    }).toList();
    _bombKillCursor = 0;

    final killCount = _bombKillQueue.length;
    state.score += (200 + killCount * 30).toInt();
    onRewardCollected?.call('💥 BOMB  ×$killCount KILLS');
    // NO notifyListeners here — tick fires one within 16ms
  }

  // ── MAIN TICK ──────────────────────────────────────────────────────────────
  void _tick() {
    if (state.isPaused || !state.isPlaying) return;

    // ── FREEZE FRAME ── stall game logic for a few frames after bomb
    if (freezeFrameTimer > 0) {
      freezeFrameTimer -= _tickRate;
      _animTick += _tickRate;
      notifyListeners(); // needed: screen reads activeBomb state for the flash
      return;
    }

    _gameTime += _tickRate;
    _animTick += _tickRate;

    // ── REBALANCED DIFFICULTY ─────────────────────────────────────
    // Slower ramp: reaches max difficulty at ~350s instead of ~275s
    state.difficulty = min(_gameTime / 70.0, 5.0);

    // ── REBALANCED SPEED ────────────────────────────────────────
    // Gentler per-sector jump (0.15 instead of 0.25), lower max (2.5 vs 2.8)
    // This keeps the game playable through sector 3-4 for new players.
    final sectorSpeedBase = 1.0 + (state.sector - 1) * 0.15;
    final diffSpeed = state.difficulty * 0.18;
    state.speed = (sectorSpeedBase + diffSpeed).clamp(1.0, 1.9);

    // Near-death slow: if 1 life left, brief bullet-time on close calls
    if (nearDeathSlowTimer > 0) nearDeathSlowTimer -= _tickRate;
    final nearDeathMult = nearDeathSlowTimer > 0 ? 0.35 : 1.0;

    // Slow power-up
    final slowedSpeed = state.isSlowActive
        ? (state.speed * 0.45).clamp(0.45, state.speed)
        : state.speed * nearDeathMult;

    state.score = (_gameTime * 14).floor();

    // ── REBALANCED SECTOR TIMING ──────────────────────────────────
    // 35 seconds per sector instead of 28 — more time to adapt
    state.sector = min((_gameTime / 35.0).floor() + 1, 5);

    // Weapon timer
    if (state.weaponTimer > 0) {
      state.weaponTimer -= _tickRate;
      if (state.weaponTimer <= 0) {
        state.currentWeapon = player.baseWeapon;
        state.weaponTimer = 0;
      }
    }

    // ── RAMPAGE TICK ──────────────────────────────────────────────────────
    rampage.flashPhase += _tickRate * 8;
    if (rampage.isActive) {
      rampage.timer -= _tickRate;
      state.isShieldActive = true;
      state.shieldTimer = rampage.timer;
      if (rampage.timer <= 0) {
        rampage.isActive = false;
        rampage.timer = 0;
        rampage.chargeLevel = 0;
        state.isShieldActive = false;
        onRewardCollected?.call('RAMPAGE OVER');
      }
    }

    // ── BOSS SPAWN & RESPAWN SYSTEM ─────────────────────────────
    // Boss first appears at sector 3, then respawns every 45s after kill,
    // each wave with +20 HP and faster fire rate.
    _timeSinceLastBoss += _tickRate;
    final bossFullyGone = boss == null || boss!.isFullyDead;
    final firstSpawnReady =
        state.sector >= 2 && !bossSpawned && _gameTime > 40.0;
    final respawnReady = bossFullyGone &&
        bossKillCount > 0 &&
        state.sector >= 2 &&
        _timeSinceLastBoss > _bossRespawnInterval;

    if (firstSpawnReady || respawnReady) {
      _timeSinceLastBoss = 0;
      bossSpawned = true;
      final wave = bossKillCount + 1;
      final hpScale = 60.0 + state.sector * 15 + bossKillCount * 20.0;
      final rateScale =
          max(1.2, 3.5 - state.sector * 0.3 - bossKillCount * 0.2);
      boss = BossShip(
        hp: hpScale,
        maxHp: hpScale,
        fireRate: bossKillCount >= 1 ? max(0.9, rateScale - 0.3) : rateScale,
        fireTimer: 4.0,
      );
      final msg = bossKillCount == 0
          ? '⚠  IMPERIAL HUNTER DETECTED'
          : '⚠  HUNTER ${_romanNumeral(wave)} — UPGRADED';
      onRewardCollected?.call(msg);
      shakeIntensity = 9.0;
    }

    // ── BOSS TICK ──────────────────────────────────────────────────────────
    if (boss != null && !boss!.isFullyDead) {
      boss!.pulsePhase += _tickRate * 2.5;
      if (!boss!.isDead) {
        if (boss!.y < 0.12)
          boss!.y += boss!.enterSpeed * (1.0 + state.sector * 0.3);
        boss!.x += (player.x - boss!.x) * 0.008;
        boss!.fireTimer -= _tickRate;
        if (boss!.fireTimer < 0.8)
          boss!.warningFlash =
              (boss!.warningFlash + _tickRate * 3).clamp(0.0, 1.0);
        if (boss!.fireTimer <= 0) {
          boss!.warningFlash = 0;
          bossFire();
          boss!.fireTimer = boss!.fireRate;
        }
        if (rampage.isActive) boss!.hp -= _tickRate * 8;
        if (boss!.hp <= 0) {
          boss!.isDead = true;
          bossDefeated = true;
          bossKillCount++; // track kill count for respawn scaling
          _timeSinceLastBoss = 0; // reset respawn timer
          shakeIntensity = 12.0;
          rampage.chargeLevel = 1.0;
          // Reduced to 8 particles — enough visual impact, no lag spike
          for (int i = 0; i < 8; i++) {
            final a = _rng.nextDouble() * 2 * pi;
            final spd = 0.008 + _rng.nextDouble() * 0.022;
            const cols = [
              Colors.white,
              Color(0xFFFF2D55),
              Color(0xFFFF6B00),
              Color(0xFFFFD60A),
            ];
            particles.add({
              'x': boss!.x,
              'y': boss!.y,
              'vx': cos(a) * spd,
              'vy': sin(a) * spd,
              'life': 1.0,
              'color': cols[_rng.nextInt(cols.length)],
              'size': 8.0 + _rng.nextDouble() * 16,
              'decay': 0.014,
              'shape': 'ember',
              'angle': a,
              'spin': 0.0,
            });
          }
          // 2 shockwaves only — 5 was overkill
          shockwaves.add(Shockwave(
              x: boss!.x,
              y: boss!.y,
              radius: 0.01,
              life: 1.0,
              color: Colors.white));
          shockwaves.add(Shockwave(
              x: boss!.x,
              y: boss!.y,
              radius: 0.02,
              life: 1.0,
              color: const Color(0xFFFF2D55)));
          state.score += 5000;
          final reward = bossKillCount == 1
              ? '★  HUNTER DESTROYED  +5000'
              : '★  HUNTER ${_romanNumeral(bossKillCount)} DESTROYED  +5000';
          onRewardCollected?.call(reward);
        }
      } else {
        boss!.deathTimer += _tickRate * 1.8; // dies faster = less lag frames
      }

      // Move missiles
      for (final m in bossMissiles) {
        m.x += m.vx;
        m.y += m.vy;
        m.life -= _tickRate * 0.35;
        if (m.y > 1.1 || m.x < -0.05 || m.x > 1.05 || m.life <= 0)
          m.active = false;
      }
      bossMissiles.removeWhere((m) => !m.active);

      // Missile vs player
      if (!state.isShieldActive) {
        for (final m in bossMissiles) {
          if (!m.active) continue;
          if (sqrt(pow(m.x - player.x, 2) + pow(m.y - player.y, 2)) < 0.055) {
            m.active = false;
            spawnExplosionParticles(m.x, m.y);
            handleHit();
            break;
          }
        }
      }

      // Bullets vs boss
      if (!boss!.isDead && boss!.y > -0.05) {
        const bossW = 0.22;
        const bossH = 0.14;
        for (final b in bullets) {
          if (!b.active) continue;
          if (b.x > boss!.x - bossW / 2 &&
              b.x < boss!.x + bossW / 2 &&
              b.y > boss!.y - bossH / 2 &&
              b.y < boss!.y + bossH / 2) {
            b.active = false;
            boss!.hp -= 1;
            rampage.chargeLevel = (rampage.chargeLevel + 0.018).clamp(0, 1.0);
            spawnHitSparks(boss!.x + (_rng.nextDouble() - 0.5) * 0.12, boss!.y,
                const Color(0xFFFF2D55));
            shakeIntensity = max(shakeIntensity, 3.0);
          }
        }
      }
    }

    // ── GAUNTLET: activates at sector 5 ───────────────────────────────────
    if (state.sector >= 5 && !gauntletActive && !escaped) {
      gauntletActive = true;
      gauntletTimer = 0;
      onRewardCollected?.call('⚡  FINAL GAUNTLET — SURVIVE 30s');
      shakeIntensity = 10.0;
    }
    if (gauntletActive && !escaped) {
      gauntletTimer += _tickRate;
      if (gauntletTimer >= _gauntletDuration) {
        escaped = true;
        escapeFlashTimer = 1.0;
        state.score += 10000;
        onRewardCollected?.call('★★★  ESCAPED  +10000  ★★★');
        shakeIntensity = 12.0;
        for (int i = 0; i < 18; i++) {
          final a = _rng.nextDouble() * 2 * pi;
          final spd = 0.01 + _rng.nextDouble() * 0.028;
          const cols = [Colors.white, Color(0xFF00FFD1), Color(0xFFFFD60A)];
          particles.add({
            'x': player.x,
            'y': player.y,
            'vx': cos(a) * spd,
            'vy': sin(a) * spd - 0.01,
            'life': 1.0,
            'color': cols[_rng.nextInt(cols.length)],
            'size': 6.0 + _rng.nextDouble() * 12,
            'decay': 0.012,
            'shape': 'ember',
            'angle': a,
            'spin': 0.0,
          });
        }
        Future.delayed(const Duration(milliseconds: 2800), () => stopGame());
      }
    }
    if (escapeFlashTimer > 0) escapeFlashTimer -= _tickRate * 1.2;

    // ── DRAMA SYSTEM: tension builds, then breathes ───────────────────────
    // Tension rises as speed and sector increase; obstacles being close raises it faster
    final targetTension = (state.speed - 1.0) / 1.8 + (state.sector - 1) * 0.18;
    tensionLevel =
        (tensionLevel + (targetTension - tensionLevel) * 0.01).clamp(0.0, 1.0);

    // Breath window: every N waves, open a short calm gap
    _breathCooldown += _tickRate;
    if (isBreathWindow) {
      breathTimer -= _tickRate;
      if (breathTimer <= 0) {
        isBreathWindow = false;
        _waveCount = 0;
      }
    }

    // Near-miss detection: player passed within danger range of a wall
    if (nearMissCooldown > 0) nearMissCooldown -= _tickRate;
    if (nearMissFlash > 0) nearMissFlash -= _tickRate * 3.5;
    if (nearMissCooldown <= 0) {
      for (final obs in obstacles) {
        if (obs.isFullyDead || obs.isDying) continue;
        if (obs.type != ObstacleType.laserWall &&
            obs.type != ObstacleType.sweepBeam) continue;
        double dist = 999.0;
        if (obs.type == ObstacleType.laserWall) {
          final obsBottom = obs.y + obs.height;
          final obsTop = obs.y;
          // Near miss = player passed through the y-band recently
          if (player.y > obsTop - 0.06 && player.y < obsBottom + 0.06) {
            final leftEdgeDist = (player.x - obs.x - obs.width).abs();
            final rightEdgeDist = (player.x - obs.x).abs();
            dist = min(leftEdgeDist, rightEdgeDist);
          }
        }
        if (dist < 0.045 && dist > 0.01) {
          nearMissFlash = 1.0;
          nearMissCooldown = 0.9;
          nearMissStreak++;
          final bonus = nearMissStreak >= 3
              ? 120
              : nearMissStreak >= 2
                  ? 80
                  : 50;
          state.score += bonus;
          if (nearMissStreak >= 2) {
            onRewardCollected?.call('🔥 NEAR MISS ×$nearMissStreak  +$bonus');
          }
          break;
        }
      }
    }

    // Combo flash on milestones
    if (comboFlash > 0) comboFlash -= _tickRate * 2.5;

    // Sweep warning flash
    if (sweepWarningFlash > 0) sweepWarningFlash -= _tickRate * 2.0;

    // Danger vignette: brighten when obstacles are very close vertically
    double closestObstacleDist = 1.0;
    for (final obs in obstacles) {
      if (obs.isFullyDead || obs.y < 0) continue;
      final dy = (obs.y - player.y).abs();
      if (dy < closestObstacleDist) closestObstacleDist = dy;
    }
    final targetVignette =
        closestObstacleDist < 0.12 ? (1.0 - closestObstacleDist / 0.12) : 0.0;
    dangerVignette = (dangerVignette + (targetVignette - dangerVignette) * 0.15)
        .clamp(0.0, 1.0);

    // Player movement
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

    // Auto-fire — fires at real rate regardless of slow mode
    _timeSinceLastShot += _tickRate;
    if (_isFiring && _timeSinceLastShot >= getFireRate()) {
      spawnBullets();
      _timeSinceLastShot = 0;
    }

    // Stars parallax — uses slowed speed
    for (final star in stars) {
      star.y += star.speed * slowedSpeed;
      if (star.y > 1.05) {
        star.y = -0.05;
        star.x = _rng.nextDouble();
      }
    }

    updateTrail(_effectiveSpeedMult);

    // Ghost after-images
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

    // Spawn timers — use wall-clock time (not slowed) so obstacles keep coming
    _timeSinceLastObstacle += _tickRate;
    _timeSinceLastCoin += _tickRate;
    _timeSinceLastPowerUp += _tickRate;
    _timeSinceLastAsteroid += _tickRate;

    if (_timeSinceLastObstacle >= _obstacleInterval) {
      spawnPattern();
      _timeSinceLastObstacle = 0;
    }
    // Asteroid trickle — always some asteroids from sector 2+
    if (state.sector >= 2 &&
        _timeSinceLastAsteroid >= _asteroidTrickleInterval) {
      spawnFloatingAsteroid();
      _timeSinceLastAsteroid = 0;
    }

    if (_timeSinceLastCoin >= _coinInterval) {
      spawnCoin();
      _timeSinceLastCoin = 0;
    }
    if (_timeSinceLastPowerUp >= _powerUpInterval) {
      spawnPowerUp();
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

    // Move bullets — full speed always
    for (final b in bullets) {
      b.y += b.vy;
      b.x += b.vx;
      if (b.y < -0.05 || b.y > 1.05 || b.x < -0.05 || b.x > 1.05)
        b.active = false;
    }
    bullets.removeWhere((b) => !b.active);

    // Move & animate obstacles — use slowedSpeed
    for (final obs in obstacles) {
      if (!obs.isDying) {
        obs.y += obs.speed * slowedSpeed;
        obs.rotation += obs.rotationSpeed * _effectiveSpeedMult;
        // Tracker mine homing
        if (obs.type == ObstacleType.mine && obs.mineType == MineType.tracker) {
          final dx = player.x - obs.x;
          final dy = player.y - obs.y;
          final dist = sqrt(dx * dx + dy * dy);
          if (dist > 0.02) {
            final trackSpeed = 0.0006 + state.difficulty * 0.0002;
            obs.trackerVX += (dx / dist) * trackSpeed;
            obs.trackerVY += (dy / dist) * trackSpeed;
            final vmag = sqrt(
                obs.trackerVX * obs.trackerVX + obs.trackerVY * obs.trackerVY);
            const vmax = 0.004;
            if (vmag > vmax) {
              obs.trackerVX = obs.trackerVX / vmag * vmax;
              obs.trackerVY = obs.trackerVY / vmag * vmax;
            }
          }
          obs.x += obs.trackerVX * _effectiveSpeedMult;
          obs.y += obs.trackerVY * _effectiveSpeedMult;
        }
      }
      if (obs.isDying) obs.deathTimer += _tickRate * 2.5;
      if (obs.type == ObstacleType.sweepBeam && !obs.sweepDone) {
        // Sweep beam moves at real speed — it's a timed hazard
        obs.sweepProgress += obs.sweepSpeed * _tickRate;
        if (obs.sweepProgress >= 1.0) obs.sweepDone = true;
      }
      if (obs.type == ObstacleType.pulseGate) obs.pulsePhase += _tickRate * 2.8;
      if (obs.type == ObstacleType.mine) obs.pulsePhase += _tickRate * 3;
    }
    obstacles.removeWhere((o) =>
        o.isFullyDead ||
        o.y > 1.2 ||
        o.x < -0.15 ||
        o.x > 1.15 ||
        (o.type == ObstacleType.sweepBeam && o.sweepDone && o.y > 0.2));

    // Move coins & pickups
    for (final coin in coins) {
      coin.y += coin.speed * slowedSpeed;
      coin.pulsePhase += _tickRate * 3;
    }
    coins.removeWhere((c) => c.y > 1.1 || c.collected);

    for (final pu in powerUps) {
      pu.y += pu.speed * slowedSpeed;
      pu.pulsePhase += _tickRate * 2;
    }
    powerUps.removeWhere((p) => p.y > 1.1 || p.collected);

    for (final c in chests) {
      c.y += c.speed * slowedSpeed;
      c.pulsePhase += _tickRate * 2.5;
    }
    chests.removeWhere((c) => c.y > 1.1 || c.collected);

    // Particles
    for (final p in particles) {
      p['y'] = (p['y'] as double) + (p['vy'] as double);
      p['x'] = (p['x'] as double) + (p['vx'] as double);
      p['vy'] = (p['vy'] as double) + 0.0002;
      p['life'] = (p['life'] as double) - (p['decay'] as double? ?? 0.035);
      // Update spin angle
      if (p.containsKey('spin') && p.containsKey('angle')) {
        p['angle'] = (p['angle'] as double) + (p['spin'] as double);
      }
    }
    particles.removeWhere((p) => (p['life'] as double) <= 0);

    // Shockwaves
    for (final sw in shockwaves) {
      sw.radius += 0.025;
      sw.life -= 0.04;
    }
    shockwaves.removeWhere((sw) => sw.life <= 0);

    // Bomb animation
    if (activeBomb != null) {
      activeBomb!.detonationTimer += _tickRate * 1.4;
      activeBomb!.radius = activeBomb!.detonationTimer * 1.2;
      if (activeBomb!.detonationTimer >= 1.0) activeBomb = null;
    }

    // Bomb kill drain — 4 per frame after freeze, each with mini sparks
    if (_bombKillCursor < _bombKillQueue.length) {
      final end = (_bombKillCursor + 4).clamp(0, _bombKillQueue.length);
      for (int i = _bombKillCursor; i < end; i++) {
        final obs = _bombKillQueue[i];
        if (obs.isFullyDead) {
          _bombKillCursor++;
          continue;
        }
        obs.hp = 0;
        final cx = obs.x + obs.width / 2;
        final cy = obs.y + obs.height / 2;
        for (int j = 0; j < 4; j++) {
          final a = _rng.nextDouble() * 2 * pi;
          particles.add({
            'x': cx,
            'y': cy,
            'vx': cos(a) * 0.010,
            'vy': sin(a) * 0.010 - 0.003,
            'life': 0.75,
            'color': obs.color,
            'size': 3.5 + _rng.nextDouble() * 5,
            'decay': 0.05,
            'shape': 'ember',
            'angle': a,
            'spin': 0.0,
          });
        }
        if (i % 2 == 0)
          shockwaves.add(Shockwave(
              x: cx, y: cy, radius: 0.01, life: 0.55, color: obs.color));
        _bombKillCursor++;
      }
    }

    // Sweep beam warning: flash 0.5s before beam arrives in player zone
    sweepWarningActive = false;
    for (final obs in obstacles) {
      if (obs.type != ObstacleType.sweepBeam || obs.sweepDone) continue;
      final beamY = obs.y;
      if ((beamY - player.y).abs() < 0.18 && beamY < player.y) {
        sweepWarningActive = true;
        sweepWarningFlash = (sweepWarningFlash + _tickRate * 4).clamp(0.0, 1.0);
        break;
      }
    }

    // Screen shake — clamp max so it never causes flicker, decay fast
    if (shakeIntensity > 0) {
      shakeIntensity = (shakeIntensity * 0.72).clamp(0.0, 12.0);
      shakeOffset = Offset((_rng.nextDouble() - 0.5) * shakeIntensity,
          (_rng.nextDouble() - 0.5) * shakeIntensity);
      if (shakeIntensity < 0.4) {
        shakeIntensity = 0;
        shakeOffset = Offset.zero;
      }
    }

    checkBulletCollisions();
    checkCollisions();
    onScoreUpdate?.call();
    notifyListeners();
  }

  // ── ASTEROID TRICKLE ───────────────────────────────────────────────────────
  double get _asteroidTrickleInterval {
    // More asteroids in higher sectors
    switch (state.sector) {
      case 2:
        return 3.5;
      case 3:
        return 2.5;
      case 4:
        return 1.8;
      case 5:
        return 1.2;
      default:
        return 99.0;
    }
  }

  void activateRampage() {
    rampageActivate();
  }

  String _romanNumeral(int n) {
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

  @override
  void dispose() {
    _gameLoop?.cancel();
    super.dispose();
  }
}
