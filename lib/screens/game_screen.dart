import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../models/game_models.dart';
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

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _game = GameProvider();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
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
                  maxCombo: _game.state.maxCombo,
                ),
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

      _game.onCoinCollected = () {
        HapticFeedback.lightImpact();
      };

      _game.startGame(skin: settings.selectedSkin);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _game.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: AnimatedBuilder(
        animation: _animController,
        builder: (context, _) {
          return ListenableBuilder(
            listenable: _game,
            builder: (context, _) {
              return GestureDetector(
                onPanUpdate: (d) =>
                    _game.moveTo(d.localPosition.dx / size.width),
                onTapDown: (d) => _game.moveTo(d.localPosition.dx / size.width),
                child: Transform.translate(
                  offset: _game.shakeOffset,
                  child: Stack(children: [
                    // Game canvas
                    CustomPaint(
                      size: size,
                      painter: GamePainter(_game, _game.animTick),
                    ),

                    // Slow time effect — blue tint overlay
                    if (_game.state.isSlowActive)
                      Positioned.fill(
                          child: IgnorePointer(
                              child: Container(
                        color: AppTheme.slowColor.withOpacity(0.04),
                      ))),

                    // Hit flash
                    if (_showHitFlash)
                      Positioned.fill(
                          child: IgnorePointer(
                              child: Container(
                        color: AppTheme.danger.withOpacity(0.28),
                      ))),

                    // Shield border glow
                    if (_game.state.isShieldActive)
                      Positioned.fill(
                          child: IgnorePointer(
                              child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: AppTheme.accentAlt.withOpacity(0.5),
                              width: 2),
                        ),
                      ))),

                    // HUD
                    SafeArea(
                        child: _HUD(
                            game: _game,
                            onBack: () {
                              _game.stopGame();
                              Navigator.pop(context);
                            })),

                    // Pause overlay
                    if (_game.state.isPaused)
                      _PauseOverlay(
                          game: _game,
                          onQuit: () {
                            _game.stopGame();
                            Navigator.pop(context);
                          }),

                    // Sector announcement
                    _SectorBanner(game: _game),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

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
        vsync: this, duration: const Duration(milliseconds: 2000));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sector = widget.game.state.sector;
    if (sector != _lastSector && sector > 1) {
      _lastSector = sector;
      _ctrl.forward(from: 0);
    }

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final opacity =
            _ctrl.isAnimating ? (sin(_anim.value * pi)).clamp(0.0, 1.0) : 0.0;
        if (opacity <= 0) return const SizedBox.shrink();
        return Positioned.fill(
            child: IgnorePointer(
                child: Center(
          child: Opacity(
            opacity: opacity,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppTheme.accent.withOpacity(0.6)),
                  bottom: BorderSide(color: AppTheme.accent.withOpacity(0.6)),
                ),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  'ENTERING SECTOR $_lastSector',
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 11,
                    letterSpacing: 6,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getSectorName(_lastSector),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ]),
            ),
          ),
        )));
      },
    );
  }

  String _getSectorName(int sector) {
    const names = [
      '',
      'VOID EXPANSE',
      'ASTEROID BELT',
      'NEBULA CORE',
      'DEBRIS FIELD',
      'DEEP SPACE'
    ];
    return sector < names.length ? names[sector] : 'UNKNOWN SPACE';
  }
}

class _PauseOverlay extends StatelessWidget {
  final GameProvider game;
  final VoidCallback onQuit;
  const _PauseOverlay({required this.game, required this.onQuit});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
        child: Container(
      color: Colors.black.withOpacity(0.75),
      child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('◼ PAUSED',
            style: TextStyle(
              color: AppTheme.accent,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: 6,
            )),
        const SizedBox(height: 8),
        Text('SECTOR ${game.state.sector}',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              letterSpacing: 4,
            )),
        const SizedBox(height: 40),
        _PauseBtn('▶  RESUME', AppTheme.accent, AppTheme.bg, game.pauseGame),
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
              style: TextStyle(
                color: fg,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ))),
    ),
  );
}

// ─── HUD ────────────────────────────────────────────────────────────────────

class _HUD extends StatelessWidget {
  final GameProvider game;
  final VoidCallback onBack;
  const _HUD({required this.game, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Top row
        Row(children: [
          _HUDBtn(icon: Icons.arrow_back_ios_new, onTap: onBack),
          const SizedBox(width: 10),
          // Sector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.card.withOpacity(0.85),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
            ),
            child: Text(
              'SECTOR ${game.state.sector}',
              style: const TextStyle(
                  color: AppTheme.accent,
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w900),
            ),
          ),
          const Spacer(),
          // Score
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.card.withOpacity(0.9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Text(
              _formatScore(game.state.score),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
          const Spacer(),
          _HUDBtn(
              icon: game.state.isPaused ? Icons.play_arrow : Icons.pause,
              onTap: game.pauseGame),
        ]),

        const SizedBox(height: 10),

        // Lives + coins row
        Row(children: [
          // Lives
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
          // Coins
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.coinColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.coinColor.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.circle, color: AppTheme.coinColor, size: 8),
              const SizedBox(width: 5),
              Text('${game.state.coins}',
                  style: const TextStyle(
                    color: AppTheme.coinColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  )),
            ]),
          ),
        ]),

        // Power-up bars
        if (game.state.isShieldActive || game.state.isSlowActive) ...[
          const SizedBox(height: 8),
          Row(children: [
            if (game.state.isShieldActive) ...[
              _PowerBar(
                  label: 'SHL',
                  color: AppTheme.accentAlt,
                  progress: game.state.shieldTimer / 6.0),
              const SizedBox(width: 8),
            ],
            if (game.state.isSlowActive)
              _PowerBar(
                  label: 'SLW',
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
            child: Text(
              '✕${game.state.combo}  COMBO',
              style: const TextStyle(
                  color: AppTheme.coinColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 2),
            ),
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
          border: Border.all(color: AppTheme.cardBorder),
        ),
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
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 44,
          height: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: AppTheme.bg,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1)),
      ]),
    );
  }
}
