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
  double tensionLevel = 0.0;      // 0..1 — how "oh shit" the moment feels
  double breathTimer = 0.0;       // counts down a calm window
  bool isBreathWindow = false;    // true = calm gap between waves
  double _breathCooldown = 0.0;   // time since last breath
  int _waveCount = 0;             // waves since last breath
  static const int _waveBeforeBreathe = 4;

  // Near-miss
  double nearMissFlash = 0.0;     // 0..1, fades — painter reads this
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
    return base.clamp(0.55, 2.2);
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
      stars.add(StarParticle(x: _rng.nextDouble(), y: _rng.nextDouble(), speed: 0.0004, size: 0.5 + _rng.nextDouble() * 0.8, opacity: 0.2 + _rng.nextDouble() * 0.3, layer: 0));
    }
    for (int i = 0; i < 40; i++) {
      stars.add(StarParticle(x: _rng.nextDouble(), y: _rng.nextDouble(), speed: 0.001, size: 0.8 + _rng.nextDouble() * 1.2, opacity: 0.3 + _rng.nextDouble() * 0.4, layer: 1));
    }
    for (int i = 0; i < 15; i++) {
      stars.add(StarParticle(x: _rng.nextDouble(), y: _rng.nextDouble(), speed: 0.003, size: 1.2 + _rng.nextDouble() * 1.5, opacity: 0.6 + _rng.nextDouble() * 0.4, layer: 2));
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
    freezeFrameTimer = _freezeDuration; // ← THE key juice trick: ~4 frame freeze
    shakeIntensity = 32.0;
    tensionLevel = 0.0; // bomb RESETS tension — this IS the release moment

    shockwaves.add(Shockwave(x: player.x, y: player.y, radius: 0.01, life: 1.0, color: Colors.white));
    shockwaves.add(Shockwave(x: player.x, y: player.y, radius: 0.015, life: 0.85, color: player.color));
    shockwaves.add(Shockwave(x: player.x, y: player.y, radius: 0.02, life: 0.65, color: const Color(0xFFFF6B00)));

    // Small burst up front — rest come during kill drain
    for (int i = 0; i < 22; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 0.014 + _rng.nextDouble() * 0.032;
      final cols = [Colors.white, Colors.white, const Color(0xFFFF6B2B), const Color(0xFFFFD60A)];
      particles.add({'x': player.x, 'y': player.y,
        'vx': cos(angle) * speed, 'vy': sin(angle) * speed,
        'life': 1.0, 'color': cols[_rng.nextInt(cols.length)],
        'size': 7.0 + _rng.nextDouble() * 16, 'decay': 0.013});
    }

    // Queue kills — ticker drains 4/frame after freeze ends
    _bombKillQueue = obstacles.where((o) {
      if (o.isDying || o.isFullyDead) return false;
      if (o.type == ObstacleType.sweepBeam || o.type == ObstacleType.pulseGate) return false;
      return true;
    }).toList();
    _bombKillCursor = 0;

    final killCount = _bombKillQueue.length;
    state.score += (200 + killCount * 30).toInt();
    onRewardCollected?.call('💥 BOMB  ×$killCount KILLS');
    notifyListeners();
  }

  // ── MAIN TICK ──────────────────────────────────────────────────────────────
  void _tick() {
    if (state.isPaused || !state.isPlaying) return;

    // ── FREEZE FRAME ── stall game logic for a few frames after bomb
    if (freezeFrameTimer > 0) {
      freezeFrameTimer -= _tickRate;
      _animTick += _tickRate; // keep animations running so flash renders
      notifyListeners();
      return; // skip everything else — the white flash does the work
    }

    _gameTime += _tickRate;
    _animTick += _tickRate;

    // Difficulty: capped at 5, but sector boosts it
    state.difficulty = min(_gameTime / 55.0, 5.0);

    // SPEED: sector-adjusted — each sector adds a noticeable jump
    final sectorSpeedBase = 1.0 + (state.sector - 1) * 0.25;
    final diffSpeed = state.difficulty * 0.30;
    state.speed = (sectorSpeedBase + diffSpeed).clamp(1.0, 2.8);

    // Near-death slow: if 1 life left, brief bullet-time on close calls
    if (nearDeathSlowTimer > 0) nearDeathSlowTimer -= _tickRate;
    final nearDeathMult = nearDeathSlowTimer > 0 ? 0.35 : 1.0;

    // Slow power-up
    final slowedSpeed = state.isSlowActive
        ? (state.speed * 0.45).clamp(0.45, state.speed)
        : state.speed * nearDeathMult;

    state.score = (_gameTime * 14).floor();
    state.sector = min((_gameTime / 28.0).floor() + 1, 5);

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

    // ── BOSS SPAWN: enters at sector 3 ────────────────────────────────────
    if (state.sector >= 3 && !bossSpawned && _gameTime > 58.0) {
      boss = BossShip(
        hp: 60.0 + state.sector * 15,
        maxHp: 60.0 + state.sector * 15,
        fireRate: max(1.8, 3.5 - state.sector * 0.4),
        fireTimer: 4.0,
      );
      bossSpawned = true;
      onRewardCollected?.call('⚠  IMPERIAL HUNTER DETECTED');
      shakeIntensity = 20.0;
    }

    // ── BOSS TICK ──────────────────────────────────────────────────────────
    if (boss != null && !boss!.isFullyDead) {
      boss!.pulsePhase += _tickRate * 2.5;
      if (!boss!.isDead) {
        if (boss!.y < 0.12) boss!.y += boss!.enterSpeed * (1.0 + state.sector * 0.3);
        boss!.x += (player.x - boss!.x) * 0.008;
        boss!.fireTimer -= _tickRate;
        if (boss!.fireTimer < 0.8) boss!.warningFlash = min(1.0, boss!.warningFlash + _tickRate * 3);
        if (boss!.fireTimer <= 0) {
          boss!.warningFlash = 0;
          _bossFire();
          boss!.fireTimer = boss!.fireRate;
        }
        if (rampage.isActive) boss!.hp -= _tickRate * 8;
        if (boss!.hp <= 0) {
          boss!.isDead = true;
          bossDefeated = true;
          shakeIntensity = 35.0;
          rampage.chargeLevel = 1.0;
          for (int i = 0; i < 40; i++) {
            final a = _rng.nextDouble() * 2 * pi;
            final spd = 0.008 + _rng.nextDouble() * 0.025;
            final cols = [Colors.white, const Color(0xFFFF2D55), const Color(0xFFFF6B00), const Color(0xFFFFD60A)];
            particles.add({'x': boss!.x, 'y': boss!.y, 'vx': cos(a)*spd, 'vy': sin(a)*spd, 'life': 1.0, 'color': cols[_rng.nextInt(cols.length)], 'size': 8.0+_rng.nextDouble()*18, 'decay': 0.012});
          }
          for (int i = 0; i < 5; i++) shockwaves.add(Shockwave(x: boss!.x + (_rng.nextDouble()-0.5)*0.1, y: boss!.y, radius: 0.01+i*0.008, life: 1.0, color: i.isEven ? Colors.white : const Color(0xFFFF2D55)));
          state.score += 5000;
          onRewardCollected?.call('★  HUNTER DESTROYED  +5000');
        }
      } else {
        boss!.deathTimer += _tickRate * 0.8;
      }

      // Move missiles
      for (final m in bossMissiles) {
        m.x += m.vx; m.y += m.vy; m.life -= _tickRate * 0.35;
        if (m.y > 1.1 || m.x < -0.05 || m.x > 1.05 || m.life <= 0) m.active = false;
      }
      bossMissiles.removeWhere((m) => !m.active);

      // Missile vs player
      if (!state.isShieldActive) {
        for (final m in bossMissiles) {
          if (!m.active) continue;
          if (sqrt(pow(m.x - player.x, 2) + pow(m.y - player.y, 2)) < 0.055) {
            m.active = false;
            _spawnExplosionParticles(m.x, m.y);
            _handleHit();
            break;
          }
        }
      }

      // Bullets vs boss
      if (!boss!.isDead && boss!.y > -0.05) {
        const bossW = 0.22; const bossH = 0.14;
        for (final b in bullets) {
          if (!b.active) continue;
          if (b.x > boss!.x - bossW/2 && b.x < boss!.x + bossW/2 && b.y > boss!.y - bossH/2 && b.y < boss!.y + bossH/2) {
            b.active = false;
            boss!.hp -= 1;
            rampage.chargeLevel = (rampage.chargeLevel + 0.018).clamp(0, 1.0);
            _spawnHitSparks(boss!.x + (_rng.nextDouble()-0.5)*0.12, boss!.y, const Color(0xFFFF2D55));
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
      shakeIntensity = 25.0;
    }
    if (gauntletActive && !escaped) {
      gauntletTimer += _tickRate;
      if (gauntletTimer >= _gauntletDuration) {
        escaped = true;
        escapeFlashTimer = 1.0;
        state.score += 10000;
        onRewardCollected?.call('★★★  ESCAPED  +10000  ★★★');
        shakeIntensity = 40.0;
        for (int i = 0; i < 50; i++) {
          final a = _rng.nextDouble() * 2 * pi;
          final spd = 0.01 + _rng.nextDouble() * 0.03;
          final cols = [Colors.white, const Color(0xFF00FFD1), const Color(0xFFFFD60A)];
          particles.add({'x': player.x, 'y': player.y, 'vx': cos(a)*spd, 'vy': sin(a)*spd-0.01, 'life': 1.0, 'color': cols[_rng.nextInt(cols.length)], 'size': 6.0+_rng.nextDouble()*14, 'decay': 0.01});
        }
        Future.delayed(const Duration(milliseconds: 2800), () => stopGame());
      }
    }
    if (escapeFlashTimer > 0) escapeFlashTimer -= _tickRate * 1.2;

    // ── DRAMA SYSTEM: tension builds, then breathes ───────────────────────
    // Tension rises as speed and sector increase; obstacles being close raises it faster
    final targetTension = (state.speed - 1.0) / 1.8 + (state.sector - 1) * 0.18;
    tensionLevel = (tensionLevel + (targetTension - tensionLevel) * 0.01).clamp(0.0, 1.0);

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
        if (obs.type != ObstacleType.laserWall && obs.type != ObstacleType.sweepBeam) continue;
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
          final bonus = nearMissStreak >= 3 ? 120 : nearMissStreak >= 2 ? 80 : 50;
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
    final targetVignette = closestObstacleDist < 0.12 ? (1.0 - closestObstacleDist / 0.12) : 0.0;
    dangerVignette = (dangerVignette + (targetVignette - dangerVignette) * 0.15).clamp(0.0, 1.0);

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
    if (_isFiring && _timeSinceLastShot >= _getFireRate()) {
      _spawnBullets();
      _timeSinceLastShot = 0;
    }

    // Stars parallax — uses slowed speed
    for (final star in stars) {
      star.y += star.speed * slowedSpeed;
      if (star.y > 1.05) { star.y = -0.05; star.x = _rng.nextDouble(); }
    }

    _updateTrail(_effectiveSpeedMult);

    // Ghost after-images
    if (player.trailStyle == TrailStyle.ghost) {
      _ghostTimer += _tickRate;
      if (_ghostTimer > 0.08) {
        _ghostTimer = 0;
        ghostImages.add({'x': player.x, 'y': player.y, 'life': 1.0, 'size': player.size.toDouble()});
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
      _spawnPattern();
      _timeSinceLastObstacle = 0;
    }
    // Asteroid trickle — always some asteroids from sector 2+
    if (state.sector >= 2 && _timeSinceLastAsteroid >= _asteroidTrickleInterval) {
      _spawnFloatingAsteroid();
      _timeSinceLastAsteroid = 0;
    }

    if (_timeSinceLastCoin >= _coinInterval) { _spawnCoin(); _timeSinceLastCoin = 0; }
    if (_timeSinceLastPowerUp >= _powerUpInterval) { _spawnPowerUp(); _timeSinceLastPowerUp = 0; }

    // Power-up timers
    if (state.isShieldActive) { state.shieldTimer -= _tickRate; if (state.shieldTimer <= 0) state.isShieldActive = false; }
    if (state.isSlowActive) { state.slowTimer -= _tickRate; if (state.slowTimer <= 0) state.isSlowActive = false; }

    // Move bullets — full speed always
    for (final b in bullets) {
      b.y += b.vy;
      b.x += b.vx;
      if (b.y < -0.05 || b.y > 1.05 || b.x < -0.05 || b.x > 1.05) b.active = false;
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
            final vmag = sqrt(obs.trackerVX * obs.trackerVX + obs.trackerVY * obs.trackerVY);
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
        o.x < -0.15 || o.x > 1.15 ||
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
    }
    particles.removeWhere((p) => (p['life'] as double) <= 0);

    // Shockwaves
    for (final sw in shockwaves) { sw.radius += 0.025; sw.life -= 0.04; }
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
        if (obs.isFullyDead) { _bombKillCursor++; continue; }
        obs.hp = 0;
        final cx = obs.x + obs.width / 2;
        final cy = obs.y + obs.height / 2;
        for (int j = 0; j < 4; j++) {
          final a = _rng.nextDouble() * 2 * pi;
          particles.add({'x': cx, 'y': cy,
            'vx': cos(a) * 0.010, 'vy': sin(a) * 0.010 - 0.003,
            'life': 0.75, 'color': obs.color,
            'size': 3.5 + _rng.nextDouble() * 5, 'decay': 0.05});
        }
        if (i % 2 == 0) shockwaves.add(Shockwave(x: cx, y: cy, radius: 0.01, life: 0.55, color: obs.color));
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
        sweepWarningFlash = min(1.0, sweepWarningFlash + _tickRate * 4);
        break;
      }
    }

    // Screen shake
    if (shakeIntensity > 0) {
      shakeIntensity *= 0.80;
      shakeOffset = Offset((_rng.nextDouble() - 0.5) * shakeIntensity, (_rng.nextDouble() - 0.5) * shakeIntensity);
      if (shakeIntensity < 0.3) { shakeIntensity = 0; shakeOffset = Offset.zero; }
    }

    _checkBulletCollisions();
    _checkCollisions();
    onScoreUpdate?.call();
    notifyListeners();
  }

  // ── ASTEROID TRICKLE ───────────────────────────────────────────────────────
  double get _asteroidTrickleInterval {
    // More asteroids in higher sectors
    switch (state.sector) {
      case 2: return 3.5;
      case 3: return 2.5;
      case 4: return 1.8;
      case 5: return 1.2;
      default: return 99.0;
    }
  }

  // ── FIRE RATE ──────────────────────────────────────────────────────────────
  double _getFireRate() {
    if (player.skin == SkinType.titan) return 0.14;
    switch (state.currentWeapon) {
      case WeaponType.rapidFire: return 0.07;
      case WeaponType.spread: return 0.20;
      case WeaponType.laser: return 0.05;
      default: return _fireRate;
    }
  }

  // ── BULLET SPAWN ──────────────────────────────────────────────────────────
  void _spawnBullets() {
    final color = player.color;

    void flash(double bx, double by) {
      for (int i = 0; i < 4; i++) {
        final angle = -pi / 2 + (_rng.nextDouble() - 0.5) * 0.8;
        particles.add({'x': bx, 'y': by, 'vx': cos(angle) * 0.006, 'vy': sin(angle) * 0.006, 'life': 0.4, 'color': Colors.white, 'size': 2.5, 'decay': 0.06});
      }
    }

    switch (player.skin) {
      case SkinType.phantom:
        if (state.currentWeapon == WeaponType.rapidFire) {
          bullets.add(Bullet(x: player.x, y: player.y - 0.03, vy: -0.030, color: Colors.yellowAccent, shape: BulletShape.needle));
        } else {
          bullets.add(Bullet(x: player.x, y: player.y - 0.03, vy: -0.025, color: color, shape: BulletShape.needle));
        }
        flash(player.x, player.y - 0.03);
        break;

      case SkinType.nova:
        final shots = state.currentWeapon == WeaponType.spread ? 5 : 3;
        for (int i = 0; i < shots; i++) {
          final offset = (i - shots ~/ 2);
          final angle = -pi / 2 + offset * 0.22;
          bullets.add(Bullet(
            x: player.x, y: player.y - 0.03,
            vx: cos(angle) * 0.012, vy: sin(angle) * 0.022,
            color: color, shape: BulletShape.plasma,
          ));
        }
        flash(player.x, player.y - 0.03);
        break;

      case SkinType.inferno:
        final fireRate = state.currentWeapon == WeaponType.rapidFire;
        bullets.add(Bullet(
          x: player.x + (_rng.nextDouble() - 0.5) * 0.015, y: player.y - 0.03,
          vy: fireRate ? -0.030 : -0.025,
          color: color, shape: BulletShape.shell,
        ));
        flash(player.x, player.y - 0.03);
        break;

      case SkinType.specter:
        if (state.currentWeapon == WeaponType.laser) {
          bullets.add(Bullet(x: player.x - 0.025, y: player.y - 0.03, vy: -0.045, color: color, shape: BulletShape.beam));
          bullets.add(Bullet(x: player.x + 0.025, y: player.y - 0.03, vy: -0.045, color: color, shape: BulletShape.beam));
        } else {
          bullets.add(Bullet(x: player.x, y: player.y - 0.03, vy: -0.045, color: color, shape: BulletShape.beam));
        }
        flash(player.x, player.y - 0.03);
        break;

      case SkinType.titan:
        bullets.add(Bullet(x: player.x - 0.04, y: player.y - 0.03, vy: -0.022, color: color, shape: BulletShape.cannon));
        bullets.add(Bullet(x: player.x + 0.04, y: player.y - 0.03, vy: -0.022, color: color, shape: BulletShape.cannon));
        if (state.currentWeapon == WeaponType.spread) {
          bullets.add(Bullet(x: player.x - 0.07, y: player.y - 0.01, vx: -0.006, vy: -0.018, color: color, shape: BulletShape.cannon));
          bullets.add(Bullet(x: player.x + 0.07, y: player.y - 0.01, vx: 0.006, vy: -0.018, color: color, shape: BulletShape.cannon));
        }
        flash(player.x - 0.04, player.y - 0.03);
        flash(player.x + 0.04, player.y - 0.03);
        break;
    }
  }

  // ── BULLET vs OBSTACLE ─────────────────────────────────────────────────────
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
            hit = sqrt(pow(bullet.x - cx, 2) + pow(bullet.y - cy, 2)) < obs.width * 0.55;
            break;
          case ObstacleType.mine:
            final cx = obs.x + obs.width / 2;
            final cy = obs.y + obs.height / 2;
            hit = sqrt(pow(bullet.x - cx, 2) + pow(bullet.y - cy, 2)) < obs.width * 0.7;
            break;
          case ObstacleType.laserWall:
            hit = bullet.x >= obs.x && bullet.x <= obs.x + obs.width && bullet.y >= obs.y && bullet.y <= obs.y + obs.height;
            break;
          case ObstacleType.sweepBeam:
          case ObstacleType.pulseGate:
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
    final cx = obs.x + obs.width / 2;
    final cy = obs.y + obs.height / 2;
    _spawnHitSparks(cx, cy, obs.color);

    if (obs.hp <= 0) {
      shakeIntensity = (obs.wallTier == WallTier.armored) ? 14.0 : (obs.wallTier == WallTier.reinforced) ? 10.0 : 5.0;
      _spawnExplosionParticles(cx, cy);
      if (obs.type == ObstacleType.laserWall && obs.wallTier != null) {
        _spawnDebrisParticles(cx, cy, obs.color, obs.wallTier!);
      }
      if (obs.wallTier == WallTier.reinforced || obs.wallTier == WallTier.armored) {
        shockwaves.add(Shockwave(x: cx, y: cy, radius: 0.02, life: 1.0, color: obs.color));
      }
      if (obs.type == ObstacleType.mine && obs.mineType == MineType.cluster) {
        _spawnClusterChildren(cx, cy);
      }

      double dropChance = 0.30;
      if (obs.wallTier == WallTier.reinforced) dropChance = 0.55;
      if (obs.wallTier == WallTier.armored) dropChance = 0.80;
      if (obs.type == ObstacleType.asteroid) dropChance = 0.40;
      if (obs.type == ObstacleType.mine) dropChance = 0.25;
      if (_rng.nextDouble() < dropChance) _spawnChest(cx, cy);

      int bonus = 50;
      if (obs.wallTier == WallTier.fragile) bonus = 20;
      if (obs.wallTier == WallTier.standard) bonus = 50;
      if (obs.wallTier == WallTier.reinforced) bonus = 150;
      if (obs.wallTier == WallTier.armored) bonus = 400;
      if (obs.type == ObstacleType.mine) {
        bonus = obs.mineType == MineType.cluster ? 60 : obs.mineType == MineType.tracker ? 80 : 30;
      }
      if (obs.type == ObstacleType.asteroid) bonus = 60;
      state.score += bonus;
      // Charge rampage meter on kill
      if (!rampage.isActive) {
        final charge = obs.wallTier == WallTier.armored ? 0.12
            : obs.wallTier == WallTier.reinforced ? 0.07
            : obs.type == ObstacleType.mine ? 0.05
            : 0.03;
        rampage.chargeLevel = (rampage.chargeLevel + charge).clamp(0.0, 1.0);
      }
    }
  }

  void _spawnClusterChildren(double cx, double cy) {
    for (int i = 0; i < 3; i++) {
      final angle = (2 * pi / 3) * i + _rng.nextDouble() * 0.5;
      final dist = 0.04 + _rng.nextDouble() * 0.03;
      obstacles.add(Obstacle(
        x: cx + cos(angle) * dist - 0.018,
        y: cy + sin(angle) * dist,
        width: 0.035, height: 0.035,
        speed: 0.002 + state.difficulty * 0.0005,
        type: ObstacleType.mine,
        color: const Color(0xFFFF9900),
        mineType: MineType.proximity,
        rotationSpeed: (_rng.nextDouble() - 0.5) * 0.1,
        hp: 1,
      ));
    }
  }

  void _spawnHitSparks(double x, double y, Color color) {
    for (int i = 0; i < 8; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 0.005 + _rng.nextDouble() * 0.01;
      particles.add({'x': x, 'y': y, 'vx': cos(angle) * speed, 'vy': sin(angle) * speed, 'life': 0.7, 'color': Color.lerp(color, Colors.white, 0.6)!, 'size': 2.5 + _rng.nextDouble() * 2, 'decay': 0.05});
    }
  }

  void _spawnExplosionParticles(double x, double y, {bool intense = false}) {
    final count = intense ? 35 : 18; // Reduced from 40/22 to avoid lag
    for (int i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = intense ? (0.008 + _rng.nextDouble() * 0.025) : (0.006 + _rng.nextDouble() * 0.016);
      final colors = [const Color(0xFFFF2D55), const Color(0xFFFF6B2B), const Color(0xFFFFB020), Colors.white, const Color(0xFFFFFF00)];
      particles.add({'x': x, 'y': y, 'vx': cos(angle) * speed, 'vy': sin(angle) * speed - 0.003, 'life': 1.0, 'color': colors[_rng.nextInt(colors.length)], 'size': intense ? (5.0 + _rng.nextDouble() * 10) : (4.0 + _rng.nextDouble() * 7), 'decay': intense ? 0.025 : 0.035});
    }
  }

  void _spawnDebrisParticles(double x, double y, Color color, WallTier tier) {
    final count = tier == WallTier.armored ? 18 : tier == WallTier.reinforced ? 12 : 6;
    for (int i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 0.004 + _rng.nextDouble() * 0.018;
      final size = tier == WallTier.armored ? (6.0 + _rng.nextDouble() * 10) : tier == WallTier.reinforced ? (4.0 + _rng.nextDouble() * 7) : (2.0 + _rng.nextDouble() * 4);
      particles.add({'x': x, 'y': y, 'vx': cos(angle) * speed, 'vy': sin(angle) * speed, 'life': 1.0, 'color': color, 'size': size, 'decay': 0.015, 'isDebris': true});
    }
  }

  // Bomb particles: reduced count to avoid lag
  // ignore: unused_element
  void _spawnBombExplosionParticles(double x, double y) {
    for (int i = 0; i < 50; i++) { // was 80
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 0.005 + _rng.nextDouble() * 0.035;
      final colors = [Colors.white, const Color(0xFFFF6B2B), const Color(0xFFFFD60A), const Color(0xFFFF00FF), const Color(0xFF00FFFF)];
      particles.add({'x': x, 'y': y, 'vx': cos(angle) * speed, 'vy': sin(angle) * speed, 'life': 1.0, 'color': colors[_rng.nextInt(colors.length)], 'size': 4.0 + _rng.nextDouble() * 12, 'decay': 0.015});
    }
    for (int i = 0; i < 20; i++) { // was 40
      particles.add({'x': x + (_rng.nextDouble() - 0.5) * 0.15, 'y': y, 'vx': (_rng.nextDouble() - 0.5) * 0.008, 'vy': -0.008 - _rng.nextDouble() * 0.018, 'life': 1.0, 'color': const Color(0xFFFF4400), 'size': 5.0 + _rng.nextDouble() * 8, 'decay': 0.012});
    }
  }

  // ── CHEST SPAWN ────────────────────────────────────────────────────────────
  void _spawnChest(double x, double y) {
    TreasureReward reward;
    final roll = _rng.nextDouble();
    if (roll < 0.08) reward = TreasureReward.bomb;
    else if (roll < 0.12) reward = TreasureReward.weaponRapid;
    else if (roll < 0.16) reward = TreasureReward.weaponSpread;
    else if (roll < 0.20) reward = TreasureReward.weaponLaser;
    else {
      const basics = [TreasureReward.slowTime, TreasureReward.extraLife, TreasureReward.coins, TreasureReward.shield];
      reward = basics[_rng.nextInt(basics.length)];
    }
    final coinAmt = reward == TreasureReward.coins ? (3 + _rng.nextInt(8)) : 0;
    chests.add(TreasureChest(
      x: x.clamp(0.05, 0.95), y: y,
      speed: 0.002, reward: reward,
      coinAmount: coinAmt, sectorIndex: state.sector,
    ));
  }

  // ── TRAIL ──────────────────────────────────────────────────────────────────
  void _updateTrail(double speedMult) {
    final color = player.color;
    switch (player.trailStyle) {
      case TrailStyle.clean:
        trail.add(TrailPoint(x: player.x, y: player.y + 0.022, life: 1.0, size: 5.0 + _rng.nextDouble() * 3, color: color));
        if (_rng.nextDouble() < 0.5) trail.add(TrailPoint(x: player.x, y: player.y + 0.022, life: 0.6, size: 2.5, color: Colors.white));
        break;
      case TrailStyle.scatter:
        for (int i = 0; i < 3; i++) {
          trail.add(TrailPoint(x: player.x, y: player.y + 0.02, life: 0.8, size: 2.5 + _rng.nextDouble() * 2, color: color, vx: (_rng.nextDouble() - 0.5) * 0.012));
        }
        break;
      case TrailStyle.fire:
        for (final dx in [-0.025, 0.0, 0.025]) {
          trail.add(TrailPoint(x: player.x + dx, y: player.y + 0.025, life: 1.0, size: 7.0 + _rng.nextDouble() * 5, color: color));
          trail.add(TrailPoint(x: player.x + dx + (_rng.nextDouble() - 0.5) * 0.01, y: player.y + 0.025, life: 0.7, size: 4.0, color: const Color(0xFFFF2D00)));
        }
        break;
      case TrailStyle.ghost:
        trail.add(TrailPoint(x: player.x + (_rng.nextDouble() - 0.5) * 0.015, y: player.y + 0.02, life: 0.5, size: 4.0, color: color.withOpacity(0.4)));
        break;
      case TrailStyle.wide:
        for (final dx in [-0.04, 0.0, 0.04]) {
          trail.add(TrailPoint(x: player.x + dx, y: player.y + 0.03, life: 1.0, size: 8.0 + _rng.nextDouble() * 4, color: color));
          trail.add(TrailPoint(x: player.x + dx, y: player.y + 0.03, life: 0.8, size: 5.0, color: Colors.white.withOpacity(0.5)));
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

  // ── PATTERN SPAWNER ────────────────────────────────────────────────────────
  void _spawnPattern() {
    _waveCount++;

    // BREATH WINDOW: after N waves, send a sparse wave and open the gap
    // This is the "release" in the tension-release cycle
    if (!isBreathWindow && _waveCount >= _waveBeforeBreathe && _breathCooldown > 8.0) {
      isBreathWindow = true;
      breathTimer = 2.2; // 2.2s of relative calm
      _breathCooldown = 0;
      tensionLevel *= 0.3; // tension snaps down — player feels the exhale
      // Breath wave: just a single fragile gap wall, no extras
      _spawnGapWall(forceTier: WallTier.fragile);
      state.lastPattern = PatternType.gapWall;
      onRewardCollected?.call('◎  CLEAR  +300');
      state.score += 300;
      return;
    }

    final pattern = _pickPattern();
    state.lastPattern = pattern;
    switch (pattern) {
      case PatternType.gapWall: _spawnGapWall(); break;
      case PatternType.zigzag: _spawnZigzag(); break;
      case PatternType.minefield: _spawnMinefield(); break;
      case PatternType.sweepBeam: _spawnSweepBeam(); break;
      case PatternType.pulseGate: _spawnPulseGate(); break;
    }

    // Sector bonuses — extra obstacles per sector
    if (state.sector >= 3 && pattern == PatternType.gapWall && _rng.nextDouble() < 0.4) {
      _spawnFloatingAsteroid();
    }
    if (state.sector >= 4 && _rng.nextDouble() < 0.35) {
      _spawnExtraMine();
    }
    if (state.sector >= 5 && _rng.nextDouble() < 0.4) {
      _spawnGapWall();
    }
  }

  void _bossFire() {
    if (boss == null || boss!.isDead) return;
    final bx = boss!.x;
    final by = boss!.y + 0.09;
    final dx = player.x - bx;
    final dy = player.y - by;
    final dist = sqrt(dx*dx + dy*dy);
    if (dist < 0.01) return;
    final bvx = (dx/dist) * 0.013;
    final bvy = (dy/dist) * 0.013;
    bossMissiles.add(BossMissile(x: bx, y: by, vx: bvx, vy: bvy));
    bossMissiles.add(BossMissile(x: bx-0.06, y: by, vx: bvx-0.004, vy: bvy+0.002, color: const Color(0xFFFF6B00)));
    bossMissiles.add(BossMissile(x: bx+0.06, y: by, vx: bvx+0.004, vy: bvy+0.002, color: const Color(0xFFFF6B00)));
    shakeIntensity = max(shakeIntensity, 5.0);
    for (int i = 0; i < 8; i++) {
      final a = _rng.nextDouble() * 2 * pi;
      particles.add({'x': bx, 'y': by, 'vx': cos(a)*0.008, 'vy': sin(a)*0.008, 'life': 0.5, 'color': const Color(0xFFFF2D55), 'size': 3.0+_rng.nextDouble()*5, 'decay': 0.06});
    }
  }

  void activateRampage() {
    if (!isRampageReady) return;
    rampage.isActive = true;
    rampage.timer = 10.0;
    rampage.chargeLevel = 0;
    shakeIntensity = 20.0;
    onRewardCollected?.call('🔥 RAMPAGE — 10s INVINCIBLE');
    for (int i = 0; i < 30; i++) {
      final a = _rng.nextDouble() * 2 * pi;
      final spd = 0.01 + _rng.nextDouble() * 0.025;
      particles.add({'x': player.x, 'y': player.y, 'vx': cos(a)*spd, 'vy': sin(a)*spd, 'life': 1.0, 'color': const Color(0xFFFF6B00), 'size': 5.0+_rng.nextDouble()*12, 'decay': 0.02});
    }
    for (int i = 0; i < 3; i++) shockwaves.add(Shockwave(x: player.x, y: player.y, radius: 0.01+i*0.01, life: 1.0, color: i == 0 ? Colors.white : const Color(0xFFFF6B00)));
    notifyListeners();
  }

  void _spawnExtraMine() {
    final mType = _pickMineType();
    obstacles.add(Obstacle(
      x: 0.05 + _rng.nextDouble() * 0.9,
      y: -0.08 - _rng.nextDouble() * 0.1,
      width: 0.055, height: 0.055,
      speed: 0.003 + state.difficulty * 0.0008,
      type: ObstacleType.mine,
      color: _mineColor(mType),
      mineType: mType,
      rotationSpeed: (_rng.nextDouble() - 0.5) * 0.08,
    ));
  }

  WallTier _pickWallTier() {
    final d = state.difficulty;
    final s = state.sector;
    final roll = _rng.nextDouble();
    // Sector-boosted tier probability
    if (s >= 5) {
      if (roll < 0.05) return WallTier.fragile;
      if (roll < 0.20) return WallTier.standard;
      if (roll < 0.55) return WallTier.reinforced;
      return WallTier.armored;
    }
    if (s >= 4 || d >= 3.0) {
      if (roll < 0.10) return WallTier.fragile;
      if (roll < 0.30) return WallTier.standard;
      if (roll < 0.65) return WallTier.reinforced;
      return WallTier.armored;
    }
    if (s >= 3 || d >= 1.5) {
      if (roll < 0.15) return WallTier.fragile;
      if (roll < 0.45) return WallTier.standard;
      if (roll < 0.82) return WallTier.reinforced;
      return WallTier.armored;
    }
    if (s >= 2 || d >= 0.5) {
      if (roll < 0.3) return WallTier.fragile;
      if (roll < 0.75) return WallTier.standard;
      return WallTier.reinforced;
    }
    return roll < 0.6 ? WallTier.fragile : WallTier.standard;
  }

  MineType _pickMineType() {
    final d = state.difficulty;
    final s = state.sector;
    final roll = _rng.nextDouble();
    if (s >= 4 || d >= 2.0) {
      if (roll < 0.35) return MineType.proximity;
      if (roll < 0.65) return MineType.tracker;
      return MineType.cluster;
    }
    if (s >= 3 || d >= 1.0) return roll < 0.55 ? MineType.proximity : MineType.tracker;
    return MineType.proximity;
  }

  Color _mineColor(MineType type) {
    switch (type) {
      case MineType.proximity: return const Color(0xFFFF6B2B);
      case MineType.tracker: return const Color(0xFF00CFFF);
      case MineType.cluster: return const Color(0xFFFF2D55);
    }
  }

  void _spawnGapWall({WallTier? forceTier}) {
    final tier = forceTier ?? _pickWallTier();
    final tierData = wallTierData(tier);
    final pal = sectorPalette(state.sector);
    final wallCol = pal.wallColor;
    // Gap gets narrower in higher sectors
    final gapWidth = (0.28 - state.difficulty * 0.012 - (state.sector - 1) * 0.008).clamp(0.18, 0.28);

    double referenceCenter = _lastGapCenter;
    double bestY = -999.0;
    for (final obs in obstacles) {
      if (obs.type != ObstacleType.laserWall) continue;
      if (obs.x < 0.02) {
        for (final obs2 in obstacles) {
          if (obs2.type == ObstacleType.laserWall && obs2.x > 0.05 && (obs2.y - obs.y).abs() < 0.015) {
            final gc = (obs.width + obs2.x) / 2.0;
            if (obs.y > bestY) { bestY = obs.y; referenceCenter = gc; }
            break;
          }
        }
      }
    }

    final minC = (referenceCenter - _maxGapShift).clamp(0.14, 0.86);
    final maxC = (referenceCenter + _maxGapShift).clamp(0.14, 0.86);
    double gapCenter = minC + _rng.nextDouble() * (maxC - minC);
    gapCenter = gapCenter.clamp(gapWidth / 2 + 0.04, 1.0 - gapWidth / 2 - 0.04);
    _lastGapCenter = gapCenter;

    double lowestSpawnY = -0.055;
    for (final obs in obstacles) {
      if (obs.type != ObstacleType.laserWall) continue;
      if (obs.y < 0.0 && obs.y < lowestSpawnY) lowestSpawnY = obs.y;
    }
    final spawnY = lowestSpawnY - _minRowSeparation;
    final gapLeft = (gapCenter - gapWidth / 2).clamp(0.03, 0.75);
    final spd = 0.0042 + state.difficulty * 0.0016 + (state.sector - 1) * 0.0008;
    final h = tierData.thickness;

    if (gapLeft > 0.02) {
      obstacles.add(Obstacle(x: 0, y: spawnY, width: gapLeft, height: h, speed: spd, type: ObstacleType.laserWall, color: wallCol, wallTier: tier, sectorIndex: state.sector));
    }
    final rightStart = gapLeft + gapWidth;
    if (rightStart < 0.98) {
      obstacles.add(Obstacle(x: rightStart, y: spawnY, width: 1.0 - rightStart, height: h, speed: spd, type: ObstacleType.laserWall, color: wallCol, wallTier: tier, sectorIndex: state.sector));
    }
  }

  void _spawnZigzag() {
    final tier = _pickWallTier();
    final tierData = wallTierData(tier);
    final pal = sectorPalette(state.sector);
    final wallCol = pal.wallColor;
    final spd = 0.0038 + state.difficulty * 0.0014 + (state.sector - 1) * 0.0006;
    final h = tierData.thickness;
    final leftSide = _rng.nextBool();
    final gw = state.sector >= 4 ? 0.26 : 0.30; // Tighter gaps in later sectors

    final gap1Center = leftSide ? 0.20 : 0.70;
    final gap1Left = gap1Center - gw / 2;
    if (gap1Left > 0.02) obstacles.add(Obstacle(x: 0, y: -0.06, width: gap1Left, height: h, speed: spd, type: ObstacleType.laserWall, color: wallCol, wallTier: tier, sectorIndex: state.sector));
    final gap1Right = gap1Left + gw;
    if (gap1Right < 0.98) obstacles.add(Obstacle(x: gap1Right, y: -0.06, width: 1.0 - gap1Right, height: h, speed: spd, type: ObstacleType.laserWall, color: wallCol, wallTier: tier, sectorIndex: state.sector));

    final gap2Center = leftSide ? 0.70 : 0.20;
    final gap2Left = gap2Center - gw / 2;
    if (gap2Left > 0.02) obstacles.add(Obstacle(x: 0, y: -0.42, width: gap2Left, height: h, speed: spd, type: ObstacleType.laserWall, color: wallCol, wallTier: tier, sectorIndex: state.sector));
    final gap2Right = gap2Left + gw;
    if (gap2Right < 0.98) obstacles.add(Obstacle(x: gap2Right, y: -0.42, width: 1.0 - gap2Right, height: h, speed: spd, type: ObstacleType.laserWall, color: wallCol, wallTier: tier, sectorIndex: state.sector));
  }

  void _spawnMinefield() {
    final spd = 0.003 + state.difficulty * 0.0008 + (state.sector - 1) * 0.0005;
    const mineSize = 0.055;
    const cols = 6;
    const colW = 1.0 / cols;
    final colIndices = List.generate(cols, (i) => i)..shuffle(_rng);
    // More mines in later sectors
    final mineCount = state.sector >= 4 ? 5 : state.sector >= 3 ? 4 : 3;
    final usedCols = colIndices.take(mineCount).toList();
    for (int i = 0; i < usedCols.length; i++) {
      final col = usedCols[i];
      final x = colW * col + colW * 0.5 + (_rng.nextDouble() - 0.5) * colW * 0.3;
      final yOffset = -0.06 - (i * 0.09) - _rng.nextDouble() * 0.03;
      final mType = _pickMineType();
      obstacles.add(Obstacle(
        x: x.clamp(0.05, 0.95), y: yOffset,
        width: mineSize, height: mineSize,
        speed: spd, type: ObstacleType.mine,
        color: _mineColor(mType), mineType: mType,
        rotationSpeed: (_rng.nextDouble() - 0.5) * 0.08,
      ));
    }
  }

  void _spawnSweepBeam() {
    final yPos = player.y - 0.12 + _rng.nextDouble() * 0.08;
    final fromLeft = _rng.nextBool();
    // Faster sweeps in later sectors
    final sweepSpd = 0.28 + state.difficulty * 0.04 + (state.sector - 1) * 0.04;
    obstacles.add(Obstacle(
      x: 0, y: yPos.clamp(0.15, 0.75), width: 1.0, height: 0.032, speed: 0.0008,
      type: ObstacleType.sweepBeam, color: const Color(0xFFFF0080),
      sweepFromLeft: fromLeft, sweepSpeed: sweepSpd,
    ));
  }

  void _spawnPulseGate() {
    final centerX = 0.22 + _rng.nextDouble() * 0.56;
    final spd = 0.003 + state.difficulty * 0.0008 + (state.sector - 1) * 0.0006;
    const startPhase = pi / 2;
    // Tighter gap in later sectors
    final halfGap = (0.16 - state.difficulty * 0.008 - (state.sector - 1) * 0.006).clamp(0.10, 0.16);
    obstacles.add(Obstacle(
      x: 0, y: -0.06, width: 1.0, height: 0.05, speed: spd,
      type: ObstacleType.pulseGate, color: const Color(0xFF00CFFF),
      gapCenterX: centerX, gapHalfWidth: halfGap, pulsePhase: startPhase,
    ));
  }

  void _spawnFloatingAsteroid() {
    final size = 0.025 + _rng.nextDouble() * 0.022;
    final spd = 0.004 + state.difficulty * 0.0015 + (state.sector - 1) * 0.0005;
    obstacles.add(Obstacle(
      x: 0.06 + _rng.nextDouble() * 0.88,
      y: -0.15 - _rng.nextDouble() * 0.1,
      width: size, height: size,
      speed: spd * (0.8 + _rng.nextDouble() * 0.5),
      type: ObstacleType.asteroid, color: const Color(0xFF8B6E4E),
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
        coins.add(Coin(x: (baseX + offset).clamp(0.1, 0.9), y: -0.05 - i * 0.001, speed: 0.003 + state.difficulty * 0.0008, pulsePhase: i * 0.4));
      }
    } else {
      coins.add(Coin(x: 0.1 + _rng.nextDouble() * 0.8, y: -0.05, speed: 0.003 + state.difficulty * 0.0008));
    }
  }

  void _spawnPowerUp() {
    if (_rng.nextDouble() < 0.55) {
      powerUps.add(PowerUp(x: 0.1 + _rng.nextDouble() * 0.8, y: -0.05, speed: 0.003, type: PowerUpType.values[_rng.nextInt(PowerUpType.values.length)]));
    }
  }

  // ── COLLISIONS ─────────────────────────────────────────────────────────────
  void _checkCollisions() {
    final pw = player.size / screenWidth;
    final ph = player.size / screenHeight;
    final px = player.x, py = player.y;

    if (!state.isShieldActive) {
      for (final obs in obstacles) {
        if (obs.isDying || (obs.hp <= 0 && obs.isShootable)) continue;
        bool hit = false;
        const margin = 0.01;
        switch (obs.type) {
          case ObstacleType.asteroid:
          case ObstacleType.mine:
            final dist = sqrt(pow(px - (obs.x + obs.width / 2), 2) + pow(py - (obs.y + obs.height / 2), 2));
            hit = dist < obs.width * 0.5 + pw * 0.45;
            break;
          case ObstacleType.laserWall:
            hit = px + pw / 2 - margin > obs.x && px - pw / 2 + margin < obs.x + obs.width && py + ph / 2 - margin > obs.y && py - ph / 2 + margin < obs.y + obs.height;
            break;
          case ObstacleType.sweepBeam:
            if (!obs.sweepDone) {
              final beamX = obs.sweepFromLeft ? obs.sweepProgress : (1.0 - obs.sweepProgress);
              const beamW = 0.055;
              hit = (beamX - px).abs() < beamW + pw && py + ph / 2 > obs.y && py - ph / 2 < obs.y + obs.height;
            }
            break;
          case ObstacleType.pulseGate:
            final openness = (sin(obs.pulsePhase) + 1) / 2;
            final halfGap = obs.gapHalfWidth * max(openness, 0.08);
            final distFromCenter = (px - obs.gapCenterX).abs();
            final inGapZone = py + ph / 2 > obs.y && py - ph / 2 < obs.y + obs.height;
            hit = inGapZone && distFromCenter > halfGap + pw * 0.4 && openness < 0.15;
            break;
        }
        if (hit) { _handleHit(); return; }
      }
    }

    // Coins
    for (final coin in coins) {
      if (!coin.collected) {
        final dist = sqrt(pow(px - coin.x, 2) + pow(py - coin.y, 2));
        if (dist < 0.028 + pw) {
          coin.collected = true; state.coins++; state.combo++;
          state.maxCombo = max(state.maxCombo, state.combo);
          _spawnCoinParticles(coin.x, coin.y); onCoinCollected?.call();
          // Combo milestones
          if (state.combo == 10 || state.combo == 25 || state.combo == 50) {
            comboFlash = 1.0;
            onRewardCollected?.call('🔥 COMBO ×${state.combo}  INSANE!');
          }
        }
      }
    }

    // Power-ups
    for (final pu in powerUps) {
      if (!pu.collected) {
        final dist = sqrt(pow(px - pu.x, 2) + pow(py - pu.y, 2));
        if (dist < 0.04 + pw) {
          pu.collected = true; _applyPowerUp(pu.type); _spawnPowerUpParticles(pu.x, pu.y, pu.type);
        }
      }
    }

    // Chests
    for (final chest in chests) {
      if (!chest.collected) {
        final dist = sqrt(pow(px - chest.x, 2) + pow(py - chest.y, 2));
        if (dist < 0.05 + pw) {
          chest.collected = true; _applyChestReward(chest); _spawnChestParticles(chest.x, chest.y);
        }
      }
    }
  }

  void _applyChestReward(TreasureChest chest) {
    switch (chest.reward) {
      case TreasureReward.slowTime:
        state.isSlowActive = true; state.slowTimer = 5.0; onRewardCollected?.call('⏱ SLOW TIME'); break;
      case TreasureReward.extraLife:
        state.lives = min(state.lives + 1, 5); onRewardCollected?.call('♥ EXTRA LIFE'); break;
      case TreasureReward.coins:
        state.coins += chest.coinAmount; onRewardCollected?.call('✦ ${chest.coinAmount} CREDITS'); break;
      case TreasureReward.shield:
        state.isShieldActive = true; state.shieldTimer = 6.0; onRewardCollected?.call('◉ SHIELD'); break;
      case TreasureReward.bomb:
        state.bombs = min(state.bombs + 1, 9); onRewardCollected?.call('💥 BOMB +1'); shakeIntensity = 6.0; break;
      case TreasureReward.weaponRapid:
        state.currentWeapon = WeaponType.rapidFire; state.weaponTimer = 8.0; onRewardCollected?.call('⚡ RAPID FIRE'); break;
      case TreasureReward.weaponSpread:
        state.currentWeapon = WeaponType.spread; state.weaponTimer = 8.0; onRewardCollected?.call('✦ SPREAD SHOT'); break;
      case TreasureReward.weaponLaser:
        state.currentWeapon = WeaponType.laser; state.weaponTimer = 8.0; onRewardCollected?.call('⟐ LASER BEAM'); break;
    }
  }

  void _handleHit() {
    state.combo = 0;
    nearMissStreak = 0; // streak resets on hit
    state.lives--;
    onHit?.call();
    shakeIntensity = 18.0;
    tensionLevel = 1.0; // maxed — they got hit
    _spawnExplosionParticles(player.x, player.y, intense: true);
    if (state.lives <= 0) {
      stopGame();
    } else {
      state.isShieldActive = true;
      state.shieldTimer = 2.5;
      // Near-death slow: if on last life, brief bullet-time so player can breathe
      if (state.lives == 1) {
        nearDeathSlowTimer = 1.8;
        onRewardCollected?.call('⚠  LAST LIFE — SLOW TIME');
      }
    }
  }

  void _applyPowerUp(PowerUpType type) {
    switch (type) {
      case PowerUpType.shield: state.isShieldActive = true; state.shieldTimer = 6.0; break;
      case PowerUpType.slowTime: state.isSlowActive = true; state.slowTimer = 5.0; break;
      case PowerUpType.extraLife: state.lives = min(state.lives + 1, 5); break;
    }
  }

  void _spawnCoinParticles(double x, double y) {
    for (int i = 0; i < 10; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 0.004 + _rng.nextDouble() * 0.008;
      particles.add({'x': x, 'y': y, 'vx': cos(angle) * speed, 'vy': sin(angle) * speed - 0.012, 'life': 1.0, 'color': const Color(0xFFFFD60A), 'size': 3.0 + _rng.nextDouble() * 3, 'decay': 0.04});
    }
  }

  void _spawnPowerUpParticles(double x, double y, PowerUpType type) {
    final color = type == PowerUpType.shield ? const Color(0xFF4D7CFF) : type == PowerUpType.slowTime ? const Color(0xFF8B5CF6) : const Color(0xFFFF2D55);
    for (int i = 0; i < 14; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 0.005 + _rng.nextDouble() * 0.01;
      particles.add({'x': x, 'y': y, 'vx': cos(angle) * speed, 'vy': sin(angle) * speed - 0.008, 'life': 1.0, 'color': color, 'size': 3.0 + _rng.nextDouble() * 4, 'decay': 0.035});
    }
  }

  void _spawnChestParticles(double x, double y) {
    for (int i = 0; i < 20; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final speed = 0.005 + _rng.nextDouble() * 0.016;
      final colors = [const Color(0xFFFFD60A), const Color(0xFFFFB020), Colors.white, const Color(0xFF00FFD1)];
      particles.add({'x': x, 'y': y, 'vx': cos(angle) * speed, 'vy': sin(angle) * speed - 0.012, 'life': 1.0, 'color': colors[_rng.nextInt(colors.length)], 'size': 4.0 + _rng.nextDouble() * 6, 'decay': 0.025});
    }
  }

  @override
  void dispose() {
    _gameLoop?.cancel();
    super.dispose();
  }
}
