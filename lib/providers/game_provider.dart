import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/game_models.dart';
import '../utils/safe_color.dart';

part 'systems/spawner.dart';
part 'systems/combat.dart';
part 'systems/particles.dart';
part 'systems/boss_system.dart';
part 'systems/scenarios.dart';

class GameProvider extends ChangeNotifier {
  final Random _rng = Random();
  Timer? _gameLoop;

  RunState state = RunState();
  Player player = Player();
  List<GameEntity> obstacles = [];
  List<Coin> coins = [];
  List<PowerUp> powerUps = [];
  List<Bullet> bullets = [];
  List<TreasureChest> chests = [];
  List<Particle> particles = [];
  List<StarParticle> stars = [];
  List<TrailPoint> trail = [];
  List<Shockwave> shockwaves = [];

  Bomb? activeBomb;
  List<GameEntity> _bombKillQueue = [];
  int _bombKillCursor = 0;
  List<GhostImage> ghostImages = [];

  // ── BOSS (data lives here for painter access) ──────────────────────────────
  BossShip? boss;
  List<BossMissile> bossMissiles = [];

  // ── RAMPAGE ───────────────────────────────────────────────────────────────
  RampageState rampage = RampageState();
  bool get isRampageReady => rampage.chargeLevel >= 1.0 && !rampage.isActive;

  // ── SCENARIO SYSTEM ───────────────────────────────────────────────────────
  final List<GameScenario> _scenarios = [];

  // Convenience accessors for the two core scenarios.
  GauntletScenario get _gauntlet =>
      _scenarios.whereType<GauntletScenario>().first;
  BossEncounterScenario get _bossEncounter =>
      _scenarios.whereType<BossEncounterScenario>().first;

  // Pass-through getters so painters keep working unchanged.
  bool get gauntletActive => _gauntlet.isActive;
  double get gauntletTimer => _gauntlet.timer;
  bool get escaped => _gauntlet.escaped;
  double get escapeFlashTimer => _gauntlet.escapeFlashTimer;
  bool get bossDefeated => _bossEncounter.defeated;
  bool get bossSpawned => _bossEncounter.spawned;
  int get bossKillCount => _bossEncounter.killCount;

  /// The currently active environmental effect (if any).
  EnvironmentalEffect get activeEnvironment {
    for (final s in _scenarios) {
      if (s is EnvironmentScenario && s.isActive) return s.effect;
    }
    return EnvironmentalEffect.none;
  }

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
  SectorConfig get sectorConfig => resolveSectorConfig(state.sector);

  // ── SECTOR-DRIVEN OBSTACLE INTERVALS ───────────────────────────────────────
  double get _obstacleInterval {
    final cfg = sectorConfig;
    // Per-pattern base from config (default 1.0)
    final base = cfg.patternIntervals[state.lastPattern] ?? 1.0;
    // Sector reduces interval
    final scaled = base - (state.sector - 1) * cfg.intervalPerSector;
    return scaled.clamp(cfg.minInterval, cfg.maxInterval);
  }

  double get _effectiveSpeedMult => 1.0;

  PatternType _pickPattern() {
    final cfg = sectorConfig;
    final d = state.difficulty;
    // Build weighted pool from config, filtering by minDifficulty
    final entries = cfg.patterns.where((e) => d >= e.minDifficulty).toList();
    if (entries.isEmpty) return PatternType.gapWall;

    // Remove last pattern to avoid repeats
    final filtered = entries.where((e) => e.type != state.lastPattern).toList();
    final pool = filtered.isEmpty ? entries : filtered;

    // Weighted random pick
    final totalW = pool.fold<double>(0, (s, e) => s + e.weight);
    var roll = _rng.nextDouble() * totalW;
    for (final e in pool) {
      roll -= e.weight;
      if (roll <= 0) return e.type;
    }
    return pool.last.type;
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
    rampage = RampageState();
    // Reset all scenarios
    _scenarios.clear();
    _scenarios.addAll([GauntletScenario(), BossEncounterScenario()]);
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
    if (state.isGameOver) return; // guard against double-call
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
      particles.add(Particle(
        x: player.x,
        y: player.y,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        life: 1.0,
        color: cols[_rng.nextInt(cols.length)],
        size: 7.0 + _rng.nextDouble() * 14,
        decay: 0.014,
        shape: ParticleShape.ember,
        angle: angle,
      ));
    }

    // Queue kills — ticker drains 4/frame after freeze ends
    _bombKillQueue = obstacles.where((o) {
      if (o.isDying || o.isFullyDead) return false;
      if (o is SweepBeamEntity || o is PulseGateEntity) return false;
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
    // Gentle per-sector ramp with a hard ceiling so the game stays
    // playable even at sector 8+.  Difficulty adds a small bonus that
    // also plateaus, keeping late-game challenge in pattern complexity
    // rather than raw scroll velocity.
    final sectorSpeedBase = 1.0 + (state.sector - 1) * 0.08;
    final diffSpeed = state.difficulty * 0.14;
    state.speed = (sectorSpeedBase + diffSpeed).clamp(1.0, 1.65);

    // Near-death slow: if 1 life left, brief bullet-time on close calls
    if (nearDeathSlowTimer > 0) nearDeathSlowTimer -= _tickRate;
    final nearDeathMult = nearDeathSlowTimer > 0 ? 0.35 : 1.0;

    final slowedSpeed = state.speed * nearDeathMult;

    state.score = (_gameTime * 14).floor();

    // ── SECTOR TIMING ────────────────────────────────────────────
    // 35 seconds per sector.  No cap — sector grows as long as you
    // survive.  Config/palette default to sector-5 values for 6+.
    state.sector = (_gameTime / 35.0).floor() + 1;

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

    // ── SCENARIO DELEGATION ─────────────────────────────────────────────────
    // Activate pending scenarios, then tick all active ones.
    for (final s in _scenarios) {
      if (!s.isActive && !s.isComplete && s.canActivate(this)) {
        s.onActivate(this);
      }
      if (s.isActive) s.update(this, _tickRate);
    }

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
        if (obs is! LaserWallEntity && obs is! SweepBeamEntity) continue;
        double dist = 999.0;
        if (obs is LaserWallEntity) {
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
        ghostImages.add(GhostImage(
          x: player.x,
          y: player.y,
          life: 1.0,
          size: player.size.toDouble(),
        ));
      }
      for (final g in ghostImages) g.life -= 0.07;
      ghostImages.removeWhere((g) => g.life <= 0);
    } else {
      ghostImages.clear();
    }

    // Spawn timers — use wall-clock time (not slowed) so obstacles keep coming
    _timeSinceLastObstacle += _tickRate;
    _timeSinceLastCoin += _tickRate;
    _timeSinceLastPowerUp += _tickRate;
    _timeSinceLastAsteroid += _tickRate;

    // Reduce spawn pressure during active boss fight — double interval
    final bossAlive = boss != null && !boss!.isDead;
    final effectiveInterval =
        bossAlive ? _obstacleInterval * 2.0 : _obstacleInterval;
    if (_timeSinceLastObstacle >= effectiveInterval) {
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
    // Move bullets — full speed always
    for (final b in bullets) {
      b.y += b.vy;
      b.x += b.vx;
      if (b.y < -0.05 || b.y > 1.05 || b.x < -0.05 || b.x > 1.05)
        b.active = false;
    }
    bullets.removeWhere((b) => !b.active);
    // Hard cap — Specter laser can produce 66+ bullets; trim oldest
    if (bullets.length > 80) {
      bullets.removeRange(0, bullets.length - 80);
    }

    // Move & animate obstacles — each entity owns its own update logic
    for (final obs in obstacles) {
      if (!obs.isDying) {
        obs.update(_tickRate, slowedSpeed, _effectiveSpeedMult, player.x,
            player.y, state.difficulty);
      }
      if (obs.isDying) obs.deathTimer += _tickRate * 2.5;
    }
    obstacles.removeWhere((o) => o.shouldRemove());

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
      p.y += p.vy;
      p.x += p.vx;
      p.vy += 0.0002;
      p.life -= p.decay;
      p.angle += p.spin;
    }
    particles.removeWhere((p) => p.life <= 0);
    // Hard cap — prevent GPU overload during intense boss fights
    if (particles.length > 150) {
      particles.removeRange(0, particles.length - 150);
    }

    // Shockwaves
    for (final sw in shockwaves) {
      sw.radius += 0.025;
      sw.life -= 0.04;
    }
    shockwaves.removeWhere((sw) => sw.life <= 0);
    // Hard cap
    if (shockwaves.length > 20) {
      shockwaves.removeRange(0, shockwaves.length - 20);
    }

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
          particles.add(Particle(
            x: cx,
            y: cy,
            vx: cos(a) * 0.010,
            vy: sin(a) * 0.010 - 0.003,
            life: 0.75,
            color: obs.color,
            size: 3.5 + _rng.nextDouble() * 5,
            decay: 0.05,
            shape: ParticleShape.ember,
            angle: a,
          ));
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
      if (obs is! SweepBeamEntity || obs.sweepDone) continue;
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

  @override
  void dispose() {
    _gameLoop?.cancel();
    super.dispose();
  }
}
