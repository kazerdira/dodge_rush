import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import 'game_screen.dart';
import 'home_screen.dart';

class GameOverScreen extends StatefulWidget {
  final int score;
  final int coins;
  final int maxCombo;

  const GameOverScreen({super.key, required this.score, required this.coins, this.maxCombo = 0});

  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen> with TickerProviderStateMixin {
  late AnimationController _slideCtrl;
  late AnimationController _pulseCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _pulseAnim;
  bool _isNewBest = false;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutBack));
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsProvider>();
      setState(() => _isNewBest = widget.score > settings.bestScore);
    });
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: SlideTransition(
          position: _slideAnim,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isNewBest) ...[
                  ScaleTransition(
                    scale: _pulseAnim,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('🏆 NEW BEST!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 3)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Game Over title
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(colors: [AppTheme.danger, Color(0xFFFF8C42)]).createShader(b),
                  child: const Text('GAME\nOVER', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 62, fontWeight: FontWeight.w900, height: 0.95, letterSpacing: 2)),
                ),

                const SizedBox(height: 36),

                // Score card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Column(children: [
                    const Text('SCORE', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, letterSpacing: 3)),
                    const SizedBox(height: 6),
                    Text('${widget.score}', style: const TextStyle(color: AppTheme.accent, fontSize: 58, fontWeight: FontWeight.w900, height: 1)),
                    Divider(color: AppTheme.cardBorder, height: 28),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                      _Stat(icon: Icons.emoji_events_rounded, label: 'BEST', value: '${settings.bestScore}', color: AppTheme.coinColor),
                      _Stat(icon: Icons.toll_rounded, label: 'COINS', value: '+${widget.coins}', color: AppTheme.coinColor),
                      _Stat(icon: Icons.local_fire_department, label: 'COMBO', value: 'x${widget.maxCombo}', color: AppTheme.warning),
                    ]),
                  ]),
                ),

                const SizedBox(height: 28),

                // Revive - Ad button
                _AdButton(onTap: () => _showAdDialog(context)),

                const SizedBox(height: 14),

                // Play again
                _BigButton(
                  label: 'PLAY AGAIN',
                  gradient: const LinearGradient(colors: [AppTheme.accent, AppTheme.accentAlt]),
                  textColor: AppTheme.bg,
                  onTap: () => Navigator.pushReplacement(context, _fade(const GameScreen())),
                ),

                const SizedBox(height: 14),

                // Home
                _BigButton(
                  label: 'HOME',
                  gradient: null,
                  textColor: AppTheme.textSecondary,
                  onTap: () => Navigator.pushAndRemoveUntil(context, _fade(const HomeScreen()), (_) => false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PageRouteBuilder _fade(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
    transitionDuration: const Duration(milliseconds: 300),
  );

  void _showAdDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Revive?', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800)),
        content: const Text('In production, a rewarded ad plays here.\n\nAdd your AdMob IDs in ad_manager.dart to enable.', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK', style: TextStyle(color: AppTheme.accent)))],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _Stat({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10, letterSpacing: 1)),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
    ]);
  }
}

class _AdButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AdButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppTheme.coinColor, width: 1.5),
          color: AppTheme.coinColor.withOpacity(0.08),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.play_circle_outline, color: AppTheme.coinColor, size: 22),
          const SizedBox(width: 10),
          const Text('WATCH AD TO REVIVE', style: TextStyle(color: AppTheme.coinColor, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13)),
        ]),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  final String label;
  final LinearGradient? gradient;
  final Color textColor;
  final VoidCallback onTap;
  const _BigButton({required this.label, required this.gradient, required this.textColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity, height: 56,
        decoration: BoxDecoration(
          gradient: gradient,
          color: gradient == null ? AppTheme.card : null,
          borderRadius: BorderRadius.circular(28),
          border: gradient == null ? Border.all(color: AppTheme.cardBorder) : null,
        ),
        child: Center(child: Text(label, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 3))),
      ),
    );
  }
}
