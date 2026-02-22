import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import 'game_screen.dart';
import 'shop_screen.dart';
import 'settings_screen.dart';
import 'dart:math';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _bgCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.07).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _bgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(children: [
        // Animated background
        AnimatedBuilder(
          animation: _bgCtrl,
          builder: (_, __) => CustomPaint(size: size, painter: _BgPainter(_bgCtrl.value * 2 * pi)),
        ),

        SafeArea(child: Column(children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.coinColor.withOpacity(0.3))),
                child: Row(children: [
                  const Text('🪙', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text('${settings.totalCoins}', style: const TextStyle(color: AppTheme.coinColor, fontWeight: FontWeight.w800, fontSize: 16)),
                ]),
              ),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.settings_outlined, color: AppTheme.textSecondary, size: 22)),
              ),
            ]),
          ),

          const Spacer(),

          // Logo
          Column(children: [
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, child) => Transform.scale(scale: _pulseAnim.value, child: child),
              child: ShaderMask(
                shaderCallback: (b) => const LinearGradient(colors: [AppTheme.accent, AppTheme.accentAlt]).createShader(b),
                child: const Text('DODGE', style: TextStyle(fontSize: 66, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -2)),
              ),
            ),
            const Text('RUSH', style: TextStyle(fontSize: 66, fontWeight: FontWeight.w900, color: AppTheme.textSecondary, letterSpacing: 8, height: 0.8)),
          ]),

          const SizedBox(height: 20),

          // Best score
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.accent.withOpacity(0.2))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.emoji_events_rounded, color: AppTheme.coinColor, size: 18),
              const SizedBox(width: 8),
              Text('BEST: ${settings.bestScore}', style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w700, letterSpacing: 1, fontSize: 14)),
            ]),
          ),

          const Spacer(),

          // Play button
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, child) => Container(
              width: 200, height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.accent, AppTheme.accentAlt], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [BoxShadow(color: AppTheme.accent.withOpacity(0.35 + _pulseCtrl.value * 0.2), blurRadius: 18 + _pulseCtrl.value * 12, spreadRadius: 1)],
              ),
              child: child,
            ),
            child: GestureDetector(
              onTap: () => Navigator.push(context, PageRouteBuilder(
                pageBuilder: (_, __, ___) => const GameScreen(),
                transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
                transitionDuration: const Duration(milliseconds: 300),
              )),
              child: const Center(child: Text('PLAY', style: TextStyle(color: AppTheme.bg, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 4))),
            ),
          ),

          const SizedBox(height: 28),

          // Bottom buttons
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _BottomBtn(icon: Icons.storefront_rounded, label: 'SHOP', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopScreen()))),
            const SizedBox(width: 16),
            _BottomBtn(icon: Icons.leaderboard_rounded, label: 'STATS', onTap: () => _showStats(context, settings)),
          ]),

          const SizedBox(height: 40),
        ])),
      ]),
    );
  }

  void _showStats(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('YOUR STATS', style: TextStyle(color: AppTheme.accent, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 24),
          _StatRow(icon: Icons.emoji_events_rounded, label: 'Best Score', value: '${settings.bestScore}', color: AppTheme.coinColor),
          _StatRow(icon: Icons.sports_esports_rounded, label: 'Games Played', value: '${settings.gamesPlayed}', color: AppTheme.accent),
          _StatRow(icon: Icons.monetization_on_rounded, label: 'Total Coins', value: '${settings.totalCoins}', color: AppTheme.coinColor),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _BottomBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _BottomBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.textSecondary.withOpacity(0.2))),
        child: Row(children: [
          Icon(icon, color: AppTheme.textSecondary, size: 17),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w700, letterSpacing: 1, fontSize: 13)),
        ]),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _StatRow({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
        const Spacer(),
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _BgPainter extends CustomPainter {
  final double angle;
  _BgPainter(this.angle);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 0.5..color = AppTheme.accent.withOpacity(0.03);
    const step = 44.0;
    for (double x = 0; x < size.width; x += step) canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (double y = 0; y < size.height; y += step) canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    paint
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80)
      ..color = AppTheme.accent.withOpacity(0.06);
    canvas.drawCircle(Offset(size.width * 0.5 + cos(angle) * size.width * 0.25, size.height * 0.3 + sin(angle * 0.7) * 80), 180, paint);
    paint.color = AppTheme.accentAlt.withOpacity(0.05);
    canvas.drawCircle(Offset(size.width * 0.3 + cos(angle + 2) * 80, size.height * 0.7), 150, paint);
  }

  @override
  bool shouldRepaint(_BgPainter old) => true;
}
