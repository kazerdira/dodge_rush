import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import 'game_screen.dart';
import 'home_screen.dart';

class GameOverScreen extends StatefulWidget {
  final int score;
  final int coins;
  final int maxCombo;

  const GameOverScreen({
    super.key,
    required this.score,
    required this.coins,
    this.maxCombo = 0,
  });

  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen> with TickerProviderStateMixin {
  late AnimationController _enterCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _bgCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _pulseAnim;
  bool _isNewBest = false;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat();

    _fadeAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutBack));
    _pulseAnim = Tween<double>(begin: 0.96, end: 1.04)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsProvider>();
      setState(() => _isNewBest = widget.score > 0 && widget.score >= settings.bestScore);
    });
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
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
        // Background
        AnimatedBuilder(
          animation: _bgCtrl,
          builder: (_, __) => CustomPaint(size: size, painter: _GameOverBgPainter(_bgCtrl.value)),
        ),

        SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // New best banner
                    if (_isNewBest) ...[
                      ScaleTransition(
                        scale: _pulseAnim,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD60A), Color(0xFFFF8F00)],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.emoji_events_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text('NEW RECORD', style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 4,
                            )),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Mission failed text
                    const Text('MISSION', style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      letterSpacing: 8,
                      fontWeight: FontWeight.w700,
                    )),
                    const SizedBox(height: 4),
                    ShaderMask(
                      shaderCallback: (b) => const LinearGradient(
                        colors: [AppTheme.danger, Color(0xFFFF8C42)],
                      ).createShader(b),
                      child: const Text('FAILED', style: TextStyle(
                        color: Colors.white,
                        fontSize: 72,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2,
                        height: 1,
                      )),
                    ),

                    const SizedBox(height: 32),

                    // Score card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Column(children: [
                        const Text('DISTANCE SCORE', style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                          letterSpacing: 4,
                        )),
                        const SizedBox(height: 8),
                        Text('${widget.score}', style: const TextStyle(
                          color: AppTheme.accent,
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          letterSpacing: -2,
                        )),
                        Divider(color: AppTheme.cardBorder, height: 28),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                          _Stat(label: 'BEST', value: '${settings.bestScore}', color: AppTheme.warning, icon: Icons.emoji_events_rounded),
                          _Stat(label: 'CREDITS', value: '+${widget.coins}', color: AppTheme.coinColor, icon: Icons.circle),
                          _Stat(label: 'COMBO', value: 'x${widget.maxCombo}', color: AppTheme.purple, icon: Icons.local_fire_department),
                        ]),
                      ]),
                    ),

                    const SizedBox(height: 24),

                    // Revive button
                    GestureDetector(
                      onTap: () => _showReviveDialog(context),
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.coinColor.withOpacity(0.6), width: 1.5),
                          color: AppTheme.coinColor.withOpacity(0.07),
                        ),
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.play_circle_outline, color: AppTheme.coinColor, size: 20),
                          SizedBox(width: 10),
                          Text('WATCH AD — CONTINUE MISSION', style: TextStyle(
                            color: AppTheme.coinColor,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            fontSize: 12,
                          )),
                        ]),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Play again
                    GestureDetector(
                      onTap: () => Navigator.pushReplacement(context, _fade(const GameScreen())),
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.accent, Color(0xFF00D4FF)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.rocket_launch_rounded, color: AppTheme.bg, size: 18),
                          SizedBox(width: 10),
                          Text('NEW MISSION', style: TextStyle(
                            color: AppTheme.bg,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                          )),
                        ])),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Home
                    GestureDetector(
                      onTap: () => Navigator.pushAndRemoveUntil(context, _fade(const HomeScreen()), (_) => false),
                      child: Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppTheme.card,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: const Center(child: Text('RETURN TO BASE', style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                        ))),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  PageRouteBuilder _fade(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
    transitionDuration: const Duration(milliseconds: 400),
  );

  void _showReviveDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Continue Mission?', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800)),
        content: const Text(
          'Watch a short ad to continue from where you crashed.\n\nAdd your AdMob IDs in ad_manager.dart to activate.',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: TextStyle(color: AppTheme.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w900))),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _Stat({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9, letterSpacing: 2)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16)),
    ]);
  }
}

class _GameOverBgPainter extends CustomPainter {
  final double t;
  _GameOverBgPainter(this.t);

  static final _rng = Random(999);
  static final List<List<double>> _stars = List.generate(
    100,
    (_) => [_rng.nextDouble(), _rng.nextDouble(), _rng.nextDouble() * 1.5 + 0.3, _rng.nextDouble()],
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = AppTheme.bg);

    final p = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);
    p.color = AppTheme.danger.withOpacity(0.04 + sin(t * 2 * pi) * 0.015);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.3), 200, p);
    p.color = AppTheme.purple.withOpacity(0.04);
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.7), 160, p);
    p.maskFilter = null;

    final sp = Paint()..style = PaintingStyle.fill;
    for (final star in _stars) {
      sp.color = Colors.white.withOpacity((star[3] * 0.5).clamp(0.05, 0.5));
      canvas.drawCircle(Offset(star[0] * size.width, star[1] * size.height), star[2] * 0.6, sp);
    }
  }

  @override
  bool shouldRepaint(_GameOverBgPainter old) => true;
}
