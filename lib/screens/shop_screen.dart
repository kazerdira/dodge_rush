import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../models/game_models.dart';

const _skinNames = ['PHANTOM', 'NOVA', 'INFERNO', 'SPECTER', 'TITAN'];
const _skinSubs = ['Stealth Interceptor', 'Delta Striker', 'Assault Wedge', 'Ghost Cruiser', 'Heavy Carrier'];
const _skinLore = [
  'Needle-thin. Leaves a clean ion trail. Built for precision.',
  'Wide delta wings. Sparks fly sideways. Pure aggression.',
  'Armored wedge. Three-column fire cone. Burns everything.',
  'Jagged silhouette. Leaves ghost echoes in its wake.',
  'Massive armored hull. Triple engine columns. Unstoppable.',
];
const _skinPrices = [0, 100, 200, 350, 600];

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> with TickerProviderStateMixin {
  late AnimationController _animCtrl;
  int _previewSkin = -1; // which card is being hovered/focused

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() { _animCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary), onPressed: () => Navigator.pop(context)),
        title: const Text('HANGAR', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w900, letterSpacing: 6, fontSize: 18)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: AppTheme.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.coinColor.withOpacity(0.3))),
            child: Row(children: [
              const Icon(Icons.circle, color: AppTheme.coinColor, size: 10),
              const SizedBox(width: 6),
              Text('${settings.totalCoins}', style: const TextStyle(color: AppTheme.coinColor, fontWeight: FontWeight.w900, fontSize: 15)),
            ]),
          ),
        ],
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Text('CHOOSE YOUR CRAFT — EACH FLIES DIFFERENTLY', style: TextStyle(color: AppTheme.textSecondary, fontSize: 9, letterSpacing: 3, fontWeight: FontWeight.w700)),
        ),

        Expanded(child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: SkinType.values.length,
          itemBuilder: (context, i) {
            final skin = SkinType.values[i];
            final color = skinColor(skin);
            final unlocked = settings.unlockedSkins.contains(i);
            final selected = settings.selectedSkinIndex == i;
            final price = _skinPrices[i];

            return GestureDetector(
              onTap: () {
                if (unlocked) {
                  settings.selectSkin(i);
                } else if (settings.spendCoins(price)) {
                  settings.unlockSkin(i); settings.selectSkin(i);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${_skinNames[i]} acquired!', style: const TextStyle(color: Colors.white)),
                    backgroundColor: AppTheme.accent,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Insufficient credits', style: TextStyle(color: Colors.white)),
                    backgroundColor: AppTheme.danger, behavior: SnackBarBehavior.floating,
                  ));
                }
              },
              child: AnimatedBuilder(
                animation: _animCtrl,
                builder: (_, __) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: selected ? color : AppTheme.cardBorder, width: selected ? 1.5 : 1),
                    boxShadow: selected ? [BoxShadow(color: color.withOpacity(0.18), blurRadius: 16)] : null,
                  ),
                  child: Row(children: [
                    // Ship preview
                    SizedBox(
                      width: 90, height: 90,
                      child: CustomPaint(painter: _ShipRowPainter(skin, _animCtrl.value * 2 * pi, selected)),
                    ),

                    const SizedBox(width: 4),

                    // Info
                    Expanded(child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(_skinNames[i], style: TextStyle(color: unlocked ? AppTheme.textPrimary : AppTheme.textSecondary, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.5)),
                          const SizedBox(width: 8),
                          if (selected) Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.5))),
                            child: Text('ACTIVE', style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                          ),
                        ]),
                        const SizedBox(height: 2),
                        Text(_skinSubs[i], style: TextStyle(color: color.withOpacity(0.7), fontSize: 10, letterSpacing: 1)),
                        const SizedBox(height: 6),
                        Text(_skinLore[i], style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.4)),
                        const SizedBox(height: 8),
                        // Trail style badge
                        _TrailBadge(skin: skin),
                      ]),
                    )),

                    // Price / status
                    Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: unlocked
                          ? Icon(Icons.check_circle_rounded, color: selected ? color : AppTheme.textSecondary, size: 22)
                          : Column(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.lock_rounded, color: AppTheme.textSecondary, size: 16),
                              const SizedBox(height: 4),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.circle, color: AppTheme.coinColor, size: 8),
                                const SizedBox(width: 3),
                                Text('$price', style: const TextStyle(color: AppTheme.coinColor, fontWeight: FontWeight.w900, fontSize: 13)),
                              ]),
                            ]),
                    ),
                  ]),
                ),
              ),
            );
          },
        )),

        // Remove ads card
        Padding(
          padding: const EdgeInsets.all(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
            ),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.block, color: AppTheme.accent, size: 20)),
              const SizedBox(width: 14),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('AD-FREE PILOT', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w900, fontSize: 13)),
                SizedBox(height: 2),
                Text('One purchase — fly forever uninterrupted', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(7)), child: const Text('\$1.99', style: TextStyle(color: AppTheme.bg, fontWeight: FontWeight.w900, fontSize: 12))),
            ]),
          ),
        ),
      ]),
    );
  }
}

// Trail style badge for each skin
class _TrailBadge extends StatelessWidget {
  final SkinType skin;
  const _TrailBadge({required this.skin});

  @override
  Widget build(BuildContext context) {
    final trail = skinTrail(skin);
    final color = skinColor(skin);
    String label;
    switch (trail) {
      case TrailStyle.clean:   label = '— CLEAN ION TRAIL'; break;
      case TrailStyle.scatter: label = '✦ SCATTER SPARKS'; break;
      case TrailStyle.fire:    label = '▲ FIRE CONE'; break;
      case TrailStyle.ghost:   label = '◈ GHOST ECHOES'; break;
      case TrailStyle.wide:    label = '||| TRIPLE COLUMN'; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
    );
  }
}

// ─── Ship Row Painters (one per skin) ───────────────────────────────────────

class _ShipRowPainter extends CustomPainter {
  final SkinType skin;
  final double t;
  final bool selected;
  _ShipRowPainter(this.skin, this.t, this.selected);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.24;
    final color = skinColor(skin);
    final paint = Paint()..style = PaintingStyle.fill;

    // Glow
    if (selected) {
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      paint.color = color.withOpacity(0.35);
      canvas.drawCircle(Offset(cx, cy), r + 8, paint);
      paint.maskFilter = null;
    }

    _drawMiniShip(canvas, cx, cy, r, color, skin, t, paint);

    // Engine flame
    final flicker = sin(t * 4) * 0.2 + 0.8;
    paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    paint.shader = LinearGradient(colors: [Colors.white, color, color.withOpacity(0)], begin: Alignment.topCenter, end: Alignment.bottomCenter)
        .createShader(Rect.fromLTWH(cx - r * 0.2, cy + r * 0.7, r * 0.4, r * 0.7 * flicker));
    final flame = Path()
      ..moveTo(cx - r * 0.18, cy + r * 0.75)
      ..quadraticBezierTo(cx, cy + r * (1.4 + flicker * 0.25), cx + r * 0.18, cy + r * 0.75)
      ..close();
    canvas.drawPath(flame, paint);
    paint.shader = null; paint.maskFilter = null;
  }

  void _drawMiniShip(Canvas canvas, double cx, double cy, double r, Color color, SkinType skin, double t, Paint paint) {
    switch (skin) {
      case SkinType.phantom:
        // Narrow interceptor
        final body = Path()
          ..moveTo(cx, cy - r * 1.2)
          ..cubicTo(cx + r * 0.5, cy - r * 0.1, cx + r * 0.65, cy + r * 0.5, cx + r * 0.35, cy + r * 0.9)
          ..lineTo(cx, cy + r * 0.7)..lineTo(cx - r * 0.35, cy + r * 0.9)
          ..cubicTo(cx - r * 0.65, cy + r * 0.5, cx - r * 0.5, cy - r * 0.1, cx, cy - r * 1.2)..close();
        paint.shader = LinearGradient(colors: [Colors.white.withOpacity(0.9), color], begin: Alignment.topCenter, end: Alignment.bottomCenter).createShader(Rect.fromLTWH(cx - r, cy - r * 1.2, r * 2, r * 2.2));
        canvas.drawPath(body, paint); paint.shader = null;
        break;

      case SkinType.nova:
        // Wide delta
        final body = Path()
          ..moveTo(cx, cy - r * 0.95)..lineTo(cx + r * 1.1, cy + r * 0.65)
          ..lineTo(cx + r * 0.6, cy + r * 0.85)..lineTo(cx, cy + r * 0.55)
          ..lineTo(cx - r * 0.6, cy + r * 0.85)..lineTo(cx - r * 1.1, cy + r * 0.65)..close();
        paint.shader = RadialGradient(colors: [Colors.white.withOpacity(0.85), color, color.withOpacity(0.3)], center: const Alignment(0, -0.5)).createShader(Rect.fromLTWH(cx - r * 1.2, cy - r, r * 2.4, r * 2));
        canvas.drawPath(body, paint); paint.shader = null;
        break;

      case SkinType.inferno:
        // Chunky wedge
        final body = Path()
          ..moveTo(cx, cy - r * 0.85)..lineTo(cx + r * 0.8, cy - r * 0.05)
          ..lineTo(cx + r * 0.95, cy + r * 0.55)..lineTo(cx + r * 0.55, cy + r * 0.9)
          ..lineTo(cx, cy + r * 0.7)..lineTo(cx - r * 0.55, cy + r * 0.9)
          ..lineTo(cx - r * 0.95, cy + r * 0.55)..lineTo(cx - r * 0.8, cy - r * 0.05)..close();
        paint.shader = LinearGradient(colors: [const Color(0xFFFFCC88), color, const Color(0xFFCC2200)], begin: Alignment.topCenter, end: Alignment.bottomCenter).createShader(Rect.fromLTWH(cx - r, cy - r, r * 2, r * 2));
        canvas.drawPath(body, paint); paint.shader = null;
        break;

      case SkinType.specter:
        // Jagged ghost
        final ghostPulse = sin(t * 3) * 0.12 + 0.88;
        final body = Path()
          ..moveTo(cx, cy - r * 1.05)..lineTo(cx + r * 0.4, cy - r * 0.35)
          ..lineTo(cx + r * 0.85, cy - r * 0.15)..lineTo(cx + r * 0.45, cy + r * 0.25)
          ..lineTo(cx + r * 0.75, cy + r * 0.75)..lineTo(cx + r * 0.25, cy + r * 0.55)
          ..lineTo(cx, cy + r * 0.8)..lineTo(cx - r * 0.15, cy + r * 0.45)
          ..lineTo(cx - r * 0.55, cy + r * 0.85)..lineTo(cx - r * 0.4, cy + r * 0.25)
          ..lineTo(cx - r * 0.95, cy + r * 0.05)..lineTo(cx - r * 0.45, cy - r * 0.28)..close();
        paint.color = color.withOpacity(0.65 * ghostPulse);
        canvas.drawPath(body, paint);
        paint.color = color.withOpacity(0.9 * ghostPulse); paint.style = PaintingStyle.stroke; paint.strokeWidth = 1.2;
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
        canvas.drawPath(body, paint);
        paint.maskFilter = null; paint.style = PaintingStyle.fill;
        break;

      case SkinType.titan:
        // Boxy hull
        final hull = Path()
          ..moveTo(cx - r * 0.28, cy - r * 1.05)..lineTo(cx + r * 0.28, cy - r * 1.05)
          ..lineTo(cx + r * 0.78, cy - r * 0.65)..lineTo(cx + r * 1.0, cy - r * 0.15)
          ..lineTo(cx + r * 1.0, cy + r * 0.6)..lineTo(cx + r * 0.65, cy + r * 1.0)
          ..lineTo(cx - r * 0.65, cy + r * 1.0)..lineTo(cx - r * 1.0, cy + r * 0.6)
          ..lineTo(cx - r * 1.0, cy - r * 0.15)..lineTo(cx - r * 0.78, cy - r * 0.65)..close();
        paint.shader = LinearGradient(colors: [const Color(0xFFFFE566), color, const Color(0xFF886600)], begin: Alignment.topCenter, end: Alignment.bottomCenter).createShader(Rect.fromLTWH(cx - r, cy - r * 1.1, r * 2, r * 2.2));
        canvas.drawPath(hull, paint); paint.shader = null;
        // Panel lines
        paint.color = Colors.black.withOpacity(0.25); paint.strokeWidth = 0.8; paint.style = PaintingStyle.stroke;
        canvas.drawLine(Offset(cx - r * 0.75, cy - r * 0.4), Offset(cx - r * 0.75, cy + r * 0.7), paint);
        canvas.drawLine(Offset(cx + r * 0.75, cy - r * 0.4), Offset(cx + r * 0.75, cy + r * 0.7), paint);
        canvas.drawLine(Offset(cx - r * 0.85, cy + r * 0.1), Offset(cx + r * 0.85, cy + r * 0.1), paint);
        paint.style = PaintingStyle.fill;
        break;
    }

    // Cockpit on all
    if (skin != SkinType.specter) {
      paint.color = AppTheme.accentAlt.withOpacity(0.75);
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy - r * 0.35), width: r * 0.5, height: r * 0.35), paint);
    }
  }

  @override
  bool shouldRepaint(_ShipRowPainter old) => true;
}
