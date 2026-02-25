import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../models/game_models.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../utils/safe_color.dart';
import 'game_screen.dart';
import 'shop_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _bgCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _shipCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _shipAnim;

  @override
  void initState() {
    super.initState();
    _bgCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 20))
          ..repeat();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _shipCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _shipAnim = Tween<double>(begin: -6.0, end: 6.0)
        .animate(CurvedAnimation(parent: _shipCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _pulseCtrl.dispose();
    _shipCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(children: [
        // Animated starfield background
        AnimatedBuilder(
          animation: _bgCtrl,
          builder: (_, __) => CustomPaint(
            size: size,
            painter: _SpaceBgPainter(_bgCtrl.value),
          ),
        ),

        SafeArea(
            child: Column(children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              // Coins
              _GlassChip(
                child: Row(children: [
                  const Icon(Icons.circle, color: AppTheme.coinColor, size: 10),
                  const SizedBox(width: 6),
                  Text('${settings.totalCoins}',
                      style: const TextStyle(
                          color: AppTheme.coinColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 15)),
                ]),
              ),
              const Spacer(),
              // Best
              _GlassChip(
                child: Row(children: [
                  const Icon(Icons.emoji_events_rounded,
                      color: AppTheme.warning, size: 14),
                  const SizedBox(width: 6),
                  Text('${settings.bestScore}',
                      style: const TextStyle(
                          color: AppTheme.warning,
                          fontWeight: FontWeight.w900,
                          fontSize: 15)),
                ]),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen())),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.card.o(0.8),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: const Icon(Icons.settings_outlined,
                      color: AppTheme.textSecondary, size: 18),
                ),
              ),
            ]),
          ),

          const Spacer(),

          // Title block
          Column(children: [
            const Text(
              'STELLAR',
              style: TextStyle(
                color: AppTheme.textDim,
                fontSize: 14,
                letterSpacing: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, child) =>
                  Transform.scale(scale: _pulseAnim.value, child: child),
              child: ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [
                    AppTheme.accent,
                    Color(0xFF00E5FF),
                    AppTheme.accentAlt
                  ],
                ).createShader(b),
                child: const Text(
                  'DRIFT',
                  style: TextStyle(
                    fontSize: 88,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -4,
                    height: 0.9,
                  ),
                ),
              ),
            ),
          ]),

          const SizedBox(height: 40),

          // Animated ship preview
          AnimatedBuilder(
            animation: _shipAnim,
            builder: (_, __) => Transform.translate(
              offset: Offset(0, _shipAnim.value),
              child: SizedBox(
                width: 100,
                height: 110,
                child: CustomPaint(
                    painter: _ShipPreviewPainter(
                        _bgCtrl.value * 2 * pi, settings.selectedSkin)),
              ),
            ),
          ),

          const Spacer(),

          // PLAY button
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, child) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.o(0.3 + _pulseCtrl.value * 0.2),
                      blurRadius: 24 + _pulseCtrl.value * 16,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: GestureDetector(
              onTap: () => Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const GameScreen(),
                    transitionsBuilder: (_, a, __, c) =>
                        FadeTransition(opacity: a, child: c),
                    transitionDuration: const Duration(milliseconds: 500),
                  )),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.accent, Color(0xFF00D4FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.rocket_launch_rounded,
                        color: AppTheme.bg, size: 22),
                    SizedBox(width: 12),
                    Text('LAUNCH',
                        style: TextStyle(
                          color: AppTheme.bg,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                        )),
                  ]),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Bottom buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(children: [
              Expanded(
                  child: _SecondaryBtn(
                icon: Icons.storefront_rounded,
                label: 'HANGAR',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ShopScreen())),
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: _SecondaryBtn(
                icon: Icons.leaderboard_rounded,
                label: 'STATS',
                onTap: () => _showStats(context, settings),
              )),
            ]),
          ),

          const SizedBox(height: 36),
        ])),
      ]),
    );
  }

  void _showStats(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 36,
              height: 3,
              decoration: BoxDecoration(
                  color: AppTheme.cardBorder,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text('MISSION LOG',
              style: TextStyle(
                  color: AppTheme.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4)),
          const SizedBox(height: 24),
          _StatRow(
              icon: Icons.emoji_events_rounded,
              label: 'Best Score',
              value: '${settings.bestScore}',
              color: AppTheme.warning),
          _StatRow(
              icon: Icons.rocket_launch_rounded,
              label: 'Missions Flown',
              value: '${settings.gamesPlayed}',
              color: AppTheme.accent),
          _StatRow(
              icon: Icons.circle,
              label: 'Credits Earned',
              value: '${settings.totalCoins}',
              color: AppTheme.coinColor),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  final Widget child;
  const _GlassChip({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.card.o(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: child,
    );
  }
}

class _SecondaryBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SecondaryBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: AppTheme.textSecondary, size: 16),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  fontSize: 12)),
        ]),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _StatRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 12),
        Text(label,
            style:
                const TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 18, fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

// ─── Background Painter ──────────────────────────────────────────────────────

class _SpaceBgPainter extends CustomPainter {
  final double t;
  _SpaceBgPainter(this.t);

  static final _rng = Random(1337);
  static final List<List<double>> _staticStars = List.generate(
    120,
    (_) => [
      _rng.nextDouble(),
      _rng.nextDouble(),
      _rng.nextDouble() * 2.0,
      _rng.nextDouble()
    ],
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = AppTheme.bg);

    // Nebula glow — NO blur, layered circles at decreasing opacity
    final p = Paint()..style = PaintingStyle.fill;
    // Purple nebula
    p.color = AppTheme.purple.o(0.02 + sin(t * 2 * pi) * 0.008);
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.4), 280, p);
    p.color = AppTheme.purple.o(0.04 + sin(t * 2 * pi) * 0.012);
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.4), 200, p);
    p.color = AppTheme.purple.o(0.06 + sin(t * 2 * pi) * 0.02);
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.4), 120, p);
    // Blue-alt nebula
    p.color = AppTheme.accentAlt.o(0.02 + cos(t * 2 * pi * 0.7) * 0.006);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.55), 250, p);
    p.color = AppTheme.accentAlt.o(0.04 + cos(t * 2 * pi * 0.7) * 0.012);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.55), 180, p);
    p.color = AppTheme.accentAlt.o(0.05 + cos(t * 2 * pi * 0.7) * 0.015);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.55), 110, p);
    // Accent top
    p.color = AppTheme.accent.o(0.015);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.1), 220, p);
    p.color = AppTheme.accent.o(0.04);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.1), 150, p);

    // Stars
    final sp = Paint()..style = PaintingStyle.fill;
    for (final star in _staticStars) {
      final opacity =
          star[3] * (0.5 + sin(t * 2 * pi * 3 + star[0] * 20) * 0.3);
      sp.color = Colors.white.o(opacity.clamp(0.05, 0.9));
      canvas.drawCircle(Offset(star[0] * size.width, star[1] * size.height),
          star[2] * 0.8, sp);
    }
  }

  @override
  bool shouldRepaint(_SpaceBgPainter old) => true;
}

// ─── Ship Preview Painter ────────────────────────────────────────────────────

class _ShipPreviewPainter extends CustomPainter {
  final double t;
  final SkinType skin;
  _ShipPreviewPainter(this.t, this.skin);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.28;

    const skinColors = [
      Color(0xFF00FFD1),
      Color(0xFF4D7CFF),
      Color(0xFFFF6B2B),
      Color(0xFF8B5CF6),
      Color(0xFFFFD60A),
    ];
    final color = skinColors[skin.index % skinColors.length];
    final paint = Paint()..style = PaintingStyle.fill;

    // Engine glow
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    paint.color = color.o(0.4);
    canvas.drawCircle(Offset(cx, cy + r * 0.4), r * 0.7, paint);
    paint.maskFilter = null;

    // Ship body
    final bodyPath = Path();
    bodyPath.moveTo(cx, cy - r * 1.1);
    bodyPath.cubicTo(cx + r * 0.75, cy - r * 0.15, cx + r * 0.95, cy + r * 0.3,
        cx + r * 0.55, cy + r * 0.8);
    bodyPath.lineTo(cx + r * 0.55, cy + r * 1.0);
    bodyPath.lineTo(cx + r * 0.3, cy + r * 0.8);
    bodyPath.lineTo(cx, cy + r * 0.65);
    bodyPath.lineTo(cx - r * 0.3, cy + r * 0.8);
    bodyPath.lineTo(cx - r * 0.55, cy + r * 1.0);
    bodyPath.lineTo(cx - r * 0.55, cy + r * 0.8);
    bodyPath.cubicTo(cx - r * 0.95, cy + r * 0.3, cx - r * 0.75, cy - r * 0.15,
        cx, cy - r * 1.1);
    bodyPath.close();

    paint.shader = LinearGradient(
      colors: [Colors.white.o(0.9), color, color.o(0.5)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(cx - r, cy - r * 1.2, r * 2, r * 2.4));
    canvas.drawPath(bodyPath, paint);
    paint.shader = null;

    // Cockpit
    final cockpit = Path();
    cockpit.moveTo(cx, cy - r * 0.65);
    cockpit.cubicTo(cx + r * 0.3, cy - r * 0.25, cx + r * 0.3, cy + r * 0.1, cx,
        cy + r * 0.2);
    cockpit.cubicTo(cx - r * 0.3, cy + r * 0.1, cx - r * 0.3, cy - r * 0.25, cx,
        cy - r * 0.65);
    paint.shader = RadialGradient(
      colors: [
        AppTheme.accentAlt.o(0.9),
        AppTheme.accentAlt.o(0.3),
        Colors.black.o(0.7)
      ],
      center: const Alignment(0, -0.3),
    ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawPath(cockpit, paint);
    paint.shader = null;

    // Flames
    final flicker = sin(t * 8) * 0.2 + 0.8;
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    paint.shader = LinearGradient(
      colors: [Colors.white, color, color.o(0)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(
        Rect.fromLTWH(cx - r * 0.25, cy + r * 0.7, r * 0.5, r * 0.8));
    final flame = Path()
      ..moveTo(cx - r * 0.22, cy + r * 0.85)
      ..quadraticBezierTo(
          cx, cy + r * (1.5 + flicker * 0.3), cx + r * 0.22, cy + r * 0.85)
      ..close();
    canvas.drawPath(flame, paint);
    paint.shader = null;
    paint.maskFilter = null;
  }

  @override
  bool shouldRepaint(_ShipPreviewPainter old) => true;
}
