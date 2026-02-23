import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/game_provider.dart';
import '../providers/settings_provider.dart';
import '../models/game_models.dart';
import '../theme/app_theme.dart';
import '../game/game_painter.dart';
import 'game_over_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late GameProvider _game;
  bool _initialized = false;
  bool _showHitFlash = false;

  String? _rewardText;
  late AnimationController _toastCtrl;
  late Animation<double> _toastAnim;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _game = GameProvider();
    _animController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat();
    _toastCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));
    _toastAnim = CurvedAnimation(parent: _toastCtrl, curve: Curves.easeInOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final settings = context.read<SettingsProvider>();
      final size = MediaQuery.of(context).size;
      _game.screenWidth = size.width;
      _game.screenHeight = size.height;

      _game.onGameOver = () {
        if (!mounted) return;
        Future.delayed(const Duration(milliseconds: 400), () {
          if (!mounted) return;
          settings.updateBestScore(_game.state.score);
          settings.addCoins(_game.state.coins);
          settings.incrementGamesPlayed();
          Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => GameOverScreen(
                    score: _game.state.score,
                    coins: _game.state.coins,
                    maxCombo: _game.state.maxCombo),
                transitionsBuilder: (_, a, __, c) =>
                    FadeTransition(opacity: a, child: c),
                transitionDuration: const Duration(milliseconds: 400),
              ));
        });
      };

      _game.onHit = () {
        if (!mounted) return;
        HapticFeedback.heavyImpact();
        setState(() => _showHitFlash = true);
        Future.delayed(const Duration(milliseconds: 180), () {
          if (mounted) setState(() => _showHitFlash = false);
        });
      };

      _game.onCoinCollected = () => HapticFeedback.lightImpact();

      _game.onRewardCollected = (String text) {
        if (!mounted) return;
        setState(() => _rewardText = text);
        _toastCtrl.forward(from: 0).then((_) {
          if (mounted) setState(() => _rewardText = null);
        });
        HapticFeedback.mediumImpact();
      };

      _game.startGame(skin: settings.selectedSkin);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _toastCtrl.dispose();
    _game.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _triggerBomb() {
    if (_game.state.bombs <= 0) return;
    HapticFeedback.heavyImpact();
    _game
        .detonateBomb(); // notifyListeners() already triggers rebuild — no setState needed here
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // ── ARCHITECTURE FIX ──────────────────────────────────────────────────
    // OLD: AnimatedBuilder wraps ListenableBuilder — every notifyListeners()
    //      (60x/sec) rebuilds the entire Stack: HUD, toast, bomb button, all.
    //      On bomb tap: detonateBomb() fires notifyListeners() which triggers
    //      a full-tree rebuild at the exact moment we're doing heavy work.
    //
    // NEW: Two separate layers.
    //   Layer 1 — _GameCanvas: ListenableBuilder only. Rebuilds 60x/sec.
    //             Contains ONLY the CustomPaint + screen-space overlays that
    //             read from game state (bomb flash, shield, slow tint).
    //             These are cheap — just color containers over a canvas.
    //   Layer 2 — UI widgets: driven by setState only (hit flash, toast).
    //             HUD, bomb button, toast, pause — rebuild only when needed.
    //
    // Result: bomb tap no longer forces HUD + toast + button to rebuild.
    // ─────────────────────────────────────────────────────────────────────

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(children: [
        // ── LAYER 1: Game canvas — fast, 60fps, game-state driven ──────────
        _GameCanvas(game: _game),

        // ── LAYER 2: UI overlays — setState driven, rebuild only when needed

        // Hit flash (setState in onHit callback)
        if (_showHitFlash)
          Positioned.fill(
              child: IgnorePointer(
                  child: Container(color: AppTheme.danger.withOpacity(0.28)))),

        // HUD — ListenableBuilder inside so only HUD rebuilds, not canvas
        SafeArea(
            child: _HUD(
                game: _game,
                onBack: () {
                  _game.stopGame();
                  Navigator.pop(context);
                })),

        // Bomb button
        Positioned(
          right: 20,
          bottom: 40 + MediaQuery.of(context).padding.bottom,
          child: _BombButton(
              color: _game.player.color,
              bombCount: _game.state.bombs,
              onTap: _triggerBomb),
        ),

        // Rampage button — isolated widget with its own listener
        _RampageButton(game: _game),

        // Weapon indicator
        if (_game.state.weaponTimer > 0)
          Positioned(
            left: 20,
            bottom: 40 + MediaQuery.of(context).padding.bottom,
            child: _WeaponIndicator(game: _game),
          ),

        // Reward toast — only mounts when _rewardText != null (setState)
        if (_rewardText != null)
          Positioned(
            top: size.height * 0.28,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _toastAnim,
              builder: (_, __) {
                final opacity = sin(_toastAnim.value * pi).clamp(0.0, 1.0);
                final yOffset = -20 * _toastAnim.value;
                final isBomb = _rewardText!.contains('BOMB');
                return Transform.translate(
                  offset: Offset(0, yOffset),
                  child: Opacity(
                    opacity: opacity,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.card.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                              color: (isBomb
                                      ? const Color(0xFFFF6B00)
                                      : AppTheme.coinColor)
                                  .withOpacity(0.7),
                              width: 1.5),
                          boxShadow: [
                            BoxShadow(
                                color: (isBomb
                                        ? const Color(0xFFFF6B00)
                                        : AppTheme.coinColor)
                                    .withOpacity(0.3),
                                blurRadius: 20)
                          ],
                        ),
                        child: Text(
                          _rewardText!,
                          style: GoogleFonts.rajdhani(
                            color: isBomb
                                ? const Color(0xFFFF6B00)
                                : AppTheme.coinColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // Pause overlay
        if (_game.state.isPaused)
          _PauseOverlay(
              game: _game,
              onQuit: () {
                _game.stopGame();
                Navigator.pop(context);
              }),

        // Sector banner
        _SectorBanner(game: _game),
      ]),
    );
  }
}

// ── GAME CANVAS — isolated fast layer ────────────────────────────────────────
// Only this widget rebuilds at 60fps. HUD, toast, buttons are in parent Stack
// and only rebuild on setState. This is the key architectural fix.
class _GameCanvas extends StatelessWidget {
  final GameProvider game;
  const _GameCanvas({required this.game});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final pal = game.palette;

    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        return Stack(children: [
          // The actual game render
          GestureDetector(
            onPanUpdate: (d) => game.moveTo(d.localPosition.dx / size.width,
                d.localPosition.dy / size.height),
            onTapDown: (d) => game.moveTo(d.localPosition.dx / size.width,
                d.localPosition.dy / size.height),
            child: Transform.translate(
              offset: game.shakeOffset,
              child: CustomPaint(
                  size: size, painter: GamePainter(game, game.animTick)),
            ),
          ),

          // Slow time tint — cheap, game-state driven
          if (game.state.isSlowActive)
            Positioned.fill(
                child: IgnorePointer(
                    child: Container(
                        color: AppTheme.slowColor.withOpacity(0.04)))),

          // Bomb flash — fades via detonationTimer, no setState needed
          if (game.activeBomb != null)
            Positioned.fill(
                child: IgnorePointer(
                    child: Opacity(
              opacity: ((1.0 - game.activeBomb!.detonationTimer) * 0.35)
                  .clamp(0.0, 0.35),
              child: Container(color: const Color(0xFFFF6B00)),
            ))),

          // Shield border
          if (game.state.isShieldActive)
            Positioned.fill(
                child: IgnorePointer(
                    child: Container(
              decoration: BoxDecoration(
                  border: Border.all(
                      color: AppTheme.accentAlt.withOpacity(0.5), width: 2)),
            ))),

          // Sector vignette
          Positioned.fill(
              child: IgnorePointer(
                  child: Container(
            decoration: BoxDecoration(
                gradient: RadialGradient(
              colors: [Colors.transparent, pal.nebulaColor.withOpacity(0.28)],
              center: Alignment.center,
              radius: 1.1,
            )),
          ))),
        ]);
      },
    );
  }
}

// ── WEAPON INDICATOR ──────────────────────────────────────────────────────────
class _WeaponIndicator extends StatelessWidget {
  final GameProvider game;
  const _WeaponIndicator({required this.game});

  @override
  Widget build(BuildContext context) {
    final weapon = game.state.currentWeapon;
    Color color;
    String label;
    String icon;
    switch (weapon) {
      case WeaponType.rapidFire:
        color = Colors.yellowAccent;
        label = 'RAPID FIRE';
        icon = '⚡';
        break;
      case WeaponType.spread:
        color = Colors.orangeAccent;
        label = 'SPREAD';
        icon = '✦';
        break;
      case WeaponType.laser:
        color = Colors.redAccent;
        label = 'LASER';
        icon = '⟐';
        break;
      default:
        color = game.player.color;
        label = 'STANDARD';
        icon = '●';
        break;
    }
    final progress = (game.state.weaponTimer / 8.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.card.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
        boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 12)],
      ),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(icon, style: TextStyle(fontSize: 18, color: color)),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.rajdhani(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5)),
            const SizedBox(height: 6),
            SizedBox(
              width: 50,
              height: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppTheme.bg,
                    color: color),
              ),
            ),
          ]),
    );
  }
}

// ── BOMB BUTTON ───────────────────────────────────────────────────────────────
class _BombButton extends StatefulWidget {
  final Color color;
  final int bombCount;
  final VoidCallback onTap;
  const _BombButton(
      {required this.color, required this.bombCount, required this.onTap});

  @override
  State<_BombButton> createState() => _BombButtonState();
}

class _BombButtonState extends State<_BombButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final hasBombs = widget.bombCount > 0;
    final bombColor =
        hasBombs ? const Color(0xFFFF6B2B) : const Color(0xFF444444);
    final scale = _pressed ? 0.88 : 1.0;

    return GestureDetector(
      onTapDown: (_) {
        if (hasBombs) setState(() => _pressed = true);
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (hasBombs) widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: Transform.scale(
        scale: scale,
        child: Stack(clipBehavior: Clip.none, children: [
          // AnimatedContainer handles the pulse via implicit animation —
          // no separate AnimationController ticker needed
          AnimatedContainer(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOut,
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _pressed
                  ? bombColor.withOpacity(0.4)
                  : AppTheme.card.withOpacity(0.9),
              border: Border.all(
                  color: bombColor.withOpacity(_pressed
                      ? 1.0
                      : hasBombs
                          ? 0.7
                          : 0.3),
                  width: _pressed ? 3.0 : 2.0),
              boxShadow: hasBombs
                  ? [
                      BoxShadow(
                          color: bombColor.withOpacity(_pressed ? 0.7 : 0.25),
                          blurRadius: _pressed ? 30 : 14)
                    ]
                  : null,
            ),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('💥',
                  style: TextStyle(
                      fontSize: hasBombs ? 28 : 22,
                      color: hasBombs ? null : Colors.grey)),
              Text('BOMB',
                  style: GoogleFonts.rajdhani(
                      color: bombColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5)),
            ]),
          ),
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasBombs ? bombColor : const Color(0xFF333333),
                  border: Border.all(color: AppTheme.bg, width: 2)),
              child: Center(
                  child: Text('${widget.bombCount}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900))),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── SECTOR BANNER ─────────────────────────────────────────────────────────────
class _SectorBanner extends StatefulWidget {
  final GameProvider game;
  const _SectorBanner({required this.game});

  @override
  State<_SectorBanner> createState() => _SectorBannerState();
}

class _SectorBannerState extends State<_SectorBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  int _lastSector = 1;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    // Listen to game outside of build — never mutate state inside build()
    widget.game.addListener(_onGameTick);
  }

  void _onGameTick() {
    final sector = widget.game.state.sector;
    if (sector != _lastSector && sector > 1) {
      _lastSector = sector;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    widget.game.removeListener(_onGameTick);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Build is ONLY driven by _ctrl animation — no game reads here
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final opacity =
            _ctrl.isAnimating ? (sin(_anim.value * pi)).clamp(0.0, 1.0) : 0.0;
        if (opacity <= 0) return const SizedBox.shrink();
        final pal = sectorPalette(_lastSector);
        return Positioned.fill(
          child: IgnorePointer(
              child: Center(
                  child: Opacity(
            opacity: opacity,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                      color: pal.accentA.withOpacity(0.7), width: 1.5),
                  bottom: BorderSide(
                      color: pal.accentA.withOpacity(0.7), width: 1.5),
                ),
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    pal.nebulaColor.withOpacity(0.6),
                    Colors.transparent
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('ENTERING',
                    style: GoogleFonts.rajdhani(
                        color: pal.accentB.withOpacity(0.8),
                        fontSize: 11,
                        letterSpacing: 6,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(pal.name,
                    style: GoogleFonts.rajdhani(
                        color: pal.accentA,
                        fontSize: 28,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('SECTOR $_lastSector',
                    style: GoogleFonts.rajdhani(
                        color: pal.accentA.withOpacity(0.6),
                        fontSize: 13,
                        letterSpacing: 4,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ))),
        );
      },
    );
  }
}

// ── RAMPAGE BUTTON ────────────────────────────────────────────────────────────
// Isolated widget — only rebuilds when isRampageReady changes.
// Does NOT sit in the 60fps ListenableBuilder chain.
class _RampageButton extends StatefulWidget {
  final GameProvider game;
  const _RampageButton({required this.game});
  @override
  State<_RampageButton> createState() => _RampageButtonState();
}

class _RampageButtonState extends State<_RampageButton> {
  bool _wasReady = false;

  @override
  void initState() {
    super.initState();
    widget.game.addListener(_onGameChange);
  }

  void _onGameChange() {
    final ready = widget.game.isRampageReady;
    if (ready != _wasReady) {
      _wasReady = ready;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    widget.game.removeListener(_onGameChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.game.isRampageReady) return const SizedBox.shrink();
    return Positioned(
      left: 20,
      bottom: 100 + MediaQuery.of(context).padding.bottom,
      child: GestureDetector(
        onTap: widget.game.activateRampage,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1A0800),
            border: Border.all(color: const Color(0xFFFF6B00), width: 2.5),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFFFF6B00).withOpacity(0.6),
                  blurRadius: 18,
                  spreadRadius: 2)
            ],
          ),
          child: const Center(
            child: Text('🔥', style: TextStyle(fontSize: 30)),
          ),
        ),
      ),
    );
  }
}

// ── PAUSE OVERLAY ─────────────────────────────────────────────────────────────
class _PauseOverlay extends StatelessWidget {
  final GameProvider game;
  final VoidCallback onQuit;
  const _PauseOverlay({required this.game, required this.onQuit});

  @override
  Widget build(BuildContext context) {
    final pal = game.palette;
    return Positioned.fill(
        child: Container(
      color: Colors.black.withOpacity(0.75),
      child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('◼ PAUSED',
            style: GoogleFonts.rajdhani(
                color: pal.accentA,
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: 6)),
        const SizedBox(height: 8),
        Text(pal.name,
            style: GoogleFonts.rajdhani(
                color: pal.accentA.withOpacity(0.6),
                fontSize: 12,
                letterSpacing: 4)),
        Text('SECTOR ${game.state.sector}',
            style: GoogleFonts.rajdhani(
                color: AppTheme.textSecondary, fontSize: 11, letterSpacing: 3)),
        const SizedBox(height: 40),
        _PauseBtn('▶  RESUME', pal.accentA, AppTheme.bg, game.pauseGame),
        const SizedBox(height: 12),
        _PauseBtn(
            '⏹  ABORT MISSION', AppTheme.card, AppTheme.textSecondary, onQuit),
      ])),
    ));
  }
}

Widget _PauseBtn(String label, Color bg, Color fg, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 220,
      height: 52,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: bg == AppTheme.card
            ? Border.all(color: AppTheme.cardBorder, width: 1.5)
            : null,
      ),
      child: Center(
          child: Text(label,
              style: GoogleFonts.rajdhani(
                  color: fg,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2))),
    ),
  );
}

// ── HUD ────────────────────────────────────────────────────────────────────────
class _HUD extends StatelessWidget {
  final GameProvider game;
  final VoidCallback onBack;
  const _HUD({required this.game, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final pal = game.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Top row
        Row(children: [
          _HUDBtn(icon: Icons.arrow_back_ios_new, onTap: onBack),
          const SizedBox(width: 10),
          // Sector chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: pal.nebulaColor.withOpacity(0.6),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: pal.accentA.withOpacity(0.5)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: pal.accentA)),
              const SizedBox(width: 6),
              Text('SEC.${game.state.sector}  ${pal.name}',
                  style: GoogleFonts.rajdhani(
                      color: pal.accentA,
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w900)),
            ]),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: AppTheme.card.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.cardBorder)),
            child: Text(_formatScore(game.state.score),
                style: GoogleFonts.rajdhani(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2)),
          ),
          const Spacer(),
          _HUDBtn(
              icon: game.state.isPaused ? Icons.play_arrow : Icons.pause,
              onTap: game.pauseGame),
        ]),

        const SizedBox(height: 10),

        // Lives + coins
        Row(children: [
          Row(
              children: List.generate(5, (i) {
            if (i >= 3 && i >= game.state.lives) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                i < game.state.lives
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color:
                    i < game.state.lives ? AppTheme.danger : AppTheme.textDim,
                size: 18,
              ),
            );
          })),
          const Spacer(),
          if (game.state.bombs > 0)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B2B).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: const Color(0xFFFF6B2B).withOpacity(0.4)),
              ),
              child: Row(children: [
                const Text('💥', style: TextStyle(fontSize: 10)),
                const SizedBox(width: 4),
                Text('×${game.state.bombs}',
                    style: GoogleFonts.rajdhani(
                        color: const Color(0xFFFF6B2B),
                        fontWeight: FontWeight.w900,
                        fontSize: 13)),
              ]),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: AppTheme.coinColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.coinColor.withOpacity(0.3))),
            child: Row(children: [
              const Icon(Icons.circle, color: AppTheme.coinColor, size: 8),
              const SizedBox(width: 5),
              Text('${game.state.coins}',
                  style: GoogleFonts.rajdhani(
                      color: AppTheme.coinColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
            ]),
          ),
        ]),

        // Power-up bars
        if (game.state.isShieldActive || game.state.isSlowActive) ...[
          const SizedBox(height: 8),
          Row(children: [
            if (game.state.isShieldActive) ...[
              _PowerBar(
                  label: 'SHIELD',
                  color: AppTheme.accentAlt,
                  progress: game.state.shieldTimer / 6.0),
              const SizedBox(width: 8),
            ],
            if (game.state.isSlowActive)
              _PowerBar(
                  label: 'SLOW',
                  color: AppTheme.slowColor,
                  progress: game.state.slowTimer / 5.0),
          ]),
        ],

        // Combo
        if (game.state.combo >= 3) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.coinColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.coinColor.withOpacity(0.4)),
            ),
            child: Text('✕${game.state.combo}  COMBO',
                style: GoogleFonts.rajdhani(
                    color: AppTheme.coinColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 2)),
          ),
        ],
      ]),
    );
  }

  String _formatScore(int score) {
    if (score >= 1000) return '${(score / 1000).toStringAsFixed(1)}K';
    return '$score';
  }
}

class _HUDBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HUDBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
            color: AppTheme.card.withOpacity(0.85),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.cardBorder)),
        child: Icon(icon, color: AppTheme.textSecondary, size: 16),
      ),
    );
  }
}

class _PowerBar extends StatelessWidget {
  final String label;
  final Color color;
  final double progress;
  const _PowerBar(
      {required this.label, required this.color, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.4))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
            width: 44,
            height: 3,
            child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: AppTheme.bg,
                    color: color))),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.rajdhani(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1)),
      ]),
    );
  }
}
