# 🚀 STELLAR DRIFT — Space Arcade Game

A Flutter space dodge-and-shoot arcade game with sector progression, boss fights,
5 ship skins, combo systems, rampage mode, and a gauntlet finale.

---

## 🏗️ Architecture Refactor Roadmap

Restructuring the codebase from flat-state + big-switch-blocks into a
component-friendly architecture where **new content = new files, zero edits to
existing code**.

### Phase 1 — Typed Particle & GhostImage ✦ FOUNDATION
> Eliminates the #1 crash source (`Map<String, dynamic>` particles).

- [x] Create `ParticleShape` enum (`dot`, `spark`, `ember`, `shard`, `chunk`)
- [x] Create typed `Particle` class replacing all `Map<String, dynamic>` particles
- [x] Create typed `GhostImage` class replacing ghost `Map<String, dynamic>`
- [x] Update every `particles.add({...})` → `particles.add(Particle(...))`
- [x] Update `_tick()` particle loop to use typed fields
- [x] Update `_drawParticles()` in game_painter.dart to use typed fields
- [x] Update `_drawGhostImages()` to use typed fields
- [x] `flutter analyze` clean

### Phase 2 — Entity Base + Subclasses ✅
> Kill the Obstacle god-class. Each type owns its own fields.

- [x] Create abstract `GameEntity` base class (position, velocity, hp, size, update, getHitbox, onDeath)
- [x] Create `Hitbox` sealed class (CircleHitbox, RectHitbox, LineHitbox)
- [x] Create `AsteroidEntity` subclass
- [x] Create `LaserWallEntity` subclass
- [x] Create `MineEntity` subclass (proximity, tracker, cluster)
- [x] Create `SweepBeamEntity` subclass
- [x] Create `PulseGateEntity` subclass
- [x] Migrate `List<Obstacle>` → `List<GameEntity>` in GameProvider
- [x] Update spawner to create subclass instances
- [x] Update collision to use `entity.checkBulletHit()` / `entity.checkPlayerHit()`
- [x] Update painter to dispatch by entity type
- [x] `flutter analyze` clean

### Phase 3 — PainterRegistry ✅
> Open/closed dispatch — add a new entity without touching game_painter.

- [x] Add `String get renderType` to GameEntity + overrides in all subclasses
- [x] Create `PainterRegistry` — maps renderType string → painter function
- [x] Register existing painters (wall, mine, gate, asteroid, sweep)
- [x] Refactor `_drawObstacles()` to use `registry.paint()` dispatch
- [x] `flutter analyze` clean

### Phase 4 — DeathEffect Composition ✅
> Composable death effects snapped onto entities like LEGO.

- [x] Create `DeathEffect` sealed class + 7 concrete effects:
  - `ShakeEffect`, `ExplosionEffect`, `ShockwaveEffect`, `ChestDropEffect`, `ScoreEffect`, `RampageChargeEffect`, `SplitEffect`
- [x] Each entity carries `List<DeathEffect> deathEffects` (configured per subclass)
- [x] Replace `damageObstacle()` per-type branching with `for (fx in obs.deathEffects) switch`
- [x] Cluster mine split = `SplitEffect(3, MineType.proximity)`
- [x] `flutter analyze` clean

### Phase 5 — WeaponSlot System
> Ships fire through composable, data-driven weapon slots.

- [x] Create `BulletPort` (dx/dy offset, vx/vy velocity, shape, color, xJitter)
- [x] Create `WeaponSlot` (fire rate + `List<BulletPort>`) with `WeaponSlot.spread()` factory
- [x] Create `resolveWeaponSlot(SkinType, WeaponType)` — single source of truth for all 5 skins × weapon combos
- [x] Refactor `spawnBullets()` from per-skin switch to `slot.ports` loop
- [x] Refactor `getFireRate()` from switch/override to `slot.fireRate`
- [x] Remove unused `_fireRate` static const
- [x] Boss firing deferred to Phase 6 (aimed `BossMissile` ≠ `Bullet`)
- [x] `flutter analyze` clean

### Phase 6 — Boss Archetype + State Machine
> Multiple boss types without touching existing code.

- [x] Create `BossMissilePort` + `BossFirePattern` (data-driven missile layouts)
- [x] Create `BossPhase` with HP-threshold triggers (`fireRateScale`, `trackingSpeed`, `pattern`)
- [x] Create `BossArchetype` abstract class (`baseHp`, `baseFireRate`, `phases`, `arrivalMessage`, `defeatMessage`, `painterId`)
- [x] Migrate current boss to `ImperialHunterArchetype` with 2 phases (standard 3-missile → enraged 5-missile at ≤ 50 % HP)
- [x] Create `BossRegistry.resolve(sector, killCount)` mapping sector + wave → archetype
- [x] Refactor `bossFire()` to iterate `pattern.ports` instead of hardcoded 3-missile spawn
- [x] Refactor boss spawn to use `BossRegistry` + archetype-driven HP / fire rate / messages
- [x] Refactor boss tick: phase-scaled `fireRate`, phase-driven `trackingSpeed`
- [x] Move `_romanNumeral` to top-level `romanNumeral()` helper in game_models.dart
- [x] Remove unused `_romanNumeral` from GameProvider
- [x] `flutter analyze` clean

### Phase 7 — SectorConfig (Data-Driven Sectors)
> Adding a sector = adding one data object. Zero code changes.

- [x] Create `SectorConfig` data class (patterns, tiers, mines, intervals, bonuses, minefieldCount)
- [x] Create `PatternEntry` (weight + minDifficulty), `TierEntry`, `MineEntry`, `SectorBonus`
- [x] Define all 5 sectors as `const SectorConfig` data objects (`_sector1`–`_sector5`)
- [x] Create `resolveSectorConfig(int sector)` lookup
- [x] Add `sectorConfig` getter to GameProvider
- [x] Refactor `_pickPattern()` to weighted random from `config.patterns` (replaces 20-line if-chain)
- [x] Refactor `_pickWallTier()` to weighted random from `config.tiers` (replaces 30-line cascade)
- [x] Refactor `_pickMineType()` to weighted random from `config.mines` (replaces 12-line cascade)
- [x] Refactor `_obstacleInterval` to use `config.patternIntervals` + `config.intervalPerSector`
- [x] Refactor sector bonuses from `if sector >= N` to `config.bonuses` loop
- [x] Refactor minefield count from sector ternary to `config.minefieldCount`
- [x] `flutter analyze` clean

### Phase 8 — Scenario / Event System
> Replace inline gauntlet/escape flags with composable scenarios.

- [x] Create `GameScenario` abstract (canActivate, onActivate, update, onComplete)
- [x] Create `GauntletScenario` replacing gauntlet flags
- [x] Create `BossEncounterScenario` replacing inline boss spawn logic
- [x] Main `_tick()` delegates to scenario loop (`_scenarios` activate + update)
- [x] Support environmental effects (solar wind, visibility, gravity wells)
- [x] `flutter analyze` clean

---

## 📂 Project Structure

```
lib/
├── main.dart
├── models/
│   └── game_models.dart       ← Enums, Player, Obstacle, RunState, etc.
├── providers/
│   ├── game_provider.dart     ← Main game state + tick loop
│   ├── settings_provider.dart
│   └── systems/
│       ├── spawner.dart       ← Pattern spawning (part of game_provider)
│       ├── combat.dart        ← Hit detection, damage, rewards
│       ├── particles.dart     ← Particle spawn helpers
│       ├── boss_system.dart   ← Boss fire, rampage, arrival effects
│       └── scenarios.dart     ← GameScenario, Gauntlet, BossEncounter, Environment
├── game/
│   ├── game_painter.dart      ← Main CustomPainter
│   ├── painters/              ← wall, mine, gate, chest, bullet, boss, overlay
│   └── ships/                 ← phantom, nova, inferno, specter, titan
├── screens/                   ← home, game, game_over, shop, settings
├── theme/
│   └── app_theme.dart
└── utils/
    ├── ad_manager.dart
    └── safe_color.dart        ← SafeOpacity .o() extension
```

---

## 🚀 Run

```bash
flutter pub get
flutter run
```

## 📦 Build Release

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`
