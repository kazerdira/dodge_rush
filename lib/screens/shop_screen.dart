import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../utils/safe_color.dart';
import '../models/game_models.dart';
import '../game/ships/ships.dart';

const _skinNames = [
  'PHANTOM',
  'NOVA',
  'INFERNO',
  'SPECTER',
  'TITAN',
  'SOVEREIGN'
];
const _skinSubs = [
  'Stealth Interceptor',
  'Advanced Delta Fighter',
  'Heavy Muscle Bomber',
  'Bio-mechanical Ghost',
  'Massive Dreadnought',
  'Imperial Strike Cruiser'
];
const _skinLore = [
  'Hyper-sleek needle. Multi-layered armor with cockpit glass glare.',
  'Wide aggressive delta wings. Central fuselage with glowing vents.',
  'Flat-nosed bruiser. Dark armor plating and forward-swept canards.',
  'Organic alien curves. Energy veins pulse beneath the hull.',
  'Blocky carrier. Structural ribs, tiny windows, four-engine wall.',
  'Ivory-white hull with gold spine. Massive swept wings and twin nacelles.',
];
const _skinPrices = [0, 100, 200, 350, 600, 900];

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
    _animCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
            onPressed: () => Navigator.pop(context)),
        title: const Text('HANGAR',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
                fontSize: 18)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.coinColor.o(0.3))),
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
        ],
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Text('CHOOSE YOUR CRAFT — EACH FLIES DIFFERENTLY',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 9,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w700)),
        ),

        Expanded(
            child: ListView.builder(
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
                  settings.unlockSkin(i);
                  settings.selectSkin(i);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${_skinNames[i]} acquired!',
                        style: const TextStyle(color: Colors.white)),
                    backgroundColor: AppTheme.accent,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Insufficient credits',
                        style: TextStyle(color: Colors.white)),
                    backgroundColor: AppTheme.danger,
                    behavior: SnackBarBehavior.floating,
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
                    border: Border.all(
                        color: selected ? color : AppTheme.cardBorder,
                        width: selected ? 1.5 : 1),
                    boxShadow: selected
                        ? [BoxShadow(color: color.o(0.18), blurRadius: 16)]
                        : null,
                  ),
                  child: Row(children: [
                    // Ship preview
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: CustomPaint(
                          painter: _ShipRowPainter(
                              skin, _animCtrl.value * 2 * pi, selected)),
                    ),

                    const SizedBox(width: 4),

                    // Info
                    Expanded(
                        child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 4),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text(_skinNames[i],
                                  style: TextStyle(
                                      color: unlocked
                                          ? AppTheme.textPrimary
                                          : AppTheme.textSecondary,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      letterSpacing: 1.5)),
                              const SizedBox(width: 8),
                              if (selected)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: color.o(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: color.o(0.5))),
                                  child: Text('ACTIVE',
                                      style: TextStyle(
                                          color: color,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.5)),
                                ),
                            ]),
                            const SizedBox(height: 2),
                            Text(_skinSubs[i],
                                style: TextStyle(
                                    color: color.o(0.7),
                                    fontSize: 10,
                                    letterSpacing: 1)),
                            const SizedBox(height: 6),
                            Text(_skinLore[i],
                                style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11,
                                    height: 1.4)),
                            const SizedBox(height: 8),
                            // Trail style badge
                            _TrailBadge(skin: skin),
                          ]),
                    )),

                    // Price / status
                    Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: unlocked
                          ? Icon(Icons.check_circle_rounded,
                              color: selected ? color : AppTheme.textSecondary,
                              size: 22)
                          : Column(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.lock_rounded,
                                  color: AppTheme.textSecondary, size: 16),
                              const SizedBox(height: 4),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.circle,
                                    color: AppTheme.coinColor, size: 8),
                                const SizedBox(width: 3),
                                Text('$price',
                                    style: const TextStyle(
                                        color: AppTheme.coinColor,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13)),
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
              border: Border.all(color: AppTheme.accent.o(0.2)),
            ),
            child: Row(children: [
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: AppTheme.accent.o(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.block,
                      color: AppTheme.accent, size: 20)),
              const SizedBox(width: 14),
              const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('AD-FREE PILOT',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 13)),
                    SizedBox(height: 2),
                    Text('One purchase — fly forever uninterrupted',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11)),
                  ])),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(7)),
                  child: const Text('\$1.99',
                      style: TextStyle(
                          color: AppTheme.bg,
                          fontWeight: FontWeight.w900,
                          fontSize: 12))),
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
      case TrailStyle.clean:
        label = '— CLEAN ION TRAIL';
        break;
      case TrailStyle.scatter:
        label = '✦ SCATTER SPARKS';
        break;
      case TrailStyle.fire:
        label = '▲ FIRE CONE';
        break;
      case TrailStyle.ghost:
        label = '◈ GHOST ECHOES';
        break;
      case TrailStyle.wide:
        label = '||| TRIPLE COLUMN';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.o(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.o(0.25)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color.o(0.8),
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 1)),
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
    final r = size.width * 0.22;
    final color = skinColor(skin);

    // Glow behind selected ship
    if (selected) {
      final paint = Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..color = color.o(0.35);
      canvas.drawCircle(Offset(cx, cy), r + 8, paint);
    }

    // Translate to center so the ship functions (which draw at origin) work
    canvas.save();
    canvas.translate(cx, cy);

    // Draw the actual ship using the same functions as the game
    switch (skin) {
      case SkinType.phantom:
        drawPhantomShip(canvas, r, color, t);
        break;
      case SkinType.nova:
        drawNovaShip(canvas, r, color, t);
        break;
      case SkinType.inferno:
        drawInfernoShip(canvas, r, color, t);
        break;
      case SkinType.specter:
        drawSpecterShip(canvas, r, color, t);
        break;
      case SkinType.titan:
        drawTitanShip(canvas, r, color, t);
        break;
      case SkinType.sovereign:
        drawSovereignShip(canvas, r, color, t);
        break;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShipRowPainter old) => true;
}
