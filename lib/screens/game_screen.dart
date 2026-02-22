import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../models/game_models.dart';
import 'game_over_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameProvider _game;
  bool _showHitFlash = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _game = GameProvider();
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
        Future.delayed(const Duration(milliseconds: 350), () {
          if (!mounted) return;
          settings.updateBestScore(_game.state.score);
          settings.addCoins(_game.state.coins);
          settings.incrementGamesPlayed();
          Navigator.pushReplacement(context, PageRouteBuilder(
            pageBuilder: (_, __, ___) => GameOverScreen(score: _game.state.score, coins: _game.state.coins, maxCombo: _game.state.maxCombo),
            transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
          ));
        });
      };

      _game.onHit = () {
        if (!mounted) return;
        setState(() => _showHitFlash = true);
        Future.delayed(const Duration(milliseconds: 160), () {
          if (mounted) setState(() => _showHitFlash = false);
        });
      };

      _game.startGame(skin: settings.selectedSkin);
    }
  }

  @override
  void dispose() {
    _game.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: ListenableBuilder(
        listenable: _game,
        builder: (context, _) {
          return GestureDetector(
            onPanUpdate: (d) => _game.moveTo(d.localPosition.dx / size.width),
            onTapDown: (d) => _game.moveTo(d.localPosition.dx / size.width),
            child: Stack(children: [
              // Game canvas
              CustomPaint(
                size: size,
                painter: _GamePainter(game: _game, screenSize: size),
              ),

              // Hit flash
              if (_showHitFlash)
                Positioned.fill(child: Container(color: AppTheme.danger.withOpacity(0.22))),

              // Shield border
              if (_game.state.isShieldActive)
                Positioned.fill(child: IgnorePointer(child: Container(
                  decoration: BoxDecoration(border: Border.all(color: AppTheme.accentAlt.withOpacity(0.5), width: 3)),
                ))),

              // HUD
              SafeArea(child: _HUD(game: _game, onBack: () { _game.stopGame(); Navigator.pop(context); })),

              // Pause overlay
              if (_game.state.isPaused)
                Positioned.fill(child: Container(
                  color: Colors.black.withOpacity(0.7),
                  child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('PAUSED', style: TextStyle(color: AppTheme.accent, fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: 4)),
                    const SizedBox(height: 32),
                    _PauseBtn('RESUME', AppTheme.accent, AppTheme.bg, _game.pauseGame),
                    const SizedBox(height: 12),
                    _PauseBtn('QUIT', AppTheme.card, AppTheme.textSecondary, () { _game.stopGame(); Navigator.pop(context); }),
                  ])),
                )),
            ]),
          );
        },
      ),
    );
  }
}

Widget _PauseBtn(String label, Color bg, Color fg, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 200, height: 52,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(26),
        border: bg == AppTheme.card ? Border.all(color: AppTheme.textSecondary.withOpacity(0.3)) : null),
      child: Center(child: Text(label, style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 2))),
    ),
  );
}

class _HUD extends StatelessWidget {
  final GameProvider game;
  final VoidCallback onBack;
  const _HUD({required this.game, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(children: [
        Row(children: [
          _IconBtn(icon: Icons.arrow_back_ios_new, onTap: onBack),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(color: AppTheme.card.withOpacity(0.85), borderRadius: BorderRadius.circular(20)),
            child: Text('${game.state.score}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w900)),
          ),
          const Spacer(),
          _IconBtn(icon: game.state.isPaused ? Icons.play_arrow : Icons.pause, onTap: game.pauseGame),
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: List.generate(3, (i) => Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Icon(Icons.favorite_rounded, color: i < game.state.lives ? AppTheme.danger : AppTheme.textSecondary.withOpacity(0.2), size: 20),
          ))),
          Row(children: [
            const Text('🪙', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text('${game.state.coins}', style: const TextStyle(color: AppTheme.coinColor, fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
        ]),
        if (game.state.isShieldActive || game.state.isSlowActive) ...[
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (game.state.isShieldActive) _PowerBar(label: 'SHIELD', color: AppTheme.accentAlt, progress: game.state.shieldTimer / 5.0),
            if (game.state.isShieldActive && game.state.isSlowActive) const SizedBox(width: 8),
            if (game.state.isSlowActive) _PowerBar(label: 'SLOW', color: AppTheme.slowColor, progress: game.state.slowTimer / 4.0),
          ]),
        ],
        if (game.state.combo >= 3) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: AppTheme.coinColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.coinColor.withOpacity(0.4))),
            child: Text('x${game.state.combo} COMBO! 🔥', style: const TextStyle(color: AppTheme.coinColor, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ],
      ]),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: AppTheme.card.withOpacity(0.8), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: AppTheme.textSecondary, size: 17),
      ),
    );
  }
}

class _PowerBar extends StatelessWidget {
  final String label;
  final Color color;
  final double progress;
  const _PowerBar({required this.label, required this.color, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.5))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 48, height: 4, child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(value: progress.clamp(0.0, 1.0), backgroundColor: AppTheme.bg, color: color),
        )),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

// ─── Painter ────────────────────────────────────────────────────────────────

class _GamePainter extends CustomPainter {
  final GameProvider game;
  final Size screenSize;
  _GamePainter({required this.game, required this.screenSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Grid
    paint.color = AppTheme.accent.withOpacity(0.025);
    paint.strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 40) canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (double y = 0; y < size.height; y += 40) canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);

    // Obstacles
    for (final obs in game.obstacles) {
      final rect = Rect.fromLTWH(obs.x * size.width, obs.y * size.height, obs.width * size.width, obs.height * size.height);
      paint.color = obs.color.withOpacity(0.3);
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawRRect(RRect.fromRectAndRadius(rect.inflate(3), const Radius.circular(5)), paint);
      paint.maskFilter = null;
      paint.shader = LinearGradient(colors: [obs.color, obs.color.withOpacity(0.75)], begin: Alignment.topCenter, end: Alignment.bottomCenter).createShader(rect);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(5)), paint);
      paint.shader = null;
      paint.color = Colors.white.withOpacity(0.15);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(rect.left, rect.top, rect.width, 2.5), const Radius.circular(2)), paint);
    }

    // Coins
    for (final coin in game.coins) {
      if (coin.collected) continue;
      final c = Offset(coin.x * size.width, coin.y * size.height);
      paint.color = AppTheme.coinColor.withOpacity(0.3);
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(c, 14, paint);
      paint.maskFilter = null;
      paint.shader = RadialGradient(colors: [const Color(0xFFFFE566), AppTheme.coinColor], center: const Alignment(-0.3, -0.3)).createShader(Rect.fromCircle(center: c, radius: 11));
      canvas.drawCircle(c, 11, paint);
      paint.shader = null;
      paint.color = Colors.white.withOpacity(0.45);
      canvas.drawCircle(Offset(c.dx - 3.5, c.dy - 3.5), 3, paint);
    }

    // Power-ups
    for (final pu in game.powerUps) {
      if (pu.collected) continue;
      final c = Offset(pu.x * size.width, pu.y * size.height);
      final puColor = pu.type == PowerUpType.shield ? AppTheme.accentAlt : pu.type == PowerUpType.slowTime ? AppTheme.slowColor : AppTheme.danger;
      paint.color = puColor.withOpacity(0.3);
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(c, 20, paint);
      paint.maskFilter = null;
      paint.color = puColor.withOpacity(0.5);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2;
      canvas.drawCircle(c, 17, paint);
      paint.style = PaintingStyle.fill;
    }

    // Particles
    for (final p in game.particles) {
      final life = p['life'] as double;
      canvas.drawCircle(
        Offset((p['x'] as double) * size.width, (p['y'] as double) * size.height),
        (p['size'] as double) * life,
        paint..color = (p['color'] as Color).withOpacity(life),
      );
    }

    // Player
    final px = game.player.x * size.width;
    final py = game.player.y * size.height;
    final pr = game.player.size.toDouble();
    final pc = game.player.color;

    if (game.state.isShieldActive) {
      paint.color = AppTheme.accentAlt.withOpacity(0.25);
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
      canvas.drawCircle(Offset(px, py), pr + 12, paint);
      paint.maskFilter = null;
      paint.color = AppTheme.accentAlt.withOpacity(0.7);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2;
      canvas.drawCircle(Offset(px, py), pr + 10, paint);
      paint.style = PaintingStyle.fill;
    }

    paint.color = pc.withOpacity(0.5);
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(Offset(px, py), pr + 3, paint);
    paint.maskFilter = null;

    // Triangle shape
    final path = Path()
      ..moveTo(px, py - pr)
      ..lineTo(px + pr * 0.85, py + pr * 0.65)
      ..lineTo(px - pr * 0.85, py + pr * 0.65)
      ..close();
    paint.shader = RadialGradient(colors: [Colors.white.withOpacity(0.9), pc]).createShader(Rect.fromCircle(center: Offset(px, py), radius: pr));
    canvas.drawPath(path, paint);
    paint.shader = null;

    // Highlight
    paint.color = Colors.white.withOpacity(0.35);
    canvas.drawCircle(Offset(px - pr * 0.28, py - pr * 0.32), pr * 0.28, paint);
  }

  @override
  bool shouldRepaint(_GamePainter old) => true;
}
